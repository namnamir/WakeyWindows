param(
    [string]$Method,      # e.g. "Press-Key"
    [string]$Arg          # e.g. "{NUMLOCK}"
)

# Load modules and configurations
. .\Modules.ps1
. .\Config.ps1

# Get the current date/time
$CurrentTime = Get-Date

# Handle the log file
if ($TranscriptFlag) {
  # Stop transcription if it is running
  try {
    Stop-Transcript
    Write-Message "Transcription stopped successfully."
  } catch {
    if ($_.Exception.Message -like "*The host is not currently transcribing*") {
      Write-Message "No active transcription to stop." -Type "Warning"
    } else {
      Write-Message "Failed to stop transcription: $($_.Exception.Message)" -Type "Error"
    }
  }
  # Start transcription with error handling
  try {
    # Start logging everything in the file
    Start-Transcript -Path $Global:TranscriptFileLocation
    Write-Message "Transcription started: $Global:TranscriptFileLocation"
  } catch {
    Write-Message "Failed to start transcription: $($_.Exception.Message)" -Type "Error"
  }
}

while (
  # Check if we are in the working days
  ($CurrentTime.DayOfWeek -notin $NotWorkingDays) -and
  # Check if we are in the working hours
  ($CurrentTime -gt $TimeStart) -and
  ($CurrentTime -lt $TimeEnd) -and
  # Check if we are in any of the breaks
  (
    ($CurrentTime -lt $TimeBreak01) -or
    ($CurrentTime -gt $TimeBreak01.AddMinutes($DurationBreak01)) -or
    ($CurrentTime -lt $TimeBreak02) -or
    ($CurrentTime -gt $TimeBreak02.AddMinutes($DurationBreak02)) -or
    ($CurrentTime -lt $TimeBreak03) -or
    ($CurrentTime -gt $TimeBreak03.AddMinutes($DurationBreak03))
  )
) {
  try {
    # Set the maximum wait time based on power status
    Set-TimeWaitMax-FromPowerStatus

    # Load configurations for the current iteration as they might change
    . .\Config.ps1

    # Check if the user is active, pause until the user is inactive
    while (User-Is-Active) {
      Start-Sleep -Seconds $Global:TimeWaitMax
    }

    # Override config if arguments are provided
    if ($Method) {
      $KeepAliveMethod = $Method
      # Log the event
      Write-Message -LogMessage "The method '$KeepAliveMethod' is defined by the user." -Type "Info"
      $Method = $null  # Nullify the Method variable to prevent repeated messages
    }
    if ($Arg) {
        switch ($KeepAliveMethod) {
            "Press-Key" {
                # Ensure the key is wrapped in double quotes and curly braces if missing
                if ($Arg -notmatch '^\{.*\}$') {
                  $Key = "{$Arg}"
                  Write-Message -LogMessage "Key argument was not in correct format. Converted to $Key." -Type "Warning"
                } else {
                    $Key = $Arg
                }
            }
            "Open-Close-App" { $Application = $Arg }
            "Open-Close-Edge-Tab" { $Webpage = $Arg }
            "Run-CMDlet" { $CMDlet = [ScriptBlock]::Create($Arg) }
        }
        # Log the event
        Write-Message -LogMessage "The argument of '$Arg' for '$KeepAliveMethod' is defined by the user." -Type "Info"
        $Arg = $null  # Nullify the Arg variable to prevent repeated messages
    }

    # Run the method of keeping Windows awake
    switch -Exact ($KeepAliveMethod) {
      "Press-Key" { Press-Key -Key $Key }
      "Open-Close-App" { Open-Close-App -Application $Application }
      "Open-Close-Edge-Tab" { Open-Close-Edge-Tab -Webpage $Webpage }
      "Run-CMDlet" { Run-CMDlet -CMDlet $CMDlet }
      "Mouse-Jiggling" { Mouse-Jiggling }
      # "Change-Teams-Status" { Change-Teams-Status }
      "Random" {
        $Func = Get-Random @("Press-Key", "Open-Close-Edge-Tab", "Run-CMDlet", "Open-Close-App", "Mouse-Jiggling")

        # Log the event
        Write-Message "The function '$Func' is running."

        # Dynamically call the function with arguments
        switch ($Func) {
          "Press-Key" { Press-Key -Key $Key }
          "Open-Close-App" { Open-Close-App -Application $Application }
          "Open-Close-Edge-Tab" { Open-Close-Edge-Tab -Webpage $Webpage }
          "Run-CMDlet" { Run-CMDlet -CMDlet $CMDlet }
          "Mouse-Jiggling" { Mouse-Jiggling }
        }
      }
      default {
        Write-Message "Invalid keep-alive method: $KeepAliveMethod; Ignoring." -Type "Critical"
      }
    }

    # Wait for a random time
    $TimeWait01 = Get-Random -Minimum $TimeWaitMin -Maximum $TimeWaitMax
    # Log the event
    Write-Message "The script will be paused for $(Time-Delta-Humanize $(New-TimeSpan -Seconds $TimeWait01)); resume at $((Get-Date).AddSeconds($TimeWait01))."
    # Wait
    Start-Sleep $TimeWait01
  } catch {
    # Handle errors during keep-alive methods or checks
    Write-Message "Error keeping system awake: $($_.Exception.Message)" -Type "Critical"
    Write-Message "Error occurred. Pausing script for 60 seconds." -Type "Critical"
    Start-Sleep -Seconds 60
  }

  # Stop running if there is no working hours
  if ((Get-Date) -gt $TimeEnd) {
    # Get the starting next starting time of the tomorrow
    $TimeStartTomorrow = $TimeStart.AddMinutes($(Get-Random -Minimum -5 -Maximum 15)).AddDays(1)

    # If tomorrow is in weekend or a public holiday
    if (
      ($TimeStartTomorrow.DayOfWeek -in $NotWorkingDays) -or
      (Check-Holiday -Date $TimeStartTomorrow)
    ) {
      $TimeWait02 = ($TimeStartTomorrow.AddDays(1) - (Get-Date)).TotalSeconds

      # Log message
      $LogMessage02 = "The working hour is passed and tomorrow is a holiday; so the script will be paused for"
    }
    else {
      $TimeWait02 = ($TimeStartTomorrow - (Get-Date)).TotalSeconds

      # Log message
      $LogMessage02 = "The working hour is passed; so the script will be paused for"
    }

    # Change the screen brightness
    Change-Screen-Brightness

    # Log the event
    Write-Message "$LogMessage02 $(Time-Delta-Humanize (New-TimeSpan -Seconds $TimeWait02)); resume at $((Get-Date).AddSeconds($TimeWait02))."

    # Wait until the next working day
    Start-Sleep $TimeWait02
  }
}

# Stop logging everything in the file
if ($TranscriptFlag) {
  try {
    Stop-Transcript
    Write-Message "Transcription stopped."
  } catch {
    if ($_.Exception.Message -like "*The host is not currently transcribing*") {
      Write-Message "No active transcription to stop." -Type "Warning"
    } else {
      Write-Message "Failed to stop transcription: $($_.Exception.Message)" -Type "Error"
    }
  }
}
