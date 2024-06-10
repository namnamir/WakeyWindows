# Load modules and configurations
. .\Modules.ps1
. .\Config.ps1

# Get the current date/time
$CurrentTime = Get-Date

# Start logging everything in the file
if ($LogFileFlag) {
  Start-Transcript -Path $LogFileLocation
}

while (
  # Check if we are in the working days
  ($CurrentTime.DayOfWeek -notin $NotWorkingDays) -and
  # Check if we are in the working hours
  ($CurrentTime -gt $Time_Start) -and
  ($CurrentTime -lt $Time_End) -and
  # Check if we are in any of the breaks
  (
    ($CurrentTime -lt $Time_Break_01) -or
    ($CurrentTime -gt $Time_Break_01.AddMinutes($Duration_Break_01)) -or
    ($CurrentTime -lt $Time_Break_02) -or
    ($CurrentTime -gt $Time_Break_02.AddMinutes($Duration_Break_02)) -or
    ($CurrentTime -lt $Time_Break_03) -or
    ($CurrentTime -gt $Time_Break_03.AddMinutes($Duration_Break_03))
  )
) {
  try {
    # Run the method of keeping Windows awake
    switch -Exact ($KeepAliveMethod)
    {
      "PressKey" { Press-Key $Key }
      "OpenCloseApp" { Open-Close-App $Application }
      "OpenCloseEdgeTab" { Open-Close-Edge-Tab $Webpage }
      "RunCMDlet" { Run-CMDlet $CMDlet }
      "MouseJiggling" { Mouse-Jiggling }
      "ChangeTeamsStatus" { Change-Teams-Status }
      "Random" {
        $Func = Get-Random @("PressKey","OpenCloseEdgeTab","RunCMDlet","OpenCloseApp","MouseJiggling","ChangeTeamsStatus")

        # Log the event
        Write-Message "The function '$Func' is running."

        & $Func
      }
      default {
        Write-Message "Invalid keep-alive method: $KeepAliveMethod; Ignoring." -Type "Critical"
      }
    }
    # Get a random waiting time
    $TimeWait01 = Get-Random -Minimum $TimeWaitMin -Maximum $TimeWaitMax

    # Log the event
    Write-Message "The script will be paused for $(TimeDeltaHumanize $(New-TimeSpan -Seconds $TimeWait01)); resume at $((Get-Date).AddSeconds($TimeWait01))."

    # Wait
    Start-Sleep $TimeWait01
  } catch {
    # Handle errors during keep-alive methods or checks
    Write-Message "Error keeping system awake: $($_.Exception.Message)"
    LogMessage "Error occurred. Pausing script for 60 seconds."
    Start-Sleep -Seconds 60
  }


  # Stop running if there is no working hours
  if ((Get-Date) -gt $Time_End) {
    # Get the starting next starting time of the tomorrow
    $TimeStartTomorrow = $Time_Start.AddMinutes($(Get-Random -Minimum -5 -Maximum 15)).AddDays(1)

    # If tomorrow is in weekend or a public holiday
    if (
      ($TimeStartTomorrow.DayOfWeek -in $NotWorkingDays) -or
      (IsPublicHoliday $TimeStartTomorrow)
    ) {
      $TimeWait02 = ($TimeStartTomorrow.AddDays(1) - (Get-Date)).TotalSeconds

      # Log message
      $LogMessage02 = "The working hour is passed and tomorrow is a holiday; so the scirpt will be paused for"
    }
    else {
      $TimeWait02 = ($TimeStartTomorrow - (Get-Date)).TotalSeconds

      # Log message
      $LogMessage02 = "The working hour is passed; so the scirpt will be paused for"
    }

    # Change the screen brighness
    Change-Screen-Brightness

    # Log the event
    Write-Message "$LogMessage02 $(Time-Delta-Humanize (New-TimeSpan -Seconds $TimeWait02)); resume at $((Get-Date).AddSeconds($TimeWait02))."

    # Wait until the next working day
    Start-Sleep $TimeWait02
  }
}

# Stop logging everything in the file
if ($LogFileFlag) {
  Stop-Transcript
}
