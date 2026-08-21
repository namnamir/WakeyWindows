---
name: wakeywindows
description: |
  Comprehensive development, architecture, and coding guidelines for the WakeyWindows project.
  Covers the native PowerShell implementation (Win32 APIs, SetThreadExecutionState, P/Invoke,
  tray GUI, stealth mode, Pester testing), the C# Native subsystem, and Python development
  standards (uv, ruff, pyright, pytest, ctypes/pywin32) for maintenance and cross-platform/Python porting.
version: 1.0.0
author: Ali Nikouei
maintainer: github.com/namnamir
created: 2026-08-21
updated: 2026-08-21
---

# WakeyWindows Development & Architecture Skill

## How to Install & Use This File

This file is a **custom instructions / skill document** that guides AI coding assistants when working on **WakeyWindows** — whether modifying the native PowerShell codebase, interacting with the C# WinForms subsystem, or developing Python modules / ports.

### Quick Decision Table

| Scenario | What to do |
|---|---|
| Working in this workspace (Antigravity) | Automatically active via `.agents/skills/wakeywindows/SKILL.md`. |
| Using Claude Code / Claude Desktop | Place in `~/.claude/CLAUDE.md` or workspace root `CLAUDE.md`. |
| Using Cursor | Place in `.cursor/rules/wakeywindows.mdc` or User Rules. |
| Using GitHub Copilot | Reference from `.github/copilot-instructions.md`. |

---

## Table of Contents

