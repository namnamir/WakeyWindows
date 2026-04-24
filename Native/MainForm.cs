using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using System.Threading;

namespace PowerManager
{
    public record LogEntry(DateTime Time, string Icon, string Message);

    public class LiveStats
    {
        public string StatusText { get; init; } = "";
        public string StatusIcon { get; init; } = "";
        public Color StatusColor { get; init; } = Color.Gray;
        public TimeSpan SessionUptime { get; init; }
        public int KeepAliveCount { get; init; }
        public TimeSpan? TimeUntilNext { get; init; }
        public int CurrentIntervalSeconds { get; init; }
        public IReadOnlyList<LogEntry> RecentLog { get; init; } = Array.Empty<LogEntry>();
        public bool IsEnabled { get; init; }
    }

    public partial class MainForm : Form
    {
        private readonly NotifyIcon _trayIcon;
        private readonly ContextMenuStrip _trayMenu;
        private readonly System.Windows.Forms.Timer _keepAliveTimer;
        private readonly System.Windows.Forms.Timer _activityTimer;
        private readonly Settings _settings;
        private readonly ActivityDetector _activityDetector;
        private readonly Random _random = new();

        private bool _isPaused;
        private bool _isUserActive;
        private DateTime _lastKeepAlive = DateTime.MinValue;
        private int _currentInterval;
        private DateTime _timerStartedAt = DateTime.Now;

        private readonly DateTime _sessionStart = DateTime.Now;
        private int _keepAliveCount;
        private readonly List<LogEntry> _logEntries = new();
        private const int MaxLogEntries = 100;

        private ToolStripMenuItem _statusItem = null!;
        private ToolStripMenuItem _pauseItem = null!;
        private ToolStripMenuItem _enabledItem = null!;

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
            this.Location = new Point(-1000, -1000);

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
            menu.Items.Add(new ToolStripMenuItem("Dashboard…", null, (s, e) => ShowDashboard()));
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(new ToolStripMenuItem("Exit", null, (s, e) => ExitApplication()));

            return menu;
        }

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

            if (!_activityDetector.IsWithinWorkingHours())
            {
                UpdateTrayStatus("Outside working hours");
                AddLog("🕐", "Outside working hours — skipped");
                SetNextInterval();
                return;
            }

            if (_isUserActive || _activityDetector.ShouldPauseKeepAlive())
            {
                UpdateTrayStatus("User active — paused");
                SetNextInterval();
                return;
            }

            KeepAwake.PreventSleep(_settings.KeepDisplayOn);
            if (_settings.SimulationMethod != "api_only")
            {
                MouseJiggler.Jiggle();
                _activityDetector.MarkAsJiggle();
            }

            _lastKeepAlive = DateTime.Now;
            _keepAliveCount++;
            SetNextInterval();
            UpdateTrayStatus("Active");
            AddLog("✅", "Keep-alive sent");
        }

        private void ActivityTimer_Tick(object? sender, EventArgs e)
        {
            if (!_settings.DetectUserActivity) return;

            bool wasActive = _isUserActive;
            _isUserActive = _activityDetector.IsUserActive();

            if (_isUserActive && !wasActive)
            {
                UpdateTrayStatus("User active — paused");
                AddLog("👤", "User activity detected — paused");
            }
            else if (!_isUserActive && wasActive && _settings.Enabled && !_isPaused)
            {
                UpdateTrayStatus("Active");
                AddLog("💤", "User idle — resuming");
            }
        }

        private void Start()
        {
            _keepAliveTimer.Start();
            _activityTimer.Start();
            _timerStartedAt = DateTime.Now;

            if (!_activityDetector.IsUserActive())
            {
                KeepAwake.PreventSleep(_settings.KeepDisplayOn);
                _lastKeepAlive = DateTime.Now;
                _keepAliveCount++;
            }

            UpdateTrayStatus("Active");
            AddLog("🟢", "WakeyWindows started");
            ShowNotification("WakeyWindows", "System keep-alive is now active.");
        }

        private void Stop()
        {
            _keepAliveTimer.Stop();
            _activityTimer.Stop();
            KeepAwake.AllowSleep();
            UpdateTrayStatus("Disabled");
            AddLog("🔴", "WakeyWindows disabled");
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
                AddLog("⏸", "Paused by user");
                ShowNotification("WakeyWindows", "Keep-alive paused.");
            }
            else
            {
                UpdateTrayStatus("Active");
                AddLog("▶", "Resumed by user");
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
            _trayIcon.Text = $"WakeyWindows — {s}";
        }

        private void AddLog(string icon, string message)
        {
            _logEntries.Insert(0, new LogEntry(DateTime.Now, icon, message));
            if (_logEntries.Count > MaxLogEntries)
                _logEntries.RemoveAt(_logEntries.Count - 1);
        }

        private void ShowNotification(string title, string text)
        {
            if (!_settings.ShowBalloonTips || !_trayIcon.Visible) return;
            _trayIcon.BalloonTipTitle = title;
            _trayIcon.BalloonTipText = text;
            _trayIcon.BalloonTipIcon = ToolTipIcon.Info;
            _trayIcon.ShowBalloonTip(3000);
        }

        public LiveStats GetLiveStats()
        {
            var now = DateTime.Now;
            TimeSpan? timeUntilNext = null;

            if (_keepAliveTimer.Enabled && _settings.Enabled && !_isPaused)
            {
                var remaining = TimeSpan.FromSeconds(_currentInterval) - (now - _timerStartedAt);
                timeUntilNext = remaining.TotalSeconds > 0 ? remaining : TimeSpan.Zero;
            }

            string statusText; string statusIcon; Color statusColor;

            if (!_settings.Enabled)
            { statusText = "Disabled"; statusIcon = "⛔"; statusColor = Color.FromArgb(158, 158, 158); }
            else if (_isPaused)
            { statusText = "Paused"; statusIcon = "⏸"; statusColor = Color.FromArgb(255, 152, 0); }
            else if (_isUserActive)
            { statusText = "User active — paused"; statusIcon = "👤"; statusColor = Color.FromArgb(33, 150, 243); }
            else if (!_activityDetector.IsWithinWorkingHours())
            { statusText = "Outside working hours"; statusIcon = "🕐"; statusColor = Color.FromArgb(255, 152, 0); }
            else
            { statusText = "Active — keeping awake"; statusIcon = "✅"; statusColor = Color.FromArgb(76, 175, 80); }

            return new LiveStats
            {
                StatusText = statusText,
                StatusIcon = statusIcon,
                StatusColor = statusColor,
                SessionUptime = now - _sessionStart,
                KeepAliveCount = _keepAliveCount,
                TimeUntilNext = timeUntilNext,
                CurrentIntervalSeconds = _currentInterval,
                RecentLog = _logEntries.AsReadOnly(),
                IsEnabled = _settings.Enabled
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

                if (_settings.Enabled && !_keepAliveTimer.Enabled) Start();
                else if (!_settings.Enabled && _keepAliveTimer.Enabled) Stop();
            }
        }

        private void ExitApplication()
        {
            KeepAwake.AllowSleep();
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
