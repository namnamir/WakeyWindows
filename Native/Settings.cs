using System;
using System.Drawing;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace PowerManager
{
    public class Settings
    {
        private static readonly string ConfigPath = GetConfigPath();

        // Keep-alive settings
        [JsonPropertyName("enabled")]
        public bool Enabled { get; set; } = true;

        [JsonPropertyName("intervalMinSeconds")]
        public int IntervalMinSeconds { get; set; } = 60;

        [JsonPropertyName("intervalMaxSeconds")]
        public int IntervalMaxSeconds { get; set; } = 120;

        // Interval expressed as % of the system sleep timeout (computed → stored in IntervalMin/MaxSeconds)
        [JsonPropertyName("intervalMinPercent")]
        public int IntervalMinPercent { get; set; } = 60;

        [JsonPropertyName("intervalMaxPercent")]
        public int IntervalMaxPercent { get; set; } = 80;

        // Simulation method: "mouse_jiggle", "key_press", or "api_only"
        [JsonPropertyName("simulationMethod")]
        public string SimulationMethod { get; set; } = "mouse_jiggle";

        // Keep display on
        [JsonPropertyName("keepDisplayOn")]
        public bool KeepDisplayOn { get; set; } = true;

        // User activity detection settings
        [JsonPropertyName("detectUserActivity")]
        public bool DetectUserActivity { get; set; } = true;

        [JsonPropertyName("activityPauseSeconds")]
        public int ActivityPauseSeconds { get; set; } = 120;

        [JsonPropertyName("mouseMovementThreshold")]
        public int MouseMovementThreshold { get; set; } = 10;

        [JsonPropertyName("idleTimeoutSeconds")]
        public int IdleTimeoutSeconds { get; set; } = 30;

        // Working hours
        [JsonPropertyName("useWorkingHours")]
        public bool UseWorkingHours { get; set; } = false;

        [JsonPropertyName("workingHoursStart")]
        public string WorkingHoursStart { get; set; } = "08:30";

        [JsonPropertyName("workingHoursEnd")]
        public string WorkingHoursEnd { get; set; } = "17:00";

        [JsonPropertyName("workingDays")]
        public string[] WorkingDays { get; set; } = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" };

        // Holidays
        [JsonPropertyName("skipHolidays")]
        public bool SkipHolidays { get; set; } = false;

        [JsonPropertyName("holidayCountryCode")]
        public string HolidayCountryCode { get; set; } = "NL";

        // Tray / notifications
        [JsonPropertyName("showTrayIcon")]
        public bool ShowTrayIcon { get; set; } = true;

        [JsonPropertyName("showBalloonTips")]
        public bool ShowBalloonTips { get; set; } = true;

        [JsonPropertyName("startMinimized")]
        public bool StartMinimized { get; set; } = true;

        [JsonPropertyName("startWithWindows")]
        public bool StartWithWindows { get; set; } = false;

        // Optional URL to check for newer versions
        [JsonPropertyName("updateCheckUrl")]
        public string? UpdateCheckUrl { get; set; } = "https://raw.githubusercontent.com/namnamir/WakeyWindows/main/Version";

        // ── Appearance: colors (hex strings e.g. "#4CAF50") ───────────────
        [JsonPropertyName("colorHeaderGradientStart")]
        public string ColorHeaderGradientStart { get; set; } = "#1C3064";

        [JsonPropertyName("colorHeaderGradientEnd")]
        public string ColorHeaderGradientEnd { get; set; } = "#12204A";

        [JsonPropertyName("colorFormBackground")]
        public string ColorFormBackground { get; set; } = "#F5F7FA";

        [JsonPropertyName("colorAccentActive")]
        public string ColorAccentActive { get; set; } = "#4CAF50";

        [JsonPropertyName("colorAccentPaused")]
        public string ColorAccentPaused { get; set; } = "#FF9800";

        [JsonPropertyName("colorAccentDisabled")]
        public string ColorAccentDisabled { get; set; } = "#9E9E9E";

        [JsonPropertyName("colorAccentUserActive")]
        public string ColorAccentUserActive { get; set; } = "#2196F3";

        [JsonPropertyName("colorCountdown")]
        public string ColorCountdown { get; set; } = "#1976D2";

        [JsonPropertyName("colorProgressBar")]
        public string ColorProgressBar { get; set; } = "#1976D2";

        [JsonPropertyName("colorProgressBarUrgent")]
        public string ColorProgressBarUrgent { get; set; } = "#F4511E";

        [JsonPropertyName("colorLogBackground")]
        public string ColorLogBackground { get; set; } = "#1E1E1E";

        [JsonPropertyName("colorLogSuccess")]
        public string ColorLogSuccess { get; set; } = "#64DC78";

        [JsonPropertyName("colorLogWarning")]
        public string ColorLogWarning { get; set; } = "#FFB74D";

        [JsonPropertyName("colorLogUserActive")]
        public string ColorLogUserActive { get; set; } = "#64B5F6";

        [JsonPropertyName("colorLogDisabled")]
        public string ColorLogDisabled { get; set; } = "#EF5350";

        [JsonPropertyName("colorLogInfo")]
        public string ColorLogInfo { get; set; } = "#B4B4B4";

        // ── Appearance: fonts ─────────────────────────────────────────────
        [JsonPropertyName("fontFamily")]
        public string FontFamily { get; set; } = "Segoe UI";

        [JsonPropertyName("fontSizeBase")]
        public float FontSizeBase { get; set; } = 9f;

        [JsonPropertyName("logFontFamily")]
        public string LogFontFamily { get; set; } = "Consolas";

        [JsonPropertyName("logFontSize")]
        public float LogFontSize { get; set; } = 8.5f;

        // ── Behavior tweaks ───────────────────────────────────────────────
        [JsonPropertyName("logMaxEntries")]
        public int LogMaxEntries { get; set; } = 200;

        [JsonPropertyName("trayTooltipRefreshSeconds")]
        public int TrayTooltipRefreshSeconds { get; set; } = 5;

        [JsonPropertyName("progressUrgentThreshold")]
        public double ProgressUrgentThreshold { get; set; } = 0.20;

        // ── Color helper ──────────────────────────────────────────────────
        public static Color ParseColor(string hex, Color fallback)
        {
            try { return ColorTranslator.FromHtml(hex); }
            catch { return fallback; }
        }

        private static string GetConfigPath()
        {
            // AppContext.BaseDirectory is the correct way in single-file apps.
            // Assembly.Location returns empty string when the app is published as single-file.
            return Path.Combine(AppContext.BaseDirectory, "config.json");
        }

        public static string GetConfigFilePath() => ConfigPath;

        public static Settings Load()
        {
            try
            {
                if (File.Exists(ConfigPath))
                {
                    string json = File.ReadAllText(ConfigPath);
                    var settings = JsonSerializer.Deserialize<Settings>(json);
                    return settings ?? new Settings();
                }
            }
            catch { }

            var defaultSettings = new Settings();
            defaultSettings.Save();
            return defaultSettings;
        }

        public void Save()
        {
            try
            {
                string json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(ConfigPath, json);
            }
            catch { }
        }
    }
}
