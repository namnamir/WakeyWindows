param(
    [string]$Method,            # e.g. "Send-KeyPress"
    [string]$Arg,               # e.g. "{NUMLOCK}"
    [switch]$IgnoreBrightness   # Pass -IgnoreBrightness to disable brightness changes
)

# Load modules and configurations
. .\Modules.ps1
. .\Config.ps1

# Set up cleanup handler for script interruption
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
  try {
    if (Get-Command Stop-ActivityDetection -ErrorAction SilentlyContinue) {
      Stop-ActivityDetection
    }
  } catch {
    # Ignore cleanup errors during exit
  }
}

# Set brightness flag
if ($IgnoreBrightness) {
  $script:Config.BrightnessFlag = $false
  Write-Message -LogMessage "Brightness changes disabled via command line switch" -Type "Info"
 }

# Get the current date/time
$CurrentTime = Get-Date

# Handle the log file
if ($script:Config.TranscriptStarted) {
  # Stop transcription if it is running
  try {
    Stop-Transcript
    Write-Message -LogMessage "Transcription stopped successfully."
  } catch {
    if ($_.Exception.Message -like "*The host is not currently transcribing*") {
      Write-Message -LogMessage "No active transcription to stop." -Type "Warning"
    } else {
      Write-Message -LogMessage "Failed to stop transcription: $($_.Exception.Message)" -Type "Error"
    }
  }
  # Start transcription with error handling
  try {
    # Start logging everything in the file
    Start-Transcript -Path $script:Config.TranscriptFileLocation
    Write-Message -LogMessage "Transcription started: $($script:Config.TranscriptFileLocation)" -Type "Info"
  } catch {
    Write-Message -LogMessage "Failed to start transcription: $($_.Exception.Message)" -Type "Error"
  }
} else {
    Start-Transcript -Path $script:Config.TranscriptFileLocation -Append
    $script:Config.TranscriptStarted = $true
    Write-Message -LogMessage "Transcription started: $($script:Config.TranscriptFileLocation)" -Type "Info"
}

