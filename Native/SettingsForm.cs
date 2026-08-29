using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Security.Cryptography;
using System.Windows.Forms;

namespace PowerManager
{
    public class SettingsForm : Form
    {
        // Clean version without the +commitHash suffix
        private static string AppVersion => Application.ProductVersion.Split('+')[0];

        private readonly Settings _settings;
        private readonly Func<LiveStats> _getStats;
        private readonly System.Windows.Forms.Timer _liveTimer;

        // ── General tab ────────────────────────────────────────────────────
        private CheckBox _enabledCheckBox = null!;
        private NumericUpDown _intervalMinPctNumeric = null!;
        private NumericUpDown _intervalMaxPctNumeric = null!;
        private Label _intervalMinTimeLabel = null!;
        private Label _intervalMaxTimeLabel = null!;
        private Label _sleepTimeoutInfoLabel = null!;
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
        private Button _checkUpdateButton = null!;

        // ── Dashboard controls (live) ──────────────────────────────────────
        private Panel _accentBar = null!;
        private Label _statusIconLabel = null!;
        private Label _statusTextLabel = null!;
        private Label _methodBadgeLabel = null!;
        private Label _scheduleStatusLabel = null!;
        private Label _statusDetailLabel = null!;
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
            Font = new Font(_settings.FontFamily, _settings.FontSizeBase);

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
            Text = $"WakeyWindows  v{AppVersion}";
            MinimumSize = new Size(540, 580);
            Size = new Size(600, 680);
            FormBorderStyle = FormBorderStyle.Sizable;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = true;
            BackColor = Settings.ParseColor(_settings.ColorFormBackground, Color.FromArgb(248, 250, 252));

            // Set Form and Taskbar Icon
            try
            {
                Icon? appIcon = null;
                string localIco = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "app.ico");
                if (File.Exists(localIco)) appIcon = new Icon(localIco);
                this.Icon = appIcon ?? Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;
                this.ShowIcon = true;
            }
            catch
            {
                this.Icon = SystemIcons.Application;
            }

            // ── Modern Flat Header ─────────────────────────────────────────
            var header = new GradientPanel(
                Settings.ParseColor(_settings.ColorHeaderGradientStart, Color.FromArgb(15, 23, 42)),  // Slate 900
                Settings.ParseColor(_settings.ColorHeaderGradientEnd,   Color.FromArgb(30, 41, 59))   // Slate 800
            ) { Dock = DockStyle.Top, Height = 68 };
            header.Controls.Add(new Label
            {
                Text = "⚡  WakeyWindows",
                Font = new Font("Segoe UI", 12.5f, FontStyle.Bold),
                ForeColor = Color.White,
                BackColor = Color.Transparent,
                AutoSize = true,
                Location = new Point(18, 12)
            });
            header.Controls.Add(new Label
            {
                Text = $"System Keep-Alive Manager  ·  v{AppVersion}",
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = Color.FromArgb(148, 163, 184), // Slate 400
                BackColor = Color.Transparent,
                AutoSize = true,
                Location = new Point(20, 38)
            });

