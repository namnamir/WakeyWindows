# Variables for DateTime
$Global:NotWorkingDays = @("Saturday", "Sunday")
$Global:TimeStart = [datetime]"08:30:00"
$Global:TimeEnd = [datetime]"17:00:00"

# Break times (with margins)
$Global:TimeBreak01 = [datetime]"10:00:00"
$Global:TimeBreak02 = [datetime]"12:00:00"
$Global:TimeBreak03 = [datetime]"15:00:00"

# Break durations (with margins)
$Global:DurationBreak01 = Get-Random -Minimum 12 -Maximum 17
$Global:DurationBreak02 = Get-Random -Minimum 22 -Maximum 34
$Global:DurationBreak03 = Get-Random -Minimum 11 -Maximum 18

# Time intervals between actions
$Global:TimeWaitMin = 60  # In seconds
$Global:TimeWaitMax = 100 # In seconds

# Logging flag
$Global:LogFlag = $true
$Global:TranscriptFlag = $true
$Global:TranscriptFileLocation = ".\Logs\Transcript_$((Get-Date).ToString('yyyyMMdd')).log"
$Global:LogFileLocation = ".\Logs\Activity_$((Get-Date).ToString('yyyyMMdd')).log"
# $Global:LogFileLocation = $env:USERPROFILE + "\Documents\Activity_$((Get-Date).ToString('yyyyMMdd_HHmmss')).log"

# Public holidays parameters; set it manually or get it from the system language
$Global:CountryCode = "NL" # The ISO format of the country you need to check holidays for
$Global:LanguageCode = (Get-Culture).Name.Substring(0,2).ToUpper() # Get it from the system language
# $LanguageCode = "EN"

# Keep-alive method
# Possible options: "Press-Key", "Open-Close-App", "Open-Close-Edge-Tab", "Run-CMDlet", "Mouse-Jiggling", "Change-Teams-Status", "Random"
$Global:KeepAliveMethod = "Press-Key"

# Random application and webpage
$Global:Application = @("Notepad", "Calc", "MSPaint", "MSInfo32") | Get-Random

# Work-related webpages
$Global:Webpage = @(
    "https://office.com",                # Microsoft Office
    "https://outlook.office.com",        # Outlook Web Access
    "https://teams.microsoft.com",       # Microsoft Teams
    "https://sharepoint.com",            # SharePoint
    "https://github.com",                # GitHub
    "https://docs.microsoft.com",        # Microsoft Documentation
    "https://stackoverflow.com",         # Stack Overflow
    "https://jira.atlassian.com",        # Jira (Project Management)
    "https://confluence.atlassian.com",  # Confluence (Documentation)
    "https://azure.microsoft.com",       # Microsoft Azure
    "https://portal.azure.com",          # Azure Portal
    "https://cloud.google.com",          # Google Cloud
    "https://console.cloud.google.com",  # Google Cloud Console
    "https://servicenow.com",            # ServiceNow
    "https://developer.servicenow.com"   # ServiceNow Developer Portal
) | Get-Random

# Work-related IP addresses (e.g., internal or external services)
$Global:IPAddress = @(
    "8.8.8.8",        # Google Public DNS
    "8.8.4.4",        # Google Public DNS Secondary
    "1.1.1.1",        # Cloudflare DNS
    "1.0.0.1",        # Cloudflare DNS Secondary
    "20.190.128.0",   # Azure Public IP (example)
    "40.90.4.0",      # Azure Public IP (example)
    "52.239.148.0",   # Azure Public IP (example)
    "13.107.42.14",   # Microsoft Teams
    "13.107.6.158",   # Microsoft Office
    "40.97.132.2",    # Microsoft Exchange Online
    "142.250.190.78", # Google Workspace (example)
    "172.217.0.0",    # Google Public IP (example)
    "216.58.192.0",   # Google Public IP (example)
    "199.91.136.0",   # ServiceNow Public IP (example)
    "149.96.0.0",     # ServiceNow Public IP (example)
    "208.67.222.222", # OpenDNS Primary
    "208.67.220.220", # OpenDNS Secondary
    "192.168.1.1",    # Local Gateway
    "10.0.0.1",       # Internal Network Gateway
    "172.16.0.1"      # Internal Network Gateway
) | Get-Random

# Random key and cmdlet
$Global:Key = @("{NUMLOCK}", "{F15}", "{F16}", "{SCROLLLOCK}", "{CAPSLOCK}", "{END}", "{HOME}", "{LEFT}", "{RIGHT}", "{UP}", "{DOWN}", "{PGUP}", "{PGDN}") | Get-Random
$Global:CMDlet = @(
    # System Information
    { Get-Process | Select-Object -First 1 },
    { Get-Service | Select-Object -First 1 },
    { Get-EventLog -LogName System -Newest 1 },
    { Get-WmiObject -Class Win32_OperatingSystem },
    { Get-ComputerInfo | Select-Object -First 1 },

    # Networking
    { Test-Connection -ComputerName $($Global:IPAddress) -Count 1 },
    { Test-Connection -ComputerName $($Global:Webpage -replace '^https?://', '') -Count 1 },
    { Resolve-DnsName $($Global:Webpage -replace '^https?://', '') },
    { Get-NetIPAddress | Select-Object -First 1 },
    { Get-NetAdapter | Select-Object -First 1 },

    # File System
    { Get-ChildItem -Path C:\Windows\System32 -File | Select-Object -First 1 },
    { Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion' },
    { Get-Volume | Select-Object -First 1 },

    # PowerShell Environment
    { Get-Command | Select-Object -First 1 },
    { Get-Module | Select-Object -First 1 },
    { Get-PSDrive | Select-Object -First 1 },
    { Get-Host },

    # Random Fun
    { Write-Output 'PowerShell is awesome!' },
    { Write-Host 'Stay awake!' },
    { Start-Sleep -Seconds 1 },
    { Get-Date },

    # Custom
    { Get-Random -Minimum 1 -Maximum 100 },
    { Write-Information 'This is a test message!' },
    { Write-Warning 'This is a warning message!' },
    { Write-Error 'This is an error message!' }
) | Get-Random

# Brightness settings
$Global:BrightnessFlag = $true
$Global:BrightnessMin = 0
$Global:BrightnessMax = 100
if ($null -eq $Global:BrightnessInitial) { 
    $Global:BrightnessInitial = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness).CurrentBrightness 
}
