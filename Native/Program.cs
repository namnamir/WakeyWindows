using System;
using System.Windows.Forms;
using System.Threading;

namespace PowerManager
{
    internal static class Program
    {
        private static Mutex? _mutex;

        [STAThread]
        static void Main(string[] args)
        {
            // Ensure only one instance runs
            bool createdNew = false;
            try
            {
                _mutex = new Mutex(true, mutexName, out createdNew);
            }
            catch (AbandonedMutexException)
            {
                // Previous instance terminated unexpectedly; this instance now owns the mutex
                createdNew = true;
            }

            if (!createdNew)
            {
                // Another instance is actively running
                return;
            }

            try
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainForm(args));
            }
            finally
            {
                try
                {
                    _mutex?.ReleaseMutex();
                }
                catch { }
                _mutex?.Dispose();
            }
        }
    }
}
