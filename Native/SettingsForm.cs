using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Windows.Forms;

namespace PowerManager
{
    public class SettingsForm : Form
    {
        private readonly Settings _settings;
        private readonly Func<LiveStats> _getStats;
        private readonly System.Windows.Forms.Timer _liveTimer;

        // ── General tab ────────────────────────────────────────────────────
        private CheckBox _enabledCheckBox = null!;
        private NumericUpDown _intervalMinNumeric = null!;
        private NumericUpDown _intervalMaxNumeric = null!;
        private ComboBox _simulationMethodCombo = null!;
        private CheckBox _keepDisplayOnCheckBox = null!;

        // ── Activity tab ───────────────────────────────────────────────────
        private CheckBox _detectActivityCheckBox = null!;
        private NumericUpDown _activityPauseNumeric = null!;
        private NumericUpDown _idleTimeoutNumeric = null!;
        private NumericUpDown _mouseThresholdNumeric = null!;

        // ── Schedule tab ───────────────────────────────────────────────────
        private CheckBox _useWorkingHoursCheckBox = null!;
        private TextBox _workingHoursStartTextBox = null!;
        private TextBox _workingHoursEndTextBox = null!;
        private CheckBox[] _dayCheckBoxes = null!;
        private CheckBox _skipHolidaysCheckBox = null!;
        private TextBox _holidayCountryTextBox = null!;

        // ── Display tab ────────────────────────────────────────────────────
        private CheckBox _showTrayIconCheckBox = null!;
        private CheckBox _showBalloonTipsCheckBox = null!;
        private CheckBox _startWithWindowsCheckBox = null!;

        // ── About tab ─────────────────────────────────────────────────────
        private Label _versionLabel = null!;
        private Button _checkUpdateButton = null!;

        // ── Dashboard controls (live) ──────────────────────────────────────
        private Panel _accentBar = null!;
        private Label _statusIconLabel = null!;
        private Label _statusTextLabel = null!;
        private Label _methodBadgeLabel = null!;
        private Label _sessionUptimeLabel = null!;
        private Label _keepAliveCountLabel = null!;
        private Label _countdownLabel = null!;
        private Label _nextAtLabel = null!;
        private Label _intervalLabel = null!;
        private Panel _progressFill = null!;
        private Panel _progressContainer = null!;
        private RichTextBox _logBox = null!;
        private int _lastLogCount = -1;
        private double _lastProgressPct = 0;

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
            string version = Application.ProductVersion;
            Text = $"WakeyWindows  v{version}";
            Size = new Size(560, 620);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = true;
            BackColor = Color.FromArgb(245, 247, 250);

            // ── Header ─────────────────────────────────────────────────────
            var header = new GradientPanel { Dock = DockStyle.Top, Height = 72 };

