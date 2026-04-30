using System.Runtime.InteropServices;

namespace PowerManager
{
    internal static class KeyboardSimulator
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public KEYBDINPUT ki;
            private readonly long _padding; // pad to match union size
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public nint dwExtraInfo;
        }

        private const uint INPUT_KEYBOARD = 1;
        private const uint KEYEVENTF_KEYUP = 0x0002;
        private const ushort VK_F15 = 0x7E; // F15 — harmless, no application listens to it

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        // Press and release F15. Updates GetLastInputInfo so Teams sees activity.
        public static void PressKey()
        {
            var down = new INPUT
            {
                type = INPUT_KEYBOARD,
                ki = new KEYBDINPUT { wVk = VK_F15 }
            };
            var up = new INPUT
            {
                type = INPUT_KEYBOARD,
                ki = new KEYBDINPUT { wVk = VK_F15, dwFlags = KEYEVENTF_KEYUP }
            };
            SendInput(2, new[] { down, up }, Marshal.SizeOf<INPUT>());
        }
    }
}
