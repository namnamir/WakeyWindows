param(
  [string]$Method,             # e.g. "Send-KeyPress"
  [string]$Arg,                # e.g. "{NUMLOCK}"
  [switch]$IgnoreBrightness,   # Pass -IgnoreBrightness to disable brightness changes
  [switch]$IgnoreWorkingHours, # Pass -IgnoreWorkingHours to bypass time restrictions
  [switch]$IgnoreHolidays,     # Pass -IgnoreHolidays to bypass holiday restrictions
  [switch]$ForceRun,           # Pass -ForceRun to bypass ALL restrictions (time, holidays, etc.)
  [switch]$Help                # Pass -Help to show help information
)

# Show help if requested
if ($Help) {
  . .\Modules.ps1
  Show-ScriptHelp
  exit 0
}

# Load modules and configurations
. .\Modules.ps1
. .\Config.ps1

# Track script start time for status monitoring
$script:ScriptStartTime = Get-Date

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

# Get the current date/time
$CurrentTime = Get-Date

# Check working hours and bypass options
$workingHoursStatusArgs = @{
    CurrentTime = $CurrentTime
}
if ($IgnoreWorkingHours) { $workingHoursStatusArgs.IgnoreWorkingHours = $true }
if ($IgnoreHolidays)     { $workingHoursStatusArgs.IgnoreHolidays     = $true }
if ($ForceRun)           { $workingHoursStatusArgs.ForceRun           = $true }
$workingHoursStatus = Test-WorkingHours @workingHoursStatusArgs

# Display working hours status (non-log informational output)
foreach ($message in $workingHoursStatus.Messages) {
  Write-Message -LogMessage $message -AsLog:$false
}

# Check if we should run
if (-not $workingHoursStatus.ShouldRun) {
  Write-Message -LogMessage "Script will not run: $($workingHoursStatus.Reason)" -Type "Warning" -Level 2
  if ($workingHoursStatus.NextRunTime) {
    Write-Message -LogMessage "Next scheduled run: $($workingHoursStatus.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Type "Info"
  }
  
  # Add helpful hints (non-log informational output)
  Write-Message -LogMessage "💡 Need to run outside working hours? Try these options:" -AsLog:$false
  Write-Message -LogMessage "   -IgnoreWorkingHours  : Bypass time restrictions" -AsLog:$false
  Write-Message -LogMessage "   -IgnoreHolidays      : Bypass holiday restrictions" -AsLog:$false
  Write-Message -LogMessage "   -ForceRun            : Bypass ALL restrictions" -AsLog:$false
  Write-Message -LogMessage "   -IgnoreBrightness    : Disable brightness control" -AsLog:$false
  Write-Message -LogMessage "📖 For more help: Get-Help .\Main.ps1 -Full" -AsLog:$false
  Write-Message -LogMessage "🔧 Example: .\Main.ps1 -Method Send-KeyPress -Arg F16 -ForceRun" -AsLog:$false
  
  exit 0
}

# Display bypass information if any
if ($workingHoursStatus.BypassReasons.Count -gt 0) {
  Write-Message -LogMessage "Bypass options active: $($workingHoursStatus.BypassReasons -join ', ')" -Type "Info"
}

# Handle the log file
if ($script:Config.TranscriptStarted) {
  # Stop transcription if it is running
  try {
    Stop-Transcript
    Write-Message -LogMessage "Transcription stopped successfully."
  } catch {
    if ($_.Exception.Message -like "*The host is not currently transcribing*") {
      Write-Message -LogMessage "No active transcription to stop." -Type "Warning" -Level 2
    } else {
      Write-Message -LogMessage "Failed to stop transcription: $($_.Exception.Message)" -Type "Error" -Level 1
    }
  }
  # Start transcription with error handling
  try {
    # Start logging everything in the file
    Start-Transcript -Path $script:Config.TranscriptFileLocation
    Write-Message -LogMessage "Transcription started: $($script:Config.TranscriptFileLocation)" -Type "Info" -Level 2
  } catch {
    Write-Message -LogMessage "Failed to start transcription: $($_.Exception.Message)" -Type "Error" -Level 1
  }
} else {
    Start-Transcript -Path $script:Config.TranscriptFileLocation -Append
    $script:Config.TranscriptStarted = $true
    Write-Message -LogMessage "Transcription started: $($script:Config.TranscriptFileLocation)" -Type "Info" -Level 2
}

