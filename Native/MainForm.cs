using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using System.Threading;

namespace PowerManager
{
    public record LogEntry(DateTime Time, string Icon, string Message, LogLevel Level);

    public enum LogLevel { Info, Success, Warning, UserActive, Disabled }

    public class LiveStats
    {
        public string StatusText { get; init; } = "";
        public string StatusIcon { get; init; } = "";
        public Color StatusColor { get; init; } = Color.Gray;
        public string ActiveMethod { get; init; } = "";
        public TimeSpan SessionUptime { get; init; }
        public int KeepAliveCount { get; init; }
        public TimeSpan? TimeUntilNext { get; init; }
        public DateTime? NextFireAt { get; init; }
        public int CurrentIntervalSeconds { get; init; }
        public IReadOnlyList<LogEntry> RecentLog { get; init; } = Array.Empty<LogEntry>();
        public bool IsEnabled { get; init; }
        public int SleepTimeoutAcSeconds { get; init; }
        public int SleepTimeoutDcSeconds { get; init; }
    }

    public partial class MainForm : Form
    {
        private readonly NotifyIcon _trayIcon;
        private readonly ContextMenuStrip _trayMenu;
        private readonly System.Windows.Forms.Timer _keepAliveTimer;
        private readonly System.Windows.Forms.Timer _activityTimer;
        private readonly System.Windows.Forms.Timer _trayTooltipTimer;
        private readonly Settings _settings;
        private readonly ActivityDetector _activityDetector;
        private readonly Random _random = new();

        private bool _isPaused;
        private bool _isUserActive;
        private bool _wasWithinHours = true;
        private DateTime _lastKeepAlive = DateTime.MinValue;
        private int _currentInterval;
        private DateTime _timerStartedAt = DateTime.Now;

        private readonly DateTime _sessionStart = DateTime.Now;
        private int _keepAliveCount;
        private readonly List<LogEntry> _logEntries = new();
        private int MaxLogEntries => _settings.LogMaxEntries;

        private int _sleepTimeoutAc = -1;
        private int _sleepTimeoutDc = -1;

        private ToolStripMenuItem _statusItem = null!;
        private ToolStripMenuItem _pauseItem = null!;
        private ToolStripMenuItem _enabledItem = null!;
        private ToolStripMenuItem _methodMenu = null!;

        public MainForm(string[] args)
        {
            _settings = Settings.Load();
            _activityDetector = new ActivityDetector(_settings);

            InitializeComponent();
            this.ShowInTaskbar = false;
            this.WindowState = FormWindowState.Minimized;
            this.Visible = false;
            this.FormBorderStyle = FormBorderStyle.FixedToolWindow;
            this.Size = new Size(1, 1);
            this.Location = new Point(-2000, -2000);

            _trayMenu = CreateTrayMenu();

            Icon trayIconImage;
            try { trayIconImage = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application; }
            catch { trayIconImage = SystemIcons.Application; }

            _trayIcon = new NotifyIcon
            {
                Text = "WakeyWindows",
                Icon = trayIconImage,
                ContextMenuStrip = _trayMenu,
                Visible = _settings.ShowTrayIcon
            };
            _trayIcon.DoubleClick += (s, e) => ShowDashboard();

            _keepAliveTimer = new System.Windows.Forms.Timer();
            _keepAliveTimer.Tick += KeepAliveTimer_Tick;
            SetNextInterval();

            _activityTimer = new System.Windows.Forms.Timer { Interval = 2000 };
            _activityTimer.Tick += ActivityTimer_Tick;

            _trayTooltipTimer = new System.Windows.Forms.Timer { Interval = _settings.TrayTooltipRefreshSeconds * 1000 };
            _trayTooltipTimer.Tick += (s, e) => RefreshTrayTooltip();
            _trayTooltipTimer.Start();

            if (_settings.Enabled) Start();
            UpdateTrayStatus();
        }

        private void InitializeComponent()
        {
            this.SuspendLayout();
            this.ClientSize = new Size(1, 1);
            this.Name = "MainForm";
            this.Text = "WakeyWindows";
            this.ResumeLayout(false);
        }

