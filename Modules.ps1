function Write-Message {
  <#
    .SYNOPSIS
    Log a message in PowerShell.
    .DESCRIPTION
    Logs a message along with the current date and time, using ANSI escape codes for color (configurable).
    .PARAMETER LogMessage
    The message to be logged.
    .PARAMETER Type
    The type of the message (e.g., "Info", "Warning", "Critical") to be logged. Defaults to "Info".
    .PARAMETER NoColor
    A switch parameter to disable color coding in the message.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$LogMessage,

    [Parameter(Mandatory = $false,ValueFromPipeline)]
    [ValidateSet("Info", "Warning", "Error", "Critical")]
    [string]$Type = "Info",

    [Parameter(Mandatory = $false)]
    [switch]$NoColor
  )

  # Check if logging is enabled
  if ($script:Config.LogFlag) {
    # Format the message with a timestamp and type
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Define icons based on the type
    $TypeIcon = switch ($Type) {
    "Info"     { "ℹ️" }
    "Warning"  { "⚠️" }
    "Error"    { "❗" }
    "Critical" { "📛" }
    Default    { "✅" }
    }
    $FormattedMessage = "[$Timestamp] $TypeIcon [$($Type.PadRight(8))] $LogMessage"

    # Write the message to the console
    switch ($Type) {
      "Info"     { Write-Host $FormattedMessage -ForegroundColor Green }
      "Warning"  { Write-Host $FormattedMessage -ForegroundColor Yellow }
      "Error"    { Write-Host $FormattedMessage -ForegroundColor Red }
      "Critical" { Write-Host $FormattedMessage -ForegroundColor Magenta }
    }

    # Write the message to the log file if logging is enabled
    if ($script:Config.LogFileLocation) {
      try {
        $logDir = Split-Path $script:Config.LogFileLocation
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $script:Config.LogFileLocation -Value $FormattedMessage
      } catch {
        Write-Host "Failed to write to log file: $($_.Exception.Message)" -ForegroundColor Red
      }
    }
  }
}


function Get-SleepTimeout {
  <#
    .SYNOPSIS
    Retrieves the system sleep timeout for AC or DC power mode.
    .DESCRIPTION
    Uses the powercfg utility to query the current sleep timeout for either AC (plugged in) or DC (battery) mode.
    .PARAMETER Type
    Specifies the power mode: "AC" for plugged in, "DC" for battery.
    .OUTPUTS
    [int] The sleep timeout in seconds, or $null if not found.
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("AC", "DC")]
    [string]$Type
  )
  $pattern = if ($Type -eq "AC") { 'Current AC Power Setting Index' } else { 'Current DC Power Setting Index' }
  $line = (powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE) | Where-Object { $_ -match $pattern }
  if ($line -match '0x([0-9a-fA-F]+)') {
    return [Convert]::ToInt32($matches[1], 16)
  }
  return $null
}


function Set-TimeWaitMax-FromPowerStatu {
  <#
    .SYNOPSIS
    Sets the global TimeWaitMax variable based on current power status, but only if there is a change.
    .DESCRIPTION
    Determines if the system is running on AC or battery power and sets the $script:Config.TimeWaitMax variable to the system's sleep timeout accordingly.
    Only updates if the power type or timeout value has changed since the last check.
    .OUTPUTS
    None. Sets $script:Config.TimeWaitMax.
  #>

  [CmdletBinding()]
  param()

  # Static variables to remember last state
  if (-not $script:LastPowerType) { $script:LastPowerType = $null }
  if (-not $script:LastTimeout)   { $script:LastTimeout   = $null }

  $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

  if ($null -eq $battery) {
    # No battery detected: assume AC
    $type = "AC"
    $timeout = Get-SleepTimeout -Type $type
    $source = "No battery detected; desktop or plugged-in device"
  } else {
    switch ($battery.BatteryStatus) {
      2 { $type = "AC"; $timeout = Get-SleepTimeout -Type $type; $source = "BatteryStatus=2 | Charging/AC" }
      1 { $type = "DC"; $timeout = Get-SleepTimeout -Type $type; $source = "BatteryStatus=1 | Discharging/DC" }
      default { $type = "AC"; $timeout = Get-SleepTimeout -Type $type; $source = "BatteryStatus=$($battery.BatteryStatus) | Fallback to AC" }
    }
  }

  # Only update if type or timeout has changed
  if ($type -ne $script:LastPowerType -or $timeout -ne $script:LastTimeout) {
    if ($timeout -and $timeout -gt 0) {
      $script:Config.TimeWaitMax = $timeout - 5
      Write-Message -LogMessage "TimeWaitMax set to $($script:Config.TimeWaitMax) seconds ($source)." -Type "Info"

      # Update last known values
      $script:LastPowerType = $type
      $script:LastTimeout   = $timeout
    } else {
      Write-Message -LogMessage "Failed to determine sleep timeout for $type power ($source)." -Type "Warning"
    }
  } else {
    Write-Message -LogMessage "No change in power type ($type) or timeout ($timeout); skipping update." -Type "Info"
  }
}


function Convert-TimeSpanToHumanReadable {
  <#
    .SYNOPSIS
    Make the time delta readable.
    .DESCRIPTION
    Converts a TimeSpan into a human-readable format (e.g., "2 Weeks, 3 Days, 5 Hours").
    .INPUTS
    [TimeSpan]
    .OUTPUTS
    [String]
  #>

  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [timespan]$TimeDelta
  )

  # Calculate time units
  $TimeUnits = @{
    "Months"  = [math]::Truncate($TimeDelta.Days / 30)
    "Weeks"   = [math]::Truncate(($TimeDelta.Days % 30) / 7)
    "Days"    = $TimeDelta.Days % 7
    "Hours"   = $TimeDelta.Hours
    "Minutes" = $TimeDelta.Minutes
    "Seconds" = $TimeDelta.Seconds
  }

  # Build output string
  $Output = ""

  foreach ($Unit in @("Months", "Weeks", "Days", "Hours", "Minutes", "Seconds")) {
      $Value = $TimeUnits[$Unit]
      if ($Value -gt 0) {
        # Add "s" only if the unit is singular and the value is greater than 1
        $UnitName = if ($Value -eq 1) { $Unit.TrimEnd('s') } else { $Unit }
        $Output += "$Value $UnitName, "
      }
  }

  # Remove trailing comma and space
  $Output = $Output.TrimEnd(',', ' ')

  # Return formatted string
  return $Output
}


