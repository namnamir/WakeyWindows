# WakeyWindows — Configuration Guide

WakeyWindows stores all its settings in a plain text file called **`config.json`**, located in the same folder as `PowerManager.exe`. You can open and edit it with any text editor (Notepad works fine).

> **Tip:** The in-app Settings window covers the most common options. This guide documents everything, including the settings that only exist in the file.

---

## How to find and edit the file

1. Right-click the WakeyWindows tray icon → **Dashboard…**
2. Go to the **About** tab — the full path to `config.json` is shown under **Config**.
3. Open that path in Notepad (or any editor), make your changes, save, then restart WakeyWindows.

If the file doesn't exist yet, WakeyWindows creates it with sensible defaults the first time it runs.

---

## Settings reference

### Keep-alive behaviour

| Setting | What it does | Default |
|---|---|---|
| `enabled` | Master on/off switch. `true` = active, `false` = disabled. | `true` |
| `simulationMethod` | How WakeyWindows keeps the PC awake. Options: `"mouse_jiggle"`, `"key_press"` (uses the harmless F15 key), `"api_only"` (no visible input, just tells Windows to stay awake). | `"mouse_jiggle"` |
| `keepDisplayOn` | Keep the monitor on as well, not just prevent sleep. Set `false` if you want the screen to turn off but the PC to stay awake. | `true` |
| `intervalMinPercent` | Minimum keep-alive frequency, as a percentage of your system's sleep timeout. 60% of a 5-minute timeout = send a keep-alive at least every 3 minutes. | `60` |
| `intervalMaxPercent` | Maximum keep-alive frequency, same percentage idea. The actual timing is randomised between min and max to look natural. | `80` |
| `intervalMinSeconds` | ⚠ **Computed automatically** from `intervalMinPercent`. You can hard-code a number here (in seconds) to override the percentage logic entirely, but it will be overwritten next time the percentage changes. | `60` |
| `intervalMaxSeconds` | Same as above for the upper bound. | `120` |

---

### Activity detection

| Setting | What it does | Default |
|---|---|---|
| `detectUserActivity` | When `true`, WakeyWindows pauses automatically while you are actively using the mouse or keyboard — no need to click Pause manually. | `true` |
| `activityPauseSeconds` | How many seconds of real activity before WakeyWindows considers you "active" and backs off. | `120` |
| `idleTimeoutSeconds` | How long you have to stop moving the mouse/keyboard before WakeyWindows decides you're idle again and resumes. | `30` |
| `mouseMovementThreshold` | Minimum mouse movement in pixels that counts as "real" activity (so that WakeyWindows's own tiny mouse jiggle doesn't trigger it). | `10` |

---

### Schedule (working hours)

| Setting | What it does | Default |
|---|---|---|
| `useWorkingHours` | When `true`, WakeyWindows only runs during the hours and days you specify below. Outside those hours the PC can sleep normally. | `false` |
| `workingHoursStart` | Time of day when WakeyWindows starts. Format: `"HH:MM"` (24-hour). | `"08:30"` |
| `workingHoursEnd` | Time of day when WakeyWindows stops and lets the PC sleep. | `"17:00"` |
| `workingDays` | List of days WakeyWindows is allowed to run. Example: `["Monday","Tuesday","Wednesday","Thursday","Friday"]`. | Mon–Fri |
| `skipHolidays` | When `true`, WakeyWindows skips public holidays by checking the Open Holidays API. Requires `holidayCountryCode`. | `false` |
| `holidayCountryCode` | Two-letter country code for holiday lookup. Examples: `"NL"`, `"DE"`, `"GB"`, `"US"`, `"FR"`. | `"NL"` |

---

### Tray icon and notifications

