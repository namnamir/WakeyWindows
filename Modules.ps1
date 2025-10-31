function Write-Message {
  <#
    .SYNOPSIS
    Log a message in PowerShell.
    .DESCRIPTION
    Logs a message along with the current date and time, using ANSI escape codes for color (configurable).
    Supports verbosity levels for filtering and can output as plain console messages (non-log).
    .PARAMETER LogMessage
    The message to be logged.
    .PARAMETER Type
    The type of the message (e.g., "Info", "Warning", "Critical") to be logged. Defaults to "Info".
    Type is independent of Level - it's just semantic meaning for display.
    .PARAMETER NoColor
    A switch parameter to disable color coding in the message.
    .PARAMETER Level
    Verbosity level (1-4) for filtering - independent of Type.
    1=Most important, 2=Important, 3=Normal, 4=Debug/Verbose
    Message shows if Level <= LogVerbosity threshold. Defaults to 3.
    .PARAMETER AsLog
    When false, treat as a plain console message (no timestamp/type, not written to file).
    Defaults to true (full log format).
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
    [switch]$NoColor,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1,4)]
    [int]$Level = 3,

    [Parameter(Mandatory = $false)]
    [bool]$AsLog = $true
  )

  # Non-log console message: no timestamp/type and not written to file
  if (-not $AsLog) {
    Write-Host $LogMessage
    return
  }

  # Logging disabled entirely
  if (-not $script:Config.LogFlag) { return }

  # Enforce verbosity threshold: Message shows if Level <= LogVerbosity
  # Type (Info/Warning/Error/Critical) is separate - just semantic meaning for display
  # Level (1-4) is for filtering - assigned per message independently
  $threshold = if ($null -ne $script:Config.LogVerbosity) { [int]$script:Config.LogVerbosity } else { 3 }
  if ($Level -gt $threshold) { return }

  # Resolve formatting configuration
  $tsFormat = if ($script:Config.LogTimestampFormat) { $script:Config.LogTimestampFormat } else { "yyyy-MM-dd HH:mm:ss" }

  # Map type to icon and short label
  $TypeIcon = switch ($Type) {
    "Info"     { "ℹ️" }
    "Warning"  { "⚠️" }
    "Error"    { "❗" }
    "Critical" { "📛" }
    Default     { "✅" }
  }
  $TypeShort = switch ($Type) {
    "Info"     { "INFO" }
    "Warning"  { "WARN" }
    "Error"    { "ERRS" }
    "Critical" { "CRIT" }
    Default     { "INFO" }
  }
  $Timestamp = Get-Date -Format $tsFormat
  $FormattedMessage = "[$Timestamp] $TypeIcon [$TypeShort] $LogMessage"

  # Console output (optional)
  if ($script:Config.LogWriteToConsole) {
    $fg = switch ($Type) {
      "Info"     { 'Green' }
      "Warning"  { 'Yellow' }
      "Error"    { 'Red' }
      "Critical" { 'Magenta' }
      default     { 'White' }
    }
    if ($NoColor) { $fg = 'White' }
    Write-Host $FormattedMessage -ForegroundColor $fg
  }

  # File output (optional)
  if ($script:Config.LogWriteToFile -and $script:Config.LogFileLocation) {
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


function Set-TimeWaitMax-FromPowerStatus {
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
      # Use the minimum of system timeout (minus 5s safety margin) and Config value
      # This ensures we respect user's desired max wait time while still preventing sleep
      $systemMax = $timeout - 5
      $configMax = $script:Config.TimeWaitMax
      $script:Config.TimeWaitMax = [Math]::Min($systemMax, $configMax)
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
    .PARAMETER TypingActivity
    Typing activity information including typing speed and pattern.
    .PARAMETER TrackpadGestures
    Array of trackpad gestures detected.
    .OUTPUTS
    [PSCustomObject] containing:
    - IsActive: True if any user activity detected
    - Reasons: Array of detailed status messages
    - ActivityType: Type of activity detected
    - Confidence: Confidence level (0-100) of activity detection
    - InputDevice: Type of input device used (Mouse, Trackpad)
    - GestureType: Type of trackpad gesture detected
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
      $script:ActivityCheckCount = 0
      $script:LastSystemMetrics = $null
    }

    # Skip if less than TimeCooldown since last check
    if (([datetime]::Now - $script:LastCheckTime).TotalSeconds -le $Script:Config.TimeCooldown) {
      return $false
    }

    # Update last check time
    $script:LastCheckTime = [datetime]::Now
    $script:ActivityCheckCount++

    # Load assemblies only once
    if (-not $script:AssembliesLoaded) {
      Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
      Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
      $script:AssembliesLoaded = $true
    }

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

      # Reset brightness and energy efficiency if configured
      if ($script:Config.BrightnessFlag -and $script:BrightnessState -ne "Normal") {
          $script:BrightnessState = "Normal"
          Write-Message -LogMessage "Restoring energy efficiency settings due to user activity." -Type "Info"
          Set-EnergyEfficiencyMode -Mode "Normal"
      }
      return $true
    }
    else {
      $inactiveSeconds = [datetime]::Now - $script:LastActivityTime

      # Apply energy efficiency measures if inactive for too long
      if ($script:Config.BrightnessFlag -and 
        $inactiveSeconds.TotalSeconds -gt $script:Config.TimeWaitMax -and
        $script:BrightnessState -eq "Normal"
      ) {
          $script:BrightnessState = "Dimmed"
          Write-Message -LogMessage "Applying energy efficiency measures due to inactivity: $($activityStatus.Reasons -join ' | ')" -Type "Warning"
          Set-EnergyEfficiencyMode -Mode $script:Config.EnergyEfficiencyMode
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

    # Reset energy efficiency settings to normal
    if ($script:Config.BrightnessFlag) {
      try {
        Set-EnergyEfficiencyMode -Mode "Normal"
        Write-Message -LogMessage "Energy efficiency settings restored to normal" -Type "Info"
      } catch {
        Write-Message -LogMessage "Failed to restore energy efficiency settings: $($_.Exception.Message)" -Type "Warning"
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


function Test-WorkingHours {
  <#
    .SYNOPSIS
    Checks if the current time is within working hours and handles bypass options.
    .DESCRIPTION
    Determines if the script should run based on working hours, holidays, and bypass parameters.
    Provides detailed messaging about why the script is or isn't running.
    .PARAMETER CurrentTime
    The current date/time to check.
    .PARAMETER IgnoreWorkingHours
    Bypass working hours restrictions.
    .PARAMETER IgnoreHolidays
    Bypass holiday restrictions.
    .PARAMETER ForceRun
    Bypass all restrictions.
    .OUTPUTS
    [PSCustomObject] containing working hours status and messages.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [datetime]$CurrentTime,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreWorkingHours = $false,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreHolidays = $false,

    [Parameter(Mandatory = $false)]
    [switch]$ForceRun = $false
  )

  try {
    $status = @{
      ShouldRun = $false
      Reason = ""
      Messages = @()
      NextRunTime = $null
      BypassReasons = @()
    }

    # Check if ForceRun is enabled
    if ($ForceRun) {
      $status.ShouldRun = $true
      $status.Reason = "ForceRun enabled - bypassing all restrictions"
      $status.BypassReasons += "All restrictions bypassed"
      $status.Messages += "🚀 ForceRun enabled - running regardless of time/day restrictions"
      return [PSCustomObject]$status
    }

    # Check if it's a working day
    $isWorkingDay = $CurrentTime.DayOfWeek -notin $script:Config.NotWorkingDays
    if (-not $isWorkingDay) {
      $status.Messages += "📅 Today is $($CurrentTime.DayOfWeek) - not a working day"
      if (-not $IgnoreWorkingHours) {
        $status.Reason = "Not a working day"
        $status.Messages += "❌ Script will not run on non-working days"
        
        # Calculate next working day
        $nextWorkingDay = $CurrentTime
        do {
          $nextWorkingDay = $nextWorkingDay.AddDays(1)
        } while ($nextWorkingDay.DayOfWeek -in $script:Config.NotWorkingDays)
        
        $status.NextRunTime = $nextWorkingDay.Date.Add($script:Config.TimeStart)
        $status.Messages += "⏰ Next run: $($status.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        return [PSCustomObject]$status
      } else {
        $status.BypassReasons += "Working day restriction bypassed"
        $status.Messages += "✅ Working day restriction bypassed"
      }
    } else {
      $status.Messages += "✅ Today is $($CurrentTime.DayOfWeek) - working day"
    }

    # Check if it's a holiday
    $isHoliday = Test-Holiday -Date $CurrentTime -CountryCode $script:Config.CountryCode -LanguageCode $script:Config.LanguageCode
    if ($isHoliday) {
      $status.Messages += "🎉 Today is a public holiday"
      if (-not $IgnoreHolidays) {
        $status.Reason = "Public holiday"
        $status.Messages += "❌ Script will not run on public holidays"
        
        # Calculate next working day after holiday
        $nextWorkingDay = $CurrentTime.AddDays(1)
        while ($nextWorkingDay.DayOfWeek -in $script:Config.NotWorkingDays -or 
               (Test-Holiday -Date $nextWorkingDay -CountryCode $script:Config.CountryCode -LanguageCode $script:Config.LanguageCode)) {
          $nextWorkingDay = $nextWorkingDay.AddDays(1)
        }
        
        $status.NextRunTime = $nextWorkingDay.Date.Add($script:Config.TimeStart)
        $status.Messages += "⏰ Next run: $($status.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        return [PSCustomObject]$status
      } else {
        $status.BypassReasons += "Holiday restriction bypassed"
        $status.Messages += "✅ Holiday restriction bypassed"
      }
    } else {
      $status.Messages += "✅ Today is not a public holiday"
    }

    # Check if it's within working hours
    $isWithinHours = $CurrentTime -ge $script:Config.TimeStart -and $CurrentTime -le $script:Config.TimeEnd
    if (-not $isWithinHours) {
      $status.Messages += "🕐 Current time: $($CurrentTime.ToString('HH:mm:ss'))"
      $status.Messages += "⏰ Working hours: $($script:Config.TimeStart.ToString('HH:mm:ss')) - $($script:Config.TimeEnd.ToString('HH:mm:ss'))"
      
      if (-not $IgnoreWorkingHours) {
        $status.Reason = "Outside working hours"
        $status.Messages += "❌ Script will not run outside working hours"
        
        # Calculate next run time
        if ($CurrentTime -lt $script:Config.TimeStart) {
          # Before start time - run today
          $status.NextRunTime = $CurrentTime.Date.Add($script:Config.TimeStart)
        } else {
          # After end time - run tomorrow
          $nextDay = $CurrentTime.Date.AddDays(1)
          # Skip non-working days and holidays
          while ($nextDay.DayOfWeek -in $script:Config.NotWorkingDays -or 
                 (Test-Holiday -Date $nextDay -CountryCode $script:Config.CountryCode -LanguageCode $script:Config.LanguageCode)) {
            $nextDay = $nextDay.AddDays(1)
          }
          $status.NextRunTime = $nextDay.Add($script:Config.TimeStart)
        }
        
        $status.Messages += "⏰ Next run: $($status.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        return [PSCustomObject]$status
      } else {
        $status.BypassReasons += "Working hours restriction bypassed"
        $status.Messages += "✅ Working hours restriction bypassed"
      }
    } else {
      $status.Messages += "✅ Current time is within working hours"
    }

    # Check if it's during a break
    $isDuringBreak = $false
    $breakInfo = ""
    
    if ($CurrentTime -ge $script:Config.TimeBreak01 -and $CurrentTime -le $script:Config.TimeBreak01.AddMinutes($script:Config.DurationBreak01)) {
      $isDuringBreak = $true
      $breakInfo = "Break 1 ($($script:Config.TimeBreak01.ToString('HH:mm')) - $($script:Config.TimeBreak01.AddMinutes($script:Config.DurationBreak01).ToString('HH:mm')))"
    } elseif ($CurrentTime -ge $script:Config.TimeBreak02 -and $CurrentTime -le $script:Config.TimeBreak02.AddMinutes($script:Config.DurationBreak02)) {
      $isDuringBreak = $true
      $breakInfo = "Break 2 ($($script:Config.TimeBreak02.ToString('HH:mm')) - $($script:Config.TimeBreak02.AddMinutes($script:Config.DurationBreak02).ToString('HH:mm')))"
    } elseif ($CurrentTime -ge $script:Config.TimeBreak03 -and $CurrentTime -le $script:Config.TimeBreak03.AddMinutes($script:Config.DurationBreak03)) {
      $isDuringBreak = $true
      $breakInfo = "Break 3 ($($script:Config.TimeBreak03.ToString('HH:mm')) - $($script:Config.TimeBreak03.AddMinutes($script:Config.DurationBreak03).ToString('HH:mm')))"
    }

    if ($isDuringBreak) {
      $status.Messages += "☕ Currently during $breakInfo"
      $status.Messages += "✅ Script will run during breaks"
    } else {
      $status.Messages += "✅ Not during any scheduled break"
    }

    # All checks passed
    $status.ShouldRun = $true
    $status.Reason = "All conditions met"
    $status.Messages += "✅ All working hours conditions met - script will run"

    return [PSCustomObject]$status
  } catch {
    Write-Message -LogMessage "Error checking working hours: $($_.Exception.Message)" -Type "Critical"
    return [PSCustomObject]@{
      ShouldRun = $false
      Reason = "Error checking working hours"
      Messages = @("❌ Error checking working hours: $($_.Exception.Message)")
      NextRunTime = $null
      BypassReasons = @()
    }
  }
}


function Get-ResourceUsage {
  <#
    .SYNOPSIS
    Gets current resource usage information for monitoring efficiency.
    .DESCRIPTION
    Monitors CPU, memory, and other resource usage to help optimize script performance.
    .OUTPUTS
    [PSCustomObject] containing resource usage information.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param()

  try {
    $process = Get-Process -Id $PID -ErrorAction SilentlyContinue
    $memory = [System.GC]::GetTotalMemory($false)
    
    $usage = @{
      ProcessId = $PID
      WorkingSet = if ($process) { $process.WorkingSet64 } else { 0 }
      PrivateMemory = if ($process) { $process.PrivateMemorySize64 } else { 0 }
      GCMemory = $memory
      ThreadCount = if ($process) { $process.Threads.Count } else { 0 }
      HandleCount = if ($process) { $process.HandleCount } else { 0 }
      CpuTime = if ($process) { $process.TotalProcessorTime } else { [TimeSpan]::Zero }
    }

    return [PSCustomObject]$usage
  } catch {
    return [PSCustomObject]@{
      ProcessId = $PID
      WorkingSet = 0
      PrivateMemory = 0
      GCMemory = 0
      ThreadCount = 0
      HandleCount = 0
      CpuTime = [TimeSpan]::Zero
    }
  }
}


function Optimize-ScriptPerformance {
  <#
    .SYNOPSIS
    Optimizes script performance by adjusting settings based on resource usage.
    .DESCRIPTION
    Monitors resource usage and adjusts script behavior to maintain efficiency.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param()

  try {
    $resourceUsage = Get-ResourceUsage
    
    # Adjust cooldown based on memory usage
    if ($resourceUsage.WorkingSet -gt 100MB) {
      $script:Config.TimeCooldown = [Math]::Min($script:Config.TimeCooldown + 1, 10)
      Write-Message -LogMessage "Increased cooldown to $($script:Config.TimeCooldown)s due to high memory usage" -Type "Info"
    } elseif ($resourceUsage.WorkingSet -lt 50MB) {
      $script:Config.TimeCooldown = [Math]::Max($script:Config.TimeCooldown - 1, 1)
    }

    # Force garbage collection if memory usage is high
    if ($resourceUsage.GCMemory -gt 50MB) {
      [System.GC]::Collect()
      [System.GC]::WaitForPendingFinalizers()
      Write-Message -LogMessage "Performed garbage collection due to high memory usage" -Type "Info"
    }

    # Log resource usage periodically
    if ($script:ActivityCheckCount -and $script:ActivityCheckCount % 100 -eq 0) {
      Write-Message -LogMessage "Resource usage - Memory: $([Math]::Round($resourceUsage.WorkingSet / 1MB, 2))MB, Threads: $($resourceUsage.ThreadCount), Handles: $($resourceUsage.HandleCount)" -Type "Info"
    }
  } catch {
    # Ignore optimization errors
  }
}


function Get-ScriptStatus {
  <#
    .SYNOPSIS
    Gets current script status and performance information.
    .DESCRIPTION
    Provides comprehensive status information including resource usage, activity detection, and configuration.
    .OUTPUTS
    [PSCustomObject] containing script status information.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param()

  try {
    $resourceUsage = Get-ResourceUsage
    $workingHoursInfo = Get-WorkingHoursInfo
    
    $status = @{
      ScriptRunning = $true
      StartTime = if ($script:ScriptStartTime) { $script:ScriptStartTime } else { Get-Date }
      Uptime = if ($script:ScriptStartTime) { (Get-Date) - $script:ScriptStartTime } else { [TimeSpan]::Zero }
      ActivityChecks = if ($script:ActivityCheckCount) { $script:ActivityCheckCount } else { 0 }
      ResourceUsage = $resourceUsage
      WorkingHours = $workingHoursInfo
      BrightnessState = if ($script:BrightnessState) { $script:BrightnessState } else { "Unknown" }
      LastActivity = if ($script:LastActivityTime) { $script:LastActivityTime } else { "Unknown" }
      Config = @{
        KeepAliveMethod = $script:Config.KeepAliveMethod
        TimeWaitMin = $script:Config.TimeWaitMin
        TimeWaitMax = $script:Config.TimeWaitMax
        BrightnessFlag = $script:Config.BrightnessFlag
        EnergyEfficiencyMode = $script:Config.EnergyEfficiencyMode
      }
    }

    return [PSCustomObject]$status
  } catch {
    return [PSCustomObject]@{
      ScriptRunning = $false
      Error = $_.Exception.Message
    }
  }
}


function Show-ScriptHelp {
  <#
    .SYNOPSIS
    Shows comprehensive help information for the WakeyWindows script.
    .DESCRIPTION
    Displays detailed help information including parameters, examples, and usage tips.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param()

  Write-Host "`n🚀 WakeyWindows - Keep Your PC Awake Script" -ForegroundColor Cyan
  Write-Host ("=" * 70) -ForegroundColor Cyan
  
  Write-Host "`n📋 PARAMETERS:" -ForegroundColor Yellow
  $defaultMethod = if ($script:Config -and $script:Config.KeepAliveMethod) { $script:Config.KeepAliveMethod } else { "Send-KeyPress" }
  Write-Host "  -Method <string>           : Keep-alive method (Send-KeyPress, Start-AppSession, etc.)" -ForegroundColor White
  Write-Host "                            Default: $defaultMethod" -ForegroundColor Gray
  Write-Host "  -Arg <string>              : Argument for the method (e.g., F16, Notepad)" -ForegroundColor White
  $defaultKey = if ($script:Config -and $script:Config.Key) { $script:Config.Key } else { "random from config" }
  Write-Host "                            Default: $defaultKey" -ForegroundColor Gray
  Write-Host "  -IgnoreBrightness          : Disable brightness control" -ForegroundColor White
  $brightnessDefault = if ($script:Config -and $script:Config.BrightnessFlag) { "enabled" } else { "disabled" }
  Write-Host "                            Default: $brightnessDefault" -ForegroundColor Gray
  Write-Host "  -IgnoreWorkingHours        : Bypass time restrictions" -ForegroundColor White
  if ($script:Config -and $script:Config.TimeStart -and $script:Config.TimeEnd) {
    Write-Host "                            Default: $($script:Config.TimeStart.ToString('HH:mm'))-$($script:Config.TimeEnd.ToString('HH:mm'))" -ForegroundColor Gray
  }
  Write-Host "  -IgnoreHolidays            : Bypass holiday restrictions" -ForegroundColor White
  if ($script:Config -and $script:Config.CountryCode) {
    Write-Host "                            Default: enabled, country: $($script:Config.CountryCode)" -ForegroundColor Gray
  }
  Write-Host "  -ForceRun                  : Bypass ALL restrictions" -ForegroundColor White
  Write-Host "  -LogVerbosity <0-4>        : 0=Silent, 1=Errors, 2=Warnings+, 3=Info+, 4=Debug" -ForegroundColor White
  $defaultVerbosity = if ($script:Config -and $script:Config.LogVerbosity) { $script:Config.LogVerbosity } else { 4 }
  Write-Host "                            Default: $defaultVerbosity" -ForegroundColor Gray
  
  Write-Host "`n🔧 EXAMPLES:" -ForegroundColor Yellow
  Write-Host "  .\Main.ps1 -Method Send-KeyPress -Arg F16" -ForegroundColor Green
  Write-Host "  .\Main.ps1 -Method Start-AppSession -Arg Notepad -IgnoreBrightness" -ForegroundColor Green
  Write-Host "  .\Main.ps1 -Method Send-KeyPress -Arg F16 -ForceRun" -ForegroundColor Green
  Write-Host "  .\Main.ps1 -Method Random -IgnoreWorkingHours" -ForegroundColor Green
  
  Write-Host "`n⚡ KEEP-ALIVE METHODS:" -ForegroundColor Yellow
  Write-Host "  Send-KeyPress              : Press a key (most efficient)" -ForegroundColor White
  Write-Host "  Start-AppSession           : Open/close applications" -ForegroundColor White
  Write-Host "  Start-EdgeSession          : Open/close web pages" -ForegroundColor White
  Write-Host "  Invoke-CMDlet              : Run PowerShell commands" -ForegroundColor White
  Write-Host "  Move-MouseRandom           : Move mouse cursor" -ForegroundColor White
  Write-Host "  Random                     : Randomly choose method" -ForegroundColor White
  
  Write-Host "`n💡 TIPS:" -ForegroundColor Yellow
  Write-Host "  • Use -ForceRun to run anytime" -ForegroundColor White
  Write-Host "  • Use -IgnoreBrightness to disable screen dimming" -ForegroundColor White
  Write-Host "  • Send-KeyPress is most energy efficient" -ForegroundColor White
  Write-Host "  • Check Config.ps1 for customization options" -ForegroundColor White
  
  Write-Host ("=" * 70) -ForegroundColor Cyan
  Write-Host ""
}


function Get-WorkingHoursInfo {
  <#
    .SYNOPSIS
    Gets detailed information about working hours configuration.
    .DESCRIPTION
    Provides comprehensive information about working hours, breaks, holidays, and scheduling.
    .OUTPUTS
    [PSCustomObject] containing working hours information.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param()

  try {
    $info = @{
      WorkingDays = $script:Config.NotWorkingDays
      WorkingHours = "$($script:Config.TimeStart.ToString('HH:mm')) - $($script:Config.TimeEnd.ToString('HH:mm'))"
      Breaks = @()
      HolidayCountry = $script:Config.CountryCode
      HolidayLanguage = $script:Config.LanguageCode
      CurrentTime = Get-Date
      IsWorkingDay = (Get-Date).DayOfWeek -notin $script:Config.NotWorkingDays
      IsWithinHours = (Get-Date) -ge $script:Config.TimeStart -and (Get-Date) -le $script:Config.TimeEnd
      IsHoliday = Test-Holiday -Date (Get-Date) -CountryCode $script:Config.CountryCode -LanguageCode $script:Config.LanguageCode
    }

    # Add break information
    $info.Breaks += "Break 1: $($script:Config.TimeBreak01.ToString('HH:mm')) - $($script:Config.TimeBreak01.AddMinutes($script:Config.DurationBreak01).ToString('HH:mm')) ($($script:Config.DurationBreak01) min)"
    $info.Breaks += "Break 2: $($script:Config.TimeBreak02.ToString('HH:mm')) - $($script:Config.TimeBreak02.AddMinutes($script:Config.DurationBreak02).ToString('HH:mm')) ($($script:Config.DurationBreak02) min)"
    $info.Breaks += "Break 3: $($script:Config.TimeBreak03.ToString('HH:mm')) - $($script:Config.TimeBreak03.AddMinutes($script:Config.DurationBreak03).ToString('HH:mm')) ($($script:Config.DurationBreak03) min)"

    return [PSCustomObject]$info
  } catch {
    Write-Message -LogMessage "Error getting working hours info: $($_.Exception.Message)" -Type "Warning"
    return [PSCustomObject]@{
      WorkingDays = @()
      WorkingHours = "Unknown"
      Breaks = @()
      HolidayCountry = "Unknown"
      HolidayLanguage = "Unknown"
      CurrentTime = Get-Date
      IsWorkingDay = $false
      IsWithinHours = $false
      IsHoliday = $false
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
    Simulates pressing a specific key using .NET methods. Supports F1-F12 (via SendKeys) and F13-F24 (via Win32 SendInput API).
    Common keys like NUMLOCK, CAPSLOCK, and special keys are also supported.
    .PARAMETER Key
    The key value to be pressed (e.g., '{F1}', '{F16}', 'A', '{ENTER}', '{NUMLOCK}').
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Key
  )

  # Validate key is not empty
  if ([string]::IsNullOrWhiteSpace($Key)) {
    Write-Message -LogMessage "Key argument is empty or null." -Type "Warning"
    return
  }

  try {
    # Load assembly only once (cache check using script-scoped variable)
    if (-not $script:WindowsFormsLoaded) {
      Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
      $script:WindowsFormsLoaded = $true
    }

    # Handle extended function keys (F13-F24) using Win32 SendInput API
    # SendKeys only supports F1-F12, so we need Win32 API for F13-F24
    $fMatch = [regex]::Match($Key, '^\{F(\d{1,2})\}$')
    if ($fMatch.Success) {
      $fn = [int]$fMatch.Groups[1].Value
      if ($fn -ge 13 -and $fn -le 24) {
        # Lazy-load Win32 SendInput API only when needed (F13-F24)
        if (-not ("Win32.KeyboardInput" -as [type])) {
          Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Win32 {
  public static class KeyboardInput {
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT {
      public uint type;
      public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    struct InputUnion {
      [FieldOffset(0)]
      public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT {
      public ushort wVk;
      public ushort wScan;
      public uint dwFlags;
      public uint time;
      public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    const uint INPUT_KEYBOARD = 1;
    const uint KEYEVENTF_KEYUP = 0x0002;

    public static void SendVirtualKey(ushort vk) {
      var down = new INPUT {
        type = INPUT_KEYBOARD,
        U = new InputUnion {
          ki = new KEYBDINPUT {
            wVk = vk,
            wScan = 0,
            dwFlags = 0,
            time = 0,
            dwExtraInfo = IntPtr.Zero
          }
        }
      };
      var up = new INPUT {
        type = INPUT_KEYBOARD,
        U = new InputUnion {
          ki = new KEYBDINPUT {
            wVk = vk,
            wScan = 0,
            dwFlags = KEYEVENTF_KEYUP,
            time = 0,
            dwExtraInfo = IntPtr.Zero
          }
        }
      };
      INPUT[] inputs = new INPUT[] { down, up };
      SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
    }
  }
}
"@ -ErrorAction Stop
        }
        
        # Calculate virtual key code (F1 = 0x70, F2 = 0x71, ..., F16 = 0x7F)
        $vk = [ushort](0x70 + ($fn - 1))
        
    # Log the event
    Write-Message -LogMessage "The key '$Key' (F$fn) is going to be pressed using Win32 API." -Type "Info" -Level 2
        
        # Send using Win32 SendInput
        [Win32.KeyboardInput]::SendVirtualKey($vk)
        return
      }
    }

    # Log the event
    Write-Message -LogMessage "The key '$Key' is going to be pressed." -Type "Info" -Level 2

    # Flush any pending keystrokes for reliability
    [System.Windows.Forms.SendKeys]::Flush()

    # Send the key (F1-F12 and other keys use SendKeys)
    [System.Windows.Forms.SendKeys]::SendWait($Key)

  } catch [System.Reflection.ReflectionTypeLoadException] {
    Write-Message -LogMessage "Failed to load System.Windows.Forms assembly: $($_.Exception.Message)" -Type "Critical"
  } catch {
    Write-Message -LogMessage "Error sending key '$Key': $($_.Exception.Message)" -Type "Critical"
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
    Adjusts the screen brightness level with multi-monitor support and smooth transitions.
    .DESCRIPTION
    Sets the screen brightness to a specified level with support for multiple monitors,
    smooth transitions, and various energy efficiency features.
    .PARAMETER Level
    The desired brightness level (0-100).
    .PARAMETER SmoothTransition
    Enable smooth brightness transitions instead of instant changes.
    .PARAMETER MonitorIndex
    Specific monitor index to adjust (0 for all monitors).
    .PARAMETER TurnOffMonitors
    Turn off monitors instead of just dimming them.
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 100)]
    [int]$Level,

    [Parameter(Mandatory = $false)]
    [switch]$SmoothTransition,

    [Parameter(Mandatory = $false)]
    [int]$MonitorIndex = 0,

    [Parameter(Mandatory = $false)]
    [switch]$TurnOffMonitors = $false
  )

  try {
    # If turning off monitors, use a different approach
    if ($TurnOffMonitors -and $Level -eq 0) {
      Set-MonitorPower -State "Off"
      return
    }

    # Get all monitors
    $monitors = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue
    
    if (-not $monitors) {
      Write-Message -LogMessage "No monitors found for brightness control." -Type "Warning"
      return
    }

    # If MonitorIndex is 0, adjust all monitors
    $monitorsToAdjust = if ($MonitorIndex -eq 0) { $monitors } else { $monitors | Select-Object -Index ($MonitorIndex - 1) }

    foreach ($monitor in $monitorsToAdjust) {
      $currentBrightness = $monitor.CurrentBrightness
      
      if ($Level -ne $currentBrightness) {
        Write-Message -LogMessage "Adjusting monitor brightness from $currentBrightness% to $Level%." -Type "Info"

        if ($SmoothTransition -or $script:Config.BrightnessSmoothTransition) {
          # Smooth transition
          $steps = [Math]::Abs($Level - $currentBrightness)
          $stepSize = if ($steps -gt 0) { ($Level - $currentBrightness) / $steps } else { 0 }
          
          for ($i = 1; $i -le $steps; $i++) {
            $intermediateLevel = [Math]::Round($currentBrightness + ($stepSize * $i))
            $intermediateLevel = [Math]::Max(0, [Math]::Min(100, $intermediateLevel))
            
            try {
              $brightnessMethods = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods
              if ($brightnessMethods) {
                Invoke-CimMethod -InputObject $brightnessMethods -MethodName "WmiSetBrightness" -Arguments @{Timeout=0; Brightness=$intermediateLevel} | Out-Null
              }
            } catch {
              # Continue with next step even if one fails
            }
            
            Start-Sleep -Milliseconds 50  # Smooth transition delay
          }
        } else {
          # Instant change
          try {
            $brightnessMethods = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods
            if ($brightnessMethods) {
              Invoke-CimMethod -InputObject $brightnessMethods -MethodName "WmiSetBrightness" -Arguments @{Timeout=0; Brightness=$Level} | Out-Null
            }
          } catch {
            Write-Message -LogMessage "Failed to set brightness using WMI method." -Type "Warning"
          }
        }
      }
    }
  } catch {
    Write-Message -LogMessage "Error adjusting screen brightness: $($_.Exception.Message)" -Type "Critical"
  }
}


function Set-MonitorPower {
  <#
    .SYNOPSIS
    Controls monitor power state (on/off) for energy efficiency.
    .DESCRIPTION
    Turns monitors on or off to save energy when user is inactive.
    .PARAMETER State
    Monitor power state: "On", "Off", or "Standby".
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("On", "Off", "Standby")]
    [string]$State
  )

  try {
    # Use Windows API to control monitor power
    Add-Type -TypeDefinition @"
      using System;
      using System.Runtime.InteropServices;
      public class MonitorPower {
        [DllImport("user32.dll")]
        public static extern int SendMessage(IntPtr hWnd, int hMsg, IntPtr wParam, IntPtr lParam);
        
        [DllImport("user32.dll")]
        public static extern IntPtr GetDesktopWindow();
        
        public const int WM_SYSCOMMAND = 0x0112;
        public const int SC_MONITORPOWER = 0xF170;
        public const int MONITOR_ON = -1;
        public const int MONITOR_OFF = 2;
        public const int MONITOR_STANDBY = 1;
      }
"@

    $desktopWindow = [MonitorPower]::GetDesktopWindow()
    $command = switch ($State) {
      "On" { [MonitorPower]::MONITOR_ON }
      "Off" { [MonitorPower]::MONITOR_OFF }
      "Standby" { [MonitorPower]::MONITOR_STANDBY }
    }

    $result = [MonitorPower]::SendMessage($desktopWindow, [MonitorPower]::WM_SYSCOMMAND, [MonitorPower]::SC_MONITORPOWER, [IntPtr]$command)
    
    if ($result -eq 0) {
      Write-Message -LogMessage "Monitor power set to $State." -Type "Info"
    } else {
      Write-Message -LogMessage "Failed to set monitor power to $State." -Type "Warning"
    }
  } catch {
    Write-Message -LogMessage "Error controlling monitor power: $($_.Exception.Message)" -Type "Critical"
  }
}


function Get-MonitorInfo {
  <#
    .SYNOPSIS
    Gets information about all connected monitors.
    .DESCRIPTION
    Lists all connected monitors with their capabilities and current settings.
    .OUTPUTS
    [PSCustomObject] containing monitor information.
  #>

  [OutputType([PSCustomObject])]
  [CmdletBinding()]
  param()

  try {
    $monitors = @()
    
    # Get WMI monitor information
    $wmiMonitors = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue
    $wmiMethods = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue
    
    # Get display configuration
    $displayConfig = Get-CimInstance -ClassName Win32_DisplayConfiguration -ErrorAction SilentlyContinue
    
    for ($i = 0; $i -lt $wmiMonitors.Count; $i++) {
      $monitor = $wmiMonitors[$i]
      $method = if ($wmiMethods -and $i -lt $wmiMethods.Count) { $wmiMethods[$i] } else { $null }
      
      $monitorInfo = @{
        Index = $i
        InstanceName = $monitor.InstanceName
        CurrentBrightness = $monitor.CurrentBrightness
        Level = $monitor.Level
        BrightnessControlSupported = $null -ne $method
        DeviceName = if ($displayConfig -and $i -lt $displayConfig.Count) { $displayConfig[$i].DeviceName } else { "Unknown" }
        PixelsPerXLogicalInch = if ($displayConfig -and $i -lt $displayConfig.Count) { $displayConfig[$i].PixelsPerXLogicalInch } else { 0 }
        PixelsPerYLogicalInch = if ($displayConfig -and $i -lt $displayConfig.Count) { $displayConfig[$i].PixelsPerYLogicalInch } else { 0 }
      }
      
      $monitors += [PSCustomObject]$monitorInfo
    }
    
    return $monitors
  } catch {
    Write-Message -LogMessage "Error getting monitor information: $($_.Exception.Message)" -Type "Warning"
    return @()
  }
}


function Set-EnergyEfficiencyMode {
  <#
    .SYNOPSIS
    Sets various energy efficiency modes when user is inactive.
    .DESCRIPTION
    Applies multiple energy-saving measures including brightness, monitor power,
    and system power settings to maximize energy efficiency.
    .PARAMETER Mode
    Energy efficiency mode: "Normal", "Dim", "Sleep", or "Off".
    .OUTPUTS
    None
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Normal", "Dim", "Sleep", "Off")]
    [string]$Mode
  )

  try {
    switch ($Mode) {
      "Normal" {
        # Restore normal settings
        if ($script:Config.BrightnessFlag) {
          Set-ScreenBrightness -Level $script:Config.BrightnessInitial -SmoothTransition:$script:Config.BrightnessSmoothTransition
        }
        Set-MonitorPower -State "On"
        Write-Message -LogMessage "Energy efficiency mode set to Normal." -Type "Info"
      }
      
      "Dim" {
        # Dim screens but keep them on
        if ($script:Config.BrightnessFlag) {
          Set-ScreenBrightness -Level $script:Config.BrightnessMin -SmoothTransition:$script:Config.BrightnessSmoothTransition
        }
        Write-Message -LogMessage "Energy efficiency mode set to Dim." -Type "Info"
      }
      
      "Sleep" {
        # Put monitors to sleep
        Set-MonitorPower -State "Standby"
        Write-Message -LogMessage "Energy efficiency mode set to Sleep." -Type "Info"
      }
      
      "Off" {
        # Turn off monitors completely
        Set-MonitorPower -State "Off"
        Write-Message -LogMessage "Energy efficiency mode set to Off." -Type "Info"
      }
    }
  } catch {
    Write-Message -LogMessage "Error setting energy efficiency mode: $($_.Exception.Message)" -Type "Critical"
  }
}