using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace PowerManager
{
    internal static class MouseJiggler
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public MOUSEINPUT mi;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        private const uint INPUT_MOUSE = 0;
        private const uint MOUSEEVENTF_MOVE = 0x0001;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        // Moves the mouse by +pixels then back. Uses SendInput so GetLastInputInfo
        // is updated, which is what Teams uses to detect user presence.
        public static void Jiggle(int pixels = 1)
        {
            Move(pixels, 0);
            Thread.Sleep(50);
            Move(-pixels, 0);
        }

        private static void Move(int dx, int dy)
        {
            var input = new INPUT
            {
                type = INPUT_MOUSE,
                mi = new MOUSEINPUT
                {
                    dx = dx,
                    dy = dy,
                    dwFlags = MOUSEEVENTF_MOVE
                }
            };
            SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>());
        }
    }
}