while (
  # Check if we are in the working days
  ($CurrentTime.DayOfWeek -notin $script:Config.NotWorkingDays) -and
  # Check if we are in the working hours
  ($CurrentTime -gt $script:Config.TimeStart) -and
  ($CurrentTime -lt $script:Config.TimeEnd) -and
  # Check if we are in any of the breaks
  (
    ($CurrentTime -lt $script:Config.TimeBreak01) -or
    ($CurrentTime -gt $script:Config.TimeBreak01.AddMinutes($script:Config.DurationBreak01)) -or
    ($CurrentTime -lt $script:Config.TimeBreak02) -or
    ($CurrentTime -gt $script:Config.TimeBreak02.AddMinutes($script:Config.DurationBreak02)) -or
    ($CurrentTime -lt $script:Config.TimeBreak03) -or
    ($CurrentTime -gt $script:Config.TimeBreak03.AddMinutes($script:Config.DurationBreak03))
  )
) {
  try {
    # Set the maximum wait time based on power status
    Set-TimeWaitMax-FromPowerStatu

    # Load configurations for the current iteration as they might change
    . .\Config.ps1

    # Check if the user is active; if so, wait until they are inactive
    $pollInterval = 2
    $activeElapsed = 0

    while ($activeElapsed -lt $script:Config.TimeWaitMax) {
      if (-not (Test-UserActivity)) {
        break
      }
      Start-Sleep -Seconds $pollInterval
      $activeElapsed += $pollInterval
    }

    # Override config if arguments are provided
    if ($Method) {
      $script:Config.KeepAliveMethod = $Method
      # Log the event
      Write-Message -LogMessage "The method '$($script:Config.KeepAliveMethod)' is defined by the user." -Type "Info"
      $Method = $null  # Nullify the Method variable to prevent repeated messages
    }
    if ($Arg) {
        switch ($script:Config.KeepAliveMethod) {
            "Send-KeyPress" {
                # Ensure the key is wrapped in double quotes and curly braces if missing
                if ($Arg -notmatch '^\{.*\}$') {
                  $script:Config.Key = "{$Arg}"
                  Write-Message -LogMessage "Key argument was not in correct format. Converted to $($script:Config.Key)." -Type "Warning"
                } else {
                    $script:Config.Key = $Arg
                }
            }
            "Start-AppSession" { $script:Config.Application = $Arg }
            "Start-EdgeSession" { $script:Config.Webpage = $Arg }
            "Invoke-CMDlet" { $script:Config.CMDlet = [ScriptBlock]::Create($Arg) }
        }
        # Log the event
        Write-Message -LogMessage "The argument of '$Arg' for '$($script:Config.KeepAliveMethod)' is defined by the user." -Type "Info"
        $Arg = $null  # Nullify the Arg variable to prevent repeated messages
    }

    # Run the method of keeping Windows awake
    switch -Exact ($script:Config.KeepAliveMethod) {
      "Send-KeyPress" { Send-KeyPress -Key $script:Config.Key }
      "Start-AppSession" { Start-AppSession -Application $script:Config.Application }
      "Start-EdgeSession" { Start-EdgeSession -Webpage $script:Config.Webpage }
      "Invoke-CMDlet" { Invoke-CMDlet -CMDlet $script:Config.CMDlet }
      "Move-MouseRandom" { Move-MouseRandom }
      # "Change-Teams-Status" { Change-Teams-Status }
      "Random" {
        $Func = Get-Random @("Send-KeyPress", "Start-EdgeSession", "Invoke-CMDlet", "Start-AppSession", "Move-MouseRandom")

        # Log the event
        Write-Message -LogMessage "The function '$Func' is running."

        # Dynamically call the function with arguments
        switch ($Func) {
          "Send-KeyPress" { Send-KeyPress -Key $script:Config.Key }
          "Start-AppSession" { Start-AppSession -Application $script:Config.Application }
          "Start-EdgeSession" { Start-EdgeSession -Webpage $script:Config.Webpage }
          "Invoke-CMDlet" { Invoke-CMDlet -CMDlet $script:Config.CMDlet }
          "Move-MouseRandom" { Move-MouseRandom }
        }
      }
      default {
        Write-Message -LogMessage "Invalid keep-alive method: $($script:Config.KeepAliveMethod); Ignoring." -Type "Critical"
      }
    }

    # Wait for a random time
    $TimeWait01 = Get-Random -Minimum $script:Config.TimeWaitMin -Maximum $script:Config.TimeWaitMax
    # Log the event
    Write-Message -LogMessage "The script will be paused for $(Convert-TimeSpanToHumanReadable $(New-TimeSpan -Seconds $TimeWait01)); resume at $((Get-Date).AddSeconds($TimeWait01))."
    # Wait
    Start-Sleep $TimeWait01

  } catch {
    # Handle errors during keep-alive methods or checks
    Write-Message -LogMessage "Error keeping system awake: $($_.Exception.Message)" -Type "Critical"
    Write-Message -LogMessage "Error occurred. Pausing script for 60 seconds." -Type "Critical"
    Start-Sleep -Seconds 60
  }

  # Stop running if there is no working hours
  if ((Get-Date) -gt $script:Config.TimeEnd) {
    # Get the starting next starting time of the tomorrow
    $script:Config.TimeStartTomorrow = $script:Config.TimeStart.AddMinutes($(Get-Random -Minimum -5 -Maximum 15)).AddDays(1)

    # If tomorrow is in weekend or a public holiday
    if (
      ($script:Config.TimeStartTomorrow.DayOfWeek -in $script:Config.NotWorkingDays) -or
      (Test-Holiday -Date $script:Config.TimeStartTomorrow -CountryCode $script:Config.CountryCode -LanguageCode $script:Config.LanguageCode)
    ) {
      $TimeWait02 = ($script:Config.TimeStartTomorrow.AddDays(1) - (Get-Date)).TotalSeconds

      # Log message
      $LogMessage02 = "The working hour is passed and tomorrow is a holiday; so the script will be paused for"
    }
    else {
      $TimeWait02 = ($script:Config.TimeStartTomorrow - (Get-Date)).TotalSeconds

      # Log message
      $LogMessage02 = "The working hour is passed; so the script will be paused for"
    }

    # Log the event
    Write-Message -LogMessage "$LogMessage02 $(Convert-TimeSpanToHumanReadable (New-TimeSpan -Seconds $TimeWait02)); resume at $((Get-Date).AddSeconds($TimeWait02))."

    # Wait until the next working day
    Start-Sleep $TimeWait02
  }
}

# Stop activity detection and clean up resources
try {
  Stop-ActivityDetection
} catch {
  Write-Message -LogMessage "Error during activity detection cleanup: $($_.Exception.Message)" -Type "Warning"
}

# Stop logging everything in the file
if ($script:Config.TranscriptStarted) {
  try {
    Stop-Transcript
    $script:Config.TranscriptStarted = $false
    Write-Message -LogMessage "Transcription stopped." -Type "Info"
  } catch {
    if ($_.Exception.Message -like "*The host is not currently transcribing*") {
      Write-Message -LogMessage "No active transcription to stop." -Type "Warning"
    } else {
      Write-Message -LogMessage "Failed to stop transcription: $($_.Exception.Message)" -Type "Error"
    }
  }
}