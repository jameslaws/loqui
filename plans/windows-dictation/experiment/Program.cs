// Throwaway probe for the Loqui for Windows plan. Proves, on a GitHub Windows runner:
// 1. a low-level keyboard hook sees (and swallows) a global shortcut,
// 2. audio played into a virtual cable is captured through the normal microphone path (WASAPI),
// 3. the on-device engine turns that capture into text,
// 4. the text is pasted at the cursor of a real app (Notepad) with Ctrl+V and read back.
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

static class Probe
{
    [STAThread]
    static int Main(string[] args)
    {
        string speechWav = args[0], sherpaExe = args[1], modelDir = args[2], outDir = args[3];
        Directory.CreateDirectory(outDir);
        var report = new StringBuilder();
        void Log(string s) { Console.WriteLine(s); report.AppendLine(s); }

        Log($"OS: {Environment.OSVersion}  64-bit: {Environment.Is64BitProcess}  arch: {RuntimeInformation.ProcessArchitecture}");
        Log($"Session: {Process.GetCurrentProcess().SessionId}  UserInteractive: {Environment.UserInteractive}");
        Log($"Input desktop: {DesktopName()}");

        // 1. Hook
        var hook = new HookThread();
        hook.Start();
        Thread.Sleep(300);
        var notepad = Process.Start("notepad.exe");
        notepad.WaitForInputIdle(5000);
        IntPtr np = IntPtr.Zero;
        for (int i = 0; i < 50 && np == IntPtr.Zero; i++) { Thread.Sleep(100); notepad.Refresh(); np = FindNotepad(notepad); }
        Log($"Notepad window: 0x{np:X}");
        Focus(np);
        Log($"Foreground is Notepad: {GetForegroundWindow() == np}");
        Kb.Chord(Kb.VK_CONTROL, Kb.VK_SHIFT, Kb.VK_SPACE);
        bool fired = hook.Fired.WaitOne(3000);
        Log($"HOOK: shortcut Ctrl+Shift+Space seen by low-level hook: {fired} (injected flag: {hook.SawInjected})");
        Thread.Sleep(300);
        Log($"HOOK: Notepad text after shortcut (should be empty, shortcut swallowed): '{ReadNotepad(np)}'");

        // 2. Audio through the virtual cable
        var en = new MMDeviceEnumerator();
        foreach (var d in en.EnumerateAudioEndPoints(DataFlow.All, DeviceState.Active))
            Log($"AUDIO device: {d.DataFlow} '{d.FriendlyName}'");
        string capturePath = Path.Combine(outDir, "captured-16k.wav");
        string transcript = "";
        try
        {
            var mic = en.GetDefaultAudioEndpoint(DataFlow.Capture, Role.Communications);
            var spk = en.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
            Log($"AUDIO default mic: '{mic.FriendlyName}'  default output: '{spk.FriendlyName}'");
            var raw = Path.Combine(outDir, "captured-raw.wav");
            using (var cap = new WasapiCapture(mic))
            {
                var writer = new WaveFileWriter(raw, cap.WaveFormat);
                cap.DataAvailable += (_, e) => writer.Write(e.Buffer, 0, e.BytesRecorded);
                cap.StartRecording();
                using (var reader = new AudioFileReader(speechWav))
                using (var outDev = new WasapiOut(spk, AudioClientShareMode.Shared, false, 100))
                {
                    outDev.Init(reader);
                    outDev.Play();
                    while (outDev.PlaybackState == PlaybackState.Playing) Thread.Sleep(100);
                }
                Thread.Sleep(600);
                cap.StopRecording();
                Thread.Sleep(300);
                writer.Dispose();
            }
            using (var r = new AudioFileReader(raw))
            {
                ISampleProvider s = r;
                if (s.WaveFormat.Channels > 1) s = s.ToMono();
                var rs = new WdlResamplingSampleProvider(s, 16000);
                WaveFileWriter.CreateWaveFile16(capturePath, rs);
            }
            Log($"AUDIO captured {new FileInfo(capturePath).Length} bytes at 16 kHz mono");

            // 3. Engine on the captured audio
            var sw = Stopwatch.StartNew();
            var psi = new ProcessStartInfo(sherpaExe,
                $"--tokens={modelDir}/tokens.txt --encoder={modelDir}/encoder.int8.onnx --decoder={modelDir}/decoder.int8.onnx --joiner={modelDir}/joiner.int8.onnx --model-type=nemo_transducer --num-threads=4 \"{capturePath}\"")
            { RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false };
            var p = Process.Start(psi)!;
            string so = p.StandardOutput.ReadToEnd(), se = p.StandardError.ReadToEnd();
            p.WaitForExit();
            sw.Stop();
            var all = so + "\n" + se;
            var m = System.Text.RegularExpressions.Regex.Match(all, "\"text\"\\s*:\\s*\"(.*?)\"");
            transcript = m.Success ? m.Groups[1].Value : "";
            Log($"ENGINE on captured audio took {sw.ElapsedMilliseconds} ms: '{transcript}'");
            if (!m.Success) Log(all);
        }
        catch (Exception ex) { Log($"AUDIO failed: {ex.GetType().Name}: {ex.Message}"); }

        // 4. Paste at the cursor
        string toPaste = string.IsNullOrWhiteSpace(transcript) ? "Loqui probe text." : transcript;
        Clip.Set(toPaste);
        Focus(np);
        Thread.Sleep(150);
        Kb.Chord(Kb.VK_CONTROL, Kb.VK_V);
        Thread.Sleep(800);
        var got = ReadNotepad(np);
        Log($"PASTE: Notepad now holds: '{got}'");
        Log($"PASTE: matches what was put on the clipboard: {got.Trim() == toPaste.Trim()}");
        Screenshot(Path.Combine(outDir, "desktop.png"));
        File.WriteAllText(Path.Combine(outDir, "report.txt"), report.ToString());
        try { notepad.Kill(); } catch { }
        hook.Stop();
        return 0;
    }

