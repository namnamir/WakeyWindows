using System;
using System.Drawing;
using System.Runtime.InteropServices;

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
        private struct POINT
        {
            public int X;
            public int Y;
        }

        [DllImport("user32.dll")]
        private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("kernel32.dll")]
        private static extern uint GetTickCount();

        private Point _lastMousePosition;
        private DateTime _lastActivityTime;
        private readonly Settings _settings;

        public ActivityDetector(Settings settings)
        {
            _settings = settings;
            _lastMousePosition = GetCurrentMousePosition();
            _lastActivityTime = DateTime.Now;
        }

        /// <summary>
        /// Gets the number of seconds since the last user input (keyboard or mouse)
        /// </summary>
        public int GetIdleTimeSeconds()
        {
            LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
            lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);

            if (GetLastInputInfo(ref lastInputInfo))
            {
                uint idleTime = GetTickCount() - lastInputInfo.dwTime;
                return (int)(idleTime / 1000);
            }

            return 0;
        }

        /// <summary>
        /// Checks if user is currently active (working)
        /// </summary>
        public bool IsUserActive()
        {
            if (!_settings.DetectUserActivity)
                return false;

            // Check system-wide idle time
            int idleSeconds = GetIdleTimeSeconds();
            if (idleSeconds < _settings.IdleTimeoutSeconds)
            {
                _lastActivityTime = DateTime.Now;
                return true;
            }

            // Check mouse movement
            Point currentPos = GetCurrentMousePosition();
            int deltaX = Math.Abs(currentPos.X - _lastMousePosition.X);
            int deltaY = Math.Abs(currentPos.Y - _lastMousePosition.Y);

            if (deltaX > _settings.MouseMovementThreshold || deltaY > _settings.MouseMovementThreshold)
            {
                _lastMousePosition = currentPos;
                _lastActivityTime = DateTime.Now;
                return true;
            }

            return false;
        }

        /// <summary>
        /// Checks if we should pause keep-alive due to recent user activity
        /// </summary>
        public bool ShouldPauseKeepAlive()
        {
            if (!_settings.DetectUserActivity)
                return false;

            // If user was recently active, pause keep-alive
            double secondsSinceActivity = (DateTime.Now - _lastActivityTime).TotalSeconds;
            return secondsSinceActivity < _settings.ActivityPauseSeconds;
        }

        /// <summary>
        /// Updates the last known mouse position (call when keep-alive moves mouse)
        /// </summary>
        public void UpdateMousePosition()
        {
            _lastMousePosition = GetCurrentMousePosition();
        }

        private Point GetCurrentMousePosition()
        {
            if (GetCursorPos(out POINT point))
            {
                return new Point(point.X, point.Y);
            }
            return Point.Empty;
        }

        /// <summary>
        /// Checks if current time is within working hours
        /// </summary>
        public bool IsWithinWorkingHours()
        {
            if (!_settings.UseWorkingHours)
                return true;

            var now = DateTime.Now;
            string currentDay = now.DayOfWeek.ToString();

            // Check if today is a working day
            bool isWorkingDay = false;
            foreach (var day in _settings.WorkingDays)
            {
                if (day.Equals(currentDay, StringComparison.OrdinalIgnoreCase))
                {
                    isWorkingDay = true;
                    break;
                }
            }

            if (!isWorkingDay)
                return false;

            // Check if within working hours
            if (TimeSpan.TryParse(_settings.WorkingHoursStart, out TimeSpan start) &&
                TimeSpan.TryParse(_settings.WorkingHoursEnd, out TimeSpan end))
            {
                TimeSpan currentTime = now.TimeOfDay;
                return currentTime >= start && currentTime <= end;
            }

            return true;
        }
    }
}