| Setting | What it does | Default |
|---|---|---|
| `showTrayIcon` | Show or hide the tray icon. If you hide it, you can only exit via Task Manager — be careful. | `true` |
| `showBalloonTips` | Show Windows balloon notifications (e.g. "Keep-alive paused") in the bottom-right corner. | `true` |
| `startWithWindows` | Launch WakeyWindows automatically when you log in. The Settings window can toggle this too. | `false` |
| `startMinimized` | Start with no visible window — just the tray icon. Normally you want this `true`. | `true` |
| `trayTooltipRefreshSeconds` | How often (in seconds) the tray tooltip countdown updates. Lower = smoother, slightly more CPU. | `5` |

---

### Update check

| Setting | What it does | Default |
|---|---|---|
| `updateCheckUrl` | URL of a plain-text file containing the latest version number. WakeyWindows compares it to its own version when you click "Check for updates". Set to `null` or remove the line to disable update checks entirely. | GitHub `Version` file |

---

### Advanced behaviour tweaks

These are not in the Settings window. Edit them in `config.json` only if you need to.

| Setting | What it does | Default |
|---|---|---|
| `logMaxEntries` | Maximum number of lines kept in the dashboard activity log. Older lines are discarded. | `200` |
| `progressUrgentThreshold` | When the countdown progress bar drops below this fraction (0–1), it turns red/orange to warn that a keep-alive is imminent. `0.20` means "turn red at 20% remaining". | `0.20` |

---

### Colours

All colour values are hex strings like `"#4CAF50"`. You can pick colours at [htmlcolorcodes.com](https://htmlcolorcodes.com) or any colour picker.

| Setting | What it colours |
|---|---|
| `colorHeaderGradientStart` | Top of the dark blue header bar (the gradient start). |
| `colorHeaderGradientEnd` | Bottom of the header bar (the gradient end). |
| `colorFormBackground` | Background of the entire Settings/Dashboard window. |
| `colorAccentActive` | Colour used for "Active" state — status card left bar, text, etc. |
| `colorAccentPaused` | Colour used for "Paused" or "Outside hours" state. |
| `colorAccentDisabled` | Colour used when WakeyWindows is fully disabled. |
| `colorAccentUserActive` | Colour used when auto-paused because you're actively using the PC. |
| `colorCountdown` | The big countdown number in the Dashboard. |
| `colorProgressBar` | The progress bar fill colour (normal state). |
| `colorProgressBarUrgent` | Progress bar colour when the threshold above is crossed. |
| `colorLogBackground` | Background of the activity log box. |
| `colorLogSuccess` | Log lines for successful keep-alive events. |
| `colorLogWarning` | Log lines for warnings (paused, outside hours, etc.). |
| `colorLogUserActive` | Log lines when activity detection kicks in. |
| `colorLogDisabled` | Log lines when WakeyWindows is disabled. |
| `colorLogInfo` | Log lines for general info messages. |

---

### Fonts

| Setting | What it does | Default |
|---|---|---|
| `fontFamily` | Font used throughout the Settings/Dashboard window. Any font installed on your PC works. | `"Segoe UI"` |
| `fontSizeBase` | Base font size in points. | `9` |
| `logFontFamily` | Font for the activity log box. A monospace font looks best here. | `"Consolas"` |
| `logFontSize` | Font size for the log box. | `8.5` |

---

## Example: minimal config for a 9-to-5 schedule

```json
{
  "enabled": true,
  "simulationMethod": "mouse_jiggle",
  "keepDisplayOn": true,
  "intervalMinPercent": 60,
  "intervalMaxPercent": 80,
  "detectUserActivity": true,
  "activityPauseSeconds": 120,
  "idleTimeoutSeconds": 30,
  "mouseMovementThreshold": 10,
  "useWorkingHours": true,
  "workingHoursStart": "09:00",
  "workingHoursEnd": "17:00",
  "workingDays": ["Monday","Tuesday","Wednesday","Thursday","Friday"],
  "skipHolidays": true,
  "holidayCountryCode": "NL",
  "showTrayIcon": true,
  "showBalloonTips": true,
  "startWithWindows": true
}
```

> All other settings not listed here will use their defaults automatically — you don't need to include every setting in the file.
