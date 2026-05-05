using System;
using System.Drawing;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace PowerManager
{
    public class ActivityDetector
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct LASTINPUTINFO
        {
            public uint cbSize;
            public uint dwTime;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int X; public int Y; }

        [DllImport("user32.dll")] private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
        [DllImport("user32.dll")] private static extern bool GetCursorPos(out POINT lpPoint);
        [DllImport("kernel32.dll")] private static extern uint GetTickCount();
        [DllImport("kernel32.dll")] private static extern IntPtr LocalFree(IntPtr hMem);
        [DllImport("powrprof.dll")] private static extern uint PowerGetActiveScheme(IntPtr UserRootPowerKey, out IntPtr ActivePolicyGuid);
        [DllImport("powrprof.dll")] private static extern uint PowerReadACValueIndex(IntPtr RootPowerKey, ref Guid SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, out uint AcValueIndex);
        [DllImport("powrprof.dll")] private static extern uint PowerReadDCValueIndex(IntPtr RootPowerKey, ref Guid SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, out uint DcValueIndex);

        private static readonly Guid _sleepSubgroup = new Guid("238C9FA8-0AAD-41ED-83F4-97BE242C8F20");
        private static readonly Guid _standbyTimeout = new Guid("29F6C1DB-86DA-48C5-9FDB-F2B67B1F44DA");

        private static readonly HttpClient _http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };

        private Point _lastMousePosition;
        private DateTime _lastActivityTime;
        private DateTime _lastJiggleTime = DateTime.MinValue;
        private readonly Settings _settings;

        // Holiday cache
        private HashSet<string>? _holidayCache;
        private int _holidayCacheYear = -1;
        private bool _holidayFetchInProgress;

        public ActivityDetector(Settings settings)
        {
            _settings = settings;
            _lastMousePosition = GetCurrentMousePosition();
            _lastActivityTime = DateTime.Now;
        }

        public int GetIdleTimeSeconds()
        {
            var info = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>() };
            if (GetLastInputInfo(ref info))
                return (int)((GetTickCount() - info.dwTime) / 1000);
            return 0;
        }

        public void MarkAsJiggle()
        {
            _lastJiggleTime = DateTime.Now;
            _lastMousePosition = GetCurrentMousePosition();
        }

        public bool IsUserActive()
        {
            if (!_settings.DetectUserActivity) return false;

            bool recentJiggle = (DateTime.Now - _lastJiggleTime).TotalSeconds < 3;
            int idleSeconds = GetIdleTimeSeconds();
            if (idleSeconds < _settings.IdleTimeoutSeconds && !recentJiggle)
            {
                _lastActivityTime = DateTime.Now;
                return true;
            }

            Point currentPos = GetCurrentMousePosition();
            int dx = Math.Abs(currentPos.X - _lastMousePosition.X);
            int dy = Math.Abs(currentPos.Y - _lastMousePosition.Y);
            if (dx > _settings.MouseMovementThreshold || dy > _settings.MouseMovementThreshold)
            {
                _lastMousePosition = currentPos;
                _lastActivityTime = DateTime.Now;
                return true;
            }

            return false;
        }

        public bool ShouldPauseKeepAlive()
        {
            if (!_settings.DetectUserActivity) return false;
            return (DateTime.Now - _lastActivityTime).TotalSeconds < _settings.ActivityPauseSeconds;
        }

        public void UpdateMousePosition() => _lastMousePosition = GetCurrentMousePosition();

        private Point GetCurrentMousePosition()
        {
            if (GetCursorPos(out POINT p)) return new Point(p.X, p.Y);
            return Point.Empty;
        }

        public bool IsWithinWorkingHours()
        {
            if (!_settings.UseWorkingHours) return true;

            var now = DateTime.Now;
            string today = now.DayOfWeek.ToString();

            bool isWorkingDay = false;
            foreach (var day in _settings.WorkingDays)
                if (day.Equals(today, StringComparison.OrdinalIgnoreCase)) { isWorkingDay = true; break; }

            if (!isWorkingDay) return false;

            if (!TimeSpan.TryParse(_settings.WorkingHoursStart, out var start) ||
                !TimeSpan.TryParse(_settings.WorkingHoursEnd, out var end))
                return true;

            return now.TimeOfDay >= start && now.TimeOfDay <= end;
        }

        // Returns true when today is a public holiday (and the setting is on).
        // Holiday list is fetched from Open Holidays API and cached for the year.
        public bool IsTodayHoliday()
        {
            if (!_settings.SkipHolidays) return false;

            var today = DateTime.Today;
            if (_holidayCacheYear != today.Year)
                RefreshHolidayCache(today.Year);

            return _holidayCache?.Contains(today.ToString("yyyy-MM-dd")) == true;
        }

        // Returns system sleep timeout in seconds for (AC, DC). 0 = never sleep. -1 = unavailable.
        public static (int Ac, int Dc) GetSleepTimeouts()
        {
            IntPtr schemePtr = IntPtr.Zero;
            try
            {
                if (PowerGetActiveScheme(IntPtr.Zero, out schemePtr) != 0) return (-1, -1);
                Guid scheme = Marshal.PtrToStructure<Guid>(schemePtr);
                var sub = _sleepSubgroup;
                var setting = _standbyTimeout;
                PowerReadACValueIndex(IntPtr.Zero, ref scheme, ref sub, ref setting, out uint ac);
                PowerReadDCValueIndex(IntPtr.Zero, ref scheme, ref sub, ref setting, out uint dc);
                return ((int)ac, (int)dc);
            }
            catch { return (-1, -1); }
            finally { if (schemePtr != IntPtr.Zero) LocalFree(schemePtr); }
        }

        private void RefreshHolidayCache(int year)
        {
            if (_holidayFetchInProgress) return;
            _holidayFetchInProgress = true;
            _holidayCacheYear = year;
            _holidayCache ??= new HashSet<string>();

            // Fire-and-forget; cache is populated asynchronously.
            Task.Run(async () =>
            {
                try
                {
                    string country = string.IsNullOrWhiteSpace(_settings.HolidayCountryCode) ? "NL" : _settings.HolidayCountryCode.ToUpper();
                    string url = $"https://openholidaysapi.org/PublicHolidays?countryIsoCode={country}&languageIsoCode=EN&validFrom={year}-01-01&validTo={year}-12-31";
                    var json = await _http.GetStringAsync(url);
                    using var doc = JsonDocument.Parse(json);
                    var dates = new HashSet<string>();
                    foreach (var el in doc.RootElement.EnumerateArray())
                    {
                        if (el.TryGetProperty("startDate", out var d))
                            dates.Add(d.GetString() ?? "");
                    }
                    _holidayCache = dates;
                }
                catch { /* keep stale or empty cache on failure */ }
                finally { _holidayFetchInProgress = false; }
            });
        }
    }
}