- [Getting Started Checklist](#getting-started-checklist)
- [How the AI Should Use This Skill](#how-the-ai-should-use-this-skill)
- [1. WakeyWindows Architecture & Core Principles](#1-wakeywindows-architecture--core-principles)
- [2. PowerShell Implementation Standards](#2-powershell-implementation-standards)
- [3. Python Development Standards](#3-python-development-standards)
- [4. Win32 Native API & Interop (PowerShell / Python / C#)](#4-win32-native-api--interop-powershell--python--c)
- [5. Keep-Alive Methods & Stealth Mode Safeguards](#5-keep-alive-methods--stealth-mode-safeguards)
- [6. Project Structure & Tier System (YAGNI)](#6-project-structure--tier-system-yagni)
- [7. Configuration & Texts/Localization](#7-configuration--textslocalization)
- [8. Error Handling & Exception Patterns](#8-error-handling--exception-patterns)
- [9. Logging, Verbosity & Transcription](#9-logging-verbosity--transcription)
- [10. Testing & Verification (Pester & Pytest)](#10-testing--verification-pester--pytest)
- [11. Cross-Language Conversion Cheat Sheet (PowerShell ↔ Python ↔ C#)](#11-cross-language-conversion-cheat-sheet)
- [12. Bug Fixing & Anti-Regression Rules](#12-bug-fixing--anti-regression-rules)
- [13. AI Agent Memory & Rule Refinement](#13-ai-agent-memory--rule-refinement)
- [Glossary](#glossary)

---

## Getting Started Checklist

When starting any task in WakeyWindows:

- [ ] Identify the target component: **PowerShell core** (`Main.ps1`, `Modules.ps1`, `Config.ps1`, `Texts.ps1`), **C# Native** (`Native/`), or **Python** subsystem/port.
- [ ] Determine project **Tier** (Tier 1: single script, Tier 2: modular script/package, Tier 3: multi-subsystem engine).
- [ ] Review any active flags: `-Stealth`, `-ForceRun`, `-IgnoreWorkingHours`, `-IgnoreHolidays`, `-LogVerbosity`.
- [ ] Maintain surgical edits: Do NOT rewrite entire files; preserve all existing comments and docstrings.
- [ ] Verify functionality via automated tests (`Invoke-Pester` for PowerShell or `uv run pytest` for Python) or manual dry-runs.

---

## How the AI Should Use This Skill

- **Step 1 — Analyze**: Inspect existing files (`Main.ps1`, `Modules.ps1`, `Config.ps1`, etc.) to match established variable naming, configuration dictionaries, and Win32 P/Invoke conventions.
- **Step 2 — Preserve & Isolate**: When adding or fixing features, make surgical changes without removing unrelated helpers, error handling branches, or localized strings in `Texts.ps1`.
- **Step 3 — Validate Interop**: Ensure any native Win32 API calls (`SetThreadExecutionState`, `GetLastInputInfo`, `SendInput`, `mouse_event`) handle 32-bit and 64-bit architectures correctly and release unmanaged resources cleanly.
- **Step 4 — Verify**: Run syntax and unit checks before declaring completion.

---

## 1. WakeyWindows Architecture & Core Principles

WakeyWindows operates on a non-intrusive principle: keep the workstation awake during designated hours without altering Windows global power management policies.

```
                    ┌─────────────────────────┐
                    │        Main.ps1         │
                    │   (CLI / Orchestrator)  │
                    └───────────┬─────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│    Config.ps1    │  │    Texts.ps1     │  │   Modules.ps1    │
│ (Settings & State│  │ (Localization &  │  │ (Keep-Alive, Win32│
│    Management)   │  │ UI String Table) │  │ Idle & Tray GUI) │
└──────────────────┘  └──────────────────┘  └─────────┬────────┘
                                                      │
                                                      ▼
                                            ┌──────────────────┐
                                            │ Win32 Native API │
                                            │ (P/Invoke kernel │
                                            │ user32 / gdi32)  │
                                            └──────────────────┘
```

### Core Responsibilities
1. **State Evaluation**: Evaluates current time against `TimeStart`, `TimeEnd`, and breaks (`TimeBreak01`, etc.) plus public holiday calendars (unless `-ForceRun` or `-Ignore*` flags are active).
2. **Idle & Activity Detection**: Uses Win32 `GetLastInputInfo` to check user inactivity threshold before issuing simulated activity.
3. **Simulation Methods**:
   - `Send-KeyPress` (e.g., non-disruptive keys like `F16`, `F24`, or `NUMLOCK`).
   - `Move-MouseRandom` / low-level `mouse_event` coordinate nudges.
   - `Start-AppSession` / `Start-EdgeSession`.
   - `Invoke-CMDlet`.
   - `SetThreadExecutionState` (Stealth Mode default).
4. **Stealth Mode**: Disables logs, suppresses notifications, randomizes execution jitter, and uses direct thread execution flags without physical keystrokes.

---

## 2. PowerShell Implementation Standards

### Runtime & Compatibility
- **Target**: PowerShell 5.1 (Windows PowerShell) and PowerShell 7+ (Core).
- Avoid Windows-only cmdlets that break cross-edition compatibility unless wrapped with fallbacks.
- Use explicit scopes: `$script:Config`, `$script:Texts`, `$Global:` only where necessary for tray event callbacks.

### Code Style & Structure
- Function names MUST follow standard PowerShell approved verbs (`Verb-Noun`): e.g., `Invoke-KeepAlive`, `Get-LastInputTime`, `Show-AppNotification`.
- Always provide Comment-Based Help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`).
- Use typed parameters with sensible validation:
  ```powershell
  function Invoke-KeepAliveMethod {
      [CmdletBinding()]
      param(
          [Parameter(Mandatory = $true)]
          [ValidateSet("Send-KeyPress", "Move-MouseRandom", "Start-AppSession", "Start-EdgeSession", "Invoke-CMDlet", "Random")]
          [string]$Method,

          [Parameter(Mandatory = $false)]
          [string]$Argument
      )
      # Implementation
  }
  ```

### Memory & Process Cleanliness
- Unregister engine events upon exit (`PowerShell.Exiting`).
- Cleanly dispose of `System.Windows.Forms.NotifyIcon` and GDI icon handles:
  ```powershell
  if ($script:TrayIcon) {
      $script:TrayIcon.Visible = $false
      $script:TrayIcon.Dispose()
  }
  ```

---

## 3. Python Development Standards

When writing new Python tools, scripts, or porting WakeyWindows to Python:

### Tooling & Core Stack
- **Package & Environment Manager**: `uv` exclusively (never raw `pip` or `pipenv`).
- **Linter & Formatter**: `ruff` (`ruff check . --fix` and `ruff format .`).
- **Static Type Checker**: `pyright` in strict mode (`typeCheckingMode = "strict"`).
- **Test Framework**: `pytest`.
- **Target Version**: Python 3.11+.

### Python Keep-Alive Pattern (`ctypes` Win32)
```python
import ctypes
from ctypes import wintypes
import time
from enum import IntFlag

class ExecutionState(IntFlag):
    ES_SYSTEM_REQUIRED = 0x00000001
    ES_DISPLAY_REQUIRED = 0x00000002
    ES_USER_PRESENT = 0x00000004
    ES_CONTINUOUS = 0x80000000

def set_thread_execution_state(flags: ExecutionState) -> int:
    """Set Windows thread execution state to prevent sleep.
    
    Args:
        flags: Bitwise OR combination of ExecutionState flags.
        
    Returns:
        Previous execution state bitmask, or 0 on failure.
    """
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.SetThreadExecutionState.argtypes = [wintypes.DWORD]
    kernel32.SetThreadExecutionState.restype = wintypes.DWORD
    return int(kernel32.SetThreadExecutionState(flags))
```

---

## 4. Win32 Native API & Interop (PowerShell / Python / C#)

### Key Win32 Functions & Constants

| API Function | DLL | Purpose in WakeyWindows |
|---|---|---|
| `SetThreadExecutionState` | `kernel32.dll` | Informs system that thread requires display/system active (`0x80000001` or `0x80000003`). |
| `GetLastInputInfo` | `user32.dll` | Retrieves tick count of the last input event (mouse or keyboard) to measure idle time. |
| `SendInput` | `user32.dll` | Synthesizes keystrokes and mouse motions with `dwExtraInfo` masking. |
| `mouse_event` / `keybd_event` | `user32.dll` | Legacy input synthesis fallback. |

### PowerShell P/Invoke Example
```powershell
$Signature = @"
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
"@
$ExecutionState = Add-Type -MemberDefinition $Signature -Name "Win32ExecutionState" -Namespace "WakeyNative" -PassThru
```

---

## 5. Keep-Alive Methods & Stealth Mode Safeguards

### Method Selection Hierarchy
1. **Stealth / System State (`SetThreadExecutionState`)**:
   - Zero physical input simulation.
   - Ideal for strict monitoring or background presence without interference.
2. **Ghost Keystrokes (`Send-KeyPress -Arg F16`)**:
   - `F13-F24` virtual key codes generate real input messages that reset idle timers without producing visible characters in text fields or disrupting games/work.
3. **Micro Mouse Nudges (`Move-MouseRandom`)**:
   - Relative movement (e.g. `+1, -1` delta) with instantaneous restoration.
4. **App / Command Invocation (`Start-AppSession`, `Invoke-CMDlet`)**:
   - Periodic scheduled tasks for multi-purpose automation.

### Stealth Mode Rules
- When `-Stealth` is active:
  - Disable console transcriptions and log file writes unless overridden by `-LogVerbosity`.
  - Disable brightness and display manipulation APIs.
  - Apply randomized jitter intervals (`Interval +/- JitterFactor`) to prevent recurring cadence signatures.

---

## 6. Project Structure & Tier System (YAGNI)

### Tier Selection for WakeyWindows Components

| Tier | Scope | Layout |
|---|---|---|
| **Tier 1** | Standalone one-off automation scripts | Single `.ps1` or `.py` file in root. |
| **Tier 2** | Modular PowerShell / Python Tool (Current WakeyWindows structure) | Structured flat scripts: `Main.ps1`, `Modules.ps1`, `Config.ps1`, `Texts.ps1`. |
| **Tier 3** | Full Native Package with Compiled Subsystems | `src/`, `Native/` (C# .NET solution), `Tests/`, `docs/`. |

### AI Scratchpad Rule
- **NEVER** leave temporary exploratory scripts (e.g. `test_key.ps1`, `temp_fix.py`) in the root directory.
- Use `temp/` or `.agents/scratch/` for all temporary files and ensure `.gitignore` excludes them.

---

## 7. Configuration & Texts/Localization

### Structure of `Config.ps1`
- Use the central `$script:Config = @{ ... }` hashtable pattern.
- All configuration parameters should have safe fallback defaults.
- Time intervals must be parsed using `[datetime]` or `[timespan]`.

### Structure of `Texts.ps1`
- All UI messages, prompt dialogs, tray tooltips, and console status outputs belong in `$script:Texts`.
- Keep messages parameterized using string format tokens (`{0}`, `{1}`).
- Never hardcode raw user-facing text directly inside deeply nested module logic.

---

## 8. Error Handling & Exception Patterns

### PowerShell
- Use structured `try { ... } catch [SpecificException] { ... }` blocks.
- Respect `$ErrorActionPreference = "Stop"` within functions when failure requires deterministic fallbacks.
- Log failures through `Write-AppLog` with appropriate level (`1=Error`, `2=Warning`).

### Python
- Define custom exceptions inheriting from a root `WakeyWindowsError`.
- Never catch naked `except:` — always catch specific exception classes.

---

## 9. Logging, Verbosity & Transcription

### Verbosity Levels (0 to 4)
- **Level 0 (Silent)**: No console output, no log file entries.
- **Level 1 (Error)**: Critical failures, P/Invoke errors, unhandled exceptions.
- **Level 2 (Warning)**: Skipping run due to holidays, outside working hours, idle threshold not met.
- **Level 3 (Info)**: Keep-alive trigger events, state transitions, method executions.
- **Level 4 (Debug/Verbose)**: Raw Win32 tick comparisons, mouse delta coordinates, JSON payload dumps.

---

## 10. Testing & Verification (Pester & Pytest)

### Pester (PowerShell Tests)
- Unit test files named `*.Tests.ps1`.
- Mock native Win32 calls where possible to prevent interfering with developer desktop state during test runs.
- Run tests with:
  ```powershell
  Invoke-Pester -Path .\Tests -Output Detailed
  ```

### Pytest (Python Tests)
- Run with:
  ```bash
  uv run pytest -v --cov=wakey
  ```

---

## 11. Cross-Language Conversion Cheat Sheet

| Task | PowerShell 5.1 / 7+ | Python 3.11+ | C# (.NET) |
|---|---|---|---|
| **Set Execution State** | `[WakeyNative.Win32ExecutionState]::SetThreadExecutionState(...)` | `ctypes.windll.kernel32.SetThreadExecutionState(...)` | `SetThreadExecutionState(...)` via `[DllImport("kernel32")]` |
| **Get Last Input Info** | `[WakeyNative.Win32Input]::GetLastInputInfo(...)` | `ctypes.windll.user32.GetLastInputInfo(...)` | `GetLastInputInfo(ref LASTINPUTINFO plii)` |
| **Read JSON Config** | `Get-Content $Path \| ConvertFrom-Json` | `json.loads(Path(path).read_text())` | `JsonSerializer.Deserialize<T>(...)` |
| **Current Timestamp** | `Get-Date` | `datetime.now()` | `DateTime.Now` |
| **Sleep / Delay** | `Start-Sleep -Seconds $s` | `time.sleep(s)` | `Thread.Sleep(ms)` or `Task.Delay(ms)` |
| **Random Range** | `Get-Random -Minimum $min -Maximum $max` | `random.randint(min, max)` | `Random.Shared.Next(min, max)` |
| **Check Process** | `Get-Process -Name $name -ErrorAction SilentlyContinue` | `psutil.process_iter(...)` | `Process.GetProcessesByName(...)` |

---

## 12. Bug Fixing & Anti-Regression Rules

When modifying existing WakeyWindows code:
1. **Surgical Edits Only**: Modify only the specific lines or helper functions required. Never regenerate or reformat an entire file unless explicitly requested.
2. **Preserve Native P/Invoke Definitions**: Retain 32-bit and 64-bit struct layouts (e.g., `LASTINPUTINFO.cbSize` initialization).
3. **Preserve Comments & Docstrings**: Keep all parameter descriptions, copyright banners, and author tags intact.
4. **Test Before & After**: Verify that modifications do not break `-Stealth`, `-ForceRun`, or scheduled break windows.

---

## 13. AI Agent Memory & Rule Refinement

- **Proactive Rule Refinement**: If a new edge case (e.g., Windows 11 lock screen behavior, dual-monitor coordinate clamping, battery saver overrides) is discovered and solved, update this skill file or `.agents/AGENTS.md`.
- **Context Awareness**: Before implementing a helper function, verify if an equivalent already exists in `Modules.ps1` or `Native/`.

---

## Glossary

| Term | Definition |
|---|---|
| **SetThreadExecutionState** | Win32 API that informs the Windows power manager that the calling thread requires system or display availability. |
| **GetLastInputInfo** | Win32 API function that populates `LASTINPUTINFO` with the tick count of the most recent user input. |
| **Stealth Mode** | Execution mode eliminating visible UI, logs, and physical keystroke synthesis in favor of API state flags and jittered timing. |
| **P/Invoke** | Platform Invocation Services allowing managed code (PowerShell/.NET) to call unmanaged Win32 C/C++ APIs. |
| **Pester** | The standard unit testing and mocking framework for PowerShell. |
| **uv** | Fast Python package and environment manager used for Python tooling. |
