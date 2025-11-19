<#
  .SYNOPSIS
    Centralized text strings for WakeyWindows script.
  
  .DESCRIPTION
    This file contains all user-facing text strings used throughout the script.
    All messages should reference this file for easier maintenance and translation support.
    
    Structure:
    - Each category is a hashtable under $script:Texts
    - Use $script:Texts.Category.Key to access messages
    - For parameterized messages, use -f operator or string interpolation
#>

# Initialize the script-scoped texts object
$script:Texts = @{
  # ============================================================================
  # General Status Messages
  # ============================================================================
  General = @{
    ScriptWillNotRun = "Script will not run: {0}"
    NextScheduledRun = "Next scheduled run: {0}"
    BypassOptionsActive = "Bypass options active: {0}"
    TranscriptionStopped = "Transcription stopped."
    TranscriptionStoppedSuccess = "Transcription stopped successfully."
    NoActiveTranscription = "No active transcription to stop."
    TranscriptionStarted = "Transcription started: {0}"
    TranscriptionStartFailed = "Failed to start transcription: {0}"
    TranscriptionStopFailed = "Failed to stop transcription: {0}"
    LogFileWriteFailed = "Failed to write to log file: {0}"
    LogVerbositySet = "Log verbosity set to {0} (0=Silent, 1=Errors, 2=Warnings+, 3=Info+, 4=Debug)"
  }
  
  # ============================================================================
  # Working Hours & Scheduling Messages
  # ============================================================================
  WorkingHours = @{
    WorkingHoursEnded = "Working hours ended. Script will stop."
    NonWorkingDayDetected = "Non-working day detected. Script will stop."
    PublicHolidayDetected = "Public holiday detected. Script will stop."
    ErrorCheckingWorkingHours = "Error checking working hours: {0}"
    ErrorGettingWorkingHoursInfo = "Error getting working hours info: {0}"
    ErrorCheckingHoliday = "Error checking public holiday: {0}"
    # Working Hours Status Messages (from Test-WorkingHours)
    ForceRunEnabled = "ForceRun enabled - bypassing all restrictions"
    AllRestrictionsBypassed = "All restrictions bypassed"
    ForceRunMessage = "🚀 ForceRun enabled - running regardless of time/day restrictions"
    TodayIsNonWorkingDay = "📅 Today is {0} - not a working day"
    NotAWorkingDay = "Not a working day"
    ScriptNotRunNonWorkingDay = "❌ Script will not run on non-working days"
    NextRunNonWorkingDay = "⏰ Next run: {0}"
    WorkingDayBypassed = "Working day restriction bypassed"
    WorkingDayBypassedMessage = "✅ Working day restriction bypassed"
    TodayIsWorkingDay = "✅ Today is {0} - working day"
    TodayIsHoliday = "🎉 Today is a public holiday"
    PublicHoliday = "Public holiday"
    ScriptNotRunHoliday = "❌ Script will not run on public holidays"
    NextRunHoliday = "⏰ Next run: {0}"
    HolidayBypassed = "Holiday restriction bypassed"
    HolidayBypassedMessage = "✅ Holiday restriction bypassed"
    TodayIsNotHoliday = "✅ Today is not a public holiday"
    CurrentTime = "🕐 Current time: {0}"
    WorkingHours = "⏰ Working hours: {0} - {1}"
    OutsideWorkingHours = "Outside working hours"
    ScriptNotRunOutsideHours = "❌ Script will not run outside working hours"
    NextRunOutsideHours = "⏰ Next run: {0}"
    WorkingHoursBypassed = "Working hours restriction bypassed"
    WorkingHoursBypassedMessage = "✅ Working hours restriction bypassed"
    CurrentTimeWithinHours = "✅ Current time is within working hours"
    DuringBreak = "☕ Currently during {0}"
    ScriptRunsDuringBreaks = "✅ Script will run during breaks"
    NotDuringBreak = "✅ Not during any scheduled break"
    AllConditionsMet = "All conditions met"
    AllConditionsMetMessage = "✅ All working hours conditions met - script will run"
    ErrorCheckingWorkingHoursReason = "Error checking working hours"
    ErrorCheckingWorkingHoursMessage = "❌ Error checking working hours: {0}"
  }
  
  # ============================================================================
  # Keep-Alive Method Messages
  # ============================================================================
  KeepAlive = @{
    MethodDefinedByUser = "The method '{0}' is defined by the user."
    ArgumentDefinedByUser = "The argument of '{0}' for '{1}' is defined by the user."
    KeyFormatConverted = "Key argument was not in correct format. Converted to {0}."
    InvalidMethodIgnored = "Invalid keep-alive method: {0}; Ignoring."
    FunctionRunning = "The function '{0}' is running."
    ScriptPaused = "The script will be paused for {0}; resume at {1}."
  }
  
  # ============================================================================
  # Key Press Messages
  # ============================================================================
  KeyPress = @{
    KeyGoingToBePressed = "The key '{0}' is going to be pressed."
    KeyGoingToBePressedWin32 = "The key '{0}' (F{1}) is going to be pressed using Win32 API."
    KeyEmptyOrNull = "Key argument is empty or null."
    KeySendFailed = "Error sending key '{0}': {1}"
    AssemblyLoadFailed = "Failed to load System.Windows.Forms assembly: {0}"
  }
  
  # ============================================================================
  # Mouse Movement Messages
  # ============================================================================
  Mouse = @{
    MouseMoving = "Moving mouse cursor from [{0}, {1}] to a random position within screen boundaries: [{2}, {3}]"
    MouseMoveFailed = "Error moving the mouse cursor: {0}"
  }
  
  # ============================================================================
  # Application Session Messages
  # ============================================================================
  Application = @{
    AppWillOpen = "The application '{0}' will be opened for '{1}' and then closed at '{2}'."
    AppBeingClosed = "The application '{0}' is being closed."
    AppError = "Error opening or closing the application: {0}"
  }
  
  # ============================================================================
  # Webpage Session Messages
  # ============================================================================
  Webpage = @{
    WebpageWillOpen = "The webpage '{0}' will be opened in Edge for '{1}' and then closed at '{2}'."
    WebpageBeingClosed = "The webpage '{0}' is being closed."
    WebpageError = "Error opening or closing the webpage: '{0}'"
  }
  
  # ============================================================================
  # CMDlet Execution Messages
  # ============================================================================
  CMDlet = @{
    Running = "Running cmdlet: '{0}'"
    Completed = "Cmdlet '{0}' completed successfully."
    Error = "Error executing cmdlet '{0}': {1}"
  }
  
  # ============================================================================
  # Power & System Messages
  # ============================================================================
  System = @{
    TimeWaitMaxSet = "TimeWaitMax set to {0} seconds ({1})."
    SleepTimeoutFailed = "Failed to determine sleep timeout for {0} power ({1})."
    NoPowerChange = "No change in power type ({0}) or timeout ({1}); skipping update."
    ErrorKeepingAwake = "Error keeping system awake: {0}"
    ErrorPausing = "Error occurred. Pausing script for 60 seconds."
  }
  
  # ============================================================================
  # Activity Detection Messages
  # ============================================================================
  Activity = @{
    TrackingStarted = "Enhanced user activity tracking started."
    ActivityDetected = "User activity detected ({0}): {1}. Pausing script for '{2}'."
    ActivityCheckError = "Error checking user activity: {0}"
    ActivityDetectionStopping = "Stopping activity detection and cleaning up resources..."
    ActivityDetectionStopped = "Activity detection stopped and resources cleaned up successfully."
    ActivityPatternError = "Error analyzing activity pattern: {0}"
    TrackpadActivityError = "Error detecting trackpad activity: {0}"
    SystemMetricsError = "Error getting system activity metrics: {0}"
    # Activity Reason Messages
    TrackpadMoved = "✅🖱️ Trackpad Moved by {0} pixels ({1}, {2}) [{3}]"
    TrackpadGesture = "✅👆🏼 Gesture: {0}"
    MouseMoved = "✅🖱️ Mouse Moved by {0} pixels ({1}, {2})"
    MouseStatic = "❌🖱️ Mouse Static ({0}px)"
    TypingContinuous = "✅⌨️ User is typing continuously ({0} WPM)"
    TypingFast = "✅⌨️ Fast typing detected ({0} WPM)"
    TypingNormal = "✅⌨️ Normal typing ({0} WPM)"
    KeyPressedWithPattern = "✅⌨️ Key Pressed ({0}) - {1}"
    KeyPressed = "✅⌨️ Key Pressed ({0})"
    NoKeys = "❌⌨️ No Keys"
    TrackpadGestures = "✅👆🏼 Trackpad Gestures: {0}"
    MouseClicked = "✅👆🏼 Mouse Clicked {0}"
    NoClicks = "❌👆🏼 No Clicks"
    WindowFocusChanged = "✅🪟 Window Focus Changed: '{0}' → '{1}'"
    WindowStatic = "❌🪟 Window Static"
    MouseWheel = "✅🖱️ Mouse Wheel: {0}"
    NoWheelMovement = "❌🖱️ No Wheel Movement"
    MovementTooSmall = "❌🖱️ Movement too small for analysis"
    MovementPatternMouse = "❌🖱️ Movement pattern suggests traditional mouse"
    InsufficientData = "Insufficient data for pattern analysis"
    IrregularTiming = "Irregular timing pattern detected"
    DiverseActivity = "Diverse activity types detected"
    ReasonableIntervals = "Reasonable activity intervals"
    NaturalMousePatterns = "Natural mouse movement patterns"
    PatternAnalysisFailed = "Pattern analysis failed"
    # Trackpad Detection Reasons
    LaptopDetected = "✅💻 Laptop detected (likely has trackpad)"
    PreciseMovement = "✅🎯 Precise movement detected ({0}px)"
    DiagonalMovement = "✅↗️ Diagonal movement detected ({0}°)"
    SmoothMovement = "✅🌊 Smooth movement pattern detected"
    VerticalScrolling = "✅📜 Vertical scrolling gesture detected"
    HorizontalSwipe = "✅👈 Horizontal swipe gesture detected"
    SmallCircular = "✅🔄 Small circular movement detected"
    TrackpadDetectionFailed = "Trackpad detection failed"
  }
  
  # ============================================================================
  # Brightness & Display Messages
  # ============================================================================
  Brightness = @{
    BrightnessDisabled = "Brightness changes disabled via command line switch"
    NoMonitorsFound = "No monitors found for brightness control."
    BrightnessAdjusting = "Adjusting monitor brightness from {0}% to {1}%."
    BrightnessSetFailed = "Failed to set brightness using WMI method."
    BrightnessError = "Error adjusting screen brightness: {0}"
    MonitorInfoError = "Error getting monitor information: {0}"
  }
  
  # ============================================================================
  # Energy Efficiency Messages
  # ============================================================================
  Energy = @{
    RestoringNormal = "Restoring energy efficiency settings due to user activity."
    ApplyingMeasures = "Applying energy efficiency measures due to inactivity: {0}"
    SettingsRestored = "Energy efficiency settings restored to normal"
    SettingsRestoreFailed = "Failed to restore energy efficiency settings: {0}"
    ModeSetNormal = "Energy efficiency mode set to Normal."
    ModeSetDim = "Energy efficiency mode set to Dim."
    ModeSetSleep = "Energy efficiency mode set to Sleep."
    ModeSetOff = "Energy efficiency mode set to Off."
    ModeSetError = "Error setting energy efficiency mode: {0}"
    MonitorPowerSet = "Monitor power set to {0}."
    MonitorPowerFailed = "Failed to set monitor power to {0}."
    MonitorPowerError = "Error controlling monitor power: {0}"
  }
  
  # ============================================================================
  # Performance & Resource Messages
  # ============================================================================
  Performance = @{
    CooldownIncreased = "Increased cooldown to {0}s due to high memory usage"
    GarbageCollectionPerformed = "Performed garbage collection due to high memory usage"
    ResourceUsage = "Resource usage - Memory: {0}MB, Threads: {1}, Handles: {2}"
    CleanupError = "Error during cleanup: {0}"
    ActivityCleanupError = "Error during activity detection cleanup: {0}"
  }
  
  # ============================================================================
  # Help & UI Messages
  # ============================================================================
  Help = @{
    Title = "🚀 WakeyWindows - Keep Your PC Awake Script"
    SectionParameters = "📋 PARAMETERS:"
    SectionExamples = "🔧 EXAMPLES:"
    SectionMethods = "⚡ KEEP-ALIVE METHODS:"
    SectionTips = "💡 TIPS:"
    MethodDescription = "Keep-alive method (Send-KeyPress, Start-AppSession, etc.)"
    ArgDescription = "Argument for the method (e.g., F16, Notepad)"
    IgnoreBrightnessDescription = "Disable brightness control"
    IgnoreWorkingHoursDescription = "Bypass time restrictions"
    IgnoreHolidaysDescription = "Bypass holiday restrictions"
    ForceRunDescription = "Bypass ALL restrictions"
    LogVerbosityDescription = "0=Silent, 1=Errors, 2=Warnings+, 3=Info+, 4=Debug"
    DefaultLabel = "Default: {0}"
    TipForceRun = "• Use -ForceRun to run anytime"
    TipIgnoreBrightness = "• Use -IgnoreBrightness to disable screen dimming"
    TipEnergyEfficient = "• Send-KeyPress is most energy efficient"
    TipConfigFile = "• Check Config.ps1 for customization options"
    MethodSendKeyPress = "  Send-KeyPress              : Press a key (most efficient)"
    MethodStartAppSession = "  Start-AppSession           : Open/close applications"
    MethodStartEdgeSession = "  Start-EdgeSession          : Open/close web pages"
    MethodInvokeCMDlet = "  Invoke-CMDlet              : Run PowerShell commands"
    MethodMoveMouseRandom = "  Move-MouseRandom           : Move mouse cursor"
    MethodRandom = "  Random                     : Randomly choose method"
  }
}

