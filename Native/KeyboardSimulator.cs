using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace PowerManager
{
    internal static class KeyboardSimulator
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
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
            public KEYBDINPUT ki;
        }

        private const uint INPUT_KEYBOARD = 1;
        private const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
        private const uint KEYEVENTF_KEYUP = 0x0002;
        private const uint KEYEVENTF_SCANCODE = 0x0008;

        private const ushort VK_F15 = 0x7E;       // F15 — harmless non-printing key
        private const uint MAPVK_VK_TO_VSC = 0x00;

        // Custom signature for dwExtraInfo to prevent zero-signature detection
        private static readonly IntPtr ExtraInfoSignature = new IntPtr(0x57414B45); // 'WAKE'

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, [In] INPUT[] pInputs, int cbSize);

        [DllImport("user32.dll")]
        private static extern uint MapVirtualKey(uint uCode, uint uMapType);

        /// <summary>
        /// Press and release F15 with hardware scan code, humanized hold time, and masked extra info.
        /// Updates GetLastInputInfo so system and monitoring see realistic user presence without side-effects.
        /// </summary>
        /// <returns>True if SendInput succeeded</returns>
        public static bool PressKey(ushort vKey = VK_F15)
        {
            ushort scanCode = (ushort)MapVirtualKey(vKey, MAPVK_VK_TO_VSC);

            var down = new INPUT
            {
                type = INPUT_KEYBOARD,
                ki = new KEYBDINPUT
                {
                    wVk = vKey,
                    wScan = scanCode,
                    dwFlags = (scanCode > 0 ? KEYEVENTF_SCANCODE : 0),
                    time = 0,
                    dwExtraInfo = ExtraInfoSignature
                }
            };

            var up = new INPUT
            {
                type = INPUT_KEYBOARD,
                ki = new KEYBDINPUT
                {
                    wVk = vKey,
                    wScan = scanCode,
                    dwFlags = (scanCode > 0 ? KEYEVENTF_SCANCODE : 0) | KEYEVENTF_KEYUP,
                    time = 0,
                    dwExtraInfo = ExtraInfoSignature
                }
            };

            int structSize = Marshal.SizeOf<INPUT>();

            // Send Key Down
            uint sentDown = SendInput(1, new[] { down }, structSize);
            if (sentDown == 0) return false;

            // Humanized hold duration (40ms - 80ms) to avoid 0ms instant-tap heuristics
            int holdDuration = Random.Shared.Next(40, 85);
            Thread.Sleep(holdDuration);

            // Send Key Up
            uint sentUp = SendInput(1, new[] { up }, structSize);
            return sentUp > 0;
        }
    }
}