            // ── Bottom Button Panel ─────────────────────────────────────────
            var buttonPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 52,
                BackColor = Color.FromArgb(241, 245, 249) // Slate 100
            };
            var saveButton = new Button
            {
                Text = "Save Changes",
                Size = new Size(110, 32),
                FlatStyle = FlatStyle.System,
                Font = new Font("Segoe UI Semibold", 9f, FontStyle.Bold)
            };
            var cancelButton = new Button
            {
                Text = "Cancel",
                Size = new Size(85, 32),
                DialogResult = DialogResult.Cancel,
                FlatStyle = FlatStyle.System
            };
            saveButton.Click += OkButton_Click;
            buttonPanel.Controls.Add(saveButton);
            buttonPanel.Controls.Add(cancelButton);
            buttonPanel.Resize += (s, e) =>
            {
                int y = (buttonPanel.ClientSize.Height - 32) / 2;
                cancelButton.Location = new Point(buttonPanel.ClientSize.Width - 98, y);
                saveButton.Location = new Point(buttonPanel.ClientSize.Width - 216, y);
            };

            // ── Tab Control ────────────────────────────────────────────────
            var tabControl = new TabControl
            {
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9f),
                Padding = new Point(12, 5)
            };
            tabControl.TabPages.Add(BuildDashboardTab());
            tabControl.TabPages.Add(BuildGeneralTab());
            tabControl.TabPages.Add(BuildActivityTab());
            tabControl.TabPages.Add(BuildScheduleTab());
            tabControl.TabPages.Add(BuildDisplayTab());
            tabControl.TabPages.Add(BuildAboutTab());

            Controls.Add(tabControl);
            Controls.Add(buttonPanel);
            Controls.Add(header);

            AcceptButton = saveButton;
            CancelButton = cancelButton;
        }

        // ════════════════════════════════════════════════════════════════════
        // DASHBOARD TAB (MODERN MERGED LAYOUT)
        // ════════════════════════════════════════════════════════════════════

        private TabPage BuildDashboardTab()
        {
            var bg = Settings.ParseColor(_settings.ColorFormBackground, Color.FromArgb(248, 250, 252));
            var page = new TabPage("🖥  Dashboard") { BackColor = bg };

            var layout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 5,
                Padding = new Padding(12, 10, 12, 10),
                BackColor = bg
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // 0: Merged Status & Schedule Hero Card
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 8));  // 1: spacer
            layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // 2: Countdown Card
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 8));  // 3: spacer
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); // 4: Expanded Activity Log (fills majority)

            layout.Controls.Add(BuildHeroStatusCard(), 0, 0);
            layout.Controls.Add(new Label(), 0, 1);
            layout.Controls.Add(BuildCountdownCard(), 0, 2);
            layout.Controls.Add(new Label(), 0, 3);
            layout.Controls.Add(BuildLogCard(), 0, 4);

            page.Controls.Add(layout);
            return page;
        }

        private Panel BuildHeroStatusCard()
        {
            var card = MakeCard();

            _accentBar = new Panel { Width = 5, Dock = DockStyle.Left, BackColor = Settings.ParseColor(_settings.ColorAccentActive, Color.FromArgb(16, 185, 129)) };
            card.Controls.Add(_accentBar);

            var content = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = 1,
                Padding = new Padding(12, 10, 12, 10),
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink
            };
            content.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            content.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            content.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            // Left: Status Headline & Dynamic Badges
            var leftFlow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                Dock = DockStyle.Fill,
                Margin = new Padding(0)
            };

            var titleFlow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                AutoSize = true,
                Margin = new Padding(0, 0, 0, 4)
            };
            _statusIconLabel = new Label
            {
                Text = "🟢",
                Font = new Font("Segoe UI", 16f),
                AutoSize = true,
                Margin = new Padding(0, 0, 6, 0)
            };
            _statusTextLabel = new Label
            {
                Text = "Active — keeping awake",
                Font = new Font("Segoe UI Semibold", 11.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42),
                AutoSize = true,
                Margin = new Padding(0, 2, 0, 0)
            };
            titleFlow.Controls.Add(_statusIconLabel);
            titleFlow.Controls.Add(_statusTextLabel);
            leftFlow.Controls.Add(titleFlow);

            var badgesFlow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = true,
                AutoSize = true,
                Margin = new Padding(0)
            };

            _methodBadgeLabel = new Label
            {
                Text = "Mode: Mouse jiggle",
                Font = new Font("Segoe UI Semibold", 8f),
                ForeColor = Color.FromArgb(71, 85, 105),
                BackColor = Color.FromArgb(241, 245, 249),
                AutoSize = true,
                Padding = new Padding(6, 3, 6, 3),
                Margin = new Padding(0, 0, 6, 3)
            };
            _scheduleStatusLabel = new Label
            {
                Text = "Schedule: All day",
                Font = new Font("Segoe UI Semibold", 8f),
                ForeColor = Color.FromArgb(71, 85, 105),
                BackColor = Color.FromArgb(241, 245, 249),
                AutoSize = true,
                Padding = new Padding(6, 3, 6, 3),
                Margin = new Padding(0, 0, 6, 3)
            };
            _statusDetailLabel = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 8f),
                ForeColor = Color.FromArgb(2, 132, 199),
                AutoSize = true,
                Margin = new Padding(0, 4, 0, 0),
                Visible = false
            };
            badgesFlow.Controls.Add(_methodBadgeLabel);
            badgesFlow.Controls.Add(_scheduleStatusLabel);
            badgesFlow.Controls.Add(_statusDetailLabel);
            leftFlow.Controls.Add(badgesFlow);
            content.Controls.Add(leftFlow, 0, 0);

            // Right: Clean Session Metrics
            var statsBox = new Panel
            {
                AutoSize = true,
                Dock = DockStyle.Right,
                Padding = new Padding(10, 2, 4, 2),
                Margin = new Padding(0)
            };
            var statsFlow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                Dock = DockStyle.Fill
            };
            var uptimeRow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, AutoSize = true, Margin = new Padding(0, 0, 0, 2) };
            uptimeRow.Controls.Add(MakeStatCaption("Session:"));
            _sessionUptimeLabel = MakeStatValue("0s");
            uptimeRow.Controls.Add(_sessionUptimeLabel);

            var countRow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, AutoSize = true, Margin = new Padding(0) };
            countRow.Controls.Add(MakeStatCaption("Keep-alives:"));
            _keepAliveCountLabel = MakeStatValue("0");
            countRow.Controls.Add(_keepAliveCountLabel);

            statsFlow.Controls.Add(uptimeRow);
            statsFlow.Controls.Add(countRow);
            statsBox.Controls.Add(statsFlow);
            content.Controls.Add(statsBox, 1, 0);

            card.Controls.Add(content);
            return card;
        }

        private Panel BuildCountdownCard()
        {
            var card = MakeCard();

            var content = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = 2,
                Padding = new Padding(12, 8, 12, 8),
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink
            };
            content.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            content.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            content.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            content.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            _countdownLabel = new Label
            {
                Text = "—",
                Font = new Font("Segoe UI", 16f, FontStyle.Bold),
                ForeColor = Settings.ParseColor(_settings.ColorCountdown, Color.FromArgb(2, 132, 199)),
                AutoSize = true,
                Margin = new Padding(0, 0, 12, 0),
                Anchor = AnchorStyles.Left | AnchorStyles.Top
            };
            content.Controls.Add(_countdownLabel, 0, 0);
            content.SetRowSpan(_countdownLabel, 2);

            _progressContainer = new Panel
            {
                Dock = DockStyle.Fill,
                Height = 8,
                BackColor = Color.FromArgb(226, 232, 240), // Slate 200
                Margin = new Padding(0, 6, 0, 4)
            };
            _progressFill = new Panel
            {
                Location = new Point(0, 0),
                Height = 8,
                BackColor = Settings.ParseColor(_settings.ColorProgressBar, Color.FromArgb(2, 132, 199))
            };
            _progressContainer.Controls.Add(_progressFill);
            _progressContainer.Resize += (s, e) => RefreshProgressFill();
            content.Controls.Add(_progressContainer, 1, 0);

            var metaFlow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                AutoSize = true,
                Dock = DockStyle.Fill,
                Margin = new Padding(0)
            };
            _nextAtLabel = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 8f),
                ForeColor = Color.FromArgb(100, 116, 139),
                AutoSize = true,
                Margin = new Padding(0, 0, 8, 0)
            };
            _intervalLabel = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 8f),
                ForeColor = Color.FromArgb(100, 116, 139),
                AutoSize = true,
                Margin = new Padding(0)
            };
            metaFlow.Controls.Add(_nextAtLabel);
            metaFlow.Controls.Add(_intervalLabel);
            content.Controls.Add(metaFlow, 1, 1);

            card.Controls.Add(content);
            return card;
        }

        private Panel BuildLogCard()
        {
            var card = MakeCard();
            var layout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 1,
                RowCount = 2,
                Padding = new Padding(10, 8, 10, 8)
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));  // Header & toolbar
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));  // Rich log box

            var headerPanel = new Panel { Dock = DockStyle.Fill };
            var titleLabel = new Label
            {
                Text = "📋  Activity Log",
                Font = new Font("Segoe UI Semibold", 9.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(51, 65, 85),
                AutoSize = true,
                Location = new Point(0, 4)
            };
            var copyBtn = new Button
            {
                Text = "Copy",
                Size = new Size(56, 22),
                FlatStyle = FlatStyle.System,
                Font = new Font("Segoe UI", 7.5f)
            };
            copyBtn.Click += (s, e) =>
            {
                if (!string.IsNullOrEmpty(_logBox.Text))
                {
                    try { Clipboard.SetText(_logBox.Text); } catch { }
                }
            };
            var clearBtn = new Button
            {
                Text = "Clear",
                Size = new Size(56, 22),
                FlatStyle = FlatStyle.System,
                Font = new Font("Segoe UI", 7.5f)
            };
            clearBtn.Click += (s, e) => _logBox.Clear();

            headerPanel.Controls.Add(titleLabel);
            headerPanel.Controls.Add(copyBtn);
            headerPanel.Controls.Add(clearBtn);
            headerPanel.Resize += (s, e) =>
            {
                clearBtn.Location = new Point(headerPanel.ClientSize.Width - 58, 2);
                copyBtn.Location = new Point(headerPanel.ClientSize.Width - 120, 2);
            };

            _logBox = new RichTextBox
            {
                Dock = DockStyle.Fill,
                ReadOnly = true,
                BorderStyle = BorderStyle.None,
                BackColor = Color.FromArgb(24, 24, 27),    // Dark Zinc
                ForeColor = Color.FromArgb(228, 228, 231),
                Font = new Font("Consolas", 8.5f),
                ScrollBars = RichTextBoxScrollBars.Vertical,
                WordWrap = false,
                DetectUrls = false
            };

            layout.Controls.Add(headerPanel, 0, 0);
            layout.Controls.Add(_logBox, 0, 1);
            card.Controls.Add(layout);
            return card;
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS TABS — all use AutoSize rows so content drives height
        // ════════════════════════════════════════════════════════════════════

        private TabPage BuildGeneralTab()
        {
            var page = new TabPage("⚙  General");
            var layout = MakeTable(page, 7);

            AddHeader(layout, "Keep-Alive");

            _enabledCheckBox = new CheckBox { Text = "Enabled", AutoSize = true };
            layout.Controls.Add(SpanLabel(""));
            layout.Controls.Add(_enabledCheckBox);

            // Sleep timeout info row (read-only)
            _sleepTimeoutInfoLabel = new Label
            {
                Text = "reading…",
                ForeColor = Color.FromArgb(80, 100, 140),
                AutoSize = true,
                Anchor = AnchorStyles.Left | AnchorStyles.Top,
                Padding = new Padding(0, 5, 0, 0)
            };
            layout.Controls.Add(MakeLabel("Sleep timeout:"));
            layout.Controls.Add(_sleepTimeoutInfoLabel);

            // Min % row
            var minFlow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, WrapContents = false, AutoSize = true };
            _intervalMinPctNumeric = new NumericUpDown { Minimum = 10, Maximum = 95, Value = 60, Width = 55 };
            _intervalMinPctNumeric.ValueChanged += (s, e) => RefreshIntervalControls();
            _intervalMinTimeLabel = new Label { Text = "→ —", ForeColor = Color.Gray, AutoSize = true, Margin = new Padding(4, 5, 0, 0) };
            minFlow.Controls.Add(_intervalMinPctNumeric);
            minFlow.Controls.Add(new Label { Text = "%", AutoSize = true, Margin = new Padding(2, 5, 8, 0) });
            minFlow.Controls.Add(_intervalMinTimeLabel);
            layout.Controls.Add(MakeLabel("Min interval (%):"));
            layout.Controls.Add(minFlow);

            // Max % row
            var maxFlow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, WrapContents = false, AutoSize = true };
            _intervalMaxPctNumeric = new NumericUpDown { Minimum = 15, Maximum = 98, Value = 80, Width = 55 };
            _intervalMaxPctNumeric.ValueChanged += (s, e) => RefreshIntervalControls();
            _intervalMaxTimeLabel = new Label { Text = "→ —", ForeColor = Color.Gray, AutoSize = true, Margin = new Padding(4, 5, 0, 0) };
            maxFlow.Controls.Add(_intervalMaxPctNumeric);
            maxFlow.Controls.Add(new Label { Text = "%", AutoSize = true, Margin = new Padding(2, 5, 8, 0) });
            maxFlow.Controls.Add(_intervalMaxTimeLabel);
            layout.Controls.Add(MakeLabel("Max interval (%):"));
            layout.Controls.Add(maxFlow);

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
            var layout = MakeTable(page, 5);

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

            // Outer scroll panel so content is accessible at any form size
            var scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true, Padding = new Padding(14, 12, 14, 12) };

            // ── Working Hours group ────────────────────────────────────────
            var hoursGroup = new GroupBox
            {
                Text = "Working Hours",
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Dock = DockStyle.Top,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                ForeColor = Color.FromArgb(50, 70, 120),
                Padding = new Padding(10, 6, 10, 10)
            };
            var hoursLayout = MakeGroupTable(4);

            _useWorkingHoursCheckBox = new CheckBox { Text = "Only run during working hours", AutoSize = true, Font = new Font("Segoe UI", 9f) };
            hoursLayout.Controls.Add(SpanLabel(""));
            hoursLayout.Controls.Add(_useWorkingHoursCheckBox);

            hoursLayout.Controls.Add(MakeLabel("Start time (HH:MM):"));
            _workingHoursStartTextBox = new TextBox { Width = 80 };
            hoursLayout.Controls.Add(_workingHoursStartTextBox);

            hoursLayout.Controls.Add(MakeLabel("End time (HH:MM):"));
            _workingHoursEndTextBox = new TextBox { Width = 80 };
            hoursLayout.Controls.Add(_workingHoursEndTextBox);

            hoursLayout.Controls.Add(MakeLabel("Active days:"));
            var daysFlow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, WrapContents = true, AutoSize = true };
            string[] dayNames = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
            string[] dayFull  = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" };
            _dayCheckBoxes = new CheckBox[7];
            for (int i = 0; i < 7; i++)
            {
                var cb = new CheckBox { Text = dayNames[i], Tag = dayFull[i], AutoSize = true, Margin = new Padding(0, 2, 6, 2), Font = new Font("Segoe UI", 8.5f) };
                _dayCheckBoxes[i] = cb;
                daysFlow.Controls.Add(cb);
            }
            hoursLayout.Controls.Add(daysFlow);
            hoursGroup.Controls.Add(hoursLayout);

            // ── Holidays group ─────────────────────────────────────────────
            var holidaysGroup = new GroupBox
            {
                Text = "Holidays",
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Dock = DockStyle.Top,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                ForeColor = Color.FromArgb(50, 70, 120),
                Padding = new Padding(10, 6, 10, 10),
                Margin = new Padding(0, 10, 0, 0)
            };
            var holidaysLayout = MakeGroupTable(3);

            _skipHolidaysCheckBox = new CheckBox { Text = "Skip public holidays", AutoSize = true, Font = new Font("Segoe UI", 9f) };
            holidaysLayout.Controls.Add(SpanLabel(""));
            holidaysLayout.Controls.Add(_skipHolidaysCheckBox);

            holidaysLayout.Controls.Add(MakeLabel("Country code (ISO):"));
            _holidayCountryTextBox = new TextBox { Width = 50, MaxLength = 3 };
            holidaysLayout.Controls.Add(_holidayCountryTextBox);

            holidaysLayout.Controls.Add(SpanLabel(""));
            holidaysLayout.Controls.Add(new Label
            {
                Text = "Uses Open Holidays API · examples: NL, DE, GB, US, FR",
                Font = new Font("Segoe UI", 7.5f),
                ForeColor = Color.Gray,
                AutoSize = true
            });

            holidaysGroup.Controls.Add(holidaysLayout);

            // Groups stack from bottom up with DockStyle.Top — add in reverse
            scroll.Controls.Add(holidaysGroup);
            scroll.Controls.Add(hoursGroup);
            page.Controls.Add(scroll);
            return page;
        }

        private TabPage BuildDisplayTab()
        {
            var page = new TabPage("🎨  Display");
            var layout = MakeTable(page, 4);

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
            var bgColor = Settings.ParseColor(_settings.ColorFormBackground, Color.FromArgb(245, 247, 250));
            var page = new TabPage("ℹ  About") { BackColor = bgColor };

            var scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true, Padding = new Padding(20, 16, 20, 16), BackColor = bgColor };

            // Single-column TableLayoutPanel — each row auto-sizes to content
            var layout = new TableLayoutPanel
            {
                ColumnCount = 1,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Dock = DockStyle.Top,
                BackColor = bgColor
            };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

            void AddRow(Control c, int bottomMargin = 4)
            {
                c.Margin = new Padding(0, 0, 0, bottomMargin);
                layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                layout.Controls.Add(c);
            }

            void AddSeparator() => AddRow(new Panel { Height = 1, BackColor = Color.FromArgb(210, 215, 222), Dock = DockStyle.Fill }, 10);

            // ── App header ────────────────────────────────────────────────
            var appRow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, WrapContents = false, AutoSize = true };
            appRow.Controls.Add(new Label { Text = "💤", Font = new Font("Segoe UI", 28f), AutoSize = true, Margin = new Padding(0, 0, 10, 0) });
            var appInfo = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true };
            appInfo.Controls.Add(new Label { Text = "WakeyWindows", Font = new Font("Segoe UI", 14f, FontStyle.Bold), ForeColor = Color.FromArgb(33, 33, 33), AutoSize = true });
            appInfo.Controls.Add(new Label { Text = $"Version {AppVersion}", Font = new Font("Segoe UI", 9f), ForeColor = Color.Gray, AutoSize = true });
            appRow.Controls.Add(appInfo);
            AddRow(appRow, 10);

            AddRow(new Label
            {
                Text = "Keeps your PC awake and your Teams status online\nusing the same low-level API as video players and presentation software.",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(80, 80, 80),
                AutoSize = true
            }, 12);

            // ── System info ───────────────────────────────────────────────
            AddSeparator();
            foreach (var (label, value) in new[] {
                ("OS",     Environment.OSVersion.VersionString),
                (".NET",   System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription),
                ("Config", Settings.GetConfigFilePath())
            })
            {
                var row = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, WrapContents = false, AutoSize = true };
                row.Controls.Add(new Label { Text = $"{label}:", Font = new Font("Segoe UI", 8f, FontStyle.Bold), ForeColor = Color.Gray, AutoSize = true, Margin = new Padding(0, 1, 6, 0) });
                row.Controls.Add(new Label { Text = value, Font = new Font("Segoe UI", 8f), ForeColor = Color.FromArgb(60, 60, 60), AutoSize = true, Margin = new Padding(0, 1, 0, 0) });
                AddRow(row, 3);
            }

            // ── SHA256 ────────────────────────────────────────────────────
            AddSeparator();
            AddRow(new Label { Text = "SHA256 (this exe):", Font = new Font("Segoe UI", 8f, FontStyle.Bold), ForeColor = Color.Gray, AutoSize = true }, 3);

            string sha256 = ComputeExeSha256();
            AddRow(new Label { Text = sha256, Font = new Font("Consolas", 7.5f), ForeColor = Color.FromArgb(50, 50, 80), AutoSize = true }, 6);

            var copyBtn = new Button { Text = "Copy SHA256", Size = new Size(110, 26), FlatStyle = FlatStyle.System };
            copyBtn.Click += (s, e) => { if (!string.IsNullOrEmpty(sha256)) Clipboard.SetText(sha256); };
            AddRow(copyBtn, 12);

            // ── Links / update ────────────────────────────────────────────
            AddSeparator();
            var link = new LinkLabel { Text = "github.com/namnamir/WakeyWindows", AutoSize = true, Font = new Font("Segoe UI", 9f) };
            link.LinkClicked += (s, e) =>
            {
                try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo { FileName = "https://github.com/namnamir/WakeyWindows", UseShellExecute = true }); }
                catch { }
            };
            AddRow(link, 8);

            _checkUpdateButton = new Button { Text = "Check for updates", Size = new Size(150, 30), FlatStyle = FlatStyle.System };
            _checkUpdateButton.Click += CheckUpdateButton_Click;
            AddRow(_checkUpdateButton, 0);

            scroll.Controls.Add(layout);
            page.Controls.Add(scroll);
            return page;
        }

        private static string ComputeExeSha256()
        {
            try
            {
                using var sha = SHA256.Create();
                using var stream = File.OpenRead(Application.ExecutablePath);
                return Convert.ToHexString(sha.ComputeHash(stream)).ToLowerInvariant();
            }
            catch { return "(unavailable)"; }
        }

        // ════════════════════════════════════════════════════════════════════
        // LIVE DASHBOARD UPDATE
        // ════════════════════════════════════════════════════════════════════

        private void UpdateDashboard()
        {
            if (_logBox == null) return;

            var stats = _getStats();

            _accentBar.BackColor = stats.StatusColor;
            _statusIconLabel.Text = stats.StatusIcon;
            _statusTextLabel.Text = stats.StatusText;
            _statusTextLabel.ForeColor = stats.StatusColor;
            _methodBadgeLabel.Text = $"Mode: {stats.ActiveMethod}";

            string scheduleLine = string.IsNullOrWhiteSpace(stats.ScheduleRangeLine) || stats.ScheduleRangeLine == "—"
                ? "Schedule: All day"
                : $"Schedule: {stats.ScheduleRangeLine} · {stats.ScheduleStatusLine}";
            _scheduleStatusLabel.Text = scheduleLine;

            if (!string.IsNullOrEmpty(stats.StatusDetailLine))
            {
                _statusDetailLabel.Text = stats.StatusDetailLine;
                _statusDetailLabel.ForeColor = stats.ScheduleStatusColor;
                _statusDetailLabel.Visible = true;
            }
            else
            {
                _statusDetailLabel.Visible = false;
            }

            var up = stats.SessionUptime;
            _sessionUptimeLabel.Text = up.TotalHours >= 1 ? $"{(int)up.TotalHours}h {up.Minutes}m"
                : up.Minutes > 0 ? $"{up.Minutes}m {up.Seconds}s" : $"{up.Seconds}s";
            _keepAliveCountLabel.Text = stats.KeepAliveCount.ToString();

            if (stats.TimeUntilNext.HasValue && stats.IsEnabled && stats.CurrentIntervalSeconds > 0)
            {
                var t = stats.TimeUntilNext.Value;
                _countdownLabel.Text = t.TotalSeconds >= 60
                    ? $"{(int)t.TotalMinutes}m {t.Seconds:D2}s"
                    : $"{(int)t.TotalSeconds}s";
                _intervalLabel.Text = $"interval: {stats.CurrentIntervalSeconds}s{BuildSleepInfo(stats.SleepTimeoutAcSeconds, stats.SleepTimeoutDcSeconds)}";
                _nextAtLabel.Text = stats.NextFireAt.HasValue ? $"next at {stats.NextFireAt.Value:HH:mm:ss}" : "";

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

            if (stats.RecentLog.Count != _lastLogCount)
            {
                _lastLogCount = stats.RecentLog.Count;
                _logBox.Clear();
                foreach (var entry in stats.RecentLog)
                {
                    Color msgColor = entry.Level switch
                    {
                        LogLevel.Success    => Color.FromArgb(52, 211, 153),  // Emerald 400
                        LogLevel.Warning    => Color.FromArgb(251, 191, 36),  // Amber 400
                        LogLevel.UserActive => Color.FromArgb(56, 189, 248),  // Sky 400
                        LogLevel.Disabled   => Color.FromArgb(248, 113, 113), // Red 400
                        _                   => Color.FromArgb(203, 213, 225)  // Slate 300
                    };
                    _logBox.SelectionColor = Color.FromArgb(100, 116, 139);   // Slate 500
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
            if (_progressContainer == null || _progressContainer.Width <= 0) return;
            int w = (int)(_progressContainer.Width * _lastProgressPct);
            _progressFill.Size = new Size(Math.Max(0, Math.Min(w, _progressContainer.Width)), _progressContainer.Height);
            _progressFill.BackColor = _lastProgressPct < _settings.ProgressUrgentThreshold
                ? Settings.ParseColor(_settings.ColorProgressBarUrgent, Color.FromArgb(239, 68, 68))   // Red 500
                : Settings.ParseColor(_settings.ColorProgressBar,       Color.FromArgb(2, 132, 199));  // Sky 600
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS LOAD / SAVE
        // ════════════════════════════════════════════════════════════════════

        private void LoadSettings()
        {
            _enabledCheckBox.Checked = _settings.Enabled;
            _intervalMinPctNumeric.Value = Math.Max(10, Math.Min(95, _settings.IntervalMinPercent));
            _intervalMaxPctNumeric.Value = Math.Max(15, Math.Min(98, _settings.IntervalMaxPercent));
            RefreshIntervalControls();
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
                string full = (string)cb.Tag!;
                bool found = false;
                foreach (var d in _settings.WorkingDays)
                    if (d.Equals(full, StringComparison.OrdinalIgnoreCase)) { found = true; break; }
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
            if (_intervalMinPctNumeric.Value >= _intervalMaxPctNumeric.Value)
            {
                MessageBox.Show("Min % must be less than Max %.", "Validation",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            _settings.Enabled = _enabledCheckBox.Checked;
            _settings.IntervalMinPercent = (int)_intervalMinPctNumeric.Value;
            _settings.IntervalMaxPercent = (int)_intervalMaxPctNumeric.Value;
            // IntervalMinSeconds / MaxSeconds are recomputed from % by RecomputeIntervalSeconds() in MainForm
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
                await UpdateChecker.CheckForUpdatesAsync(AppVersion, _settings.UpdateCheckUrl);

            _checkUpdateButton.Enabled = true;
            _checkUpdateButton.Text = "Check for updates";

            if (!string.IsNullOrEmpty(error))
            {
                MessageBox.Show($"Could not check for updates:\n{error}", "Update Check", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            MessageBox.Show(
                hasUpdate && latestVersion != null
                    ? $"A newer version is available!\n\nCurrent: {AppVersion}\nLatest:   {latestVersion}"
                    : "You are running the latest version. ✅",
                "Update Check", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        // ════════════════════════════════════════════════════════════════════
        // HELPERS & FLAT CONTROLS
        // ════════════════════════════════════════════════════════════════════

        private sealed class FlatCardPanel : Panel
        {
            public FlatCardPanel()
            {
                DoubleBuffered = true;
                BackColor = Color.White;
                Padding = new Padding(0);
            }

            protected override void OnPaint(PaintEventArgs e)
            {
                base.OnPaint(e);
                using var pen = new Pen(Color.FromArgb(226, 232, 240), 1); // Slate 200 soft border
                e.Graphics.DrawRectangle(pen, 0, 0, Width - 1, Height - 1);
            }
        }

        private static Panel MakeCard() => new FlatCardPanel
        {
            Dock = DockStyle.Fill
        };

        // Table for settings tabs — AutoSize rows so content is never clipped
        private static TableLayoutPanel MakeTable(TabPage page, int rows)
        {
            var table = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = rows,
                Padding = new Padding(14, 12, 14, 12),
                AutoScroll = true
            };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 200));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            for (int i = 0; i < rows; i++)
                table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            page.Controls.Add(table);
            return table;
        }

        // Table for use inside GroupBox controls
        private static TableLayoutPanel MakeGroupTable(int rows)
        {
            var table = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = rows,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink
            };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 185));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            for (int i = 0; i < rows; i++)
                table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
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

        private static Label MakeSectionHeader(string text) => new Label
        {
            Text = text,
            Font = new Font("Segoe UI Semibold", 9f, FontStyle.Bold),
            ForeColor = Color.FromArgb(70, 80, 100),
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.BottomLeft,
            Padding = new Padding(0, 0, 0, 2)
        };

        private static Label MakeLabel(string text) =>
            new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left | AnchorStyles.Top, Padding = new Padding(0, 6, 0, 0) };

        private static Label SpanLabel(string text) => new Label { Text = text, AutoSize = true };

        private static Label MakeStatCaption(string text) =>
            new Label { Text = text, ForeColor = Color.Gray, AutoSize = true, Font = new Font("Segoe UI", 8.5f), Margin = new Padding(0, 3, 4, 0) };

        private static Label MakeStatValue(string text) =>
            new Label { Text = text, ForeColor = Color.FromArgb(33, 33, 33), AutoSize = true, Font = new Font("Segoe UI Semibold", 8.5f, FontStyle.Bold), Margin = new Padding(0, 3, 10, 0) };

        // Reads current sleep timeouts and refreshes the sleep-timeout info label
        // and the computed-time labels next to the percentage spinners.
        private void RefreshIntervalControls()
        {
            var (ac, dc) = ActivityDetector.GetSleepTimeouts();

            int baseSeconds;
            string baseLabel;
            if      (ac > 0 && dc > 0) { baseSeconds = Math.Min(ac, dc); baseLabel = $"→  base {FormatSec(baseSeconds)}"; }
            else if (ac > 0)            { baseSeconds = ac;               baseLabel = $"→  base {FormatSec(ac)} (AC)"; }
            else if (dc > 0)            { baseSeconds = dc;               baseLabel = $"→  base {FormatSec(dc)} (DC)"; }
            else if (ac == 0 && dc == 0){ baseSeconds = 300;              baseLabel = "→  using 5m base (never sleep)"; }
            else                        { baseSeconds = 300;              baseLabel = "→  using 5m base (unavailable)"; }

            string FormatT(int t) => t < 0 ? "—" : t == 0 ? "never" : FormatSec(t);
            string acPart = ac >= 0 ? $"AC: {FormatT(ac)}" : "";
            string dcPart = dc >= 0 ? $"DC: {FormatT(dc)}" : "";
            string combined = (acPart.Length > 0 && dcPart.Length > 0) ? $"{acPart}  ·  {dcPart}"
                            : acPart.Length > 0 ? acPart : dcPart.Length > 0 ? dcPart : "—";
            _sleepTimeoutInfoLabel.Text = $"{combined}   {baseLabel}";

            int minS = Math.Max(10, (int)Math.Round(baseSeconds * (double)_intervalMinPctNumeric.Value / 100));
            int maxS = Math.Max(minS + 1, (int)Math.Round(baseSeconds * (double)_intervalMaxPctNumeric.Value / 100));
            _intervalMinTimeLabel.Text = $"→ {FormatSec(minS)}";
            _intervalMaxTimeLabel.Text = $"→ {FormatSec(maxS)}";
        }

        private static string BuildSleepInfo(int ac, int dc)
        {
            if (ac < 0 && dc < 0) return "";
            string FormatT(int t) => t < 0 ? "—" : t == 0 ? "never" : FormatSec(t);
            string acPart = ac >= 0 ? $"AC {FormatT(ac)}" : "";
            string dcPart = dc >= 0 ? $"DC {FormatT(dc)}" : "";
            string combined = (acPart.Length > 0 && dcPart.Length > 0) ? $"{acPart} · {dcPart}"
                            : acPart.Length > 0 ? acPart : dcPart;
            return $"  ·  sleep: {combined}";
        }

        private static string FormatSec(int s) =>
            s >= 60 ? $"{s / 60}m{(s % 60 > 0 ? $" {s % 60}s" : "")}" : $"{s}s";

        private sealed class GradientPanel : Panel
        {
            private readonly Color _start;
            private readonly Color _end;

            public GradientPanel(Color start, Color end)
            {
                DoubleBuffered = true;
                _start = start;
                _end = end;
            }

            protected override void OnPaintBackground(PaintEventArgs e)
            {
                if (ClientSize.Width <= 0 || ClientSize.Height <= 0) { base.OnPaintBackground(e); return; }
                using var brush = new LinearGradientBrush(ClientRectangle, _start, _end, LinearGradientMode.Vertical);
                e.Graphics.FillRectangle(brush, ClientRectangle);
                using var pen = new Pen(Color.FromArgb(Math.Max(0, _end.R - 10), Math.Max(0, _end.G - 10), Math.Max(0, _end.B - 10)), 1);
                e.Graphics.DrawLine(pen, 0, ClientSize.Height - 1, ClientSize.Width, ClientSize.Height - 1);
            }
        }
    }
}
