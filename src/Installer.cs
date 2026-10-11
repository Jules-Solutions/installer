using System;
using System.Diagnostics;
using System.Windows.Forms;

namespace JulesSolutions
{
    class Installer
    {
        [STAThread]
        static void Main()
        {
            try
            {
                // Start PowerShell with the install command
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -Command \"irm 'https://raw.githubusercontent.com/Jules-Solutions/installer/main/install.ps1' | iex\"",
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Normal
                };

                using (Process? process = Process.Start(psi))
                {
                    process?.WaitForExit();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Failed to start installer:\n\n" + ex.Message,
                    "Jules.Solutions Installer",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                Environment.Exit(1);
            }
        }
    }
}
