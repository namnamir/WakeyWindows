using System;
using System.Drawing;
using System.Windows.Forms;

namespace PowerManager
{
    public class SettingsForm : Form
    {
        private readonly Settings _settings;

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

        private Label _versionLabel = null!;
        private Button _checkUpdateButton = null!;

        public SettingsForm(Settings settings)
        {
            _settings = settings;
            Font = new Font("Segoe UI", 9f);
            InitializeComponent();
            LoadSettings();
        }

        private void InitializeComponent()
        {
            Text = "Settings";
            Size = new Size(480, 420);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = true;
            BackColor = Color.White;

            var tabControl = new TabControl { Dock = DockStyle.Fill };
            Controls.Add(tabControl);

            tabControl.TabPages.Add(BuildGeneralTab());
            tabControl.TabPages.Add(BuildActivityTab());
            tabControl.TabPages.Add(BuildScheduleTab());
            tabControl.TabPages.Add(BuildDisplayTab());
            tabControl.TabPages.Add(BuildAboutTab());

            // Button panel pinned to bottom
            var buttonPanel = new FlowLayoutPanel
            {
                Dock = DockStyle.Bottom,
                FlowDirection = FlowDirection.RightToLeft,
                Height = 44,
                Padding = new Padding(6, 6, 6, 6),
                BackColor = Color.FromArgb(245, 245, 245)
            };

            var cancelButton = new Button
            {
                Text = "Cancel",
                Size = new Size(80, 28),
                DialogResult = DialogResult.Cancel,
                Margin = new Padding(4, 0, 0, 0)
            };

            var okButton = new Button
            {
                Text = "OK",
                Size = new Size(80, 28),
                Margin = new Padding(4, 0, 0, 0)
            };
            okButton.Click += OkButton_Click;

            buttonPanel.Controls.Add(cancelButton);
            buttonPanel.Controls.Add(okButton);
            Controls.Add(buttonPanel);

            // Resize tab to leave room for button panel
            tabControl.Height = ClientSize.Height - buttonPanel.Height;

            AcceptButton = okButton;
            CancelButton = cancelButton;
        }

        private TabPage BuildGeneralTab()
        {
            var page = new TabPage("General");
            var layout = MakeTable(5);
            page.Controls.Add(layout);

            AddHeader(layout, "Keep-Alive");

            _enabledCheckBox = new CheckBox { Text = "Enabled", AutoSize = true };
            layout.Controls.Add(new Label());
            layout.Controls.Add(_enabledCheckBox);

            layout.Controls.Add(MakeLabel("Min interval (seconds):"));
            _intervalMinNumeric = new NumericUpDown { Minimum = 10, Maximum = 600, Value = 60, Width = 80 };
            layout.Controls.Add(_intervalMinNumeric);

            layout.Controls.Add(MakeLabel("Max interval (seconds):"));
            _intervalMaxNumeric = new NumericUpDown { Minimum = 30, Maximum = 900, Value = 120, Width = 80 };
            layout.Controls.Add(_intervalMaxNumeric);

            layout.Controls.Add(MakeLabel("Simulation method:"));
            _simulationMethodCombo = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 160 };
            _simulationMethodCombo.Items.Add("Mouse jiggle (recommended)");
            _simulationMethodCombo.Items.Add("API only (no input events)");
            layout.Controls.Add(_simulationMethodCombo);

            _keepDisplayOnCheckBox = new CheckBox { Text = "Keep display on", AutoSize = true };
            layout.Controls.Add(new Label());
            layout.Controls.Add(_keepDisplayOnCheckBox);

            return page;
        }

        private TabPage BuildActivityTab()
        {
            var page = new TabPage("Activity");
            var layout = MakeTable(5);
            page.Controls.Add(layout);

            AddHeader(layout, "Activity Detection");

            _detectActivityCheckBox = new CheckBox { Text = "Pause when user is working", AutoSize = true };
            layout.Controls.Add(new Label());
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
            var page = new TabPage("Schedule");
            var layout = MakeTable(4);
            page.Controls.Add(layout);

            AddHeader(layout, "Working Hours (Optional)");

            _useWorkingHoursCheckBox = new CheckBox { Text = "Only run during working hours", AutoSize = true };
            layout.Controls.Add(new Label());
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
            var page = new TabPage("Display");
            var layout = MakeTable(3);
            page.Controls.Add(layout);

            AddHeader(layout, "Display Settings");

            _showTrayIconCheckBox = new CheckBox { Text = "Show tray icon", AutoSize = true };
            layout.Controls.Add(new Label());
            layout.Controls.Add(_showTrayIconCheckBox);

            _showBalloonTipsCheckBox = new CheckBox { Text = "Show balloon notifications", AutoSize = true };
            layout.Controls.Add(new Label());
            layout.Controls.Add(_showBalloonTipsCheckBox);

            return page;
        }

        private TabPage BuildAboutTab()
        {
            var page = new TabPage("About");
            var layout = MakeTable(3);
            page.Controls.Add(layout);

            AddHeader(layout, "About");

            _versionLabel = new Label { AutoSize = true };
            layout.Controls.Add(new Label());
            layout.Controls.Add(_versionLabel);

            _checkUpdateButton = new Button { Text = "Check for updates", AutoSize = true };
            _checkUpdateButton.Click += CheckUpdateButton_Click;
            layout.Controls.Add(new Label());
            layout.Controls.Add(_checkUpdateButton);

            return page;
        }

        // Helpers

        private static TableLayoutPanel MakeTable(int rows)
        {
            var table = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                RowCount = rows,
                Padding = new Padding(12, 10, 12, 10),
                AutoSize = false
            };
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 190));
            table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            for (int i = 0; i < rows; i++)
                table.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));
            return table;
        }

        private static void AddHeader(TableLayoutPanel table, string text)
        {
            var label = new Label
            {
                Text = text,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                AutoSize = true,
                Anchor = AnchorStyles.Left | AnchorStyles.Bottom
            };
            table.Controls.Add(label);
            table.SetColumnSpan(label, 2);
        }

        private static Label MakeLabel(string text) =>
            new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left | AnchorStyles.Top };

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

            _versionLabel.Text = $"Version: {Application.ProductVersion}";
        }

        private void OkButton_Click(object? sender, EventArgs e)
        {
            if (_intervalMinNumeric.Value >= _intervalMaxNumeric.Value)
            {
                MessageBox.Show("Min interval must be less than max interval.", "Validation Error",
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

            _settings.Save();
            DialogResult = DialogResult.OK;
            Close();
        }

        private async void CheckUpdateButton_Click(object? sender, EventArgs e)
        {
            string currentVersion = Application.ProductVersion;
            var (hasUpdate, latestVersion, error) =
                await UpdateChecker.CheckForUpdatesAsync(currentVersion, _settings.UpdateCheckUrl);

            if (!string.IsNullOrEmpty(error))
            {
                MessageBox.Show($"Could not check for updates:\n{error}", "Update Check",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            MessageBox.Show(
                hasUpdate && latestVersion != null
                    ? $"A newer version is available.\n\nCurrent: {currentVersion}\nLatest: {latestVersion}"
                    : "You are running the latest version.",
                "Update Check", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
}
