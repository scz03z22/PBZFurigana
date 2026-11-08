using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace PBZFurigana
{
    internal sealed class ScopeOptions
    {
        internal bool FullText = true, Weapons, Characters, Books;
        internal ScopeOptions Copy() { return new ScopeOptions { FullText = FullText, Weapons = Weapons, Characters = Characters, Books = Books }; }
        internal bool AnyCategory { get { return Weapons || Characters || Books; } }
        internal bool IsEnabled(string option) { return option == "full_text" ? !AnyCategory : !FullText; }
        internal bool Get(string option)
        {
            switch (option) { case "full_text": return FullText; case "weapons": return Weapons; case "characters": return Characters; case "books": return Books; }
            throw new ArgumentException("Unknown scope option");
        }
        internal bool Set(string option, bool value)
        {
            if (!IsEnabled(option)) return false;
            switch (option) { case "full_text": FullText = value; break; case "weapons": Weapons = value; break; case "characters": Characters = value; break; case "books": Books = value; break; default: throw new ArgumentException("Unknown scope option"); }
            Validate(); return true;
        }
        internal void Validate()
        {
            if (FullText && AnyCategory) throw new InvalidDataException("Full text and categories are mutually exclusive.");
        }
        internal string Serialize()
        {
            Validate();
            return "version=1\nfull_text=" + (FullText ? "1" : "0") + "\nweapons=" + (Weapons ? "1" : "0") + "\ncharacters=" + (Characters ? "1" : "0") + "\nbooks=" + (Books ? "1" : "0") + "\n";
        }
        internal static ScopeOptions Parse(string text)
        {
            if (Encoding.UTF8.GetByteCount(text) > 4096) throw new InvalidDataException("Scope file exceeds 4096 bytes.");
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            if (text.StartsWith("\uFEFF", StringComparison.Ordinal)) text = text.Substring(1);
            char[] whitespace = { ' ', '\t', '\r', '\n', '\v', '\f' };
            foreach (string raw in text.Split('\n'))
            {
                string line = raw.Trim(whitespace); if (line.Length == 0 || line.StartsWith("#", StringComparison.Ordinal)) continue;
                int equals = line.IndexOf('=');
                if (equals < 1 || equals != line.LastIndexOf('=')) throw new InvalidDataException("Invalid scope setting.");
                string key = line.Substring(0, equals).Trim(whitespace), value = line.Substring(equals + 1).Trim(whitespace);
                if (key != "version" && key != "full_text" && key != "weapons" && key != "characters" && key != "books") throw new InvalidDataException("Unknown scope setting.");
                if ((value != "0" && value != "1") || values.ContainsKey(key)) throw new InvalidDataException("Invalid or duplicate scope value.");
                values.Add(key, value);
            }
            if (values.Count != 5 || !values.ContainsKey("version") || values["version"] != "1") throw new InvalidDataException("Incomplete or unsupported scope file.");
            var result = new ScopeOptions { FullText = values["full_text"] == "1", Weapons = values["weapons"] == "1", Characters = values["characters"] == "1", Books = values["books"] == "1" };
            result.Validate(); return result;
        }
    }

    internal static class ScopeFile
    {
        internal const string Name = "furigana-scope.ini";
        internal static ScopeOptions Read(string root)
        {
            string path = Path.Combine(root, Name);
            if (!File.Exists(path)) return new ScopeOptions();
            if (new FileInfo(path).Length > 4096) throw new InvalidDataException("Scope file exceeds 4096 bytes.");
            return ScopeOptions.Parse(File.ReadAllText(path, Encoding.UTF8));
        }
        internal static void Save(string root, ScopeOptions options)
        {
            string path = Path.Combine(root, Name), temporary = path + ".tmp-" + Guid.NewGuid().ToString("N");
            try
            {
                using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    byte[] bytes = new UTF8Encoding(false).GetBytes(options.Serialize());
                    file.Write(bytes, 0, bytes.Length); file.Flush(true);
                }
                if (File.Exists(path)) File.Replace(temporary, path, null);
                else File.Move(temporary, path);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }
    }

    internal sealed class ScopeWindow : Form
    {
        private readonly string root;
        private ScopeOptions options;
        private readonly Dictionary<string, CheckBox> checks = new Dictionary<string, CheckBox>();
        private Label status;
        private bool updating;
        internal ScopeWindow(string folder)
        {
            root = folder;
            string error = null;
            try { options = ScopeFile.Read(root); }
            catch (Exception e) { options = new ScopeOptions(); error = e.Message; }
            Text = "PBZFurigana · 表示範囲";
            ClientSize = new Size(510, 414);
            FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false; MinimizeBox = true; ShowInTaskbar = true;
            StartPosition = FormStartPosition.CenterScreen; AutoScaleDimensions = new SizeF(96F, 96F); AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Yu Gothic UI", 10F); BackColor = Color.White;
            var heading = new Label { Left = 24, Top = 20, Width = 460, Height = 31, Text = "ふりがなを表示するテキスト", Font = new Font(Font.FontFamily, 14F, FontStyle.Bold) };
            Controls.Add(heading);
            Controls.Add(new Label { Left = 25, Top = 56, Width = 459, Height = 39, Text = "「全テキスト」を選ぶか、解除して対象を組み合わせます。" });
            AddCheck("full_text", 103, "全テキスト");
            AddCheck("weapons", 143, "武器名（影の武装を含む）");
            AddCheck("characters", 183, "人物名（図鑑・話者・会話本文中の名前）");
            AddCheck("books", 223, "読み物（記憶の花・図鑑の本文を含む）");
            status = new Label { Left = 25, Top = 266, Width = 459, Height = 29, ForeColor = Color.FromArgb(40, 100, 65) };
            Controls.Add(status);
            Controls.Add(new Label { Left = 25, Top = 302, Width = 459, Height = 83, ForeColor = Color.DimGray, Text = "設定は自動保存されます。右上の「－」で最小化できます。\nゲーム内は F6 で切り替えます。変更後は一度オフにして再度オンにしてください。" });
            ApplyChecks();
            if (error != null) { status.ForeColor = Color.Firebrick; status.Text = "設定を読み込めなかったため、初期値を表示しています。"; }
            else SetStatus(false);
        }
        private void AddCheck(string key, int top, string text)
        {
            var check = new CheckBox { Left = 29, Top = top, Width = 459, Height = 31, Text = text, Tag = key };
            check.CheckedChanged += Changed; checks.Add(key, check); Controls.Add(check);
        }
        private void ApplyChecks()
        {
            updating = true;
            foreach (var item in checks) { item.Value.Checked = options.Get(item.Key); item.Value.Enabled = options.IsEnabled(item.Key); }
            updating = false;
        }
        private void Changed(object sender, EventArgs args)
        {
            if (updating) return;
            var control = (CheckBox)sender;
            var prior = options.Copy();
            if (!options.Set((string)control.Tag, control.Checked)) { ApplyChecks(); return; }
            try { ScopeFile.Save(root, options); ApplyChecks(); SetStatus(true); }
            catch (Exception e)
            {
                options = prior; ApplyChecks(); status.ForeColor = Color.Firebrick;
                status.Text = "保存できませんでした。前の設定を保持しています。";
                MessageBox.Show(this, status.Text + "\n\n" + e.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        private void SetStatus(bool saved)
        {
            status.ForeColor = Color.FromArgb(40, 100, 65);
            status.Text = !options.FullText && !options.AnyCategory
                ? "対象未選択：F6 をオンにしてもふりがなは表示されません。"
                : saved ? "保存しました。" : "現在の設定を読み込みました。";
        }
        internal bool OptionEnabled(string key) { return checks[key].Enabled; }
        internal bool OptionChecked(string key) { return checks[key].Checked; }
        internal void SetOptionForTest(string key, bool value) { checks[key].Checked = value; }
        internal void ExportPreview(string path)
        {
            CreateControl();
            foreach (Control child in Controls) { IntPtr handle = child.Handle; child.CreateControl(); }
            PerformLayout();
            // Render our own controls offscreen without showing or activating a window.
            // WM_PRINT omits children of an invisible parent, so use their actual bounds,
            // font and enabled/checked state with the standard WinForms renderers.
            using (var bitmap = new Bitmap(Width, Height))
            using (var native = CreateGraphics())
            {
                bitmap.SetResolution(native.DpiX, native.DpiY);
                DrawToBitmap(bitmap, new Rectangle(0, 0, Width, Height));
                using (var graphics = Graphics.FromImage(bitmap))
                {
                    Point client = PointToScreen(Point.Empty); client.Offset(-Left, -Top);
                    var background = ClientRectangle; background.Offset(client.X, client.Y);
                    graphics.FillRectangle(Brushes.White, background);
                    foreach (Control control in Controls)
                    {
                        Rectangle text = control.Bounds;
                        text.Offset(client.X, client.Y);
                        Color foreground = control.Enabled ? control.ForeColor : SystemColors.GrayText;
                        var check = control as CheckBox;
                        if (check != null)
                        {
                            var state = check.Checked ? (check.Enabled ? System.Windows.Forms.VisualStyles.CheckBoxState.CheckedNormal : System.Windows.Forms.VisualStyles.CheckBoxState.CheckedDisabled) : (check.Enabled ? System.Windows.Forms.VisualStyles.CheckBoxState.UncheckedNormal : System.Windows.Forms.VisualStyles.CheckBoxState.UncheckedDisabled);
                            Size glyph = CheckBoxRenderer.GetGlyphSize(graphics, state);
                            CheckBoxRenderer.DrawCheckBox(graphics, new Point(text.Left, text.Top + (text.Height - glyph.Height) / 2), state);
                            text.X += glyph.Width + 6; text.Width -= glyph.Width + 6;
                        }
                        TextRenderer.DrawText(graphics, control.Text, control.Font, text, foreground, TextFormatFlags.WordBreak | TextFormatFlags.TextBoxControl | TextFormatFlags.NoPrefix | (check != null ? TextFormatFlags.VerticalCenter : TextFormatFlags.Top));
                    }
                }
                bitmap.Save(Path.GetFullPath(path));
            }
        }
    }

    internal static class Program
    {
        [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
        private static extern int GetWindowLong(IntPtr window, int index);
        private static void Check(bool value, string label) { if (!value) throw new Exception("Test failed: " + label); }
        private static void SelfTest(string output)
        {
            Directory.CreateDirectory(output);
            string root = Path.Combine(output, "scope-test-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(root);
            var s = ScopeFile.Read(root);
            Check(s.FullText && !s.AnyCategory, "default full text");
            Check(!File.Exists(Path.Combine(root, ScopeFile.Name)), "read does not create settings");
            foreach (string key in new[] { "weapons", "characters", "books" }) Check(!s.IsEnabled(key) && !s.Set(key, true), "categories locked while full");
            Check(s.Set("full_text", false), "uncheck full");
            foreach (string key in new[] { "weapons", "characters", "books" }) Check(s.IsEnabled(key), "categories unlock");
            for (int mask = 0; mask < 8; ++mask)
            {
                var combination = new ScopeOptions { FullText = false, Weapons = (mask & 1) != 0, Characters = (mask & 2) != 0, Books = (mask & 4) != 0 };
                Check(combination.IsEnabled("full_text") == (mask == 0), "full checkbox availability");
                ScopeFile.Save(root, combination);
                Check(ScopeFile.Read(root).Serialize() == combination.Serialize(), "atomic round trip");
                File.WriteAllText(Path.Combine(output, "valid-" + mask + ".ini"), combination.Serialize(), new UTF8Encoding(false));
            }
            s.Set("characters", true); Check(!s.Set("full_text", true), "cannot select full over a category");
            s.Set("weapons", true); s.Set("characters", false); Check(!s.IsEnabled("full_text"), "another category still checked");
            s.Set("weapons", false); Check(s.IsEnabled("full_text") && s.Set("full_text", true), "clear last category then select full");
            Check(ScopeOptions.Parse("\uFEFF# comment\r\n" + s.Serialize().Replace("\n", "\r\n")).FullText, "BOM and CRLF");
            File.WriteAllText(Path.Combine(output, "valid-full.ini"), s.Serialize(), new UTF8Encoding(false));
            string[] bad = { "", "version=2\nfull_text=1\nweapons=0\ncharacters=0\nbooks=0\n", s.Serialize() + "books=1\n", s.Serialize().Replace("weapons=0", "weapons=1"), s.Serialize().Replace("books=0\n", ""), s.Serialize() + "evil=1\n", s.Serialize().Replace("books=0", "books=true"), new string('a', 4097) };
            for (int i = 0; i < bad.Length; ++i)
            {
                bool rejected = false; try { ScopeOptions.Parse(bad[i]); } catch (InvalidDataException) { rejected = true; }
                Check(rejected, "invalid config " + i);
                File.WriteAllText(Path.Combine(output, "invalid-" + i + ".ini"), bad[i], new UTF8Encoding(false));
            }
            Check(Directory.GetFiles(root, "*.tmp-*").Length == 0, "no abandoned temporary file");
            ScopeFile.Save(root, new ScopeOptions());
            using (var window = new ScopeWindow(root))
            {
                Check(window.Text == "PBZFurigana · 表示範囲", "Japanese UI independent of OS locale");
                Check((GetWindowLong(window.Handle, -16) & 0x20000) != 0, "native caption supports minimize");
                Check((GetWindowLong(window.Handle, -16) & 0x10000) == 0 && window.ShowInTaskbar, "no maximize and restore from taskbar");
                Check(window.OptionChecked("full_text") && !window.OptionEnabled("books"), "actual window default state");
                window.SetOptionForTest("books", true); Check(!window.OptionChecked("books"), "disabled checkbox cannot change settings");
                window.SetOptionForTest("full_text", false); Check(window.OptionEnabled("books"), "actual window unlocks categories");
                window.SetOptionForTest("characters", true); Check(!window.OptionEnabled("full_text") && ScopeFile.Read(root).Characters, "actual event persists and locks full");
                window.SetOptionForTest("weapons", true); window.SetOptionForTest("characters", false); Check(!window.OptionEnabled("full_text"), "actual window retains another selected category");
                window.SetOptionForTest("weapons", false); Check(window.OptionEnabled("full_text"), "actual window unlocks full after last category");
                window.SetOptionForTest("full_text", true); Check(ScopeFile.Read(root).FullText && !window.OptionEnabled("books"), "actual event saves full-text mode");
            }
            File.WriteAllText(Path.Combine(output, "configurator-self-test.txt"), "PASS: defaults; mutual exclusion; all eight category combinations; empty selection; atomic persistence; malformed configurations; BOM/CRLF; actual WinForms checkbox events and persisted choices; Japanese UI independent of OS locale; native minimize caption and taskbar restore style.\n", new UTF8Encoding(false));
        }
        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
                if (args.Length == 2 && args[0] == "--self-test") { SelfTest(Path.GetFullPath(args[1])); return 0; }
                string root = AppDomain.CurrentDomain.BaseDirectory;
                if (args.Length >= 2 && args[0] == "--render-preview")
                {
                    using (var form = new ScopeWindow(root))
                    {
                        form.ExportPreview(args[1]);
                    }
                    return 0;
                }
                if (!File.Exists(Path.Combine(root, "Scripts", "main.lua")) || !File.Exists(Path.Combine(root, "enabled.txt")))
                {
                    MessageBox.Show("PBZFurigana フォルダー内で実行してください。", "PBZFurigana", MessageBoxButtons.OK, MessageBoxIcon.Information); return 1;
                }
                Application.Run(new ScopeWindow(root)); return 0;
            }
            catch (Exception e) { Console.Error.WriteLine(e); return 1; }
        }
    }
}
