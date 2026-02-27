using System;
using System.Drawing;
using System.Windows.Forms;

namespace PowerManager
{
    public class SettingsForm : Form
    {
        private readonly Settings _settings;
        
        // Controls
        private TabControl _tabControl = null!;

        private CheckBox _enabledCheckBox = null!;
        private NumericUpDown _intervalMinNumeric = null!;
        private NumericUpDown _intervalMaxNumeric = null!;

        private CheckBox _detectActivityCheckBox = null!;
        private NumericUpDown _activityPauseNumeric = null!;
        private NumericUpDown _idleTimeoutNumeric = null!;
        private NumericUpDown _mouseThresholdNumeric = null!;

        private CheckBox _keepDisplayOnCheckBox = null!;
        private CheckBox _useWorkingHoursCheckBox = null!;
        private TextBox _workingHoursStartTextBox = null!;
        private TextBox _workingHoursEndTextBox = null!;
        private CheckBox _showTrayIconCheckBox = null!;
        private CheckBox _showBalloonTipsCheckBox = null!;

        private Label _versionLabel = null!;
        private Button _checkUpdateButton = null!;

        private Button _okButton = null!;
        private Button _cancelButton = null!;

        public SettingsForm(Settings settings)
        {
            _settings = settings;
            InitializeComponent();
            LoadSettings();
        }

