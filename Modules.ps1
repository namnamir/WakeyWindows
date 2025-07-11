# Load configurations
. .\Config.ps1


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
  if ($LogFlag) {
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
    if ($Global:LogFileLocation) {
        try {
            $logDir = Split-Path $Global:LogFileLocation
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $Global:LogFileLocation -Value $FormattedMessage
        } catch {
            Write-Host "Failed to write to log file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
  }
}


function Time-Delta-Humanize {
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


function Run-CMDlet {
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


function Press-Key {
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


function Mouse-Jiggling {
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


function Open-Close-App {
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
    [int]$WaitTime = ((Get-Random -Minimum $TimeWaitMin -Maximum $TimeWaitMax) * 0.6)
  )

  try {
    # Open the application
    Start-Process $Application

    # Log the event with calculated wait time
    Write-Message -LogMessage "The application '$Application' will be opened for '$(Time-Delta-Humanize (New-TimeSpan -Seconds $WaitTime))' and then closed at '$((Get-Date).AddSeconds($WaitTime))'." -Type "Info"

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


function Open-Close-Edge-Tab {
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
    [int]$WaitTime = ((Get-Random -Minimum $TimeWaitMin -Maximum $TimeWaitMax) * 0.6)
  )

  try {
    # Calculate the close time
    $CloseTime = (Get-Date).AddSeconds($WaitTime)

    # Open the webpage
    Start-Process microsoft-edge:$Webpage

    # Log the event with calculated wait time
    Write-Message -LogMessage "The webpage '$Webpage' will be opened in Edge for '$(Time-Delta-Humanize (New-TimeSpan -Seconds $WaitTime))' and then closed at '$CloseTime'." -Type "Info"

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


function Change-Screen-Brightness {
    <#
        .SYNOPSIS
        Adjusts the screen brightness level.
    
        .DESCRIPTION
        Sets the screen brightness to a specified level ("min" or "max").
    
        .PARAMETER State
        A text indicating the desired brightness level ("min" or "max").
    
        .OUTPUTS
        None
    #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("min","max")] # Restrict State parameter to "min" or "max"
    [string]$State
  )

  try {
    # Change the brightness only if requested
    if ($BrightnessFlag) {
      # Get the current screen brightness level
      $CurrentBrightness = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness).CurrentBrightness

      # Determine the target brightness based on the State parameter
      $TargetBrightness = if ($State -eq "min") { $BrightnessMin } elseif ($State -eq "max") { $BrightnessMax } else { Write-Error "Invalid State parameter. Must be 'min' or 'max'."; return }

      # Log the event
      Write-Message -LogMessage "The screen brightness will be changed from $CurrentBrightness% to $TargetBrightness%." -Type "Info"

      # Change the brightness of the screen
      (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,$TargetBrightness)
    }
  } catch {
    Write-Message -LogMessage "Error adjusting screen brightness: $($_.Exception.Message)" -Type "Critical"
  }
}


function Check-Holiday {
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


function Change-Teams-Status {
    <#
        .SYNOPSIS
        Changes the Microsoft Teams presence status of the signed-in user.
    
        .DESCRIPTION
        Connects to Microsoft Graph to update the presence information of the signed-in user.
    
        .PARAMETER Presence
        The desired presence status for Microsoft Teams (e.g., "Available", "Away", "Busy", "DoNotDisturb").
    
        .INPUTS
        None
    
        .OUTPUTS
        None
    #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateSet("Available","Away","Busy","DoNotDisturb")]
    [string]$Presence
  )

  try {
    # Install the Microsoft.Graph module if not already installed
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
      # Set execution policy to Unrestricted
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force
      # Install the module
      Install-Module Microsoft.Graph -Scope CurrentUser -Force
    }

    # Connect to Microsoft Graph using modern authentication (more secure)
    Connect-MgGraph -UseDeviceCode

    #   Import-Module Microsoft.Graph.CloudCommunications
    #   Import-Module Microsoft.Graph.Users.Actions

    #   # Get the user ID
    #   $UserID = (Get-MGUser -Userid "email@site.com").Id

    #   Get-MgUserPresence -UserId $userId
    #   Set-MgUserPresence -UserId $userId -BodyParameter $params

    # Specify presence information for the signed-in user
    $PresenceUpdate = New-Object Microsoft.Graph.Presence
    $PresenceUpdate.Availability = $Presence

    # Update the presence for the signed-in user
    Update-MgUser -UserId "me" -Body $PresenceUpdate

    # Success message
    Write-Message "Your Microsoft Teams presence has been changed to '$Presence'." -Type "Information"
  } catch {
    Write-Message -LogMessage "Error changing Teams status: $($_.Exception.Message)" -Type "Critical"
  } finally {
    Disconnect-MgGraph
  }
}