            var titleLabel = new Label
            {
                Text = "💤  WakeyWindows",
                Font = new Font("Segoe UI", 13f, FontStyle.Bold),
                ForeColor = Color.White,
                AutoSize = true,
                Location = new Point(16, 12)
            };
            var subtitleLabel = new Label
            {
                Text = $"System Keep-Alive Manager  ·  v{version}",
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = Color.FromArgb(180, 215, 255),
                AutoSize = true,
                Location = new Point(19, 40)
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
            var saveButton = new Button { Text = "Save", Size = new Size(90, 30), FlatStyle = FlatStyle.System };
            var cancelButton = new Button { Text = "Cancel", Size = new Size(90, 30), DialogResult = DialogResult.Cancel, FlatStyle = FlatStyle.System };
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
            var page = new TabPage("🖥  Dashboard") { BackColor = Color.FromArgb(245, 247, 250) };

            var layout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 8,
                Padding = new Padding(12, 8, 12, 8),
                BackColor = Color.FromArgb(245, 247, 250)
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));   // status header
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 80));   // status card
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 10));   // spacer
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));   // next header
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 68));   // countdown card
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 10));   // spacer
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));   // log header
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));   // log

            layout.Controls.Add(MakeSectionHeader("📊  Current Status"), 0, 0);
            layout.Controls.Add(BuildStatusCard(), 0, 1);
            layout.Controls.Add(new Label(), 0, 2);
            layout.Controls.Add(MakeSectionHeader("⏱  Next Keep-Alive"), 0, 3);
            layout.Controls.Add(BuildCountdownCard(), 0, 4);
            layout.Controls.Add(new Label(), 0, 5);
            layout.Controls.Add(MakeSectionHeader("📋  Activity Log"), 0, 6);

            _logBox = new RichTextBox
            {
                Dock = DockStyle.Fill,
                ReadOnly = true,
                BorderStyle = BorderStyle.FixedSingle,
                BackColor = Color.FromArgb(30, 30, 30),
                ForeColor = Color.FromArgb(220, 220, 220),
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
            var card = MakeCard();

            _accentBar = new Panel
            {
                Location = new Point(0, 0),
                Width = 5,
                Dock = DockStyle.Left,
                BackColor = Color.FromArgb(76, 175, 80)
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
                Location = new Point(56, 8),
                Size = new Size(360, 22),
                ForeColor = Color.FromArgb(33, 33, 33),
                AutoEllipsis = true
            };
            card.Controls.Add(_statusTextLabel);

            _methodBadgeLabel = new Label
            {
                Text = "Mode: —",
                Font = new Font("Segoe UI", 8f),
                Location = new Point(56, 32),
                AutoSize = true,
                ForeColor = Color.FromArgb(100, 100, 120),
                BackColor = Color.FromArgb(235, 237, 245),
                Padding = new Padding(4, 2, 4, 2)
            };
            card.Controls.Add(_methodBadgeLabel);

            var statsFlow = new FlowLayoutPanel
            {
                Location = new Point(56, 54),
                Size = new Size(420, 22),
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                BackColor = Color.Transparent
            };
            statsFlow.Controls.Add(MakeStatCaption("Session:"));
            _sessionUptimeLabel = MakeStatValue("0s");
            statsFlow.Controls.Add(_sessionUptimeLabel);
            statsFlow.Controls.Add(new Label { Text = " · ", ForeColor = Color.LightGray, AutoSize = true, Margin = new Padding(2, 2, 2, 0) });
            statsFlow.Controls.Add(MakeStatCaption("Keep-alives:"));
            _keepAliveCountLabel = MakeStatValue("0");
            statsFlow.Controls.Add(_keepAliveCountLabel);
            card.Controls.Add(statsFlow);

            return card;
        }

        private Panel BuildCountdownCard()
        {
            var card = MakeCard();

            _countdownLabel = new Label
            {
                Text = "—",
                Font = new Font("Segoe UI", 20f, FontStyle.Bold),
                Location = new Point(14, 6),
                Size = new Size(140, 34),
                ForeColor = Color.FromArgb(25, 118, 210),
                TextAlign = ContentAlignment.MiddleLeft
            };
            card.Controls.Add(_countdownLabel);

            _nextAtLabel = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 8f),
                Location = new Point(158, 8),
                Size = new Size(180, 16),
                ForeColor = Color.FromArgb(100, 100, 100)
            };
            card.Controls.Add(_nextAtLabel);

            _intervalLabel = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 8f),
                Location = new Point(14, 42),
                Size = new Size(300, 16),
                ForeColor = Color.FromArgb(130, 130, 130)
            };
            card.Controls.Add(_intervalLabel);

            _progressContainer = new Panel
            {
                Location = new Point(158, 28),
                Size = new Size(0, 10),
                BackColor = Color.FromArgb(218, 228, 240),
                BorderStyle = BorderStyle.None
            };
            _progressFill = new Panel
            {
                Location = new Point(0, 0),
                Size = new Size(0, 10),
                BackColor = Color.FromArgb(25, 118, 210)
            };
            _progressContainer.Controls.Add(_progressFill);
            card.Controls.Add(_progressContainer);

            card.Resize += (s, e) =>
            {
                int w = card.ClientSize.Width - 170;
                if (w < 1) return;
                _progressContainer.Size = new Size(w, 10);
                _progressContainer.Top = 30;
                RefreshProgressFill();
            };

            return card;
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS TABS
        // ════════════════════════════════════════════════════════════════════

        private TabPage BuildGeneralTab()
        {
            var page = new TabPage("⚙  General");
            var layout = MakeTable(7);
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
            _simulationMethodCombo = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 220 };
            _simulationMethodCombo.Items.Add("Mouse jiggle (recommended)");
            _simulationMethodCombo.Items.Add("Key press · F15");
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
            var outer = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 3,
                Padding = new Padding(14, 12, 14, 12)
            };
            outer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 140)); // working hours section
            outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 12));  // spacer
            outer.RowStyles.Add(new RowStyle(SizeType.Absolute, 110)); // holidays section
            page.Controls.Add(outer);

            // ── Working Hours ──────────────────────────────────────────────
            var hoursGroup = new GroupBox
            {
                Text = "Working Hours",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                ForeColor = Color.FromArgb(50, 70, 120),
                Padding = new Padding(8, 4, 8, 4)
            };
            var hoursLayout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = 4,
            };
            hoursLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 200));
            hoursLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            for (int i = 0; i < 4; i++) hoursLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));

            _useWorkingHoursCheckBox = new CheckBox { Text = "Only run during working hours", AutoSize = true, Font = new Font("Segoe UI", 9f) };
            hoursLayout.Controls.Add(SpanLabel(""));
            hoursLayout.Controls.Add(_useWorkingHoursCheckBox);

            hoursLayout.Controls.Add(MakeLabel("Start time (HH:MM):"));
            _workingHoursStartTextBox = new TextBox { Width = 80 };
            hoursLayout.Controls.Add(_workingHoursStartTextBox);

            hoursLayout.Controls.Add(MakeLabel("End time (HH:MM):"));
            _workingHoursEndTextBox = new TextBox { Width = 80 };
            hoursLayout.Controls.Add(_workingHoursEndTextBox);

            // Day checkboxes
            hoursLayout.Controls.Add(MakeLabel("Active days:"));
            var daysFlow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, WrapContents = false, AutoSize = true };
            string[] dayNames = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
            string[] dayFull  = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" };
            _dayCheckBoxes = new CheckBox[7];
            for (int i = 0; i < 7; i++)
            {
                var cb = new CheckBox
                {
                    Text = dayNames[i],
                    Tag = dayFull[i],
                    AutoSize = true,
                    Margin = new Padding(0, 2, 4, 0),
                    Font = new Font("Segoe UI", 8.5f)
                };
                _dayCheckBoxes[i] = cb;
                daysFlow.Controls.Add(cb);
            }
            hoursLayout.Controls.Add(daysFlow);

            hoursGroup.Controls.Add(hoursLayout);
            outer.Controls.Add(hoursGroup, 0, 0);
            outer.Controls.Add(new Label(), 0, 1);

            // ── Holidays ──────────────────────────────────────────────────
            var holidaysGroup = new GroupBox
            {
                Text = "Holidays",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                ForeColor = Color.FromArgb(50, 70, 120),
                Padding = new Padding(8, 4, 8, 4)
            };
            var holidaysLayout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = 3,
            };
            holidaysLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 200));
            holidaysLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            for (int i = 0; i < 3; i++) holidaysLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));

            _skipHolidaysCheckBox = new CheckBox { Text = "Skip public holidays", AutoSize = true, Font = new Font("Segoe UI", 9f) };
            holidaysLayout.Controls.Add(SpanLabel(""));
            holidaysLayout.Controls.Add(_skipHolidaysCheckBox);

            holidaysLayout.Controls.Add(MakeLabel("Country code (ISO):"));
            _holidayCountryTextBox = new TextBox { Width = 50, MaxLength = 3 };
            holidaysLayout.Controls.Add(_holidayCountryTextBox);

            var noteLabel = new Label
            {
                Text = "Uses Open Holidays API · examples: NL, DE, GB, US, FR",
                Font = new Font("Segoe UI", 7.5f),
                ForeColor = Color.Gray,
                AutoSize = true,
                Padding = new Padding(0, 2, 0, 0)
            };
            holidaysLayout.Controls.Add(SpanLabel(""));
            holidaysLayout.Controls.Add(noteLabel);

            holidaysGroup.Controls.Add(holidaysLayout);
            outer.Controls.Add(holidaysGroup, 0, 2);

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
            var page = new TabPage("ℹ  About") { BackColor = Color.FromArgb(245, 247, 250) };
            var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };

            int y = 20;

            var iconLabel = new Label { Text = "💤", Font = new Font("Segoe UI", 32f), Location = new Point(20, y), AutoSize = true };
            panel.Controls.Add(iconLabel);

            var nameLabel = new Label
            {
                Text = "WakeyWindows",
                Font = new Font("Segoe UI", 14f, FontStyle.Bold),
                ForeColor = Color.FromArgb(33, 33, 33),
                Location = new Point(78, y + 4),
                AutoSize = true
            };
            panel.Controls.Add(nameLabel);

            _versionLabel = new Label
            {
                Text = $"Version {Application.ProductVersion}",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.Gray,
                Location = new Point(80, y + 32),
                AutoSize = true
            };
            panel.Controls.Add(_versionLabel);
            y += 72;

            var descLabel = new Label
            {
                Text = "Keeps your PC awake and your Teams status online\nusing the same low-level API as video players and presentation software.",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(80, 80, 80),
                Location = new Point(20, y),
                Size = new Size(460, 40),
                AutoSize = false
            };
            panel.Controls.Add(descLabel);
            y += 50;

            // ── System info ───────────────────────────────────────────────
            var separator1 = new Panel { Location = new Point(20, y), Size = new Size(460, 1), BackColor = Color.FromArgb(210, 215, 222) };
            panel.Controls.Add(separator1);
            y += 8;

            string osVersion = Environment.OSVersion.VersionString;
            string runtimeVersion = System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription;
            string configPath = Settings.GetConfigFilePath();

            foreach (var (label, value) in new[] {
                ("OS", osVersion),
                (".NET", runtimeVersion),
                ("Config", configPath)
            })
            {
                var row = new FlowLayoutPanel { Location = new Point(20, y), Size = new Size(480, 18), FlowDirection = FlowDirection.LeftToRight, WrapContents = false };
                row.Controls.Add(new Label { Text = $"{label}:", Font = new Font("Segoe UI", 8f, FontStyle.Bold), ForeColor = Color.Gray, AutoSize = true, Margin = new Padding(0, 1, 4, 0) });
                row.Controls.Add(new Label { Text = value, Font = new Font("Segoe UI", 8f), ForeColor = Color.FromArgb(60, 60, 60), AutoSize = true, Margin = new Padding(0, 1, 0, 0) });
                panel.Controls.Add(row);
                y += 20;
            }

            // ── SHA256 ────────────────────────────────────────────────────
            y += 4;
            var separator2 = new Panel { Location = new Point(20, y), Size = new Size(460, 1), BackColor = Color.FromArgb(210, 215, 222) };
            panel.Controls.Add(separator2);
            y += 10;

            string sha256 = ComputeExeSha256();
            var sha256CaptionLabel = new Label
            {
                Text = "SHA256 (this exe):",
                Font = new Font("Segoe UI", 8f, FontStyle.Bold),
                ForeColor = Color.Gray,
                Location = new Point(20, y),
                AutoSize = true
            };
            panel.Controls.Add(sha256CaptionLabel);
            y += 18;

            var sha256ValueLabel = new Label
            {
                Text = sha256,
                Font = new Font("Consolas", 7.5f),
                ForeColor = Color.FromArgb(50, 50, 80),
                Location = new Point(20, y),
                Size = new Size(460, 16),
                AutoEllipsis = false
            };
            panel.Controls.Add(sha256ValueLabel);
            y += 22;

            var copyHashButton = new Button
            {
                Text = "Copy SHA256",
                Location = new Point(20, y),
                Size = new Size(110, 26),
                FlatStyle = FlatStyle.System
            };
            copyHashButton.Click += (s, e) =>
            {
                if (!string.IsNullOrEmpty(sha256)) Clipboard.SetText(sha256);
            };
            panel.Controls.Add(copyHashButton);

            // ── Links ─────────────────────────────────────────────────────
            y += 36;
            var separator3 = new Panel { Location = new Point(20, y), Size = new Size(460, 1), BackColor = Color.FromArgb(210, 215, 222) };
            panel.Controls.Add(separator3);
            y += 10;

            var githubLink = new LinkLabel
            {
                Text = "github.com/namnamir/WakeyWindows",
                Location = new Point(20, y),
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
                catch { }
            };
            panel.Controls.Add(githubLink);
            y += 28;

            _checkUpdateButton = new Button
            {
                Text = "Check for updates",
                Location = new Point(20, y),
                Size = new Size(150, 30),
                FlatStyle = FlatStyle.System
            };
            _checkUpdateButton.Click += CheckUpdateButton_Click;
            panel.Controls.Add(_checkUpdateButton);

            page.Controls.Add(panel);
            return page;
        }

        private static string ComputeExeSha256()
        {
            try
            {
                using var sha = SHA256.Create();
                using var stream = File.OpenRead(Application.ExecutablePath);
                byte[] hash = sha.ComputeHash(stream);
                return Convert.ToHexString(hash).ToLowerInvariant();
            }
            catch
            {
                return "(unavailable)";
            }
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
            _methodBadgeLabel.Text = $"Mode: {stats.ActiveMethod}";

            // Uptime
            var up = stats.SessionUptime;
            _sessionUptimeLabel.Text = up.TotalHours >= 1
                ? $"{(int)up.TotalHours}h {up.Minutes}m"
                : up.Minutes > 0 ? $"{up.Minutes}m {up.Seconds}s" : $"{up.Seconds}s";
            _keepAliveCountLabel.Text = stats.KeepAliveCount.ToString();

            // Countdown
            if (stats.TimeUntilNext.HasValue && stats.IsEnabled && stats.CurrentIntervalSeconds > 0)
            {
                var t = stats.TimeUntilNext.Value;
                _countdownLabel.Text = t.TotalSeconds >= 60
                    ? $"{(int)t.TotalMinutes}m {t.Seconds:D2}s"
                    : $"{(int)t.TotalSeconds}s";

                _intervalLabel.Text = $"interval: {stats.CurrentIntervalSeconds}s";

                _nextAtLabel.Text = stats.NextFireAt.HasValue
                    ? $"next at {stats.NextFireAt.Value:HH:mm:ss}"
                    : "";

                double elapsed = stats.CurrentIntervalSeconds - t.TotalSeconds;
                _lastProgressPct = Math.Max(0, Math.Min(1, elapsed / stats.CurrentIntervalSeconds));
            }
            else
            {
                _countdownLabel.Text = stats.IsEnabled ? "—" : "off";
                _intervalLabel.Text = stats.IsEnabled ? "" : "disabled";
                _nextAtLabel.Text = "";
                _lastProgressPct = 0;
            }
            RefreshProgressFill();

            // Log (color-coded by level)
            if (stats.RecentLog.Count != _lastLogCount)
            {
                _lastLogCount = stats.RecentLog.Count;
                _logBox.Clear();
                foreach (var entry in stats.RecentLog)
                {
                    Color msgColor = entry.Level switch
                    {
                        LogLevel.Success    => Color.FromArgb(100, 220, 120),
                        LogLevel.Warning    => Color.FromArgb(255, 183, 77),
                        LogLevel.UserActive => Color.FromArgb(100, 181, 246),
                        LogLevel.Disabled   => Color.FromArgb(239, 83, 80),
                        _                   => Color.FromArgb(180, 180, 180)
                    };
                    _logBox.SelectionColor = Color.FromArgb(100, 100, 100);
                    _logBox.AppendText(entry.Time.ToString("HH:mm:ss") + "  ");
                    _logBox.SelectionColor = msgColor;
                    _logBox.AppendText(entry.Icon + "  " + entry.Message + "\n");
                }
                _logBox.SelectionStart = 0;
                _logBox.ScrollToCaret();
            }
        }

        private void RefreshProgressFill()
        {
            if (_progressContainer == null) return;
            int w = (int)(_progressContainer.Width * _lastProgressPct);
            _progressFill.Size = new Size(Math.Max(0, Math.Min(w, _progressContainer.Width)), _progressContainer.Height);
            _progressFill.BackColor = _lastProgressPct < 0.2
                ? Color.FromArgb(244, 81, 30)
                : Color.FromArgb(25, 118, 210);
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS LOAD / SAVE
        // ════════════════════════════════════════════════════════════════════

        private void LoadSettings()
        {
            _enabledCheckBox.Checked = _settings.Enabled;
            _intervalMinNumeric.Value = _settings.IntervalMinSeconds;
            _intervalMaxNumeric.Value = _settings.IntervalMaxSeconds;
            _simulationMethodCombo.SelectedIndex = _settings.SimulationMethod switch
            {
                "key_press" => 1,
                "api_only"  => 2,
                _           => 0
            };
            _keepDisplayOnCheckBox.Checked = _settings.KeepDisplayOn;

            _detectActivityCheckBox.Checked = _settings.DetectUserActivity;
            _activityPauseNumeric.Value = _settings.ActivityPauseSeconds;
            _idleTimeoutNumeric.Value = _settings.IdleTimeoutSeconds;
            _mouseThresholdNumeric.Value = _settings.MouseMovementThreshold;

            _useWorkingHoursCheckBox.Checked = _settings.UseWorkingHours;
            _workingHoursStartTextBox.Text = _settings.WorkingHoursStart;
            _workingHoursEndTextBox.Text = _settings.WorkingHoursEnd;

            foreach (var cb in _dayCheckBoxes)
            {
                string dayFull = (string)cb.Tag!;
                bool found = false;
                foreach (var d in _settings.WorkingDays)
                    if (d.Equals(dayFull, StringComparison.OrdinalIgnoreCase)) { found = true; break; }
                cb.Checked = found;
            }

            _skipHolidaysCheckBox.Checked = _settings.SkipHolidays;
            _holidayCountryTextBox.Text = _settings.HolidayCountryCode;

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
            _settings.SimulationMethod = _simulationMethodCombo.SelectedIndex switch
            {
                1 => "key_press",
                2 => "api_only",
                _ => "mouse_jiggle"
            };
            _settings.KeepDisplayOn = _keepDisplayOnCheckBox.Checked;

            _settings.DetectUserActivity = _detectActivityCheckBox.Checked;
            _settings.ActivityPauseSeconds = (int)_activityPauseNumeric.Value;
            _settings.IdleTimeoutSeconds = (int)_idleTimeoutNumeric.Value;
            _settings.MouseMovementThreshold = (int)_mouseThresholdNumeric.Value;

            _settings.UseWorkingHours = _useWorkingHoursCheckBox.Checked;
            _settings.WorkingHoursStart = _workingHoursStartTextBox.Text;
            _settings.WorkingHoursEnd = _workingHoursEndTextBox.Text;

            var activeDays = new System.Collections.Generic.List<string>();
            foreach (var cb in _dayCheckBoxes)
                if (cb.Checked) activeDays.Add((string)cb.Tag!);
            _settings.WorkingDays = activeDays.ToArray();

            _settings.SkipHolidays = _skipHolidaysCheckBox.Checked;
            _settings.HolidayCountryCode = _holidayCountryTextBox.Text.Trim().ToUpper();

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
            catch { }
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

        private static Panel MakeCard()
        {
            return new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };
        }

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
            new Label { Text = text, ForeColor = Color.Gray, AutoSize = true, Font = new Font("Segoe UI", 8.5f), Margin = new Padding(0, 3, 4, 0) };

        private static Label MakeStatValue(string text) =>
            new Label { Text = text, ForeColor = Color.FromArgb(33, 33, 33), AutoSize = true, Font = new Font("Segoe UI Semibold", 8.5f, FontStyle.Bold), Margin = new Padding(0, 3, 10, 0) };

        private sealed class GradientPanel : Panel
        {
            public GradientPanel() { DoubleBuffered = true; }
            protected override void OnPaintBackground(PaintEventArgs e)
            {
                if (ClientSize.Width <= 0 || ClientSize.Height <= 0) { base.OnPaintBackground(e); return; }
                using var brush = new LinearGradientBrush(ClientRectangle,
                    Color.FromArgb(28, 48, 100), Color.FromArgb(18, 30, 72), LinearGradientMode.Vertical);
                e.Graphics.FillRectangle(brush, ClientRectangle);
                using var pen = new Pen(Color.FromArgb(10, 20, 55), 1);
                e.Graphics.DrawLine(pen, 0, ClientSize.Height - 1, ClientSize.Width, ClientSize.Height - 1);
            }
        }
    }
}
