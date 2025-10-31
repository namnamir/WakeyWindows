<#
  .SYNOPSIS
    Configuration file for WakeyWindows script.

  .DESCRIPTION
    This file contains all configurable settings for the WakeyWindows keep-alive script.
    Modify values in this file to customize the script's behavior to your needs.
#>

# Initialize the script-scoped configuration object
$script:Config = @{
  # ============================================================================
  # Working Hours and Schedule Configuration
  # ============================================================================
  
  # Days of the week when the script should not run (non-working days)
  NotWorkingDays = @("Saturday", "Sunday")
  
  # Daily working hours start time (24-hour format)
  TimeStart = [datetime]"08:30:00"
  
  # Daily working hours end time (24-hour format)
  TimeEnd = [datetime]"17:00:00"
  
  # Scheduled break times (script continues running during breaks)
  TimeBreak01 = [datetime]"10:00:00"
  TimeBreak02 = [datetime]"12:00:00"
  TimeBreak03 = [datetime]"15:00:00"
  
  # Break durations in minutes (randomized to appear more natural)
  DurationBreak01 = Get-Random -Minimum 12 -Maximum 17
  DurationBreak02 = Get-Random -Minimum 22 -Maximum 34
  DurationBreak03 = Get-Random -Minimum 11 -Maximum 18
  
  # ============================================================================
  # Keep-Alive Action Timing Configuration
  # ============================================================================
  
  # Minimum wait time between keep-alive actions (in seconds)
  TimeWaitMin = 60
  
  # Maximum wait time between keep-alive actions (in seconds)
  # Note: May be automatically adjusted based on system sleep timeout
  TimeWaitMax = 100
  
  # ============================================================================
  # Logging and Output Configuration
  # ============================================================================
  
  # Enable/disable all logging functionality
  LogFlag = $true
  
  # Log verbosity level (0-4):
  #   0 = Silent (no logs)
  #   1 = Errors only (Critical/Error messages)
  #   2 = Warnings and Important Info (Level 1-2)
  #   3 = All Info messages (Level 1-3)
  #   4 = Debug/Verbose (all messages, Level 1-4)
  LogVerbosity = 4
  
  # Timestamp format for log entries (ISO 8601-like format by default)
  LogTimestampFormat = "yyyy-MM-dd HH:mm:ss"
  
  # Enable console output for log messages
  LogWriteToConsole = $true
  
  # Enable writing log messages to file
  LogWriteToFile = $true
  
  # Enable PowerShell transcript (captures all console output)
  TranscriptFlag = $true
  
  # Transcript file location (automatically includes date in filename)
  TranscriptFileLocation = ".\Logs\Transcript_$((Get-Date).ToString('yyyyMMdd')).log"
  
  # Log file location for activity logs (automatically includes date in filename)
  LogFileLocation = ".\Logs\Activity_$((Get-Date).ToString('yyyyMMdd')).log"
  
  # ============================================================================
  # Holiday and Regional Configuration
  # ============================================================================
  
  # ISO country code for public holiday checking (e.g., "US", "GB", "NL", "DE")
  # Used by the Open Holidays API to determine which holidays apply
  CountryCode = "NL"
  
  # ISO language code for holiday names (auto-detected from system culture)
  # Can be manually overridden by uncommenting and setting the value below
  LanguageCode = (Get-Culture).Name.Substring(0, 2).ToUpper()
  # LanguageCode = "EN"  # Uncomment to override system default
  
  # ============================================================================
  # Keep-Alive Method Configuration
  # ============================================================================
  
  # Primary keep-alive method to use when script runs
  # Available options:
  #   - "Send-KeyPress"     : Press a keyboard key (most energy efficient)
  #   - "Start-AppSession"  : Open and close an application
  #   - "Start-EdgeSession" : Open and close a web page in Edge
  #   - "Invoke-CMDlet"     : Execute a PowerShell command
  #   - "Move-MouseRandom"  : Move mouse cursor randomly
  #   - "Random"             : Randomly choose from available methods
  KeepAliveMethod = "Send-KeyPress"
  
  # ============================================================================
  # Keep-Alive Method Arguments (Randomized Selections)
  # ============================================================================
  
  # Application name pool for Start-AppSession method (randomly selected)
  # Use lightweight built-in Windows applications to minimize resource usage
  Application = @(
    "Notepad",      # Text editor
    "Calc",         # Calculator
    "MSPaint",      # Paint application
    "MSInfo32",     # System information
    "Taskmgr",      # Task Manager
    "Winver"        # Windows version dialog
  ) | Get-Random
  
  # Webpage URL pool for Start-EdgeSession method (randomly selected)
  # Work-related URLs to simulate realistic browsing activity
  # Prefer public pages that don't require authentication
  Webpage = @(
    # Microsoft Services
    "https://office.com",                # Microsoft Office
    "https://outlook.office.com",        # Outlook Web Access
    "https://teams.microsoft.com",      # Microsoft Teams
    "https://sharepoint.com",            # SharePoint
    "https://docs.microsoft.com",       # Microsoft Documentation
    "https://azure.microsoft.com",       # Microsoft Azure
    "https://portal.azure.com",          # Azure Portal
    
    # Development & Documentation
    "https://github.com",                # GitHub
    "https://stackoverflow.com",         # Stack Overflow
    "https://developer.mozilla.org",    # MDN Web Docs
    "https://www.w3.org",                # W3C Standards
    
    # Project Management & Collaboration
    "https://jira.atlassian.com",        # Jira (Project Management)
    "https://confluence.atlassian.com",  # Confluence (Documentation)
    "https://servicenow.com",            # ServiceNow
    "https://developer.servicenow.com",  # ServiceNow Developer Portal
    
    # Cloud Platforms
    "https://cloud.google.com",          # Google Cloud
    "https://console.cloud.google.com",  # Google Cloud Console
    "https://aws.amazon.com",            # Amazon Web Services
    "https://console.aws.amazon.com"     # AWS Console
  ) | Get-Random
  
  # IP address pool for network-related cmdlets (randomly selected)
  # Focus on reliable public DNS servers for consistent connectivity tests
  IPAddress = @(
    # Public DNS Servers (Highly Reliable)
    "8.8.8.8",         # Google Public DNS Primary
    "8.8.4.4",         # Google Public DNS Secondary
    "1.1.1.1",         # Cloudflare DNS Primary
    "1.0.0.1",         # Cloudflare DNS Secondary
    "9.9.9.9",         # Quad9 DNS Primary
    "149.112.112.112", # Quad9 DNS Secondary
    "208.67.222.222",  # OpenDNS Primary
    "208.67.220.220",  # OpenDNS Secondary
    
    # Microsoft Services (Common Enterprise Services)
    "13.107.42.14",   # Microsoft Teams
    "13.107.6.158",   # Microsoft Office 365
    "40.97.132.2"     # Microsoft Exchange Online
  ) | Get-Random
  
  # Keyboard key pool for Send-KeyPress method (randomly selected)
  # Prefer "safe" keys that don't interfere with user activity or system functions
  # Extended function keys (F13-F24) require Win32 API support
  Key = @(
    # Lock Keys (Toggle States - Safe)
    "{NUMLOCK}",
    "{SCROLLLOCK}",
    "{CAPSLOCK}",
    
    # Extended Function Keys (F13-F24) - Safe, no system bindings
    "{F13}",
    "{F14}",
    "{F15}",
    "{F16}",
    "{F17}",
    "{F18}",
    "{F19}",
    "{F20}",
    "{F21}",
    "{F22}",
    "{F23}",
    "{F24}",
    
    # Navigation Keys (Safe when no focused application)
    "{END}",
    "{HOME}",
    "{PGUP}",
    "{PGDN}"
  ) | Get-Random
  
  # PowerShell cmdlet pool for Invoke-CMDlet method (randomly selected)
  # Organized by category - all commands are lightweight and system-safe
  CMDlet = @(
    # System Information Queries
    { Get-Process | Select-Object -First 1 -Property ProcessName, Id },
    { Get-Service | Select-Object -First 1 -Property Name, Status },
    { Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property Caption, Version },
    { Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property Name, TotalPhysicalMemory },
    { Get-ComputerInfo | Select-Object -Property WindowsProductName, WindowsVersion },
    
    # Network Connectivity Tests
    { Test-Connection -ComputerName $(IPAddress) -Count 1 -Quiet },
    { Test-Connection -ComputerName $(Webpage -replace '^https?://', '') -Count 1 -Quiet },
    { Resolve-DnsName -Name $(Webpage -replace '^https?://', '') -ErrorAction SilentlyContinue },
    { Get-NetIPAddress -AddressFamily IPv4 | Select-Object -First 1 },
    { Get-NetAdapter | Select-Object -First 1 -Property Name, Status },
    
    # File System Queries
    { Get-ChildItem -Path $env:TEMP -File | Select-Object -First 1 -Property Name, Length },
    { Get-Volume | Select-Object -First 1 -Property DriveLetter, HealthStatus },
    { Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion' -Name ProductName },
    
    # PowerShell Environment
    { Get-Command | Select-Object -First 1 -Property Name, Source },
    { Get-Module | Select-Object -First 1 -Property Name, Version },
    { Get-PSDrive | Select-Object -First 1 -Property Name, Used },
    { Get-Host | Select-Object -Property Name, Version },
    
    # System Time and Date
    { Get-Date -Format "yyyy-MM-dd HH:mm:ss" },
    { [System.DateTime]::Now.ToUniversalTime() },
    
    # Performance Counters (Lightweight)
    { Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue }
  ) | Get-Random
  
  # ============================================================================
  # Display Brightness Configuration
  # ============================================================================
  
  # Enable/disable automatic brightness control based on activity
  BrightnessFlag = $true
  
  # Minimum brightness level (0-100) when user is inactive
  BrightnessMin = 0
  
  # Maximum brightness level (0-100) when user is active
  BrightnessMax = 100
  
  # Enable smooth brightness transitions instead of instant changes
  BrightnessSmoothTransition = $true
  
  # Number of steps for smooth brightness transitions
  BrightnessTransitionSteps = 20
  
  # ============================================================================
  # Energy Efficiency Configuration
  # ============================================================================
  
  # Energy efficiency mode when user is inactive:
  #   - "Dim"    : Reduce brightness but keep display on
  #   - "Sleep"  : Put monitors in standby mode
  #   - "Off"    : Turn monitors off completely
  EnergyEfficiencyMode = "Dim"
  
  # Enable multi-monitor brightness control
  MultiMonitorSupport = $true
  
  # Enable monitor power control (on/off/standby)
  MonitorPowerControl = $true
  
  # Seconds of inactivity before applying energy efficiency measures
  EnergyEfficiencyDelay = 3
  
  # ============================================================================
  # Trackpad Detection Configuration
  # ============================================================================
  
  # Enable trackpad-specific activity detection
  TrackpadDetectionEnabled = $true
  
  # Minimum pixel movement threshold for trackpad detection
  TrackpadMovementThreshold = 2
  
  # Minimum confidence threshold (0-100) to consider activity as trackpad
  TrackpadConfidenceThreshold = 40
  
  # Enable gesture detection (scroll, swipe, pinch, etc.)
  TrackpadGestureDetection = $true
  
  # ============================================================================
  # Advanced Scheduling Configuration
  # ============================================================================
  
  # Interval in seconds between working hours re-evaluation
  WorkingHoursCheckInterval = 300
  
  # Automatically stop the script when working hours end
  AutoStopOnEndTime = $true
  
  # Enable public holiday checking
  HolidayCheckEnabled = $true
  
  # Enable detailed working hours status messages
  WorkingHoursMessaging = $true
  
  # Show next scheduled run time when script cannot run
  NextRunNotification = $true
}

# ============================================================================
# Runtime Configuration Initialization
# ============================================================================

# Initialize brightness setting from current monitor state
# This preserves the user's current brightness as the "normal" level
if ($null -eq $script:Config.BrightnessInitial) {
  try {
    $script:Config.BrightnessInitial = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness).CurrentBrightness
  }
  catch {
    Write-Warning "Failed to get current brightness: $_"
    # Fallback to a reasonable default if brightness detection fails
    $script:Config.BrightnessInitial = 50
  }
}

# Calculate cooldown time for activity detection
# This is the minimum time to wait after detecting user activity before checking again
# Set to half the difference between min and max wait times for balance
$script:Config.TimeCooldown = ($script:Config.TimeWaitMax - $script:Config.TimeWaitMin) / 2
