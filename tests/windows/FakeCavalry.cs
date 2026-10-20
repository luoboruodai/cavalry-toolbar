using System;
using System.IO;
using System.Text.RegularExpressions;
using System.Windows.Forms;
public static class FakeCavalry {
    [STAThread]
    public static void Main() {
        var form = new Form { Text = "Cavalry QA", Width = 640, Height = 480 };
        var menu = new MenuStrip();
        var scripts = new ToolStripMenuItem("Scripts");
        scripts.DropDownItems.Add(new ToolStripMenuItem("CavalryToolbar"));
        scripts.DropDownItems.Add(new ToolStripMenuItem("Panel"));
        scripts.DropDown.ItemClicked += (sender, args) => {
            string name = args.ClickedItem.Text;
            File.WriteAllText(Path.Combine(Path.GetTempPath(), "CavalryWheel-qa-receipt.json"), name);
            if (name.StartsWith("CavalryToolbar_UIDispatch_", StringComparison.Ordinal)) {
                string file = Path.Combine(Directory.GetCurrentDirectory(), name + ".js");
                string source = File.ReadAllText(file);
                var match = Regex.Match(source, "\\\"receipt\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"");
                if (match.Success) File.WriteAllText(match.Groups[1].Value, "{\"version\":1,\"status\":\"evaluated\"}");
            }
        };
        menu.Items.Add(scripts);
        form.MainMenuStrip = menu;
        form.Controls.Add(menu);
        form.Show();
        Application.Run(form);
    }
}
