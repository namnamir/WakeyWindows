using System;
using System.Net.Http;
using System.Threading.Tasks;

namespace PowerManager
{
    public static class UpdateChecker
    {
        private static readonly HttpClient Client = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(5)
        };

        public static async Task<(bool HasUpdate, string? LatestVersion, string? Error)> CheckForUpdatesAsync(
            string currentVersion,
            string? url)
        {
            if (string.IsNullOrWhiteSpace(url))
            {
                return (false, null, "Update check URL is not configured.");
            }

            try
            {
                using var response = await Client.GetAsync(url);
                response.EnsureSuccessStatusCode();

                var text = (await response.Content.ReadAsStringAsync()).Trim();
                if (string.IsNullOrEmpty(text))
                {
                    return (false, null, "Empty version response.");
                }

                var hasUpdate = IsNewerVersion(text, currentVersion);
                return (hasUpdate, text, null);
            }
            catch (Exception ex)
            {
                return (false, null, ex.Message);
            }
        }

        private static bool IsNewerVersion(string latest, string current)
        {
            if (Version.TryParse(latest, out var latestVersion) &&
                Version.TryParse(current, out var currentVersion))
            {
                return latestVersion > currentVersion;
            }

            return !string.Equals(latest, current, StringComparison.OrdinalIgnoreCase);
        }
    }
}