    // --- Notepad ---
    static IntPtr FindNotepad(Process p)
    {
        if (p.MainWindowHandle != IntPtr.Zero) return p.MainWindowHandle;
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, _) =>
        {
            var c = new StringBuilder(256); GetClassName(h, c, 256);
            if (c.ToString() == "Notepad" && IsWindowVisible(h)) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    static string ReadNotepad(IntPtr top)
    {
        foreach (var cls in new[] { "Edit", "RichEditD2DPT" })
        {
            var edit = FindChild(top, cls);
            if (edit == IntPtr.Zero) continue;
            int len = (int)SendMessage(edit, 0x000E, IntPtr.Zero, IntPtr.Zero); // WM_GETTEXTLENGTH
            var sb = new StringBuilder(len + 1);
            SendMessageText(edit, 0x000D, (IntPtr)(len + 1), sb); // WM_GETTEXT
            return sb.ToString();
        }
        return "<no edit control found>";
    }

    static IntPtr FindChild(IntPtr parent, string cls)
    {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(parent, (h, _) =>
        {
            var c = new StringBuilder(256); GetClassName(h, c, 256);
            if (c.ToString() == cls) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    static void Focus(IntPtr h)
    {
        // Alt tap lets a background process take the foreground.
        Kb.Tap(Kb.VK_MENU);
        ShowWindow(h, 5);
        SetForegroundWindow(h);
        Thread.Sleep(300);
    }

    static string DesktopName()
    {
        var d = OpenInputDesktop(0, false, 0x0001);
        if (d == IntPtr.Zero) return $"none (error {Marshal.GetLastWin32Error()})";
        var sb = new byte[256];
        GetUserObjectInformation(d, 2, sb, 256, out int n);
        return Encoding.Unicode.GetString(sb, 0, Math.Max(0, n - 2));
    }

    static void Screenshot(string path)
    {
        try
        {
            int w = GetSystemMetrics(0), h = GetSystemMetrics(1);
            using var bmp = new System.Drawing.Bitmap(w, h);
            using (var g = System.Drawing.Graphics.FromImage(bmp)) g.CopyFromScreen(0, 0, 0, 0, bmp.Size);
            bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
        }
        catch (Exception ex) { Console.WriteLine($"screenshot failed: {ex.Message}"); }
    }

    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")] static extern IntPtr SendMessageText(IntPtr h, int m, IntPtr w, StringBuilder l);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr OpenInputDesktop(uint f, bool i, uint a);
    [DllImport("user32.dll")] static extern bool GetUserObjectInformation(IntPtr h, int i, byte[] b, int n, out int needed);
}

static class Kb
{
    public const ushort VK_CONTROL = 0x11, VK_SHIFT = 0x10, VK_MENU = 0x12, VK_SPACE = 0x20, VK_V = 0x56;

    public static void Chord(params ushort[] keys)
    {
        var list = new List<INPUT>();
        foreach (var k in keys) list.Add(Key(k, false));
        for (int i = keys.Length - 1; i >= 0; i--) list.Add(Key(keys[i], true));
        uint sent = SendInput((uint)list.Count, list.ToArray(), Marshal.SizeOf<INPUT>());
        Console.WriteLine($"  SendInput sent {sent}/{list.Count} (error {Marshal.GetLastWin32Error()})");
    }
    public static void Tap(ushort k) => SendInput(2, new[] { Key(k, false), Key(k, true) }, Marshal.SizeOf<INPUT>());

    static INPUT Key(ushort vk, bool up) => new INPUT { type = 1, u = new InputUnion { ki = new KEYBDINPUT { wVk = vk, dwFlags = up ? 2u : 0u } } };

    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public InputUnion u; }
    [StructLayout(LayoutKind.Explicit)] struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] i, int size);
}

/// The clipboard, set with the two formats that keep it out of Windows clipboard history and cloud sync.
static class Clip
{
    public static void Set(string text)
    {
        for (int i = 0; i < 10 && !OpenClipboard(IntPtr.Zero); i++) Thread.Sleep(50);
        EmptyClipboard();
        var bytes = Encoding.Unicode.GetBytes(text + "\0");
        var h = Marshal.AllocHGlobal(bytes.Length);
        Marshal.Copy(bytes, 0, h, bytes.Length);
        SetClipboardData(13, h); // CF_UNICODETEXT
        foreach (var fmt in new[] { "CanIncludeInClipboardHistory", "CanUploadToCloudClipboard" })
        {
            uint id = RegisterClipboardFormat(fmt);
            var z = Marshal.AllocHGlobal(4); Marshal.WriteInt32(z, 0);
            SetClipboardData(id, z);
        }
        CloseClipboard();
    }
    [DllImport("user32.dll")] static extern bool OpenClipboard(IntPtr h);
    [DllImport("user32.dll")] static extern bool EmptyClipboard();
    [DllImport("user32.dll")] static extern bool CloseClipboard();
    [DllImport("user32.dll")] static extern IntPtr SetClipboardData(uint f, IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint RegisterClipboardFormat(string n);
}

/// A low-level keyboard hook on its own thread with a message loop, the way the app would run it.
sealed class HookThread
{
    public readonly AutoResetEvent Fired = new(false);
    public bool SawInjected;
    Thread? thread; uint threadId; IntPtr hook; HookProc? proc;
    bool ctrl, shift;

