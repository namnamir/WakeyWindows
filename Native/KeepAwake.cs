using System;
using System.Runtime.InteropServices;

namespace PowerManager
{
    public static class KeepAwake
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern uint SetThreadExecutionState(uint esFlags);

        // Execution state flags
        private const uint ES_CONTINUOUS = 0x80000000;
        private const uint ES_SYSTEM_REQUIRED = 0x00000001;
        private const uint ES_DISPLAY_REQUIRED = 0x00000002;
        private const uint ES_AWAYMODE_REQUIRED = 0x00000040;

        private static bool _isActive = false;

        /// <summary>
        /// Prevents the system from sleeping. Call periodically.
        /// </summary>
        /// <param name="keepDisplayOn">Also keep the display on</param>
        public static void PreventSleep(bool keepDisplayOn = true)
        {
            uint flags = ES_SYSTEM_REQUIRED;
            
            if (keepDisplayOn)
            {
                flags |= ES_DISPLAY_REQUIRED;
            }

            SetThreadExecutionState(flags);
            _isActive = true;
        }

        /// <summary>
        /// Sets continuous keep-awake mode (persists until AllowSleep is called)
        /// </summary>
        /// <param name="keepDisplayOn">Also keep the display on</param>
        public static void PreventSleepContinuous(bool keepDisplayOn = true)
        {
            uint flags = ES_CONTINUOUS | ES_SYSTEM_REQUIRED;
            
            if (keepDisplayOn)
            {
                flags |= ES_DISPLAY_REQUIRED;
            }

            SetThreadExecutionState(flags);
            _isActive = true;
        }

        /// <summary>
        /// Allows the system to sleep normally again
        /// </summary>
        public static void AllowSleep()
        {
            SetThreadExecutionState(ES_CONTINUOUS);
            _isActive = false;
        }

        /// <summary>
        /// Returns whether keep-awake is currently active
        /// </summary>
        public static bool IsActive => _isActive;
    }
}
