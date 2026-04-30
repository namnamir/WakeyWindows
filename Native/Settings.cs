using System;
using System.IO;
using System.Reflection;
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

        private static string GetConfigPath()
        {
            try
            {
                var entryAssembly = Assembly.GetEntryAssembly();
                var exePath = entryAssembly?.Location;
                string baseDir = !string.IsNullOrEmpty(exePath)
                    ? Path.GetDirectoryName(exePath) ?? AppDomain.CurrentDomain.BaseDirectory
                    : AppDomain.CurrentDomain.BaseDirectory;
                return Path.Combine(baseDir, "config.json");
            }
            catch
            {
                return Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "config.json");
            }
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