    public void Start()
    {
        thread = new Thread(() =>
        {
            threadId = GetCurrentThreadId();
            proc = Callback;
            hook = SetWindowsHookEx(13, proc, GetModuleHandle(null), 0); // WH_KEYBOARD_LL
            Console.WriteLine($"  hook installed: {hook != IntPtr.Zero}");
            while (GetMessage(out var msg, IntPtr.Zero, 0, 0) > 0) { }
            UnhookWindowsHookEx(hook);
        }) { IsBackground = true };
        thread.Start();
    }
    public void Stop() => PostThreadMessage(threadId, 0x0012, IntPtr.Zero, IntPtr.Zero);

    IntPtr Callback(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0)
        {
            var k = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
            bool down = wParam == 0x0100 || wParam == 0x0104;
            if (k.vkCode is 0xA2 or 0xA3 or 0x11) ctrl = down;
            if (k.vkCode is 0xA0 or 0xA1 or 0x10) shift = down;
            if (k.vkCode == 0x20 && ctrl && shift)
            {
                if (down) { SawInjected = (k.flags & 0x10) != 0; Fired.Set(); }
                return (IntPtr)1; // swallow, so the app underneath never sees it
            }
        }
        return CallNextHookEx(hook, code, wParam, lParam);
    }

    delegate IntPtr HookProc(int code, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr h; public uint m; public IntPtr w, l; public uint t; public int x, y; }
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc p, IntPtr mod, uint tid);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int c, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint a, uint b);
    [DllImport("user32.dll")] static extern bool PostThreadMessage(uint t, uint m, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string? n);
}