        private ContextMenuStrip CreateTrayMenu()
        {
            var menu = new ContextMenuStrip();

            _statusItem = new ToolStripMenuItem("● Starting…") { Enabled = false };
            menu.Items.Add(_statusItem);
            menu.Items.Add(new ToolStripSeparator());

            _enabledItem = new ToolStripMenuItem("Enabled", null, (s, e) => ToggleEnabled())
            {
                Checked = _settings.Enabled
            };
            menu.Items.Add(_enabledItem);

            _pauseItem = new ToolStripMenuItem("Pause", null, (s, e) => TogglePause());
            menu.Items.Add(_pauseItem);

            menu.Items.Add(new ToolStripSeparator());

            // Quick mode switch submenu
            _methodMenu = new ToolStripMenuItem("Mode");
            RebuildMethodMenu();
            menu.Items.Add(_methodMenu);

            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(new ToolStripMenuItem("Dashboard…", null, (s, e) => ShowDashboard()));
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(new ToolStripMenuItem("Exit", null, (s, e) => ExitApplication()));

            return menu;
        }

        private void RebuildMethodMenu()
        {
            _methodMenu.DropDownItems.Clear();
            AddMethodItem("Mouse jiggle", "mouse_jiggle");
            AddMethodItem("Key press (F15)", "key_press");
            AddMethodItem("API only", "api_only");
        }

        private void AddMethodItem(string label, string method)
        {
            var item = new ToolStripMenuItem(label, null, (s, e) => SwitchMethod(method))
            {
                Checked = _settings.SimulationMethod == method
            };
            _methodMenu.DropDownItems.Add(item);
        }

        private void SwitchMethod(string method)
        {
            _settings.SimulationMethod = method;
            _settings.Save();
            RebuildMethodMenu();
            AddLog("⚡", $"Mode switched to: {MethodLabel(method)}", LogLevel.Info);
            ShowNotification("WakeyWindows", $"Mode switched to {MethodLabel(method)}.");
        }

        private static string MethodLabel(string method) => method switch
        {
            "mouse_jiggle" => "Mouse jiggle",
            "key_press" => "Key press (F15)",
            "api_only" => "API only",
            _ => method
        };

        private void SetNextInterval()
        {
            int baseInterval = _random.Next(_settings.IntervalMinSeconds, _settings.IntervalMaxSeconds + 1);
            int jitter = _random.Next(-10, 21);
            if (_random.Next(1, 11) == 1) jitter += _random.Next(30, 61);

            _currentInterval = Math.Max(_settings.IntervalMinSeconds, baseInterval + jitter);
            _keepAliveTimer.Interval = _currentInterval * 1000;
            _timerStartedAt = DateTime.Now;
        }

        private void KeepAliveTimer_Tick(object? sender, EventArgs e)
        {
            if (_isPaused || !_settings.Enabled) return;

            bool withinHours = _activityDetector.IsWithinWorkingHours();

            // Notify on working-hours boundary transitions
            if (!withinHours && _wasWithinHours)
            {
                ShowNotification("WakeyWindows", $"Outside working hours — resumes at {_settings.WorkingHoursStart}.");
                AddLog("🕐", $"Outside working hours · resumes at {_settings.WorkingHoursStart}", LogLevel.Warning);
            }
            else if (withinHours && !_wasWithinHours)
            {
                ShowNotification("WakeyWindows", "Working hours started — keep-alive resumed.");
                AddLog("🟢", $"Working hours started · active until {_settings.WorkingHoursEnd}", LogLevel.Success);
            }
            _wasWithinHours = withinHours;

            if (!withinHours)
            {
                UpdateTrayStatus("Outside working hours");
                SetNextInterval();
                return;
            }

            if (_activityDetector.IsTodayHoliday())
            {
                UpdateTrayStatus("Holiday — paused");
                AddLog("🎉", $"Public holiday · {_settings.HolidayCountryCode} · resumes tomorrow", LogLevel.Warning);
                SetNextInterval();
                return;
            }

            if (_isUserActive || _activityDetector.ShouldPauseKeepAlive())
            {
                UpdateTrayStatus("User active — paused");
                SetNextInterval();
                return;
            }

            // Execute the selected simulation method
            KeepAwake.PreventSleepContinuous(_settings.KeepDisplayOn);
            switch (_settings.SimulationMethod)
            {
                case "mouse_jiggle":
                    MouseJiggler.Jiggle();
                    _activityDetector.MarkAsJiggle();
                    break;
                case "key_press":
                    KeyboardSimulator.PressKey();
                    _activityDetector.MarkAsJiggle();
                    break;
                // "api_only" — SetThreadExecutionState only, already called above
            }

            _lastKeepAlive = DateTime.Now;
            _keepAliveCount++;
            SetNextInterval();
            UpdateTrayStatus("Active");
            AddLog("✅", $"Keep-alive sent · {MethodLabel(_settings.SimulationMethod)} · next in ~{_currentInterval}s", LogLevel.Success);
        }

