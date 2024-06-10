# Variables for DateTime
$NotWorkingDays = @("Saturday", "Sunday")
$TimeStart = [datetime]"08:30:00"
$TimeEnd = [datetime]"17:00:00"

# Break times (with margins)
$Break01 = [datetime]"10:00:00"
$Break02 = [datetime]"12:00:00"
$Break03 = [datetime]"15:00:00"

# Break durations (with margins)
$DurationBreak01 = Get-Random -Minimum 12 -Maximum 17
$DurationBreak02 = Get-Random -Minimum 22 -Maximum 34
$DurationBreak03 = Get-Random -Minimum 11 -Maximum 18

# Time intervals between actions
$TimeWaitMin = 270 # In seconds
$TimeWaitMax = 299 # In seconds

# Logging flag
$LogFlag = $true
$LogFileFlag = $false
$LogFileLocation = $env:USERPROFILE + "\Documents\Activity.log"

# Public holidays paramenters; set it manually or get it from the system language
$CountryCode = "NL" # The ISO format of the country you need to check holidays for
$LanguageCode = (Get-Culture).Name.Substring(0,2).ToUpper() # Get it from the system language
# $LanguageCode = "EN"

# Keep-alive method
$KeepAliveMethod = "Random"

# Random application and webpage
$Application = @("Notepad","Calc","MSPaint","MSInfo32") | Get-Random
$Webpage = @("https://office.com","https://google.com") | Get-Random

# Random key and cmdlet
$Key = @("{F15}","{F16}","{SCROLLLOCK}","{CAPSLOCK}","{END}","{HOME}","{LEFT}","{RIGHT}","{UP}","{DOWN}","{PGUP}","{PGDN}") | Get-Random
$CMDlet = @("Get-Counter","ping 1.1.1.1","Test-Connection -ComputerName localhost","Start-Sleep 2","Get-History 1","Write-Information 'Hello!'","Write-Host 'Hi!'") | Get-Random

# Brightness settings
$BrightnessFlag = $true
$BrightnessMin = 0
$BrightnessMax = 100
$BrightnessInitial = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness).CurrentBrightness
