# Load modules and configurations
. .\Modules.ps1
. .\Config.ps1

# Get the current date/time
$CurrentTime = Get-Date

# Handle the log file
if ($LogFileFlag) {
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
    # Load modules and configurations
    . .\Config.ps1

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
    Write-Message "Error keeping system awake: $($_.Exception.Message)"
    Write-Message "Error occurred. Pausing script for 60 seconds."
    Start-Sleep -Seconds 60
  }

  # Stop running if there is no working hours
  if ((Get-Date) -gt $TimeEnd) {
    # Get the starting next starting time of the tomorrow
    $TimeStartTomorrow = $TimeStart.AddMinutes($(Get-Random -Minimum -5 -Maximum 15)).AddDays(1)

    # If tomorrow is in weekend or a public holiday
    if (
      ($TimeStartTomorrow.DayOfWeek -in $NotWorkingDays) -or
      (Check-Holiday $TimeStartTomorrow)
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
if ($LogFileFlag) {
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
