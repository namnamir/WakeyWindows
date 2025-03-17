# WakeyWindows

WakeyWindows is a lightweight utility that ensures your computer stays awake without altering Windows’ default settings. It simulates user activity at regular intervals, preventing the system from going into sleep mode. With an unobtrusive tray icon, WakeyWindows quietly does its job, allowing you to focus on your tasks without interruptions.

---

## Features

- Prevents the system from going into sleep mode.
- Simulates user activity (e.g., mouse movements, key presses).
- Configurable working hours, break times, and durations.
- Logs activity for debugging and monitoring purposes.
- Supports multiple keep-alive methods, including randomization.

---

## How to Configure WakeyWindows

### 1. **Edit the Configuration File**
The configuration file (`Config.ps1`) allows you to customize WakeyWindows to suit your needs. Below are the key parameters you can modify:

#### **Working Hours**
- `TimeStart`: The start of your working hours (e.g., `08:30:00`).
- `TimeEnd`: The end of your working hours (e.g., `17:00:00`).

#### **Break Times**
- `TimeBreak01`, `TimeBreak02`, `TimeBreak03`: Define break times during the day.
- `DurationBreak01`, `DurationBreak02`, `DurationBreak03`: Randomized durations for each break (in minutes).

#### **Keep-Alive Method**
- `KeepAliveMethod`: Choose how WakeyWindows simulates user activity. Options include:
  - `Press-Key`
  - `Mouse-Jiggling`
  - `Open-Close-App`
  - `Run-CMDlet`
  - `Random` (randomly selects a method).

#### **Logging**
- `LogFileFlag`: Enable or disable logging (`$true` or `$false`).
- `LogFileLocation`: Specify the path for the activity log file.
- `TranscriptFileLocation`: Specify the path for the PowerShell transcript file.

#### **Example Configuration**
```powershell
$Global:TimeStart = [datetime]"08:30:00"
$Global:TimeEnd = [datetime]"17:00:00"

$Global:TimeBreak01 = [datetime]"10:00:00"
$Global:DurationBreak01 = Get-Random -Minimum 12 -Maximum 17

$Global:KeepAliveMethod = "Random"
$Global:LogFileFlag = $true
$Global:LogFileLocation = ".\Logs\Activity.log"
$Global:TranscriptFileLocation = ".\Logs\Transcript.log"

---

## How to Run WakeyWindows

### 1. **Prerequisites**
- Ensure you have **PowerShell 5.1** or later installed on your system.
- Clone or download the WakeyWindows repository to your local machine.

### 2. **Run the Script**
1. Open PowerShell.
2. Navigate to the directory where WakeyWindows is located:
   ```powershell
   cd "C:\path\to\WakeyWindows"
   ```
3. Execute the main script:
   ```powershell
   .\Main.ps1
   ```

### 3. **Verify the Logs**
- Check the activity log file (`Activity.log`) and transcript file (`Transcript.log`) in the `Logs` directory for detailed information about the script's execution.

---

## Troubleshooting

### Common Issues
1. **File Locking Errors**:
   - Ensure no other process is using the log files.
   - Use separate files for transcription and activity logging.

2. **PowerShell Execution Policy**:
   - If you encounter an error about the execution policy, run the following command to allow script execution:
     ```powershell
     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
     ```

3. **Missing Dependencies**:
   - Ensure all required modules are loaded by running:
     ```powershell
     Get-Module
     ```

---

## Contributing

We welcome contributions to improve WakeyWindows! Feel free to submit issues, feature requests, or pull requests on the [GitHub repository](https://github.com/namnamir/WakeyWindows).

---

## License

WakeyWindows is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute this software as per the terms of the license.