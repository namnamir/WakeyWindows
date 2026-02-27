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

        // User activity detection settings
        [JsonPropertyName("detectUserActivity")]
        public bool DetectUserActivity { get; set; } = true;

        [JsonPropertyName("activityPauseSeconds")]
        public int ActivityPauseSeconds { get; set; } = 120;

        [JsonPropertyName("mouseMovementThreshold")]
        public int MouseMovementThreshold { get; set; } = 10;

        [JsonPropertyName("idleTimeoutSeconds")]
        public int IdleTimeoutSeconds { get; set; } = 30;

        // Working hours (optional)
        [JsonPropertyName("useWorkingHours")]
        public bool UseWorkingHours { get; set; } = false;

        [JsonPropertyName("workingHoursStart")]
        public string WorkingHoursStart { get; set; } = "08:30";

        [JsonPropertyName("workingHoursEnd")]
        public string WorkingHoursEnd { get; set; } = "17:00";

        [JsonPropertyName("workingDays")]
        public string[] WorkingDays { get; set; } = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" };

        // Stealth settings
        [JsonPropertyName("showTrayIcon")]
        public bool ShowTrayIcon { get; set; } = true;

        [JsonPropertyName("showBalloonTips")]
        public bool ShowBalloonTips { get; set; } = false;

        [JsonPropertyName("startMinimized")]
        public bool StartMinimized { get; set; } = true;

        [JsonPropertyName("startWithWindows")]
        public bool StartWithWindows { get; set; } = false;

        // Keep display on
        [JsonPropertyName("keepDisplayOn")]
        public bool KeepDisplayOn { get; set; } = true;

        // Optional URL to check for newer versions (plain text version string)
        [JsonPropertyName("updateCheckUrl")]
        public string? UpdateCheckUrl { get; set; } = "https://raw.githubusercontent.com/namnamir/WakeyWindows/main/Version";

        private static string GetConfigPath()
        {
            try
            {
                // Prefer the directory of the entry assembly (the actual .exe),
                // which is stable even for single-file deployments.
                var entryAssembly = Assembly.GetEntryAssembly();
                var exePath = entryAssembly?.Location;

                string baseDir;
                if (!string.IsNullOrEmpty(exePath))
                {
                    baseDir = Path.GetDirectoryName(exePath) ?? AppDomain.CurrentDomain.BaseDirectory;
                }
                else
                {
                    baseDir = AppDomain.CurrentDomain.BaseDirectory;
                }

                return Path.Combine(baseDir, "config.json");
            }
            catch
            {
                // Fallback to AppDomain base directory if anything goes wrong
                return Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "config.json");
            }
        }

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
            catch
            {
                // If config is corrupted, use defaults
            }

            // Create default config file
            var defaultSettings = new Settings();
            defaultSettings.Save();
            return defaultSettings;
        }

        public void Save()
        {
            try
            {
                var options = new JsonSerializerOptions
                {
                    WriteIndented = true
                };
                string json = JsonSerializer.Serialize(this, options);
                File.WriteAllText(ConfigPath, json);
            }
            catch
            {
                // Silently fail if we can't write config
            }
        }
    }
}
