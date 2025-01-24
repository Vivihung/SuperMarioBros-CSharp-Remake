using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace SuperMarioBros
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            // Configure high DPI settings
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
        
            // Configure global exception handling
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += (sender, e) => 
                HandleException(e.Exception);
            AppDomain.CurrentDomain.UnhandledException += (sender, e) => 
                HandleException(e.ExceptionObject as Exception);

            // Run the main form
            Application.Run(new Form1());
        }

        private static void HandleException(Exception? ex)
        {
            if (ex != null)
            {
                MessageBox.Show(
                    $"An unexpected error occurred:\n{ex.Message}\n\nStack Trace:\n{ex.StackTrace}",
                    "Application Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }
    }
}
