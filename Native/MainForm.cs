using System;
using System.Drawing;
using System.Windows.Forms;
using System.Threading;

namespace PowerManager
{
    public partial class MainForm : Form
    {
        private readonly NotifyIcon _trayIcon;
        private readonly ContextMenuStrip _trayMenu;
        private readonly System.Windows.Forms.Timer _keepAliveTimer;
        private readonly System.Windows.Forms.Timer _activityTimer;
        private readonly Settings _settings;
        private readonly ActivityDetector _activityDetector;
        private readonly Random _random = new Random();
        
        private bool _isPaused = false;
        private bool _isUserActive = false;
        private DateTime _lastKeepAlive = DateTime.MinValue;
        private int _currentInterval;

        // Menu items (for updating text)
        private ToolStripMenuItem _statusItem = null!;
        private ToolStripMenuItem _pauseItem = null!;
        private ToolStripMenuItem _enabledItem = null!;

        public MainForm(string[] args)
        {
            // Load settings
            _settings = Settings.Load();
            _activityDetector = new ActivityDetector(_settings);

            // Initialize form (hidden)
            InitializeComponent();
            this.ShowInTaskbar = false;
            this.WindowState = FormWindowState.Minimized;
            this.Visible = false;
            this.FormBorderStyle = FormBorderStyle.FixedToolWindow;
            this.Size = new Size(1, 1);
            this.Location = new Point(-1000, -1000);

            // Create tray menu
            _trayMenu = CreateTrayMenu();

            // Resolve tray icon from the executable (so it matches the app icon)
            Icon trayIconImage;
            try
            {
                trayIconImage = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;
            }
            catch
            {
                trayIconImage = SystemIcons.Application;
            }

            // Create tray icon
            _trayIcon = new NotifyIcon
            {
                Text = "Power Manager",
                Icon = trayIconImage,
                ContextMenuStrip = _trayMenu,
                Visible = _settings.ShowTrayIcon
            };
            _trayIcon.DoubleClick += (s, e) => ShowSettingsDialog();

            // Create keep-alive timer
            _keepAliveTimer = new System.Windows.Forms.Timer();
            _keepAliveTimer.Tick += KeepAliveTimer_Tick;
            SetNextInterval();

            // Create activity check timer (every 2 seconds)
            _activityTimer = new System.Windows.Forms.Timer();
            _activityTimer.Interval = 2000;
            _activityTimer.Tick += ActivityTimer_Tick;

            // Start if enabled
            if (_settings.Enabled)
            {
                Start();
            }

            UpdateStatus();
        }

        private void InitializeComponent()
        {
            this.SuspendLayout();
            this.ClientSize = new Size(1, 1);
            this.Name = "MainForm";
            this.Text = "Power Manager";
            this.ResumeLayout(false);
        }

        private ContextMenuStrip CreateTrayMenu()
        {
            var menu = new ContextMenuStrip();

            _statusItem = new ToolStripMenuItem("Status: Idle") { Enabled = false };
            menu.Items.Add(_statusItem);
            menu.Items.Add(new ToolStripSeparator());

            _enabledItem = new ToolStripMenuItem("Enabled", null, (s, e) => ToggleEnabled());
            _enabledItem.Checked = _settings.Enabled;
            menu.Items.Add(_enabledItem);

            _pauseItem = new ToolStripMenuItem("Pause", null, (s, e) => TogglePause());
            menu.Items.Add(_pauseItem);

            menu.Items.Add(new ToolStripSeparator());

            var settingsItem = new ToolStripMenuItem("Settings...", null, (s, e) => ShowSettingsDialog());
            menu.Items.Add(settingsItem);

            menu.Items.Add(new ToolStripSeparator());

            var exitItem = new ToolStripMenuItem("Exit", null, (s, e) => ExitApplication());
            menu.Items.Add(exitItem);

            return menu;
        }

        private void SetNextInterval()
        {
            // Randomize next interval with jitter
            int baseInterval = _random.Next(_settings.IntervalMinSeconds, _settings.IntervalMaxSeconds + 1);
            int jitter = _random.Next(-10, 21);
            
            // Occasionally add longer pause (10% chance)
            if (_random.Next(1, 11) == 1)
            {
                jitter += _random.Next(30, 61);
            }

            _currentInterval = Math.Max(_settings.IntervalMinSeconds, baseInterval + jitter);
            _keepAliveTimer.Interval = _currentInterval * 1000;
        }

