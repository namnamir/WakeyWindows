using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace PowerManager
{
    public class SettingsForm : Form
    {
        private readonly Settings _settings;
        private readonly Func<LiveStats> _getStats;
        private readonly System.Windows.Forms.Timer _liveTimer;

        // ── Settings controls ──────────────────────────────────────────────
        private CheckBox _enabledCheckBox = null!;
        private NumericUpDown _intervalMinNumeric = null!;
        private NumericUpDown _intervalMaxNumeric = null!;
        private ComboBox _simulationMethodCombo = null!;
        private CheckBox _keepDisplayOnCheckBox = null!;

        private CheckBox _detectActivityCheckBox = null!;
        private NumericUpDown _activityPauseNumeric = null!;
        private NumericUpDown _idleTimeoutNumeric = null!;
        private NumericUpDown _mouseThresholdNumeric = null!;

        private CheckBox _useWorkingHoursCheckBox = null!;
        private TextBox _workingHoursStartTextBox = null!;
        private TextBox _workingHoursEndTextBox = null!;

        private CheckBox _showTrayIconCheckBox = null!;
        private CheckBox _showBalloonTipsCheckBox = null!;
        private CheckBox _startWithWindowsCheckBox = null!;

        private Label _versionLabel = null!;
        private Button _checkUpdateButton = null!;

        // ── Dashboard controls (live) ──────────────────────────────────────
        private Panel _accentBar = null!;
        private Label _statusIconLabel = null!;
        private Label _statusTextLabel = null!;
        private Label _sessionUptimeLabel = null!;
        private Label _keepAliveCountLabel = null!;
        private Label _countdownLabel = null!;
        private Label _intervalLabel = null!;
        private Panel _progressFill = null!;
        private Panel _progressContainer = null!;
        private RichTextBox _logBox = null!;

        private int _lastLogCount = -1;

        public SettingsForm(Settings settings, Func<LiveStats> getStats)
        {
            _settings = settings;
            _getStats = getStats;
            Font = new Font("Segoe UI", 9f);

            InitializeComponent();
            LoadSettings();
            UpdateDashboard();

            _liveTimer = new System.Windows.Forms.Timer { Interval = 1000 };
            _liveTimer.Tick += (s, e) => UpdateDashboard();
            _liveTimer.Start();

            this.FormClosed += (s, e) => { _liveTimer.Stop(); _liveTimer.Dispose(); };
        }

        private void InitializeComponent()
        {
            Text = "WakeyWindows";
            Size = new Size(520, 560);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = true;
            BackColor = Color.FromArgb(245, 247, 250);

            // ── Header ─────────────────────────────────────────────────────
            var header = new GradientPanel
            {
                Dock = DockStyle.Top,
                Height = 72
            };

            var titleLabel = new Label
            {
                Text = "💤  WakeyWindows",
                Font = new Font("Segoe UI", 13f, FontStyle.Bold),
                ForeColor = Color.White,
                AutoSize = true,
                Location = new Point(16, 13)
            };
            var subtitleLabel = new Label
            {
                Text = "System Keep-Alive Manager",
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = Color.FromArgb(180, 215, 255),
                AutoSize = true,
                Location = new Point(19, 41)
            };

            header.Controls.Add(titleLabel);
            header.Controls.Add(subtitleLabel);

            // ── Button panel ───────────────────────────────────────────────
            var buttonPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 48,
                BackColor = Color.FromArgb(232, 234, 238)
            };

            var saveButton = new Button
            {
                Text = "Save",
                Size = new Size(90, 30),
                Location = new Point(0, 0),   // positioned below
                FlatStyle = FlatStyle.System
            };
            var cancelButton = new Button
            {
                Text = "Cancel",
                Size = new Size(90, 30),
                DialogResult = DialogResult.Cancel,
                FlatStyle = FlatStyle.System
            };

            saveButton.Click += OkButton_Click;

            buttonPanel.Controls.Add(saveButton);
            buttonPanel.Controls.Add(cancelButton);
            buttonPanel.Resize += (s, e) =>
            {
                int y = (buttonPanel.ClientSize.Height - 30) / 2;
                cancelButton.Location = new Point(buttonPanel.ClientSize.Width - 100, y);
                saveButton.Location = new Point(buttonPanel.ClientSize.Width - 200, y);
            };

            // ── Tab control ────────────────────────────────────────────────
            var tabControl = new TabControl
            {
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9f),
                Padding = new Point(10, 4)
            };

            tabControl.TabPages.Add(BuildDashboardTab());
            tabControl.TabPages.Add(BuildGeneralTab());
            tabControl.TabPages.Add(BuildActivityTab());
            tabControl.TabPages.Add(BuildScheduleTab());
            tabControl.TabPages.Add(BuildDisplayTab());
            tabControl.TabPages.Add(BuildAboutTab());

            // Add in correct dock order: top first, bottom, then fill
            Controls.Add(header);
            Controls.Add(buttonPanel);
            Controls.Add(tabControl);

            AcceptButton = saveButton;
            CancelButton = cancelButton;
        }

        // ════════════════════════════════════════════════════════════════════
        // DASHBOARD TAB
        // ════════════════════════════════════════════════════════════════════

        private TabPage BuildDashboardTab()
        {
            var page = new TabPage("🖥  Dashboard");
            page.BackColor = Color.FromArgb(245, 247, 250);

            var layout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 8,
                Padding = new Padding(12, 8, 12, 8),
                BackColor = Color.FromArgb(245, 247, 250)
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));  // "Status" header
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 70));  // status card
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 10));  // spacer
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));  // "Next" header
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));  // countdown card
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 10));  // spacer
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));  // "Log" header
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));  // log (fills rest)

            // Row 0 — Status section header
            layout.Controls.Add(MakeSectionHeader("📊  Current Status"), 0, 0);

            // Row 1 — Status card
            var statusCard = BuildStatusCard();
            layout.Controls.Add(statusCard, 0, 1);

            // Row 2 — spacer (empty)
            layout.Controls.Add(new Label(), 0, 2);

            // Row 3 — Next section header
            layout.Controls.Add(MakeSectionHeader("⏱  Next Keep-Alive"), 0, 3);

            // Row 4 — Countdown card
            var countdownCard = BuildCountdownCard();
            layout.Controls.Add(countdownCard, 0, 4);

            // Row 5 — spacer
            layout.Controls.Add(new Label(), 0, 5);

            // Row 6 — Log section header
            layout.Controls.Add(MakeSectionHeader("📋  Activity Log"), 0, 6);

            // Row 7 — Log box
            _logBox = new RichTextBox
            {
                Dock = DockStyle.Fill,
                ReadOnly = true,
                BorderStyle = BorderStyle.FixedSingle,
                BackColor = Color.White,
                Font = new Font("Consolas", 8.5f),
                ScrollBars = RichTextBoxScrollBars.Vertical,
                WordWrap = false,
                DetectUrls = false
            };
            layout.Controls.Add(_logBox, 0, 7);

            page.Controls.Add(layout);
            return page;
        }

        private Panel BuildStatusCard()
        {
            var card = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };

            _accentBar = new Panel
            {
                Location = new Point(0, 0),
                Size = new Size(5, 200),  // height updated in layout
                BackColor = Color.FromArgb(76, 175, 80),
                Dock = DockStyle.Left
            };
            card.Controls.Add(_accentBar);

            _statusIconLabel = new Label
            {
                Text = "✅",
                Font = new Font("Segoe UI", 18f),
                Location = new Point(14, 14),
                Size = new Size(36, 36),
                TextAlign = ContentAlignment.MiddleCenter
            };
            card.Controls.Add(_statusIconLabel);

            _statusTextLabel = new Label
            {
                Text = "Active — keeping awake",
                Font = new Font("Segoe UI Semibold", 10.5f, FontStyle.Bold),
                Location = new Point(56, 10),
                Size = new Size(340, 22),
                ForeColor = Color.FromArgb(33, 33, 33),
                AutoEllipsis = true
            };
            card.Controls.Add(_statusTextLabel);

            // Stats row
            var statsFlow = new FlowLayoutPanel
            {
                Location = new Point(56, 36),
                Size = new Size(370, 22),
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                BackColor = Color.Transparent
            };

            statsFlow.Controls.Add(MakeStatCaption("Session:"));
            _sessionUptimeLabel = MakeStatValue("0s");
            statsFlow.Controls.Add(_sessionUptimeLabel);

            var divider = new Label { Text = " · ", ForeColor = Color.LightGray, AutoSize = true, Margin = new Padding(2, 2, 2, 0) };
            statsFlow.Controls.Add(divider);

            statsFlow.Controls.Add(MakeStatCaption("Keep-alives:"));
            _keepAliveCountLabel = MakeStatValue("0");
            statsFlow.Controls.Add(_keepAliveCountLabel);

            card.Controls.Add(statsFlow);
            return card;
        }

        private Panel BuildCountdownCard()
        {
            var card = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };

            _countdownLabel = new Label
            {
                Text = "—",
                Font = new Font("Segoe UI", 20f, FontStyle.Bold),
                Location = new Point(14, 6),
                Size = new Size(130, 34),
                ForeColor = Color.FromArgb(25, 118, 210),
                TextAlign = ContentAlignment.MiddleLeft
            };
            card.Controls.Add(_countdownLabel);

            _intervalLabel = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 8f),
                Location = new Point(14, 42),
                Size = new Size(200, 16),
                ForeColor = Color.FromArgb(130, 130, 130)
            };
            card.Controls.Add(_intervalLabel);

            // Custom progress bar (ProgressBar ForeColor doesn't work on Win10+)
            _progressContainer = new Panel
            {
                Location = new Point(160, 20),
                Size = new Size(0, 14),  // width set in Resize
                BackColor = Color.FromArgb(218, 228, 240),
                BorderStyle = BorderStyle.None
            };

            _progressFill = new Panel
            {
                Location = new Point(0, 0),
                Size = new Size(0, 14),
                BackColor = Color.FromArgb(25, 118, 210)
            };
            _progressContainer.Controls.Add(_progressFill);
            card.Controls.Add(_progressContainer);

            // Size progress bar when card is laid out
            card.Resize += (s, e) =>
            {
                int progressWidth = card.ClientSize.Width - 172;
                if (progressWidth < 1) return;
                _progressContainer.Size = new Size(progressWidth, 14);
                _progressContainer.Top = (card.ClientSize.Height - 14) / 2;
                RefreshProgressFill();
            };

            return card;
        }

        private double _lastProgressPct = 0;

        private void RefreshProgressFill()
        {
            int w = (int)(_progressContainer.Width * _lastProgressPct);
            _progressFill.Size = new Size(Math.Max(0, Math.Min(w, _progressContainer.Width)), 14);

            // Color: green when plenty of time, orange when < 20%
            _progressFill.BackColor = _lastProgressPct < 0.2
                ? Color.FromArgb(244, 81, 30)
                : Color.FromArgb(25, 118, 210);
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS TABS
        // ════════════════════════════════════════════════════════════════════

        private TabPage BuildGeneralTab()
        {
            var page = new TabPage("⚙  General");
            var layout = MakeTable(6);
            page.Controls.Add(layout);

            AddHeader(layout, "Keep-Alive");

            _enabledCheckBox = new CheckBox { Text = "Enabled", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_enabledCheckBox);

            layout.Controls.Add(MakeLabel("Min interval (seconds):"));
            _intervalMinNumeric = new NumericUpDown { Minimum = 10, Maximum = 600, Value = 60, Width = 80 };
            layout.Controls.Add(_intervalMinNumeric);

            layout.Controls.Add(MakeLabel("Max interval (seconds):"));
            _intervalMaxNumeric = new NumericUpDown { Minimum = 30, Maximum = 900, Value = 120, Width = 80 };
            layout.Controls.Add(_intervalMaxNumeric);

            layout.Controls.Add(MakeLabel("Simulation method:"));
            _simulationMethodCombo = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 200 };
            _simulationMethodCombo.Items.Add("Mouse jiggle (recommended)");
            _simulationMethodCombo.Items.Add("API only (no input events)");
            layout.Controls.Add(_simulationMethodCombo);

            _keepDisplayOnCheckBox = new CheckBox { Text = "Keep display on", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_keepDisplayOnCheckBox);

            return page;
        }

        private TabPage BuildActivityTab()
        {
            var page = new TabPage("👁  Activity");
            var layout = MakeTable(5);
            page.Controls.Add(layout);

            AddHeader(layout, "Activity Detection");

            _detectActivityCheckBox = new CheckBox { Text = "Pause when user is working", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_detectActivityCheckBox);

            layout.Controls.Add(MakeLabel("Pause after activity (sec):"));
            _activityPauseNumeric = new NumericUpDown { Minimum = 10, Maximum = 600, Value = 120, Width = 80 };
            layout.Controls.Add(_activityPauseNumeric);

            layout.Controls.Add(MakeLabel("Idle timeout (seconds):"));
            _idleTimeoutNumeric = new NumericUpDown { Minimum = 5, Maximum = 300, Value = 30, Width = 80 };
            layout.Controls.Add(_idleTimeoutNumeric);

            layout.Controls.Add(MakeLabel("Mouse threshold (pixels):"));
            _mouseThresholdNumeric = new NumericUpDown { Minimum = 1, Maximum = 100, Value = 10, Width = 80 };
            layout.Controls.Add(_mouseThresholdNumeric);

            return page;
        }

        private TabPage BuildScheduleTab()
        {
            var page = new TabPage("🗓  Schedule");
            var layout = MakeTable(4);
            page.Controls.Add(layout);

            AddHeader(layout, "Working Hours (Optional)");

            _useWorkingHoursCheckBox = new CheckBox { Text = "Only run during working hours", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_useWorkingHoursCheckBox);

            layout.Controls.Add(MakeLabel("Start time (HH:MM):"));
            _workingHoursStartTextBox = new TextBox { Width = 80 };
            layout.Controls.Add(_workingHoursStartTextBox);

            layout.Controls.Add(MakeLabel("End time (HH:MM):"));
            _workingHoursEndTextBox = new TextBox { Width = 80 };
            layout.Controls.Add(_workingHoursEndTextBox);

            return page;
        }

        private TabPage BuildDisplayTab()
        {
            var page = new TabPage("🎨  Display");
            var layout = MakeTable(4);
            page.Controls.Add(layout);

            AddHeader(layout, "Tray & Notifications");

            _showTrayIconCheckBox = new CheckBox { Text = "Show tray icon", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_showTrayIconCheckBox);

            _showBalloonTipsCheckBox = new CheckBox { Text = "Show balloon notifications", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_showBalloonTipsCheckBox);

            _startWithWindowsCheckBox = new CheckBox { Text = "Start with Windows", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_startWithWindowsCheckBox);

            return page;
        }

        private TabPage BuildAboutTab()
        {
            var page = new TabPage("ℹ  About");
            page.BackColor = Color.FromArgb(245, 247, 250);

            var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };

            // Big icon
            var iconLabel = new Label
            {
                Text = "💤",
                Font = new Font("Segoe UI", 32f),
                Location = new Point(20, 20),
                AutoSize = true
            };
            panel.Controls.Add(iconLabel);

            var nameLabel = new Label
            {
                Text = "WakeyWindows",
                Font = new Font("Segoe UI", 14f, FontStyle.Bold),
                ForeColor = Color.FromArgb(33, 33, 33),
                Location = new Point(76, 26),
                AutoSize = true
            };
            panel.Controls.Add(nameLabel);

            _versionLabel = new Label
            {
                Text = $"Version {Application.ProductVersion}",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.Gray,
                Location = new Point(78, 52),
                AutoSize = true
            };
            panel.Controls.Add(_versionLabel);

            var descLabel = new Label
            {
                Text = "Keeps your PC awake and your Teams status online\nusing the same low-level API as video players and\npresentation software.",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(80, 80, 80),
                Location = new Point(20, 90),
                Size = new Size(420, 56),
                AutoSize = false
            };
            panel.Controls.Add(descLabel);

            var separator = new Panel
            {
                Location = new Point(20, 155),
                Size = new Size(420, 1),
                BackColor = Color.FromArgb(210, 215, 222)
            };
            panel.Controls.Add(separator);

            var githubLink = new LinkLabel
            {
                Text = "github.com/namnamir/WakeyWindows",
                Location = new Point(20, 165),
                AutoSize = true,
                Font = new Font("Segoe UI", 9f)
            };
            githubLink.LinkClicked += (s, e) =>
            {
                try
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = "https://github.com/namnamir/WakeyWindows",
                        UseShellExecute = true
                    });
                }
                catch { /* ignore */ }
            };
            panel.Controls.Add(githubLink);

            _checkUpdateButton = new Button
            {
                Text = "Check for updates",
                Location = new Point(20, 200),
                Size = new Size(150, 30),
                FlatStyle = FlatStyle.System
            };
            _checkUpdateButton.Click += CheckUpdateButton_Click;
            panel.Controls.Add(_checkUpdateButton);

            page.Controls.Add(panel);
            return page;
        }

        // ════════════════════════════════════════════════════════════════════
        // LIVE DASHBOARD UPDATE
        // ════════════════════════════════════════════════════════════════════

        private void UpdateDashboard()
        {
            if (_logBox == null) return;

            var stats = _getStats();

            // Status card
            _accentBar.BackColor = stats.StatusColor;
            _statusIconLabel.Text = stats.StatusIcon;
            _statusTextLabel.Text = stats.StatusText;
            _statusTextLabel.ForeColor = stats.StatusColor;

            // Session uptime
            var up = stats.SessionUptime;
            _sessionUptimeLabel.Text = up.TotalHours >= 1
                ? $"{(int)up.TotalHours}h {up.Minutes}m"
                : up.Minutes > 0
                    ? $"{up.Minutes}m {up.Seconds}s"
                    : $"{up.Seconds}s";

            _keepAliveCountLabel.Text = stats.KeepAliveCount.ToString();

            // Countdown
            if (stats.TimeUntilNext.HasValue && stats.IsEnabled && stats.CurrentIntervalSeconds > 0)
            {
                var t = stats.TimeUntilNext.Value;
                _countdownLabel.Text = t.TotalSeconds >= 60
                    ? $"{(int)t.TotalMinutes}m {t.Seconds:D2}s"
                    : $"{(int)t.TotalSeconds}s";

                _intervalLabel.Text = $"interval: {stats.CurrentIntervalSeconds}s · next in {_countdownLabel.Text}";

                double elapsed = stats.CurrentIntervalSeconds - t.TotalSeconds;
                _lastProgressPct = elapsed / stats.CurrentIntervalSeconds;
                _lastProgressPct = Math.Max(0, Math.Min(1, _lastProgressPct));
            }
            else
            {
                _countdownLabel.Text = stats.IsEnabled ? "—" : "off";
                _intervalLabel.Text = stats.IsEnabled ? "" : "disabled";
                _lastProgressPct = 0;
            }
            RefreshProgressFill();

            // Log
            if (stats.RecentLog.Count != _lastLogCount)
            {
                _lastLogCount = stats.RecentLog.Count;
                _logBox.Clear();
                foreach (var entry in stats.RecentLog)
                {
                    _logBox.SelectionColor = Color.FromArgb(140, 140, 140);
                    _logBox.AppendText(entry.Time.ToString("HH:mm:ss") + "  ");
                    _logBox.SelectionColor = Color.FromArgb(33, 33, 33);
                    _logBox.AppendText(entry.Icon + "  " + entry.Message + "\n");
                }
                // Scroll to top so newest entries (prepended to the list) show first
                _logBox.SelectionStart = 0;
                _logBox.ScrollToCaret();
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS LOAD / SAVE
        // ════════════════════════════════════════════════════════════════════

        private void LoadSettings()
        {
            _enabledCheckBox.Checked = _settings.Enabled;
            _intervalMinNumeric.Value = _settings.IntervalMinSeconds;
            _intervalMaxNumeric.Value = _settings.IntervalMaxSeconds;
            _simulationMethodCombo.SelectedIndex = _settings.SimulationMethod == "api_only" ? 1 : 0;
            _keepDisplayOnCheckBox.Checked = _settings.KeepDisplayOn;

            _detectActivityCheckBox.Checked = _settings.DetectUserActivity;
            _activityPauseNumeric.Value = _settings.ActivityPauseSeconds;
            _idleTimeoutNumeric.Value = _settings.IdleTimeoutSeconds;
            _mouseThresholdNumeric.Value = _settings.MouseMovementThreshold;

            _useWorkingHoursCheckBox.Checked = _settings.UseWorkingHours;
            _workingHoursStartTextBox.Text = _settings.WorkingHoursStart;
            _workingHoursEndTextBox.Text = _settings.WorkingHoursEnd;

            _showTrayIconCheckBox.Checked = _settings.ShowTrayIcon;
            _showBalloonTipsCheckBox.Checked = _settings.ShowBalloonTips;
            _startWithWindowsCheckBox.Checked = _settings.StartWithWindows;
        }

        private void OkButton_Click(object? sender, EventArgs e)
        {
            if (_intervalMinNumeric.Value >= _intervalMaxNumeric.Value)
            {
                MessageBox.Show("Min interval must be less than max interval.", "Validation",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            _settings.Enabled = _enabledCheckBox.Checked;
            _settings.IntervalMinSeconds = (int)_intervalMinNumeric.Value;
            _settings.IntervalMaxSeconds = (int)_intervalMaxNumeric.Value;
            _settings.SimulationMethod = _simulationMethodCombo.SelectedIndex == 1 ? "api_only" : "mouse_jiggle";
            _settings.KeepDisplayOn = _keepDisplayOnCheckBox.Checked;

            _settings.DetectUserActivity = _detectActivityCheckBox.Checked;
            _settings.ActivityPauseSeconds = (int)_activityPauseNumeric.Value;
            _settings.IdleTimeoutSeconds = (int)_idleTimeoutNumeric.Value;
            _settings.MouseMovementThreshold = (int)_mouseThresholdNumeric.Value;

            _settings.UseWorkingHours = _useWorkingHoursCheckBox.Checked;
            _settings.WorkingHoursStart = _workingHoursStartTextBox.Text;
            _settings.WorkingHoursEnd = _workingHoursEndTextBox.Text;

            _settings.ShowTrayIcon = _showTrayIconCheckBox.Checked;
            _settings.ShowBalloonTips = _showBalloonTipsCheckBox.Checked;
            _settings.StartWithWindows = _startWithWindowsCheckBox.Checked;

            _settings.Save();
            ApplyStartWithWindows(_settings.StartWithWindows);

            DialogResult = DialogResult.OK;
            Close();
        }

        private static void ApplyStartWithWindows(bool enable)
        {
            try
            {
                const string keyPath = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
                const string valueName = "WakeyWindows";
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(keyPath, writable: true);
                if (key == null) return;

                if (enable)
                    key.SetValue(valueName, $"\"{System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName}\"");
                else
                    key.DeleteValue(valueName, throwOnMissingValue: false);
            }
            catch { /* non-critical */ }
        }

        private async void CheckUpdateButton_Click(object? sender, EventArgs e)
        {
            _checkUpdateButton.Enabled = false;
            _checkUpdateButton.Text = "Checking…";

            var (hasUpdate, latestVersion, error) =
                await UpdateChecker.CheckForUpdatesAsync(Application.ProductVersion, _settings.UpdateCheckUrl);

            _checkUpdateButton.Enabled = true;
            _checkUpdateButton.Text = "Check for updates";

            if (!string.IsNullOrEmpty(error))
            {
                MessageBox.Show($"Could not check for updates:\n{error}", "Update Check",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            MessageBox.Show(
                hasUpdate && latestVersion != null
                    ? $"A newer version is available!\n\nCurrent: {Application.ProductVersion}\nLatest:   {latestVersion}"
                    : "You are running the latest version. ✅",
                "Update Check", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        // ════════════════════════════════════════════════════════════════════
        // HELPERS
        // ════════════════════════════════════════════════════════════════════

        private static Label MakeSectionHeader(string text) =>
            new Label
            {
                Text = text,
                Font = new Font("Segoe UI Semibold", 9f, FontStyle.Bold),
                ForeColor = Color.FromArgb(70, 80, 100),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.BottomLeft,
                Padding = new Padding(0, 0, 0, 2)
            };

        private static TableLayoutPanel MakeTable(int rows)
        {
            var table = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = rows,
                Padding = new Padding(14, 12, 14, 12)
            };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 200));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            for (int i = 0; i < rows; i++)
                table.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
            return table;
        }

        private static void AddHeader(TableLayoutPanel table, string text)
        {
            var label = new Label
            {
                Text = text,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                ForeColor = Color.FromArgb(50, 70, 120),
                AutoSize = true,
                Anchor = AnchorStyles.Left | AnchorStyles.Bottom
            };
            table.Controls.Add(label);
            table.SetColumnSpan(label, 2);
        }

        private static Label MakeLabel(string text) =>
            new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left | AnchorStyles.Top, Padding = new Padding(0, 6, 0, 0) };

        private static Label SpanLabel(string text) =>
            new Label { Text = text, AutoSize = true };

        private static Label MakeStatCaption(string text) =>
            new Label
            {
                Text = text,
                ForeColor = Color.Gray,
                AutoSize = true,
                Font = new Font("Segoe UI", 8.5f),
                Margin = new Padding(0, 3, 4, 0)
            };

        private static Label MakeStatValue(string text) =>
            new Label
            {
                Text = text,
                ForeColor = Color.FromArgb(33, 33, 33),
                AutoSize = true,
                Font = new Font("Segoe UI Semibold", 8.5f, FontStyle.Bold),
                Margin = new Padding(0, 3, 10, 0)
            };

        // ── Gradient header panel ──────────────────────────────────────────
        private sealed class GradientPanel : Panel
        {
            public GradientPanel() { DoubleBuffered = true; }

            protected override void OnPaintBackground(PaintEventArgs e)
            {
                if (ClientSize.Width <= 0 || ClientSize.Height <= 0)
                {
                    base.OnPaintBackground(e);
                    return;
                }

                using var brush = new LinearGradientBrush(
                    ClientRectangle,
                    Color.FromArgb(28, 48, 100),
                    Color.FromArgb(18, 30, 72),
                    LinearGradientMode.Vertical);
                e.Graphics.FillRectangle(brush, ClientRectangle);

                // Subtle bottom border
                using var pen = new Pen(Color.FromArgb(10, 20, 55), 1);
                e.Graphics.DrawLine(pen, 0, ClientSize.Height - 1, ClientSize.Width, ClientSize.Height - 1);
            }
        }
    }
}
