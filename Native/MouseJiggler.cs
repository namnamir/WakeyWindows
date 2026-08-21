using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace PowerManager
{
    internal static class MouseJiggler
    {
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

        [StructLayout(LayoutKind.Explicit)]
        private struct INPUT
        {
            [FieldOffset(0)]
            public uint type;

            // 64-bit alignment: union starts at offset 8 on x64, 4 on x86
            [FieldOffset(8)]
            public MOUSEINPUT mi;
        }

        private const uint INPUT_MOUSE = 0;
        private const uint MOUSEEVENTF_MOVE = 0x0001;

        // Custom signature for dwExtraInfo to prevent zero-signature detection
        private static readonly IntPtr ExtraInfoSignature = new IntPtr(0x57414B45); // 'WAKE'

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, [In] INPUT[] pInputs, int cbSize);

        /// <summary>
        /// Moves the mouse along a subtle humanized micro-path and returns it.
        /// Avoids simplistic 1-pixel linear ping-pong signatures.
        /// </summary>
        /// <returns>True if mouse movement succeeded</returns>
        public static bool Jiggle(int maxPixels = 2)
        {
            // Pick a randomized subtle direction
            int targetDx = Random.Shared.Next(-maxPixels, maxPixels + 1);
            int targetDy = Random.Shared.Next(-maxPixels, maxPixels + 1);
            if (targetDx == 0 && targetDy == 0) targetDx = (Random.Shared.Next(0, 2) == 0) ? 1 : -1;

            int structSize = Marshal.SizeOf<INPUT>();
            bool success = true;

            // Outward micro-step
            success &= SendMouseMove(targetDx, targetDy, structSize);

            // Natural human hesitation
            int hesitation = Random.Shared.Next(25, 65);
            Thread.Sleep(hesitation);

            // Inward return step
            success &= SendMouseMove(-targetDx, -targetDy, structSize);

            return success;
        }

        private static bool SendMouseMove(int dx, int dy, int structSize)
        {
            var input = new INPUT
            {
                type = INPUT_MOUSE,
                mi = new MOUSEINPUT
                {
                    dx = dx,
                    dy = dy,
                    dwFlags = MOUSEEVENTF_MOVE,
                    time = 0,
                    dwExtraInfo = ExtraInfoSignature
                }
            };

            return SendInput(1, new[] { input }, structSize) > 0;
        }
    }
}