        private void ActivityTimer_Tick(object? sender, EventArgs e)
        {
            if (!_settings.DetectUserActivity) return;

            bool wasActive = _isUserActive;
            _isUserActive = _activityDetector.IsUserActive();

            if (_isUserActive && !wasActive)
            {
                UpdateTrayStatus("User active — paused");
                AddLog("👤", $"User active — paused · resumes after {_settings.ActivityPauseSeconds}s idle", LogLevel.UserActive);
            }
            else if (!_isUserActive && wasActive && _settings.Enabled && !_isPaused)
            {
                UpdateTrayStatus("Active");
                AddLog("💤", $"User idle — keep-alive resuming · next in ~{_currentInterval}s", LogLevel.Info);
            }
        }

        private void RecomputeIntervalSeconds()
        {
            (_sleepTimeoutAc, _sleepTimeoutDc) = ActivityDetector.GetSleepTimeouts();
            int ac = _sleepTimeoutAc, dc = _sleepTimeoutDc;

            // Both unavailable — keep whatever seconds are already stored
            if (ac < 0 && dc < 0) return;

            // Pick the most restrictive active (non-zero) timeout; fall back to 5m if "never sleep"
            int baseSeconds;
            string baseLabel;
            if      (ac > 0 && dc > 0) { baseSeconds = Math.Min(ac, dc); baseLabel = $"sleep {FormatSeconds(baseSeconds)}"; }
            else if (ac > 0)            { baseSeconds = ac;               baseLabel = $"AC sleep {FormatSeconds(ac)}"; }
            else if (dc > 0)            { baseSeconds = dc;               baseLabel = $"DC sleep {FormatSeconds(dc)}"; }
            else                        { baseSeconds = 300;              baseLabel = "5m base (no sleep timeout)"; }

            int newMin = Math.Max(10, (int)Math.Round(baseSeconds * _settings.IntervalMinPercent / 100.0));
            int newMax = Math.Max(newMin + 1, (int)Math.Round(baseSeconds * _settings.IntervalMaxPercent / 100.0));

            bool changed = newMin != _settings.IntervalMinSeconds || newMax != _settings.IntervalMaxSeconds;
            if (!changed) return;

            _settings.IntervalMinSeconds = newMin;
            _settings.IntervalMaxSeconds = newMax;
            _settings.Save();
            SetNextInterval();
            AddLog("⚡", $"Interval set to {newMin}–{newMax}s  ·  {_settings.IntervalMinPercent}–{_settings.IntervalMaxPercent}%  of  {baseLabel}", LogLevel.Info);
        }