        private void InitializeComponent()
        {
            this.Text = "Settings";
            this.Size = new Size(520, 400);
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.ShowInTaskbar = true;
            
            _tabControl = new TabControl
            {
                Dock = DockStyle.Top,
                Height = this.ClientSize.Height - 80
            };
            this.Controls.Add(_tabControl);

            int leftMargin = 20;
            int labelWidth = 190;
            int controlLeft = leftMargin + labelWidth + 10;

            // === General tab ===
            var generalPage = new TabPage("General");
            var generalPanel = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
            generalPage.Controls.Add(generalPanel);
            _tabControl.TabPages.Add(generalPage);

            int y = 15;

            var generalLabel = new Label
            {
                Text = "General Settings",
                Location = new Point(leftMargin, y),
                Size = new Size(300, 20),
                Font = new Font(this.Font, FontStyle.Bold)
            };
            generalPanel.Controls.Add(generalLabel);
            y += 25;

            _enabledCheckBox = new CheckBox
            {
                Text = "Enabled",
                Location = new Point(leftMargin, y),
                Size = new Size(200, 20)
            };
            generalPanel.Controls.Add(_enabledCheckBox);
            y += 25;

            var intervalMinLabel = new Label
            {
                Text = "Min interval (seconds):",
                Location = new Point(leftMargin, y + 3),
                Size = new Size(labelWidth, 20)
            };
            generalPanel.Controls.Add(intervalMinLabel);
            _intervalMinNumeric = new NumericUpDown
            {
                Location = new Point(controlLeft, y),
                Size = new Size(80, 25),
                Minimum = 10,
                Maximum = 600,
                Value = 60
            };
            generalPanel.Controls.Add(_intervalMinNumeric);
            y += 30;

            var intervalMaxLabel = new Label
            {
                Text = "Max interval (seconds):",
                Location = new Point(leftMargin, y + 3),
                Size = new Size(labelWidth, 20)
            };
            generalPanel.Controls.Add(intervalMaxLabel);
            _intervalMaxNumeric = new NumericUpDown
            {
                Location = new Point(controlLeft, y),
                Size = new Size(80, 25),
                Minimum = 30,
                Maximum = 900,
                Value = 120
            };
            generalPanel.Controls.Add(_intervalMaxNumeric);
            y += 30;

            _keepDisplayOnCheckBox = new CheckBox
            {
                Text = "Keep display on",
                Location = new Point(leftMargin, y),
                Size = new Size(200, 20)
            };
            generalPanel.Controls.Add(_keepDisplayOnCheckBox);

            // === Activity tab ===
            var activityPage = new TabPage("Activity");
            var activityPanel = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
            activityPage.Controls.Add(activityPanel);
            _tabControl.TabPages.Add(activityPage);

            y = 15;
            var activityLabel = new Label
            {
                Text = "Activity Detection",
                Location = new Point(leftMargin, y),
                Size = new Size(300, 20),
                Font = new Font(this.Font, FontStyle.Bold)
            };
            activityPanel.Controls.Add(activityLabel);
            y += 25;

            _detectActivityCheckBox = new CheckBox
            {
                Text = "Detect user activity (pause when working)",
                Location = new Point(leftMargin, y),
                Size = new Size(320, 20)
            };
            activityPanel.Controls.Add(_detectActivityCheckBox);
            y += 25;

            var activityPauseLabel = new Label
            {
                Text = "Pause after activity (sec):",
                Location = new Point(leftMargin, y + 3),
                Size = new Size(labelWidth, 20)
            };
            activityPanel.Controls.Add(activityPauseLabel);
            _activityPauseNumeric = new NumericUpDown
            {
                Location = new Point(controlLeft, y),
                Size = new Size(80, 25),
                Minimum = 10,
                Maximum = 600,
                Value = 120
            };
            activityPanel.Controls.Add(_activityPauseNumeric);
            y += 30;

            var idleTimeoutLabel = new Label
            {
                Text = "Idle timeout (seconds):",
                Location = new Point(leftMargin, y + 3),
                Size = new Size(labelWidth, 20)
            };
            activityPanel.Controls.Add(idleTimeoutLabel);
            _idleTimeoutNumeric = new NumericUpDown
            {
                Location = new Point(controlLeft, y),
                Size = new Size(80, 25),
                Minimum = 5,
                Maximum = 300,
                Value = 30
            };
            activityPanel.Controls.Add(_idleTimeoutNumeric);
            y += 30;

            var mouseThresholdLabel = new Label
            {
                Text = "Mouse threshold (pixels):",
                Location = new Point(leftMargin, y + 3),
                Size = new Size(labelWidth, 20)
            };
            activityPanel.Controls.Add(mouseThresholdLabel);
            _mouseThresholdNumeric = new NumericUpDown
            {
                Location = new Point(controlLeft, y),
                Size = new Size(80, 25),
                Minimum = 1,
                Maximum = 100,
                Value = 10
            };
            activityPanel.Controls.Add(_mouseThresholdNumeric);

            // === Schedule tab ===
            var schedulePage = new TabPage("Schedule");
            var schedulePanel = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
            schedulePage.Controls.Add(schedulePanel);
            _tabControl.TabPages.Add(schedulePage);

            y = 15;
            var workingHoursLabel = new Label
            {
                Text = "Working Hours (Optional)",
                Location = new Point(leftMargin, y),
                Size = new Size(320, 20),
                Font = new Font(this.Font, FontStyle.Bold)
            };
            schedulePanel.Controls.Add(workingHoursLabel);
            y += 25;

            _useWorkingHoursCheckBox = new CheckBox
            {
                Text = "Only run during working hours",
                Location = new Point(leftMargin, y),
                Size = new Size(280, 20)
            };
            schedulePanel.Controls.Add(_useWorkingHoursCheckBox);
            y += 25;

            var startLabel = new Label
            {
                Text = "Start time (HH:MM):",
                Location = new Point(leftMargin, y + 3),
                Size = new Size(labelWidth, 20)
            };
            schedulePanel.Controls.Add(startLabel);
            _workingHoursStartTextBox = new TextBox
            {
                Location = new Point(controlLeft, y),
                Size = new Size(80, 25)
            };
            schedulePanel.Controls.Add(_workingHoursStartTextBox);
            y += 30;

            var endLabel = new Label
            {
                Text = "End time (HH:MM):",
                Location = new Point(leftMargin, y + 3),
                Size = new Size(labelWidth, 20)
            };
            schedulePanel.Controls.Add(endLabel);
            _workingHoursEndTextBox = new TextBox
            {
                Location = new Point(controlLeft, y),
                Size = new Size(80, 25)
            };
            schedulePanel.Controls.Add(_workingHoursEndTextBox);

            // === Display tab ===
            var displayPage = new TabPage("Display");
            var displayPanel = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
            displayPage.Controls.Add(displayPanel);
            _tabControl.TabPages.Add(displayPage);

            y = 15;
            var displayLabel = new Label
            {
                Text = "Display Settings",
                Location = new Point(leftMargin, y),
                Size = new Size(280, 20),
                Font = new Font(this.Font, FontStyle.Bold)
            };
            displayPanel.Controls.Add(displayLabel);
            y += 25;

            _showTrayIconCheckBox = new CheckBox
            {
                Text = "Show tray icon",
                Location = new Point(leftMargin, y),
                Size = new Size(220, 20)
            };
            displayPanel.Controls.Add(_showTrayIconCheckBox);
            y += 25;

            _showBalloonTipsCheckBox = new CheckBox
            {
                Text = "Show balloon notifications",
                Location = new Point(leftMargin, y),
                Size = new Size(260, 20)
            };
            displayPanel.Controls.Add(_showBalloonTipsCheckBox);

            // === About tab ===
            var aboutPage = new TabPage("About");
            var aboutPanel = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
            aboutPage.Controls.Add(aboutPanel);
            _tabControl.TabPages.Add(aboutPage);

            y = 20;
            _versionLabel = new Label
            {
                Text = $"Current version: {Application.ProductVersion}",
                Location = new Point(leftMargin, y),
                Size = new Size(360, 20)
            };
            aboutPanel.Controls.Add(_versionLabel);
            y += 35;

            _checkUpdateButton = new Button
            {
                Text = "Check for updates",
                Location = new Point(leftMargin, y),
                Size = new Size(150, 30)
            };
            _checkUpdateButton.Click += CheckUpdateButton_Click;
            aboutPanel.Controls.Add(_checkUpdateButton);

            // === Buttons ===
            _okButton = new Button
            {
                Text = "OK",
                Anchor = AnchorStyles.Bottom | AnchorStyles.Right,
                Location = new Point(this.ClientSize.Width - 190, this.ClientSize.Height - 60),
                Size = new Size(80, 30),
                DialogResult = DialogResult.OK
            };
            _okButton.Click += OkButton_Click;
            this.Controls.Add(_okButton);

            _cancelButton = new Button
            {
                Text = "Cancel",
                Anchor = AnchorStyles.Bottom | AnchorStyles.Right,
                Location = new Point(this.ClientSize.Width - 100, this.ClientSize.Height - 60),
                Size = new Size(80, 30),
                DialogResult = DialogResult.Cancel
            };
            this.Controls.Add(_cancelButton);

            this.AcceptButton = _okButton;
            this.CancelButton = _cancelButton;
        }