while ($true) {
  try {
    # Set the maximum wait time based on power status
    Set-TimeWaitMax-FromPowerStatu
    
    # Apply command line brightness override after config reload
    if ($IgnoreBrightness) {
      $script:Config.BrightnessFlag = $false
      Write-Message -LogMessage "Brightness changes disabled via command line switch" -Type "Info" -Level 2
    }

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

    # Optimize performance periodically
    Optimize-ScriptPerformance

    # Override config if arguments are provided
    if ($Method) {
      $script:Config.KeepAliveMethod = $Method
      # Log the event
      Write-Message -LogMessage "The method '$($script:Config.KeepAliveMethod)' is defined by the user." -Type "Info" -Level 3
      $Method = $null  # Nullify the Method variable to prevent repeated messages
    }
    if ($Arg) {
        switch ($script:Config.KeepAliveMethod) {
            "Send-KeyPress" {
                # Ensure the key is wrapped in double quotes and curly braces if missing
                if ($Arg -notmatch '^\{.*\}$') {
                  $script:Config.Key = "{$Arg}"
                  Write-Message -LogMessage "Key argument was not in correct format. Converted to $($script:Config.Key)." -Type "Warning" -Level 2
                } else {
                    $script:Config.Key = $Arg
                }
            }
            "Start-AppSession" { $script:Config.Application = $Arg }
            "Start-EdgeSession" { $script:Config.Webpage = $Arg }
            "Invoke-CMDlet" { $script:Config.CMDlet = [ScriptBlock]::Create($Arg) }
        }
        # Log the event
        Write-Message -LogMessage "The argument of '$Arg' for '$($script:Config.KeepAliveMethod)' is defined by the user." -Type "Info" -Level 2
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
        Write-Message -LogMessage "Invalid keep-alive method: $($script:Config.KeepAliveMethod); Ignoring." -Type "Critical" -Level 1
      }
    }

    # Wait for a random time
    $TimeWait01 = Get-Random -Minimum $script:Config.TimeWaitMin -Maximum $script:Config.TimeWaitMax
    # Log the event
    Write-Message -LogMessage "The script will be paused for $(Convert-TimeSpanToHumanReadable $(New-TimeSpan -Seconds $TimeWait01)); resume at $((Get-Date).AddSeconds($TimeWait01))." -Type "Info" -Level 2
    
    # Check if we should continue running (re-evaluate working hours periodically)
    $currentTime = Get-Date
    if (-not $ForceRun -and -not $IgnoreWorkingHours -and -not $IgnoreHolidays) {
      # Check if we've moved outside working hours
      if ($currentTime -gt $script:Config.TimeEnd) {
        Write-Message -LogMessage "Working hours ended. Script will stop." -Type "Info" -Level 2
        break
      }
      
      # Check if it's no longer a working day (in case we're running overnight)
      if ($currentTime.DayOfWeek -in $script:Config.NotWorkingDays) {
        Write-Message -LogMessage "Non-working day detected. Script will stop." -Type "Info" -Level 2
        break
      }
      
      # Check if it's now a holiday
      if (Test-Holiday -Date $currentTime -CountryCode $script:Config.CountryCode -LanguageCode $script:Config.LanguageCode) {
        Write-Message -LogMessage "Public holiday detected. Script will stop." -Type "Info"
        break
      }
    }
    
    # Wait
    Start-Sleep $TimeWait01

  } catch {
    # Handle errors during keep-alive methods or checks
    Write-Message -LogMessage "Error keeping system awake: $($_.Exception.Message)" -Type "Critical" -Level 1
    Write-Message -LogMessage "Error occurred. Pausing script for 60 seconds." -Type "Critical" -Level 1
    Start-Sleep -Seconds 60
  }

}

# Stop activity detection and clean up resources
try {
  Stop-ActivityDetection
} catch {
  Write-Message -LogMessage "Error during activity detection cleanup: $($_.Exception.Message)" -Type "Warning" -Level 2
}

# Stop logging everything in the file
if ($script:Config.TranscriptStarted) {
  try {
    Stop-Transcript
    $script:Config.TranscriptStarted = $false
    Write-Message -LogMessage "Transcription stopped." -Type "Info" -Level 2
  } catch {
    if ($_.Exception.Message -like "*The host is not currently transcribing*") {
      Write-Message -LogMessage "No active transcription to stop." -Type "Warning" -Level 2
    } else {
      Write-Message -LogMessage "Failed to stop transcription: $($_.Exception.Message)" -Type "Error" -Level 1
    }
  }
}