        private void Start()
        {
            RecomputeIntervalSeconds();
            _keepAliveTimer.Start();
            _activityTimer.Start();
            _timerStartedAt = DateTime.Now;

            if (!_activityDetector.IsUserActive())
            {
                KeepAwake.PreventSleepContinuous(_settings.KeepDisplayOn);
                _lastKeepAlive = DateTime.Now;
                _keepAliveCount++;
            }

            UpdateTrayStatus("Active");
            AddLog("🟢", $"WakeyWindows v{Application.ProductVersion.Split('+')[0]} started · Mode: {MethodLabel(_settings.SimulationMethod)}", LogLevel.Success);
            ShowNotification("WakeyWindows", $"Keep-alive active · Mode: {MethodLabel(_settings.SimulationMethod)}");
        }

        private void Stop()
        {
            _keepAliveTimer.Stop();
            _activityTimer.Stop();
            KeepAwake.AllowSleep();
            UpdateTrayStatus("Disabled");
            AddLog("🔴", $"WakeyWindows disabled · ran for {FormatUptime(DateTime.Now - _sessionStart)}", LogLevel.Disabled);
            ShowNotification("WakeyWindows", "Keep-alive disabled. System can sleep normally.");
        }

        private void ToggleEnabled()
        {
            _settings.Enabled = !_settings.Enabled;
            _enabledItem.Checked = _settings.Enabled;
            _settings.Save();

            if (_settings.Enabled) { _isPaused = false; _pauseItem.Checked = false; Start(); }
            else Stop();
        }

        private void TogglePause()
        {
            _isPaused = !_isPaused;
            _pauseItem.Checked = _isPaused;

            if (_isPaused)
            {
                KeepAwake.AllowSleep();
                UpdateTrayStatus("Paused");
                AddLog("⏸", "Paused by user · click Resume to continue", LogLevel.Warning);
                ShowNotification("WakeyWindows", "Keep-alive paused.");
            }
            else
            {
                UpdateTrayStatus("Active");
                AddLog("▶", $"Resumed by user · next keep-alive in ~{_currentInterval}s", LogLevel.Success);
                ShowNotification("WakeyWindows", "Keep-alive resumed.");
            }
        }

        private void UpdateTrayStatus(string? status = null)
        {
            string s;
            if (!_settings.Enabled) s = "Disabled";
            else if (_isPaused) s = "Paused";
            else if (status != null) s = status;
            else if (_isUserActive) s = "User active — paused";
            else s = "Active";

            _statusItem.Text = $"● {s}";
            _trayIcon.Text = TruncateTrayText($"WakeyWindows — {s}");
        }

        private void RefreshTrayTooltip()
        {
            if (!_settings.Enabled || _isPaused || _isUserActive)
            {
                UpdateTrayStatus();
                return;
            }

            if (_keepAliveTimer.Enabled)
            {
                var remaining = TimeSpan.FromSeconds(_currentInterval) - (DateTime.Now - _timerStartedAt);
                if (remaining.TotalSeconds > 0)
                {
                    string countdown = remaining.TotalSeconds >= 60
                        ? $"{(int)remaining.TotalMinutes}m {remaining.Seconds:D2}s"
                        : $"{(int)remaining.TotalSeconds}s";
                    _trayIcon.Text = TruncateTrayText($"WakeyWindows — Active · next in {countdown}");
                    _statusItem.Text = $"● Active · next in {countdown}";
                    return;
                }
            }
            UpdateTrayStatus();
        }

        private static string TruncateTrayText(string text) =>
            text.Length > 63 ? text[..60] + "…" : text;

        private static string FormatUptime(TimeSpan t) =>
            t.TotalHours >= 1 ? $"{(int)t.TotalHours}h {t.Minutes}m" :
            t.Minutes > 0     ? $"{t.Minutes}m {t.Seconds}s" : $"{t.Seconds}s";

        internal static string FormatSeconds(int s) =>
            s >= 60 ? $"{s / 60}m{(s % 60 > 0 ? $" {s % 60}s" : "")}" : $"{s}s";

        private void AddLog(string icon, string message, LogLevel level)
        {
            _logEntries.Insert(0, new LogEntry(DateTime.Now, icon, message, level));
            if (_logEntries.Count > MaxLogEntries)
                _logEntries.RemoveAt(_logEntries.Count - 1);
        }