        private void KeepAliveTimer_Tick(object? sender, EventArgs e)
        {
            if (_isPaused || !_settings.Enabled)
                return;

            // Check working hours
            if (!_activityDetector.IsWithinWorkingHours())
            {
                UpdateStatus("Outside working hours");
                return;
            }

            // Check if user is active - don't interfere
            if (_isUserActive || _activityDetector.ShouldPauseKeepAlive())
            {
                UpdateStatus("User active - paused");
                SetNextInterval();
                return;
            }

            // Perform keep-alive
            KeepAwake.PreventSleep(_settings.KeepDisplayOn);
            _lastKeepAlive = DateTime.Now;
            
            // Set next random interval
            SetNextInterval();
            
            UpdateStatus("Active");
        }

        private void ActivityTimer_Tick(object? sender, EventArgs e)
        {
            if (!_settings.DetectUserActivity)
                return;

            bool wasActive = _isUserActive;
            _isUserActive = _activityDetector.IsUserActive();

            // If user just became active, update status
            if (_isUserActive && !wasActive)
            {
                UpdateStatus("User active - paused");
            }
            else if (!_isUserActive && wasActive && _settings.Enabled && !_isPaused)
            {
                UpdateStatus("Active");
            }
        }

        private void Start()
        {
            _keepAliveTimer.Start();
            _activityTimer.Start();
            
            // Initial keep-alive
            if (!_activityDetector.IsUserActive())
            {
                KeepAwake.PreventSleep(_settings.KeepDisplayOn);
                _lastKeepAlive = DateTime.Now;
            }
            
            UpdateStatus("Active");
        }

        private void Stop()
        {
            _keepAliveTimer.Stop();
            _activityTimer.Stop();
            KeepAwake.AllowSleep();
            UpdateStatus("Disabled");
        }

        private void ToggleEnabled()
        {
            _settings.Enabled = !_settings.Enabled;
            _enabledItem.Checked = _settings.Enabled;
            _settings.Save();

            if (_settings.Enabled)
            {
                _isPaused = false;
                _pauseItem.Checked = false;
                Start();
            }
            else
            {
                Stop();
            }
        }

        private void TogglePause()
        {
            _isPaused = !_isPaused;
            _pauseItem.Checked = _isPaused;

            if (_isPaused)
            {
                KeepAwake.AllowSleep();
                UpdateStatus("Paused");
            }
            else
            {
                UpdateStatus("Active");
            }
        }

        private void UpdateStatus(string? status = null)
        {
            string displayStatus;
            
            if (!_settings.Enabled)
            {
                displayStatus = "Disabled";
            }
            else if (_isPaused)
            {
                displayStatus = "Paused";
            }
            else if (status != null)
            {
                displayStatus = status;
            }
            else if (_isUserActive)
            {
                displayStatus = "User active - paused";
            }
            else
            {
                displayStatus = "Active";
            }

            _statusItem.Text = $"Status: {displayStatus}";
            _trayIcon.Text = $"Power Manager - {displayStatus}";
        }

        private void ShowSettingsDialog()
        {
            using var dialog = new SettingsForm(_settings);
            if (dialog.ShowDialog() == DialogResult.OK)
            {
                _settings.Save();
                
                // Apply settings
                _trayIcon.Visible = _settings.ShowTrayIcon;
                _enabledItem.Checked = _settings.Enabled;
                
                if (_settings.Enabled && !_keepAliveTimer.Enabled)
                {
                    Start();
                }
                else if (!_settings.Enabled && _keepAliveTimer.Enabled)
                {
                    Stop();
                }
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
            // Minimize to tray instead of closing
            if (e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                this.Hide();
                return;
            }
            
            KeepAwake.AllowSleep();
            base.OnFormClosing(e);
        }

        protected override void SetVisibleCore(bool value)
        {
            // Start hidden
            if (!this.IsHandleCreated)
            {
                CreateHandle();
                value = false;
            }
            base.SetVisibleCore(value);
        }
    }
}