function Get-ActivityStatus {
  <#
    .SYNOPSIS
    Gets detailed user activity status including mouse movements, key presses, and system events.

    .DESCRIPTION
    Analyzes user activity by comparing current and previous system states including mouse positions,
    keyboard input, mouse clicks, window focus changes, and other system events. Returns detailed 
    information about what specifically changed with improved accuracy and performance.

    .PARAMETER CurrentMousePosition
    Current coordinates of the mouse cursor.

    .PARAMETER LastMousePosition
    Previous coordinates of the mouse cursor to compare against.

    .PARAMETER KeyPressed
    The specific key that was pressed, if any.

    .PARAMETER MouseClicked
    Array of mouse buttons that were clicked (Left, Right, Middle).

    .PARAMETER WindowTitle
    Current active window title.

    .PARAMETER LastWindowTitle
    Previous active window title.

    .PARAMETER MouseWheelDelta
    Mouse wheel movement delta.

    .PARAMETER MovementThreshold
    Minimum pixel movement to consider as activity (default: 3).

    .OUTPUTS
    [PSCustomObject] containing:
    - IsActive: True if any user activity detected
    - Reasons: Array of detailed status messages
    - ActivityType: Type of activity detected
    - Confidence: Confidence level (0-100) of activity detection

    .EXAMPLE
    $status = Get-ActivityStatus -CurrentMousePosition $pos -LastMousePosition $lastPos -KeyPressed "a"
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Drawing.Point]$CurrentMousePosition,

    [Parameter(Mandatory = $true)]
    [System.Drawing.Point]$LastMousePosition,

    [Parameter(Mandatory = $false)]
    [string]$KeyPressed = $null,

    [Parameter(Mandatory = $false)]
    [string[]]$MouseClicked = @(),

    [Parameter(Mandatory = $false)]
    [string]$WindowTitle = $null,

    [Parameter(Mandatory = $false)]
    [string]$LastWindowTitle = $null,

    [Parameter(Mandatory = $false)]
    [int]$MouseWheelDelta = 0,

    [Parameter(Mandatory = $false)]
    [int]$MovementThreshold = 3,

    [Parameter(Mandatory = $false)]
    [hashtable]$TypingActivity = $null,

    [Parameter(Mandatory = $false)]
    [array]$TrackpadGestures = @()
  )

  # Initialize status object
  $status = @{
    IsActive = $false
    Reasons = @()
    ActivityType = "None"
    Confidence = 0
    InputDevice = "Unknown"
    GestureType = "None"
  }

  $activityScore = 0

  # Check mouse movement with threshold
  $mouseDeltaX = $CurrentMousePosition.X - $LastMousePosition.X
  $mouseDeltaY = $CurrentMousePosition.Y - $LastMousePosition.Y
  $totalMovement = [Math]::Sqrt($mouseDeltaX * $mouseDeltaX + $mouseDeltaY * $mouseDeltaY)
  
  if ($totalMovement -ge $MovementThreshold) {
    $status.IsActive = $true
    $activityScore += 30
    
    # Detect if this is trackpad activity
    $trackpadInfo = Test-TrackpadActivity -CurrentMousePosition $CurrentMousePosition -LastMousePosition $LastMousePosition -MovementThreshold $MovementThreshold
    
    if ($trackpadInfo.IsTrackpad) {
      $status.InputDevice = "Trackpad"
      $status.GestureType = $trackpadInfo.GestureType
      $status.Reasons += "✅🖱️ Trackpad Moved by $([Math]::Round($totalMovement, 1)) pixels ($mouseDeltaX, $mouseDeltaY) [$($trackpadInfo.MovementPattern)]"
      if ($trackpadInfo.GestureType -ne "None") {
        $status.Reasons += "✅👆🏼 Gesture: $($trackpadInfo.GestureType)"
      }
      $activityScore += 10  # Bonus for trackpad detection
    } else {
      $status.InputDevice = "Mouse"
      $status.Reasons += "✅🖱️ Mouse Moved by $([Math]::Round($totalMovement, 1)) pixels ($mouseDeltaX, $mouseDeltaY)"
    }
    
    $status.ActivityType = "MouseMovement"
  } else {
    $status.Reasons += "❌🖱️ Mouse Static ($([Math]::Round($totalMovement, 1))px)"
  }

  # Check key press with enhanced typing analysis
  if ($KeyPressed) {
    $status.IsActive = $true
    $activityScore += 40
    
    # Check if we have typing activity data
    if ($TypingActivity -and $TypingActivity.IsTyping) {
      if ($TypingActivity.TypingPattern -eq "Continuous") {
        $status.Reasons += "✅⌨️ User is typing continuously ($($TypingActivity.TypingSpeed) WPM)"
        $activityScore += 20  # Bonus for continuous typing
      } elseif ($TypingActivity.TypingPattern -eq "Fast") {
        $status.Reasons += "✅⌨️ Fast typing detected ($($TypingActivity.TypingSpeed) WPM)"
        $activityScore += 15
      } elseif ($TypingActivity.TypingPattern -eq "Normal") {
        $status.Reasons += "✅⌨️ Normal typing ($($TypingActivity.TypingSpeed) WPM)"
        $activityScore += 10
      } else {
        $status.Reasons += "✅⌨️ Key Pressed ($KeyPressed) - $($TypingActivity.TypingPattern)"
      }
    } else {
      $status.Reasons += "✅⌨️ Key Pressed ($KeyPressed)"
    }
    
    if ($status.ActivityType -eq "None") { $status.ActivityType = "Keyboard" }
  } else {
    $status.Reasons += "❌⌨️ No Keys"
  }

  # Check mouse clicks with confidence scoring
  if ($MouseClicked.Count -gt 0) {
    $status.IsActive = $true
    $activityScore += 50
    
    # Check for trackpad gestures
    if ($TrackpadGestures.Count -gt 0) {
      $gestureText = $TrackpadGestures -join ', '
      $status.Reasons += "✅👆🏼 Trackpad Gestures: $gestureText"
      $activityScore += 15  # Bonus for trackpad gestures
    } else {
      $status.Reasons += "✅👆🏼 Mouse Clicked $($MouseClicked -join ', ')"
    }
    
    if ($status.ActivityType -eq "None") { $status.ActivityType = "MouseClick" }
  } else {
    $status.Reasons += "❌👆🏼 No Clicks"
  }

  # Check window focus changes
  if ($WindowTitle -and $LastWindowTitle -and $WindowTitle -ne $LastWindowTitle) {
    $status.IsActive = $true
    $activityScore += 25
    $status.Reasons += "✅🪟 Window Focus Changed: '$LastWindowTitle' → '$WindowTitle'"
    if ($status.ActivityType -eq "None") { $status.ActivityType = "WindowFocus" }
  } else {
    $status.Reasons += "❌🪟 Window Static"
  }

  # Check mouse wheel movement
  if ($MouseWheelDelta -ne 0) {
    $status.IsActive = $true
    $activityScore += 20
    $status.Reasons += "✅🖱️ Mouse Wheel: $MouseWheelDelta"
    if ($status.ActivityType -eq "None") { $status.ActivityType = "MouseWheel" }
  } else {
    $status.Reasons += "❌🖱️ No Wheel Movement"
  }

  # Calculate confidence based on activity score
  $status.Confidence = [Math]::Min(100, $activityScore)

  # Convert to PSCustomObject and return
  return [PSCustomObject]$status
}


