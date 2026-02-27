# Building WakeyWindows Native

This is a standalone C# application that prevents Windows from sleeping using the legitimate `SetThreadExecutionState` API. No PowerShell, no keystrokes, minimal detection surface.

## Prerequisites

- **.NET 8.0 SDK** (or 6.0+; required for `dotnet` commands)
- Windows 10/11

### Installing .NET SDK

If `dotnet` is not recognized:

1. **Install via winget (recommended):**
   ```powershell
   winget install Microsoft.DotNet.SDK.8
   ```
   Or for .NET 6: `winget install Microsoft.DotNet.SDK.6`

2. **Close and reopen PowerShell** (or your terminal) so the updated PATH is loaded. `dotnet` will not work in the same session where you just installed it.

3. **Verify:** run `dotnet --version` in the new window.

Alternatively, download and install from: [.NET Downloads](https://dotnet.microsoft.com/download).

## Quick Build

```bash
cd Native
dotnet build -c Release
```

Output: `bin\Release\net8.0-windows\PowerManager.exe`

## Customizing Name & Icon

### 1. Change Application Name

Edit `WakeyNative.csproj` and modify these values:

```xml
<AssemblyName>YourAppName</AssemblyName>
<RootNamespace>YourAppName</RootNamespace>
<Product>Your App Name</Product>
<Description>Your description here</Description>
<Company>Your Company Name</Company>
```

**Suggested names:**
- `PowerManager`
- `DisplaySettings`
- `SystemMonitor`
- `PowerConfig`
- `ScreenSaver`

### 2. Add Custom Icon

1. Place your `.ico` file in the `Native` folder
2. Uncomment and edit this line in `WakeyNative.csproj`:

```xml
<ApplicationIcon>your-icon.ico</ApplicationIcon>
```

**Finding icons:**
- Use Windows system icons from `C:\Windows\System32\shell32.dll`
- Extract with [IconsExtract](https://www.nirsoft.net/utils/iconsext.html)
- Create from PNG at [convertico.com](https://convertico.com/)

### 3. Build Single-File Executable

```bash
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true
```

Output: `bin\Release\net8.0-windows\win-x64\publish\PowerManager.exe`

### 4. Self-Contained Build (No .NET Required)

```bash
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

This creates a larger (~60MB) but fully standalone executable.

## Configuration

Settings are stored in `config.json` next to the executable:

```json
{
  "enabled": true,
  "intervalMinSeconds": 60,
  "intervalMaxSeconds": 120,
  "detectUserActivity": true,
  "activityPauseSeconds": 120,
  "mouseMovementThreshold": 10,
  "idleTimeoutSeconds": 30,
  "useWorkingHours": false,
  "workingHoursStart": "08:30",
  "workingHoursEnd": "17:00",
  "showTrayIcon": true,
  "showBalloonTips": false,
  "keepDisplayOn": true
}
```

### Key Settings

| Setting | Description |
|---------|-------------|
| `enabled` | Master on/off switch |
| `intervalMinSeconds` | Minimum time between keep-alive calls |
| `intervalMaxSeconds` | Maximum time between keep-alive calls |
| `detectUserActivity` | Pause when user is working |
| `activityPauseSeconds` | How long to pause after user activity |
| `idleTimeoutSeconds` | Seconds of idle before considering user inactive |
| `mouseMovementThreshold` | Pixels of mouse movement to count as activity |
| `keepDisplayOn` | Also prevent display from turning off |
| `showTrayIcon` | Show/hide system tray icon |

## Usage

1. Run the executable
2. It starts minimized to system tray
3. Right-click tray icon for menu:
   - **Enable/Disable** - Toggle keep-alive
   - **Pause** - Temporarily pause
   - **Settings** - Open settings dialog
   - **Exit** - Stop and exit

## How It Works

- Uses `SetThreadExecutionState` API (same as video players, presentations)
- Detects user activity via `GetLastInputInfo` API
- Pauses automatically when you're working
- No keystrokes, no mouse movements (unless you want them)
- Minimal CPU/memory footprint

## Detection Considerations

This application:
- ✅ Uses legitimate Windows APIs
- ✅ No PowerShell execution
- ✅ No simulated keystrokes
- ✅ No injected DLLs
- ✅ Looks like normal system utility
- ✅ Configurable name and icon

The `SetThreadExecutionState` API is the same one used by:
- Video players (VLC, Windows Media Player)
- Presentation software (PowerPoint)
- Download managers
- Backup software

## Troubleshooting

### Build fails with "SDK not found"
Install .NET 8.0 SDK: https://dotnet.microsoft.com/download (or use `winget install Microsoft.DotNet.SDK.8`).

### Application doesn't start
Check if .NET 8.0 runtime is installed:
```bash
dotnet --list-runtimes
```

### Settings not saving
Ensure the folder containing the exe is writable, or run as admin once.

## GitHub Releases (automated build)

The repo includes a workflow that builds the Native app and attaches the exe to a **GitHub Release** when you push a version tag.

- **Version file for update check:** The app’s “Check for updates” uses the repo’s `Version` file:  
  `https://raw.githubusercontent.com/namnamir/WakeyWindows/main/Version`  
  Keep the content of `Version` (e.g. `1.0.0`) in sync with the release tag.

**To publish a release:**

1. Update the root `Version` file to the new version (e.g. `1.0.1`).
2. Optionally update `<Version>` in `Native/WakeyNative.csproj` to match.
3. Commit, then create and push a tag:
   ```bash
   git add Version Native/WakeyNative.csproj
   git commit -m "Release 1.0.1"
   git tag v1.0.1
   git push origin main
   git push origin v1.0.1
   ```
4. On the repo’s **Actions** tab, wait for the “Release Native Build” workflow to finish.
5. Open **Releases**; the new release for `v1.0.1` will have `PowerManager.exe` attached.

## Files

```
Native/
├── WakeyNative.csproj    # Project file (customize name/icon here)
├── Program.cs            # Entry point
├── MainForm.cs           # System tray application
├── SettingsForm.cs       # Settings GUI
├── Settings.cs           # Configuration management
├── ActivityDetector.cs   # User activity detection
├── KeepAwake.cs          # SetThreadExecutionState wrapper
├── config.json           # Default configuration
└── BUILD.md              # This file
```
