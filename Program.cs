using System.Runtime.Versioning;
using System.Windows.Forms;

[assembly: SupportedOSPlatform("windows")]

namespace SuperMarioBros;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new Form1());
    }
}