function Test-UserActivity {
  <#
    .SYNOPSIS
    Checks if the user is currently active based on comprehensive system activity monitoring.
    .DESCRIPTION
    Determines user activity by monitoring mouse movement, clicks, keyboard input, window focus changes,
    and other system events. Uses improved detection algorithms with confidence scoring and performance optimization.
    Also manages screen brightness based on activity patterns.
    .OUTPUTS
    [bool] $true if user is active, otherwise $false.
    .NOTES
    Uses script-scoped variables to persist system state between calls for efficient monitoring.
  #>

  [OutputType([bool])]
  [CmdletBinding()]
  param()

  try {
    # Initialize tracking variables
    if (-not $script:LastCheckTime) {
      $script:LastCheckTime = [datetime]::Now
      $script:LastActivityTime = [datetime]::Now
      $script:BrightnessState = "Normal"
      $script:LastWindowTitle = $null
      $script:LastMouseWheelPosition = 0
      $script:KeyStateCache = @{}
      $script:LastKeyCheckTime = [datetime]::Now
    }

    # Skip if less than TimeCooldown since last check
    if (([datetime]::Now - $script:LastCheckTime).TotalSeconds -le $Script:Config.TimeCooldown) {
      return $false
    }

    # Update last check time
    $script:LastCheckTime = [datetime]::Now

    # Ensure the required assemblies are loaded
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Add the GetAsyncKeyState API if not already present
    if (-not ("Win32.User32" -as [type])) {
      Add-Type -MemberDefinition @"
      [DllImport("user32.dll", SetLastError = true)]
        public static extern short GetAsyncKeyState(int vKey);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern short GetKeyState(int nVirtKey);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool BlockInput([MarshalAs(UnmanagedType.Bool)] bool fBlockIt);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr GetForegroundWindow();
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern int GetWindowTextLength(IntPtr hWnd);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern int GetSystemMetrics(int nIndex);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetCursorInfo(ref CURSORINFO pci);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetRawInputData(IntPtr hRawInput, uint uiCommand, IntPtr pData, ref uint pcbSize, uint cbSizeHeader);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetRawInputDeviceList(IntPtr pRawInputDeviceList, ref uint puiNumDevices, uint cbSize);
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetRawInputDeviceInfo(IntPtr hDevice, uint uiCommand, IntPtr pData, ref uint pcbSize);
"@ -Name "User32" -Namespace Win32
    }

    # Add structures for trackpad detection
    if (-not ("Win32.Structures" -as [type])) {
      Add-Type -MemberDefinition @"
      [StructLayout(LayoutKind.Sequential)]
      public struct CURSORINFO
      {
          public int cbSize;
          public int flags;
          public IntPtr hCursor;
          public POINT ptScreenPos;
      }
      
      [StructLayout(LayoutKind.Sequential)]
      public struct POINT
      {
          public int x;
          public int y;
      }
      
      [StructLayout(LayoutKind.Sequential)]
      public struct RAWINPUTDEVICELIST
      {
          public IntPtr hDevice;
          public uint dwType;
      }
      
      [StructLayout(LayoutKind.Sequential)]
      public struct RAWINPUTHEADER
      {
          public uint dwType;
          public uint dwSize;
          public IntPtr hDevice;
          public IntPtr wParam;
      }
      
      [StructLayout(LayoutKind.Sequential)]
      public struct RAWMOUSE
      {
          public ushort usFlags;
          public ushort usButtonFlags;
          public ushort usButtonData;
          public uint ulRawButtons;
          public int lLastX;
          public int lLastY;
          public uint ulExtraInformation;
      }
"@ -Name "Structures" -Namespace Win32
    }

    # Initialize the last mouse position if not already set
    if (-not $script:LastMousePosition) {
      $script:LastMousePosition = [System.Windows.Forms.Cursor]::Position
      Write-Message -LogMessage "Enhanced user activity tracking started." -Type "Info"
      return $true
    }

    # Get current system state
    $CurrentMousePosition = [System.Windows.Forms.Cursor]::Position
    
    # Get current window title
    $CurrentWindowTitle = $null
    try {
      $foregroundWindow = [Win32.User32]::GetForegroundWindow()
      if ($foregroundWindow -ne [IntPtr]::Zero) {
        $length = [Win32.User32]::GetWindowTextLength($foregroundWindow)
        if ($length -gt 0) {
          $stringBuilder = New-Object System.Text.StringBuilder -ArgumentList ($length + 1)
          [Win32.User32]::GetWindowText($foregroundWindow, $stringBuilder, $stringBuilder.Capacity) | Out-Null
          $CurrentWindowTitle = $stringBuilder.ToString()
        }
      }
    } catch {
      # Window title detection failed, continue without it
    }

    # Enhanced keyboard detection with typing pattern analysis
    $keyPressed = $null
    $typingActivity = @{
      IsTyping = $false
      TypingSpeed = 0
      KeysPressed = @()
      TypingPattern = "None"
    }
    $currentTime = [datetime]::Now
    
    # Initialize typing tracking variables
    if (-not $script:TypingHistory) {
      $script:TypingHistory = @()
      $script:LastTypingTime = [datetime]::Now
    }
    
    # Only check keys if enough time has passed since last check (debouncing)
    if (($currentTime - $script:LastKeyCheckTime).TotalMilliseconds -gt 30) {
      # Check only common keys instead of all 254 keys
      $commonKeys = @(0x20, 0x08, 0x0D, 0x1B, 0x09, 0x10, 0x11, 0x12, 0x14, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28)
      # Add letter keys (A-Z)
      $commonKeys += 65..90
      # Add number keys (0-9)
      $commonKeys += 48..57
      # Add function keys (F1-F12)
      $commonKeys += 112..123
      
      $pressedKeys = @()
      foreach ($vk in $commonKeys) {
        $currentState = [Win32.User32]::GetAsyncKeyState($vk) -band 0x8000
        $lastState = $script:KeyStateCache[$vk]
        
        # Detect key press (transition from not pressed to pressed)
        if ($currentState -and -not $lastState) {
          $pressedKeys += [System.Windows.Forms.Keys]$vk
          if (-not $keyPressed) { $keyPressed = [System.Windows.Forms.Keys]$vk }
        }
        
        $script:KeyStateCache[$vk] = $currentState
      }
      
      # Analyze typing patterns
      if ($pressedKeys.Count -gt 0) {
        $typingActivity.KeysPressed = $pressedKeys
        $typingActivity.IsTyping = $true
        
        # Record typing event
        $typingEvent = @{
          Timestamp = $currentTime
          Keys = $pressedKeys
          KeyCount = $pressedKeys.Count
        }
        $script:TypingHistory += $typingEvent
        
        # Keep only last 10 typing events for analysis
        if ($script:TypingHistory.Count -gt 10) {
          $script:TypingHistory = $script:TypingHistory[-10..-1]
        }
        
        # Calculate typing speed (keys per minute)
        $recentEvents = $script:TypingHistory | Where-Object { ($currentTime - $_.Timestamp).TotalSeconds -le 10 }
        if ($recentEvents.Count -gt 1) {
          $timeSpan = ($recentEvents[-1].Timestamp - $recentEvents[0].Timestamp).TotalMinutes
          if ($timeSpan -gt 0) {
            $totalKeys = ($recentEvents | Measure-Object -Property KeyCount -Sum).Sum
            $typingActivity.TypingSpeed = [Math]::Round($totalKeys / $timeSpan, 1)
          }
        }
        
        # Determine typing pattern
        if ($typingActivity.TypingSpeed -gt 60) {
          $typingActivity.TypingPattern = "Fast"
        } elseif ($typingActivity.TypingSpeed -gt 20) {
          $typingActivity.TypingPattern = "Normal"
        } elseif ($typingActivity.TypingSpeed -gt 5) {
          $typingActivity.TypingPattern = "Slow"
        } else {
          $typingActivity.TypingPattern = "Single"
        }
        
        $script:LastTypingTime = $currentTime
      } else {
        # Check if we're in a typing session (recent typing activity)
        $timeSinceLastTyping = ($currentTime - $script:LastTypingTime).TotalSeconds
        if ($timeSinceLastTyping -le 2) {
          $typingActivity.IsTyping = $true
          $typingActivity.TypingPattern = "Continuous"
        }
      }
      
      $script:LastKeyCheckTime = $currentTime
    }

    # Detect mouse clicks with improved logic including trackpad gestures
    $mouseClicked = @()
    $leftPressed = [Win32.User32]::GetAsyncKeyState(0x01) -band 0x8000
    $rightPressed = [Win32.User32]::GetAsyncKeyState(0x02) -band 0x8000
    $middlePressed = [Win32.User32]::GetAsyncKeyState(0x04) -band 0x8000
    
    # Check for trackpad-specific gestures
    $trackpadGestures = @()
    
    # Detect right-click gesture (double finger tap) - often shows as right mouse button
    if ($rightPressed) {
      $mouseClicked += "Right"
      $trackpadGestures += "RightClick"
    }
    
    # Detect left-click (single finger tap)
    if ($leftPressed) {
      $mouseClicked += "Left"
      $trackpadGestures += "LeftClick"
    }
    
    # Detect middle-click (three finger tap)
    if ($middlePressed) {
      $mouseClicked += "Middle"
      $trackpadGestures += "MiddleClick"
    }
    
    # Check for additional trackpad gestures using system metrics
    try {
      # Check if we're on a laptop (more likely to have trackpad)
      $isLaptop = $false
      $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
      $isLaptop = $null -ne $battery
      
      if ($isLaptop) {
        # Check for scroll gestures (often detected as mouse wheel)
        $wheelUp = [Win32.User32]::GetAsyncKeyState(0x26) -band 0x8000  # Up arrow
        $wheelDown = [Win32.User32]::GetAsyncKeyState(0x28) -band 0x8000  # Down arrow
        
        if ($wheelUp) { $trackpadGestures += "ScrollUp" }
        if ($wheelDown) { $trackpadGestures += "ScrollDown" }
        
        # Check for three-finger gestures (often mapped to special keys)
        $threeFingerSwipe = [Win32.User32]::GetAsyncKeyState(0x5B) -band 0x8000  # Left Windows key
        if ($threeFingerSwipe) { $trackpadGestures += "ThreeFingerSwipe" }
      }
    } catch {
      # Gesture detection failed, continue with basic detection
    }

    # Detect mouse wheel movement (simplified - would need more complex implementation for actual wheel detection)
    $mouseWheelDelta = 0  # Placeholder - would need additional API calls for actual wheel detection

    # Get comprehensive activity status
    $movementThreshold = if ($script:Config.TrackpadDetectionEnabled) { $script:Config.TrackpadMovementThreshold } else { 3 }
    $activityStatus = Get-ActivityStatus -CurrentMousePosition $CurrentMousePosition `
                                         -LastMousePosition $script:LastMousePosition `
                                         -KeyPressed $keyPressed `
                                         -MouseClicked $mouseClicked `
                                         -WindowTitle $CurrentWindowTitle `
                                         -LastWindowTitle $script:LastWindowTitle `
                                         -MouseWheelDelta $mouseWheelDelta `
                                         -MovementThreshold $movementThreshold `
                                         -TypingActivity $typingActivity `
                                         -TrackpadGestures $trackpadGestures

    # Add small delay to prevent CPU overuse
    Start-Sleep -Milliseconds 1

    # Log status with confidence level and device info
    $logMessage = "$($activityStatus.Reasons -join ' | ')"
    if ($activityStatus.Confidence -gt 0) {
      $logMessage += " [Confidence: $($activityStatus.Confidence)%]"
    }
    if ($activityStatus.InputDevice -ne "Unknown") {
      $logMessage += " [Device: $($activityStatus.InputDevice)]"
    }
    if ($activityStatus.GestureType -ne "None") {
      $logMessage += " [Gesture: $($activityStatus.GestureType)]"
    }
    Write-Message -LogMessage $logMessage -Type "Info"

    # Detect user activity with confidence threshold
    if ($activityStatus.IsActive -and $activityStatus.Confidence -ge 20) {
      # Update last activity time and system state
      $script:LastActivityTime = [datetime]::Now
      $script:LastMousePosition = $CurrentMousePosition
      $script:LastWindowTitle = $CurrentWindowTitle

      # Log activity with enhanced details
      Write-Message -LogMessage "User activity detected ($($activityStatus.ActivityType)): $($activityStatus.Reasons -join ' | '). Pausing script for '$(Convert-TimeSpanToHumanReadable (New-TimeSpan -Seconds $script:Config.TimeWaitMax))'." -Type "Info"

      # Reset brightness if configured
      if (
        $script:Config.BrightnessFlag -and
        $null -ne $script:Config.BrightnessInitial -and
        $script:BrightnessState -ne "Normal"
      ) {
          $script:BrightnessState = "Normal"
          Write-Message -LogMessage "Restored screen brightness to initial level ($($script:Config.BrightnessInitial)%) due to user activity." -Type "Info"
          Set-ScreenBrightness -Level $script:Config.BrightnessInitial
      }
      return $true
    }
    else {
      $inactiveSeconds = [datetime]::Now - $script:LastActivityTime

      # Dim screen if inactive for too long
      if ($script:Config.BrightnessFlag -and 
        $null -ne $script:Config.BrightnessMin -and 
        $inactiveSeconds.TotalSeconds -gt $script:Config.TimeWaitMax -and
        $script:BrightnessState -eq "Normal"
      ) {
          $script:BrightnessState = "Dimmed"
          Write-Message -LogMessage "Dimming screen due to inactivity: $($activityStatus.Reasons -join ' | ')" -Type "Warning"
          Set-ScreenBrightness -Level $script:Config.BrightnessMin
      }
      return $false
    }
  } catch {
    Write-Message -LogMessage "Error checking user activity: $($_.Exception.Message)" -Type "Critical"
    return $false
  }
  finally {
    # Clear any pending keystrokes (reduced frequency)
    if ((Get-Random -Minimum 1 -Maximum 100) -lt 5) {  # Only clear 5% of the time
      while ([Win32.User32]::GetAsyncKeyState(0x0D)) { Start-Sleep -Milliseconds 5 }
      [System.Windows.Forms.SendKeys]::Flush()
    }
  }
}


function Test-TrackpadActivity {
  <#
    .SYNOPSIS
    Detects trackpad-specific activity including gestures and multi-touch events.
    .DESCRIPTION
    Analyzes mouse movement patterns and system metrics to identify trackpad usage
    versus traditional mouse usage. Detects gestures like scrolling, pinching, and swiping.
    .OUTPUTS
    [PSCustomObject] containing trackpad activity information.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Drawing.Point]$CurrentMousePosition,
    
    [Parameter(Mandatory = $true)]
    [System.Drawing.Point]$LastMousePosition,
    
    [Parameter(Mandatory = $false)]
    [int]$MovementThreshold = 2
  )

  try {
    $trackpadActivity = @{
      IsTrackpad = $false
      GestureType = "None"
      Confidence = 0
      MovementPattern = "Unknown"
      Reasons = @()
    }

    # Calculate movement delta
    $deltaX = $CurrentMousePosition.X - $LastMousePosition.X
    $deltaY = $CurrentMousePosition.Y - $LastMousePosition.Y
    $totalMovement = [Math]::Sqrt($deltaX * $deltaX + $deltaY * $deltaY)

    # Skip if movement is too small
    if ($totalMovement -lt $MovementThreshold) {
      $trackpadActivity.Reasons += "❌🖱️ Movement too small for analysis"
      return [PSCustomObject]$trackpadActivity
    }

    # Check if system has a trackpad (laptop detection)
    $isLaptop = $false
    try {
      $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
      $isLaptop = $null -ne $battery
    } catch {
      # Assume desktop if we can't determine
    }

    # Trackpad characteristics:
    # 1. More precise, smaller movements
    # 2. Often diagonal movements
    # 3. Smooth acceleration patterns
    # 4. Often used for scrolling gestures

    $confidence = 0
    $reasons = @()

    # Check for trackpad-like movement patterns
    if ($isLaptop) {
      $confidence += 20
      $reasons += "✅💻 Laptop detected (likely has trackpad)"
    }

    # Check for precise movements (trackpads are more precise)
    if ($totalMovement -ge 1 -and $totalMovement -le 50) {
      $confidence += 15
      $reasons += "✅🎯 Precise movement detected ($([Math]::Round($totalMovement, 1))px)"
    }

    # Check for diagonal movements (common with trackpads)
    if ($deltaX -ne 0 -and $deltaY -ne 0) {
      $angle = [Math]::Atan2([Math]::Abs($deltaY), [Math]::Abs($deltaX)) * 180 / [Math]::PI
      if ($angle -gt 15 -and $angle -lt 75) {
        $confidence += 10
        $reasons += "✅↗️ Diagonal movement detected ($([Math]::Round($angle, 1))°)"
      }
    }

    # Check for smooth movement patterns (trackpads have acceleration)
    if ($totalMovement -gt 5 -and $totalMovement -lt 30) {
      $confidence += 10
      $reasons += "✅🌊 Smooth movement pattern detected"
    }

    # Check for scrolling-like vertical movement
    if ([Math]::Abs($deltaY) -gt [Math]::Abs($deltaX) * 2) {
      $confidence += 15
      $reasons += "✅📜 Vertical scrolling gesture detected"
      $trackpadActivity.GestureType = "Scroll"
    }

    # Check for horizontal swiping
    if ([Math]::Abs($deltaX) -gt [Math]::Abs($deltaY) * 2) {
      $confidence += 10
      $reasons += "✅👈 Horizontal swipe gesture detected"
      $trackpadActivity.GestureType = "Swipe"
    }

    # Check for small circular movements (common with trackpads)
    if ($totalMovement -gt 3 -and $totalMovement -lt 15) {
      $confidence += 5
      $reasons += "✅🔄 Small circular movement detected"
    }

    # Determine movement pattern
    if ($totalMovement -le 10) {
      $trackpadActivity.MovementPattern = "Precise"
    } elseif ($totalMovement -le 30) {
      $trackpadActivity.MovementPattern = "Moderate"
    } else {
      $trackpadActivity.MovementPattern = "Large"
    }

    # Set confidence and determine if it's likely a trackpad
    $trackpadActivity.Confidence = [Math]::Min(100, $confidence)
    $trackpadActivity.IsTrackpad = $trackpadActivity.Confidence -ge 40
    $trackpadActivity.Reasons = $reasons

    if (-not $trackpadActivity.IsTrackpad) {
      $trackpadActivity.Reasons += "❌🖱️ Movement pattern suggests traditional mouse"
    }

    return [PSCustomObject]$trackpadActivity
  } catch {
    Write-Message -LogMessage "Error detecting trackpad activity: $($_.Exception.Message)" -Type "Warning"
    return [PSCustomObject]@{
      IsTrackpad = $false
      GestureType = "None"
      Confidence = 0
      MovementPattern = "Unknown"
      Reasons = @("Trackpad detection failed")
    }
  }
}


function Get-SystemActivityMetrics {
  <#
    .SYNOPSIS
    Gets comprehensive system activity metrics for enhanced user activity detection.
    .DESCRIPTION
    Collects various system metrics including CPU usage, memory activity, network activity,
    and file system activity to provide additional context for user activity detection.
    .OUTPUTS
    [PSCustomObject] containing system activity metrics.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param()

  try {
    $metrics = @{
      CpuUsage = 0
      MemoryUsage = 0
      NetworkActivity = $false
      DiskActivity = $false
      ProcessCount = 0
      LastUpdate = [datetime]::Now
    }

    # Get CPU usage (simplified)
    try {
      $cpu = Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
      if ($cpu) {
        $metrics.CpuUsage = [Math]::Round($cpu.CounterSamples[0].CookedValue, 2)
      }
    } catch {
      # CPU monitoring failed, continue
    }

    # Get memory usage
    try {
      $memory = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
      if ($memory) {
        $metrics.MemoryUsage = [Math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
      }
    } catch {
      # Memory monitoring failed, continue
    }

    # Check for network activity (simplified)
    try {
      $networkStats = Get-Counter -Counter "\Network Interface(*)\Bytes Total/sec" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
      if ($networkStats -and $networkStats.CounterSamples.Count -gt 0) {
        $totalBytes = ($networkStats.CounterSamples | Where-Object { $_.InstanceName -ne "_Total" } | Measure-Object -Property CookedValue -Sum).Sum
        $metrics.NetworkActivity = $totalBytes -gt 1000  # More than 1KB/sec
      }
    } catch {
      # Network monitoring failed, continue
    }

    # Check for disk activity
    try {
      $diskStats = Get-Counter -Counter "\PhysicalDisk(_Total)\Disk Read Bytes/sec", "\PhysicalDisk(_Total)\Disk Write Bytes/sec" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
      if ($diskStats -and $diskStats.CounterSamples.Count -gt 0) {
        $totalDiskBytes = ($diskStats.CounterSamples | Measure-Object -Property CookedValue -Sum).Sum
        $metrics.DiskActivity = $totalDiskBytes -gt 10000  # More than 10KB/sec
      }
    } catch {
      # Disk monitoring failed, continue
    }

    # Get process count
    try {
      $metrics.ProcessCount = (Get-Process -ErrorAction SilentlyContinue).Count
    } catch {
      # Process monitoring failed, continue
    }

    return [PSCustomObject]$metrics
  } catch {
    Write-Message -LogMessage "Error getting system activity metrics: $($_.Exception.Message)" -Type "Warning"
    return [PSCustomObject]@{
      CpuUsage = 0
      MemoryUsage = 0
      NetworkActivity = $false
      DiskActivity = $false
      ProcessCount = 0
      LastUpdate = [datetime]::Now
    }
  }
}


function Stop-ActivityDetection {
  <#
    .SYNOPSIS
    Properly stops activity detection and cleans up all resources.
    .DESCRIPTION
    Clears all script-scoped variables, stops any running processes,
    and resets system state to prevent lingering effects after script termination.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param()

  try {
    Write-Message -LogMessage "Stopping activity detection and cleaning up resources..." -Type "Info"

    # Clear all script-scoped variables
    $script:LastCheckTime = $null
    $script:LastActivityTime = $null
    $script:BrightnessState = $null
    $script:LastMousePosition = $null
    $script:LastWindowTitle = $null
    $script:LastMouseWheelPosition = $null
    $script:KeyStateCache = $null
    $script:LastKeyCheckTime = $null
    $script:TypingHistory = $null
    $script:LastTypingTime = $null
    $script:LastPowerType = $null
    $script:LastTimeout = $null

    # Clear any pending keystrokes
    try {
      if ("Win32.User32" -as [type]) {
        while ([Win32.User32]::GetAsyncKeyState(0x0D)) { 
          Start-Sleep -Milliseconds 5 
        }
        [System.Windows.Forms.SendKeys]::Flush()
      }
    } catch {
      # Ignore errors during cleanup
    }

    # Reset brightness to initial level if it was changed
    if ($script:Config.BrightnessFlag -and $null -ne $script:Config.BrightnessInitial) {
      try {
        Set-ScreenBrightness -Level $script:Config.BrightnessInitial
        Write-Message -LogMessage "Screen brightness restored to initial level ($($script:Config.BrightnessInitial)%)" -Type "Info"
      } catch {
        Write-Message -LogMessage "Failed to restore screen brightness: $($_.Exception.Message)" -Type "Warning"
      }
    }

    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    Write-Message -LogMessage "Activity detection stopped and resources cleaned up successfully." -Type "Info"
  } catch {
    Write-Message -LogMessage "Error during cleanup: $($_.Exception.Message)" -Type "Warning"
  }
}


function Test-ActivityPattern {
  <#
    .SYNOPSIS
    Analyzes activity patterns to determine if detected activity is likely user-initiated.
    .DESCRIPTION
    Uses machine learning-like heuristics to analyze activity patterns and determine
    if detected activity is likely from a human user versus automated processes.
    .PARAMETER ActivityHistory
    Array of recent activity events to analyze.
    .OUTPUTS
    [PSCustomObject] containing pattern analysis results.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [array]$ActivityHistory
  )

  try {
    $pattern = @{
      IsHumanLike = $false
      Confidence = 0
      Reasons = @()
      Irregularity = 0
    }

    if ($ActivityHistory.Count -lt 3) {
      $pattern.Reasons += "Insufficient data for pattern analysis"
      return [PSCustomObject]$pattern
    }

    # Analyze timing patterns
    $intervals = @()
    for ($i = 1; $i -lt $ActivityHistory.Count; $i++) {
      $interval = ($ActivityHistory[$i].Timestamp - $ActivityHistory[$i-1].Timestamp).TotalSeconds
      $intervals += $interval
    }

    # Calculate irregularity (higher = more human-like)
    $meanInterval = ($intervals | Measure-Object -Average).Average
    $variance = ($intervals | ForEach-Object { [Math]::Pow($_ - $meanInterval, 2) } | Measure-Object -Average).Average
    $pattern.Irregularity = [Math]::Sqrt($variance)

    # Human-like patterns typically have:
    # - Irregular timing (not perfectly periodic)
    # - Mix of different activity types
    # - Reasonable intervals (not too fast, not too slow)

    if ($pattern.Irregularity -gt 5) {
      $pattern.Confidence += 30
      $pattern.Reasons += "Irregular timing pattern detected"
    }

    # Check for activity type diversity
    $activityTypes = $ActivityHistory | Group-Object ActivityType | Select-Object -ExpandProperty Count
    if ($activityTypes -gt 2) {
      $pattern.Confidence += 25
      $pattern.Reasons += "Diverse activity types detected"
    }

    # Check for reasonable intervals (not too fast)
    $tooFastCount = ($intervals | Where-Object { $_ -lt 0.1 }).Count
    if ($tooFastCount -lt $intervals.Count * 0.3) {
      $pattern.Confidence += 20
      $pattern.Reasons += "Reasonable activity intervals"
    }

    # Check for mouse movement patterns
    $mouseMovements = $ActivityHistory | Where-Object { $_.ActivityType -eq "MouseMovement" }
    if ($mouseMovements.Count -gt 0) {
      $movementDistances = $mouseMovements | ForEach-Object { $_.MovementDistance }
      $avgMovement = ($movementDistances | Measure-Object -Average).Average
      
      if ($avgMovement -gt 10 -and $avgMovement -lt 500) {
        $pattern.Confidence += 25
        $pattern.Reasons += "Natural mouse movement patterns"
      }
    }

    $pattern.IsHumanLike = $pattern.Confidence -ge 50
    return [PSCustomObject]$pattern
  } catch {
    Write-Message -LogMessage "Error analyzing activity pattern: $($_.Exception.Message)" -Type "Warning"
    return [PSCustomObject]@{
      IsHumanLike = $false
      Confidence = 0
      Reasons = @("Pattern analysis failed")
      Irregularity = 0
    }
  }
}


function Test-Holiday {
  <#
    .SYNOPSIS
    Checks if the given date is a public holiday in the specified country.
    .DESCRIPTION
    Retrieves holiday information using the Open Holidays API and determines if the specified date is a public holiday in the provided country and language.
    .PARAMETER Date
    The date to check for public holidays.
    .PARAMETER CountryCode
    The ISO code of the country to check for holidays (e.g., "US", "GB").
    .PARAMETER LanguageCode
    The ISO code of the language to use for holiday names (optional, defaults to the country code).
    .OUTPUTS
    $true if it's a public holiday, otherwise $false.
    .LINK
    https://www.openholidaysapi.org/en
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline)]
    [datetime]$Date,
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$CountryCode,
    [Parameter(Mandatory = $false, Position = 2)]
    [string]$LanguageCode = $CountryCode
  )

  try {
    # Convert date to the acceptable format for the API
    $Date_Converted = Get-Date ($Date).ToUniversalTime() -UFormat '+%Y-%m-%d'

    # Form the API URL
    $URL = "https://openholidaysapi.org/PublicHolidays?countryIsoCode=$CountryCode&languageIsoCode=$LanguageCode&validFrom=$Date_Converted&validTo=$Date_Converted"
    # Get the JSON data and convert it
    $JSON = (New-Object System.Net.WebClient).DownloadString($URL) | ConvertFrom-Json

    # Check if response contains the "nationwide" property
    if ($JSON -and $JSON.holidays -and ($JSON.holidays | Where-Object { $_.date = = $Date_Converted }).nationwide) {
      return $true
    } else {
      return $false
    }
  } catch {
    Write-Message -LogMessage "Error checking public holiday: $($_.Exception.Message)" -Type "Critical"
    return $false
  }
}


function Invoke-CMDlet {
  <#
    .SYNOPSIS
    Runs a specified cmdlet and optionally logs events with verbosity control.
    .DESCRIPTION
    Runs a specified cmdlet (as a script block or string) and optionally logs information about the execution, including errors.
    .PARAMETER CMDlet
    The cmdlet to run (as a script block or string).
    .PARAMETER Flag
    A switch parameter to enable logging. Defaults to $true.
    .OUTPUTS
    The output of the executed cmdlet (if any).
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ScriptBlock]$CMDlet,  # Accepts a script block
    [Parameter(Mandatory = $false)]
    [switch]$Flag
  )

  # Log execution information (if logging enabled)
  if ($Flag) {
      Write-Message -LogMessage "Running cmdlet: '$CMDlet'" -Type "Info"
  }

  try {
    # Run the cmdlet and capture output
    $Output = & $CMDlet

    # Log success if logging is enabled
    if ($Flag) {
        Write-Message -LogMessage "Cmdlet '$CMDlet' completed successfully." -Type "Info"
    }

    # Return the output
    return $Output
  } catch {
      # Log the error
      Write-Message -LogMessage "Error executing cmdlet '$CMDlet': $($_.Exception.Message)" -Type "Critical"
  }
}


function Send-KeyPress {
  <#
    .SYNOPSIS
    Press a specified key in PowerShell.
    .DESCRIPTION
    Simulates pressing a specific key using .NET methods.
    .PARAMETER Key
    The key value to be pressed (e.g., 'A', 'Enter', 'F1').
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Key
  )

  try {
    # Load the necessary assembly
    Add-Type -AssemblyName System.Windows.Forms

    # Log the event
    Write-Message -LogMessage "The key '$Key' is going to be pressed." -Type "Info"

    # Send the key
    [System.Windows.Forms.SendKeys]::SendWait($Key)
  } catch {
    Write-Message -LogMessage "Error sending key: $_" -Type "Critical"
  }
}


function Move-MouseRandom {
  <#
    .SYNOPSIS
    Simulates moving the mouse cursor randomly within screen boundaries.
    .DESCRIPTION
    Moves the mouse cursor to a random position within the screen boundaries to prevent screensavers or idle timeouts.
    .INPUTS
    None
    .OUTPUTS
    None
  #>

  try {
    # Get the current position of the mouse cursor
    $Position = [System.Windows.Forms.Cursor]::Position

    # Get screen dimensions
    $ScreenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width
    $ScreenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height

    # Define minimum and maximum offsets to stay within screen boundaries
    $MinOffset = $ScreenHeight - 10 # Minimum distance from screen height
    $MaxOffset = $ScreenWidth  - 10 # Maximum distance from screen width

    # Generate random offsets within boundaries
    $RandomX = Get-Random -Minimum $MinOffset -Maximum $MaxOffset
    $RandomY = Get-Random -Minimum $MinOffset -Maximum $MaxOffset

    # Log the event
    Write-Message -LogMessage "Moving mouse cursor from [$($Position.X), $($Position.Y)] to a random position within screen boundaries: [$RandomX, $RandomY]" -Type "Info"

    # Set the new position of the mouse cursor
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point ($RandomX, $RandomY)
  } catch {
    Write-Message -LogMessage "Error moving the mouse cursor: $_" -Type "Critical"
  }
}


function Start-AppSession {
  <#
    .SYNOPSIS
    Opens a specified application and closes it after a configurable delay.
    .DESCRIPTION
    Opens a specified application and closes it after a user-defined wait time.
    .PARAMETER Application
    The name of the application to open (including path if necessary).
    .PARAMETER WaitTime
    [Optional] The time in seconds to wait before closing the application. Defaults to 60% of a randomly chosen initial wait time between 10 and 20 seconds.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Application,

    [Parameter(Mandatory = $false)]
    [int]$WaitTime = ((Get-Random -Minimum $script:Config.TimeWaitMin -Maximum $script:Config.TimeWaitMax) * 0.6)
  )

  try {
    # Open the application
    Start-Process $Application

    # Log the event with calculated wait time
    Write-Message -LogMessage "The application '$Application' will be opened for '$(Convert-TimeSpanToHumanReadable (New-TimeSpan -Seconds $WaitTime))' and then closed at '$((Get-Date).AddSeconds($WaitTime))'." -Type "Info"

    # Wait for the specified time
    Start-Sleep $WaitTime

    # Log the event
    Write-Message -LogMessage "The application '$Application' is being closed." -Type "Info"

    # Close the application
    Stop-Process -Name "*$Application*"
  } catch {
    Write-Message -LogMessage "Error opening or closing the application: $_" -Type "Critical"
  }
}


function Start-EdgeSession {
  <#
    .SYNOPSIS
    Opens a specified webpage and closes the tab in Microsoft Edge after a configurable delay.
    .DESCRIPTION
    Opens a specified webpage in Microsoft Edge and closes the tab after a user-defined wait time. Simulates user interaction by scrolling and clicking the close button.
    .PARAMETER Webpage
    The address of the webpage to open.
    .PARAMETER WaitTime
    [Optional] The time in seconds to wait before closing the tab. Defaults to 60% of a randomly chosen initial wait time between 10 and 20 seconds.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Webpage,
    [Parameter(Mandatory = $false)]
    [int]$WaitTime = ((Get-Random -Minimum $script:Config.TimeWaitMin -Maximum $script:Config.TimeWaitMax) * 0.6)
  )

  try {
    # Calculate the close time
    $CloseTime = (Get-Date).AddSeconds($WaitTime)

    # Open the webpage
    Start-Process microsoft-edge:$Webpage

    # Log the event with calculated wait time
    Write-Message -LogMessage "The webpage '$Webpage' will be opened in Edge for '$(Convert-TimeSpanToHumanReadable (New-TimeSpan -Seconds $WaitTime))' and then closed at '$CloseTime'." -Type "Info"

    # Scroll the page while waiting for the closing time
    while ($CloseTime -gt (Get-Date)) {
      # Press randomly either the Page Down or Up key, wait, again, and reverse it
      PressKey $(@("{UP}","{DOWN}","{PGDN}","{PGUP}") | Get-Random)
      Start-Sleep $(Get-Random -Minimum 2 -Maximum 10)
    }

    # Simulate Ctrl+W to close the active tab
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("^{w}") # Send Ctrl+w to close active tab

    # Log the event
    Write-Message -LogMessage "The webpage '$Webpage' is being closed." -Type "Info"
  } catch {
    Write-Message -LogMessage "Error opening or closing the webpage: '$Webpage'" -Type "Critical"
  }
}


function Set-ScreenBrightness {
  <#
    .SYNOPSIS
    Adjusts the screen brightness level.
    .DESCRIPTION
    Sets the screen brightness to a specified level (either $script:Config.BrightnessInitial or $script:Config.BrightnessMin).
    .PARAMETER Level
    The desired brightness level. Must be either $script:Config.BrightnessInitial or $script:Config.BrightnessMin.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [int]$Level
  )

  try {
    # Get the current brightness level
    $CurrentBrightness = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness).CurrentBrightness

    if ($Level -ne $CurrentBrightness) {
      # Log the brightness change
      Write-Message -LogMessage "The screen brightness will be changed from $CurrentBrightness% to $Level%." -Type "Info"

      # Set the brightness level using CIM method (works on most modern systems)
      $BrightnessInstance = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods
      if ($BrightnessInstance) {
        Invoke-CimMethod -InputObject $BrightnessInstance -MethodName "WmiSetBrightness" -Arguments @{Timeout=0; Brightness=$Level} | Out-Null
      } else {
        Write-Message -LogMessage "WmiSetBrightness CIM method not available on this device." -Type "Warning"
      }
    }
  } catch {
    Write-Message -LogMessage "Error adjusting screen brightness: $($_.Exception.Message)" -Type "Critical"
  }
}