        private void ShowNotification(string title, string text)
        {
            if (!_settings.ShowBalloonTips || !_trayIcon.Visible) return;
            _trayIcon.BalloonTipTitle = title;
            _trayIcon.BalloonTipText = text;
            _trayIcon.BalloonTipIcon = ToolTipIcon.Info;
            _trayIcon.ShowBalloonTip(4000);
        }

        public LiveStats GetLiveStats()
        {
            var now = DateTime.Now;
            TimeSpan? timeUntilNext = null;
            DateTime? nextFireAt = null;

            if (_keepAliveTimer.Enabled && _settings.Enabled && !_isPaused)
            {
                var remaining = TimeSpan.FromSeconds(_currentInterval) - (now - _timerStartedAt);
                if (remaining.TotalSeconds > 0)
                {
                    timeUntilNext = remaining;
                    nextFireAt = now + remaining;
                }
                else
                {
                    timeUntilNext = TimeSpan.Zero;
                    nextFireAt = now;
                }
            }

            string statusText; string statusIcon; Color statusColor;

            if (!_settings.Enabled)
            { statusText = "Disabled"; statusIcon = "⛔"; statusColor = Settings.ParseColor(_settings.ColorAccentDisabled, Color.Gray); }
            else if (_isPaused)
            { statusText = "Paused"; statusIcon = "⏸"; statusColor = Settings.ParseColor(_settings.ColorAccentPaused, Color.Orange); }
            else if (_isUserActive)
            { statusText = "User active — paused"; statusIcon = "👤"; statusColor = Settings.ParseColor(_settings.ColorAccentUserActive, Color.SteelBlue); }
            else if (!_activityDetector.IsWithinWorkingHours())
            { statusText = "Outside working hours"; statusIcon = "🕐"; statusColor = Settings.ParseColor(_settings.ColorAccentPaused, Color.Orange); }
            else if (_activityDetector.IsTodayHoliday())
            { statusText = "Public holiday — paused"; statusIcon = "🎉"; statusColor = Settings.ParseColor(_settings.ColorAccentPaused, Color.Orange); }
            else
            { statusText = "Active — keeping awake"; statusIcon = "✅"; statusColor = Settings.ParseColor(_settings.ColorAccentActive, Color.Green); }

            return new LiveStats
            {
                StatusText = statusText,
                StatusIcon = statusIcon,
                StatusColor = statusColor,
                ActiveMethod = MethodLabel(_settings.SimulationMethod),
                SessionUptime = now - _sessionStart,
                KeepAliveCount = _keepAliveCount,
                TimeUntilNext = timeUntilNext,
                NextFireAt = nextFireAt,
                CurrentIntervalSeconds = _currentInterval,
                RecentLog = _logEntries.AsReadOnly(),
                IsEnabled = _settings.Enabled,
                SleepTimeoutAcSeconds = _sleepTimeoutAc,
                SleepTimeoutDcSeconds = _sleepTimeoutDc
            };
        }

        private void ShowDashboard()
        {
            using var dialog = new SettingsForm(_settings, GetLiveStats);
            if (dialog.ShowDialog() == DialogResult.OK)
            {
                _settings.Save();
                _trayIcon.Visible = _settings.ShowTrayIcon;
                _enabledItem.Checked = _settings.Enabled;
                RebuildMethodMenu();

                if (_settings.Enabled && !_keepAliveTimer.Enabled) Start();
                else if (!_settings.Enabled && _keepAliveTimer.Enabled) Stop();
                else if (_settings.Enabled) RecomputeIntervalSeconds();
            }
        }

        private void ExitApplication()
        {
            KeepAwake.AllowSleep();
            _trayTooltipTimer.Stop();
            _trayIcon.Visible = false;
            _trayIcon.Dispose();
            Application.Exit();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; this.Hide(); return; }
            KeepAwake.AllowSleep();
            base.OnFormClosing(e);
        }

        protected override void SetVisibleCore(bool value)
        {
            if (!this.IsHandleCreated) { CreateHandle(); value = false; }
            base.SetVisibleCore(value);
        }
    }
}