        private void LoadSettings()
        {
            _enabledCheckBox.Checked = _settings.Enabled;
            _intervalMinNumeric.Value = _settings.IntervalMinSeconds;
            _intervalMaxNumeric.Value = _settings.IntervalMaxSeconds;
            _detectActivityCheckBox.Checked = _settings.DetectUserActivity;
            _activityPauseNumeric.Value = _settings.ActivityPauseSeconds;
            _idleTimeoutNumeric.Value = _settings.IdleTimeoutSeconds;
            _mouseThresholdNumeric.Value = _settings.MouseMovementThreshold;
            _keepDisplayOnCheckBox.Checked = _settings.KeepDisplayOn;
            _useWorkingHoursCheckBox.Checked = _settings.UseWorkingHours;
            _workingHoursStartTextBox.Text = _settings.WorkingHoursStart;
            _workingHoursEndTextBox.Text = _settings.WorkingHoursEnd;
            _showTrayIconCheckBox.Checked = _settings.ShowTrayIcon;
            _showBalloonTipsCheckBox.Checked = _settings.ShowBalloonTips;
        }

        private void OkButton_Click(object? sender, EventArgs e)
        {
            // Validate
            if (_intervalMinNumeric.Value >= _intervalMaxNumeric.Value)
            {
                MessageBox.Show("Min interval must be less than max interval.", "Validation Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // Save settings
            _settings.Enabled = _enabledCheckBox.Checked;
            _settings.IntervalMinSeconds = (int)_intervalMinNumeric.Value;
            _settings.IntervalMaxSeconds = (int)_intervalMaxNumeric.Value;
            _settings.DetectUserActivity = _detectActivityCheckBox.Checked;
            _settings.ActivityPauseSeconds = (int)_activityPauseNumeric.Value;
            _settings.IdleTimeoutSeconds = (int)_idleTimeoutNumeric.Value;
            _settings.MouseMovementThreshold = (int)_mouseThresholdNumeric.Value;
            _settings.KeepDisplayOn = _keepDisplayOnCheckBox.Checked;
            _settings.UseWorkingHours = _useWorkingHoursCheckBox.Checked;
            _settings.WorkingHoursStart = _workingHoursStartTextBox.Text;
            _settings.WorkingHoursEnd = _workingHoursEndTextBox.Text;
            _settings.ShowTrayIcon = _showTrayIconCheckBox.Checked;
            _settings.ShowBalloonTips = _showBalloonTipsCheckBox.Checked;

            // Persist to disk immediately
            _settings.Save();

            this.DialogResult = DialogResult.OK;
            this.Close();
        }

        private async void CheckUpdateButton_Click(object? sender, EventArgs e)
        {
            string currentVersion = Application.ProductVersion;
            var (hasUpdate, latestVersion, error) =
                await UpdateChecker.CheckForUpdatesAsync(currentVersion, _settings.UpdateCheckUrl);

            if (!string.IsNullOrEmpty(error))
            {
                MessageBox.Show(
                    $"Could not check for updates:\n{error}",
                    "Update Check",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
                return;
            }

            if (hasUpdate && latestVersion != null)
            {
                MessageBox.Show(
                    $"A newer version is available.\n\nCurrent: {currentVersion}\nLatest: {latestVersion}",
                    "Update Available",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
            else
            {
                MessageBox.Show(
                    "You are running the latest version.",
                    "Update Check",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
        }
    }
}
