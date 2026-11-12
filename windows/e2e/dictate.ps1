# Drives the dictation checks on a GitHub Windows computer: makes speech with
# Windows' own voice, opens Notepad, presses the shortcut the way a keyboard
# does, plays the speech into the virtual sound cable, and reads back what
# landed. It also watches loqui's bubble, its tray icon, the clipboard, its
# network connections and its memory. Nothing reaches inside loqui.
#
# Usage: powershell -File dictate.ps1 <verb> [args]. Each verb prints one JSON
# line, and exits non-zero with {"error": ...} when it can't do its job.
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Verb,
  [string]$Text,
  [string]$Wav,
  [string]$Spec = 'ctrl+shift+space',
  [string]$Mode = 'tap',
  [long]$Hwnd,
  [int]$ProcessId,
  [int]$After = 500,
  [int]$Ms = 3000,
  [int]$HoldMs = 0,
  [int]$Samples = 6,
  [string]$Shot,
  [string]$Out,
  [string]$StopFile,
  [string]$Dirs,
  [string]$Since,
  [string]$Exe,
  [switch]$NoPlay
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech, System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes
Add-Type -ReferencedAssemblies System.Drawing, System.Windows.Forms -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class Dk {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
  [StructLayout(LayoutKind.Sequential)] struct NOTIFYICONIDENTIFIER { public uint cbSize; public IntPtr hWnd; public uint uID; public Guid guidItem; }
  [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public KEYBDINPUT ki; public long pad; }
  [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }
  delegate bool EnumProc(IntPtr h, IntPtr l);

  [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] i, int size);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
  [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO i);
  [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")] static extern IntPtr SendMessageText(IntPtr h, int m, IntPtr w, StringBuilder l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")] static extern IntPtr SendMessageSet(IntPtr h, int m, IntPtr w, string l);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("shell32.dll")] static extern int Shell_NotifyIconGetRect(ref NOTIFYICONIDENTIFIER id, out RECT rect);
  [DllImport("user32.dll")] static extern bool OpenClipboard(IntPtr h);
  [DllImport("user32.dll")] static extern bool CloseClipboard();
  [DllImport("user32.dll")] static extern uint EnumClipboardFormats(uint f);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClipboardFormatName(uint f, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern IntPtr GetClipboardData(uint f);
  [DllImport("kernel32.dll")] static extern IntPtr GlobalLock(IntPtr h);
  [DllImport("kernel32.dll")] static extern bool GlobalUnlock(IntPtr h);
  [DllImport("kernel32.dll")] static extern UIntPtr GlobalSize(IntPtr h);

  // ---- Keys, sent like a keyboard (not marked as loqui's own) ----
  static INPUT Key(ushort vk, ushort scan, uint flags) {
    var i = new INPUT(); i.type = 1; i.ki.wVk = vk; i.ki.wScan = scan; i.ki.dwFlags = flags; return i;
  }
  static void Send(List<INPUT> list) {
    if (list.Count == 0) return;
    SendInput((uint)list.Count, list.ToArray(), Marshal.SizeOf(typeof(INPUT)));
  }
  public static void Down(ushort[] keys) { var l = new List<INPUT>(); foreach (var k in keys) l.Add(Key(k, 0, 0)); Send(l); }
  public static void Up(ushort[] keys) { var l = new List<INPUT>(); for (int i = keys.Length - 1; i >= 0; i--) l.Add(Key(keys[i], 0, 2)); Send(l); }
  public static void Tap(ushort[] keys) { Down(keys); Thread.Sleep(40); Up(keys); }
  /// Holds the chord for `ms`, repeating the last key every 33 ms as a held key does.
  public static void Hold(ushort[] keys, int ms) {
    Down(keys);
    var sw = Stopwatch.StartNew();
    var last = new List<INPUT>(); last.Add(Key(keys[keys.Length - 1], 0, 0));
    Thread.Sleep(500);
    while (sw.ElapsedMilliseconds < ms) { Send(last); Thread.Sleep(33); }
    Up(keys);
  }
  public static void Type(string text) {
    var l = new List<INPUT>();
    foreach (char c in text) { l.Add(Key(0, c, 4)); l.Add(Key(0, c, 4 | 2)); }   // KEYEVENTF_UNICODE
    Send(l);
  }

  // ---- Windows ----
  /// Brings a window to the front. Windows only lets the process that sent the
  /// last input do that, so an unassigned key is pressed under Alt first. A bare
  /// Alt tap would also work, but it opens Notepad's menu bar, which then eats
  /// the next key or paste.
  public static void Focus(IntPtr h) {
    if (GetForegroundWindow() == h) return;
    var l = new List<INPUT>();
    l.Add(Key(0x12, 0, 0)); l.Add(Key(0xE8, 0, 0)); l.Add(Key(0xE8, 0, 2)); l.Add(Key(0x12, 0, 2));
    Send(l);
    ShowWindow(h, 5);
    SetForegroundWindow(h);
    Thread.Sleep(300);
  }
  public static string ClassOf(IntPtr h) { var c = new StringBuilder(256); GetClassName(h, c, 256); return c.ToString(); }
  public static string TitleOf(IntPtr h) { var t = new StringBuilder(512); GetWindowText(h, t, 512); return t.ToString(); }
  public static IntPtr TopWindow(string cls) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate (IntPtr h, IntPtr l) {
      if (ClassOf(h) == cls && IsWindowVisible(h)) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  static IntPtr Child(IntPtr parent, string cls) {
    IntPtr found = IntPtr.Zero;
    EnumChildWindows(parent, delegate (IntPtr h, IntPtr l) {
      if (ClassOf(h) == cls) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  static IntPtr Editor(IntPtr top) {
    foreach (var cls in new[] { "Edit", "RichEditD2DPT" }) { var e = Child(top, cls); if (e != IntPtr.Zero) return e; }
    return IntPtr.Zero;
  }
  /// Notepad's text, or null if its editor can't be found.
  public static string NotepadText(IntPtr top) {
    var e = Editor(top);
    if (e == IntPtr.Zero) return null;
    int len = (int)SendMessage(e, 0x000E, IntPtr.Zero, IntPtr.Zero);
    var sb = new StringBuilder(len + 1);
    SendMessageText(e, 0x000D, (IntPtr)(len + 1), sb);
    return sb.ToString();
  }
  public static bool ClearNotepad(IntPtr top) {
    var e = Editor(top);
    if (e == IntPtr.Zero) return false;
    SendMessageSet(e, 0x000C, IntPtr.Zero, "");
    return true;
  }
  public static RECT Rect(IntPtr h) { RECT r; GetWindowRect(h, out r); return r; }
  public static RECT WorkArea(IntPtr h) {
    var i = new MONITORINFO(); i.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
    GetMonitorInfo(MonitorFromWindow(h, 1), ref i);
    return i.rcWork;
  }

  /// loqui's bubble: its window titled "loqui <phase>".
  public static IntPtr Bubble(int pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate (IntPtr h, IntPtr l) {
      uint owner; GetWindowThreadProcessId(h, out owner);
      if (owner == (uint)pid && TitleOf(h).StartsWith("loqui ")) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static string BubbleState(int pid) {
    var b = Bubble(pid);
    if (b == IntPtr.Zero) return "none";
    return IsWindowVisible(b) ? TitleOf(b) : "loqui hidden";
  }

  /// Watches, every 20 ms, which window has the keyboard and what the bubble shows.
  public class Sampler {
    IntPtr target; int pid; volatile bool stop; Thread thread;
    public Stopwatch Clock = Stopwatch.StartNew();
    public List<string> Changes = new List<string>();
    public bool LostForeground;
    public string LostTo = "";
    public RECT ListeningRect;
    public bool SawListening;
    public Sampler(IntPtr target, int pid) { this.target = target; this.pid = pid; }
    public void Start() { thread = new Thread(Run); thread.IsBackground = true; thread.Start(); }
    public void Stop() { stop = true; thread.Join(); }
    void Run() {
      string last = null;
      while (!stop) {
        var fg = GetForegroundWindow();
        bool kept = fg == target;
        if (!kept && !LostForeground) { LostForeground = true; LostTo = ClassOf(fg) + " " + TitleOf(fg); }
        string state = BubbleState(pid);
        if (state == "loqui listening" && !SawListening) { SawListening = true; ListeningRect = Rect(Bubble(pid)); }
        string key = (kept ? "notepad" : "OTHER") + "|" + state;
        if (key != last) { lock (Changes) Changes.Add(Clock.ElapsedMilliseconds + "|" + key); last = key; }
        Thread.Sleep(20);
      }
    }
  }

  // ---- Tray icon ----
  static IntPtr TrayWindow(int pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate (IntPtr h, IntPtr l) {
      uint owner; GetWindowThreadProcessId(h, out owner);
      if (owner == (uint)pid && ClassOf(h) == "tray_icon_app") { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static bool IconRect(int pid, out RECT rect) {
    rect = new RECT();
    var h = TrayWindow(pid);
    if (h == IntPtr.Zero) return false;
    for (uint uid = 0; uid < 9; uid++) {
      var id = new NOTIFYICONIDENTIFIER(); id.cbSize = (uint)Marshal.SizeOf(typeof(NOTIFYICONIDENTIFIER)); id.hWnd = h; id.uID = uid;
      if (Shell_NotifyIconGetRect(ref id, out rect) == 0) return true;
    }
    return false;
  }
  /// How magenta a screen rectangle is: the recording icon is magenta (bright,
  /// then dim as it pulses); the idle one is grey, which scores 0.
  public static long Magenta(RECT r, string save) {
    int w = r.Right - r.Left, h = r.Bottom - r.Top;
    long n = 0;
    using (var bmp = new Bitmap(w, h)) {
      using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(r.Left, r.Top, 0, 0, bmp.Size);
      for (int x = 0; x < w; x++) for (int y = 0; y < h; y++) {
        var c = bmp.GetPixel(x, y);
        if (c.R > 100 && c.R - c.G > 60 && c.B - c.G > 20) n += c.R - c.G;
      }
      // PowerShell passes $null as "" to a string parameter.
      if (!string.IsNullOrEmpty(save)) bmp.Save(save, ImageFormat.Png);
    }
    return n;
  }

  // ---- Clipboard ----
  public static string[] ClipboardFormats() {
    var list = new List<string>();
    for (int i = 0; i < 20 && !OpenClipboard(IntPtr.Zero); i++) Thread.Sleep(50);
    try {
      uint f = 0;
      while ((f = EnumClipboardFormats(f)) != 0) {
        var name = new StringBuilder(256);
        if (GetClipboardFormatName(f, name, 256) > 0) {
          string value = "";
          IntPtr h = GetClipboardData(f);
          if (h != IntPtr.Zero && (ulong)GlobalSize(h) >= 4) { IntPtr p = GlobalLock(h); value = Marshal.ReadInt32(p).ToString(); GlobalUnlock(h); }
          list.Add(name.ToString() + "=" + value);
        } else list.Add("#" + f);
      }
    } finally { CloseClipboard(); }
    return list.ToArray();
  }

  public static bool Contains(byte[] hay, byte[] needle) {
    for (int i = 0; i + needle.Length <= hay.Length; i++) {
      int j = 0;
      while (j < needle.Length && hay[i + j] == needle[j]) j++;
      if (j == needle.Length) return true;
    }
    return false;
  }

  public static void Screenshot(string path) {
    var b = System.Windows.Forms.SystemInformation.VirtualScreen;
    using (var bmp = new Bitmap(b.Width, b.Height))
    using (var g = Graphics.FromImage(bmp)) {
      g.CopyFromScreen(b.Left, b.Top, 0, 0, bmp.Size);
      bmp.Save(path, ImageFormat.Png);
    }
  }
}
'@
[void][Dk]::SetProcessDPIAware()

function Out-Json($value) { $value | ConvertTo-Json -Compress -Depth 6; exit 0 }
function Fail($message) {
  try { if ($Shot) { [Dk]::Screenshot("$Shot-failed.png") } } catch {}
  @{ error = $message } | ConvertTo-Json -Compress; exit 1
}

$names = @{ ctrl = 0x11; shift = 0x10; alt = 0x12; space = 0x20; win = 0x5B }
function Keys([string]$spec) {
  $vks = foreach ($part in $spec.ToLower() -split '\+') {
    if ($names.ContainsKey($part)) { [uint16]$names[$part] } else { [uint16][char]$part.ToUpper() }
  }
  return [uint16[]]$vks
}

function Rect-Json($r) { @{ left = $r.Left; top = $r.Top; right = $r.Right; bottom = $r.Bottom } }

# Notepad's text, from its editor or, for Windows 11's newer Notepad, from UI Automation.
function Notepad-Text([IntPtr]$h) {
  $t = [Dk]::NotepadText($h)
  if ($null -ne $t) { return $t }
  $root = [System.Windows.Automation.AutomationElement]::FromHandle($h)
  $doc = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)))
  if (-not $doc) { return '' }
  $pattern = $null
  if ($doc.TryGetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern, [ref]$pattern)) { return $pattern.DocumentRange.GetText(-1) }
  return ''
}

# Waits for Notepad's text to change from $before and settle; returns it and how long it took.
function Wait-Text([IntPtr]$h, [string]$before, [int]$timeout) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $text = $before
  while ($sw.ElapsedMilliseconds -lt $timeout) {
    $text = Notepad-Text $h
    if ($text -ne $before) { break }
    Start-Sleep -Milliseconds 20
  }
  $ms = $sw.ElapsedMilliseconds
  if ($text -ne $before) {
    # Let a paste finish arriving.
    do { $settled = $text; Start-Sleep -Milliseconds 150; $text = Notepad-Text $h } while ($text -ne $settled)
  }
  return @{ text = $text; ms = $(if ($text -ne $before) { $ms } else { -1 }) }
}

function Tree-Ids([int]$root) {
  $all = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId
  $ids = @($root); $grew = $true
  while ($grew) {
    $grew = $false
    foreach ($p in $all) { if ($ids -contains $p.ParentProcessId -and -not ($ids -contains $p.ProcessId)) { $ids += $p.ProcessId; $grew = $true } }
  }
  return $ids
}

switch ($Verb) {
  'make-wav' {
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(16000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
    $s.SetOutputToWaveFile($Wav, $fmt)
    $s.Speak($Text)
    $s.Dispose()
    Out-Json @{ seconds = [math]::Round(((Get-Item $Wav).Length - 44) / 32000.0, 2) }
  }
  'notepad' {
    Get-Process notepad -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    Start-Process notepad.exe
    $h = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($h -eq [IntPtr]::Zero -and $sw.ElapsedMilliseconds -lt 15000) { Start-Sleep -Milliseconds 200; $h = [Dk]::TopWindow('Notepad') }
    if ($h -eq [IntPtr]::Zero) { Fail 'Notepad has no window' }
    [Dk]::Focus($h)
    Out-Json @{ hwnd = [long]$h; foreground = ([Dk]::GetForegroundWindow() -eq $h) }
  }
  'clear' {
    $h = [IntPtr]$Hwnd
    if (-not [Dk]::ClearNotepad($h)) { [Dk]::Focus($h); [Dk]::Tap((Keys 'ctrl+a')); [Dk]::Tap([uint16[]]@(0x2E)) }
    [Dk]::Focus($h)
    Out-Json @{ text = (Notepad-Text $h) }
  }
  'read' { Out-Json @{ text = (Notepad-Text ([IntPtr]$Hwnd)) } }
  'type' {
    [Dk]::Focus([IntPtr]$Hwnd)
    [Dk]::Type($Text)
    Start-Sleep -Milliseconds 300
    Out-Json @{ text = (Notepad-Text ([IntPtr]$Hwnd)) }
  }
  'keys' {
    $h = [IntPtr]$Hwnd
    [Dk]::Focus($h)
    if ($HoldMs -gt 0) { [Dk]::Hold((Keys $Spec), $HoldMs) } else { [Dk]::Tap((Keys $Spec)) }
    Start-Sleep -Milliseconds 400
    Out-Json @{ text = (Notepad-Text $h); bubble = [Dk]::BubbleState($ProcessId) }
  }
  'dictate' {
    # Shortcut, speech into the cable, shortcut again (or hold and let go);
    # then how long the text took to land, and what the bubble did meanwhile.
    # With -Exe, loqui is started first and the shortcut pressed 1 s later.
    $h = [IntPtr]$Hwnd
    if ($Exe) {
      $started = [Diagnostics.Stopwatch]::StartNew()
      $ProcessId = (Start-Process -FilePath $Exe -PassThru).Id
    }
    [Dk]::Focus($h)
    $before = Notepad-Text $h
    $keys = Keys $Spec
    $sampler = New-Object Dk+Sampler($h, $ProcessId)
    $sampler.Start()
    $player = New-Object System.Media.SoundPlayer($Wav)
    if (-not $NoPlay) { $player.Load() }
    $seconds = ((Get-Item $Wav).Length - 44) / 32000.0
    if ($Exe) { while ($started.ElapsedMilliseconds -lt 1000) { Start-Sleep -Milliseconds 10 } }
    $pressedAt = if ($Exe) { $started.ElapsedMilliseconds } else { 0 }
    if ($Mode -eq 'hold') { [Dk]::Down($keys) } else { [Dk]::Tap($keys) }
    Start-Sleep -Milliseconds 300
    if (-not $NoPlay) { $player.Play() }
    $mid = [int]($seconds * 500)
    Start-Sleep -Milliseconds $mid
    if ($Shot) { [Dk]::Screenshot("$Shot-listening.png") }
    Start-Sleep -Milliseconds ([int]($seconds * 1000) - $mid + $After)
    $stoppedAt = $sampler.Clock.ElapsedMilliseconds
    if ($Mode -eq 'hold') { [Dk]::Up($keys) } else { [Dk]::Tap($keys) }
    $landed = Wait-Text $h $before 20000
    if ($Shot) { [Dk]::Screenshot("$Shot-pasted.png") }
    Start-Sleep -Milliseconds 1500
    $sampler.Stop()
    $work = [Dk]::WorkArea($h)
    Out-Json @{
      text = $landed.text; ms = $landed.ms; before = $before; stoppedAt = $stoppedAt
      changes = @($sampler.Changes); foregroundKept = (-not $sampler.LostForeground); lostTo = $sampler.LostTo
      listening = (Rect-Json $sampler.ListeningRect); work = (Rect-Json $work)
      pid = $ProcessId; pressedAfterStartMs = $pressedAt
    }
  }
  'tap-watch' {
    # Tap the shortcut and watch the bubble for $Ms, without speaking.
    $h = [IntPtr]$Hwnd
    [Dk]::Focus($h)
    $before = Notepad-Text $h
    $sampler = New-Object Dk+Sampler($h, $ProcessId)
    $sampler.Start()
    [Dk]::Tap((Keys $Spec))
    Start-Sleep -Milliseconds 700
    if ($Shot) { [Dk]::Screenshot("$Shot.png") }
    Start-Sleep -Milliseconds ([math]::Max(0, $Ms - 700))
    $sampler.Stop()
    Out-Json @{ before = $before; text = (Notepad-Text $h); changes = @($sampler.Changes); foregroundKept = (-not $sampler.LostForeground) }
  }
  'tray' {
    # Make sure loqui's icon shows on the taskbar, not behind the hidden-icons arrow.
    Get-ChildItem 'HKCU:\Control Panel\NotifyIconSettings' -ErrorAction SilentlyContinue |
      Where-Object { (Get-ItemProperty $_.PSPath).ExecutablePath -like '*\loqui.exe' } |
      ForEach-Object { Set-ItemProperty $_.PSPath -Name IsPromoted -Value 1 -Type DWord }
    $rect = New-Object Dk+RECT
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not [Dk]::IconRect($ProcessId, [ref]$rect) -and $sw.ElapsedMilliseconds -lt 5000) { Start-Sleep -Milliseconds 200 }
    if ($rect.Right -le $rect.Left) { Fail 'loqui has no icon in the notification area' }
    $counts = @()
    for ($i = 0; $i -lt $Samples; $i++) {
      $save = if ($Shot -and $i -eq 0) { "$Shot.png" } else { $null }
      $counts += [Dk]::Magenta($rect, $save)
      Start-Sleep -Milliseconds 150
    }
    Out-Json @{ magenta = $counts; rect = (Rect-Json $rect) }
  }
  'clipboard' {
    $formats = [Dk]::ClipboardFormats()
    Out-Json @{ text = (Get-Clipboard -Raw); formats = @($formats) }
  }
  'memory' {
    $ids = Tree-Ids $ProcessId
    $procs = Get-Process -Id $ids -ErrorAction SilentlyContinue
    $own = $procs | Where-Object Id -eq $ProcessId
    Out-Json @{
      loquiPrivateMB = [math]::Round($own.PrivateMemorySize64 / 1MB); loquiWorkingSetMB = [math]::Round($own.WorkingSet64 / 1MB)
      allPrivateMB = [math]::Round(($procs | Measure-Object PrivateMemorySize64 -Sum).Sum / 1MB)
      allWorkingSetMB = [math]::Round(($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB)
      processes = @($procs | ForEach-Object { $_.ProcessName })
    }
  }
  'net-watch' {
    # Every 250 ms until $StopFile appears: every TCP connection owned by loqui
    # or its web view processes, one JSON line per new one.
    $seen = @{}
    $rounds = 0
    while (-not (Test-Path $StopFile)) {
      $ids = Tree-Ids $ProcessId
      foreach ($c in Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $ids -contains $_.OwningProcess }) {
        $key = "$($c.LocalAddress):$($c.LocalPort)>$($c.RemoteAddress):$($c.RemotePort) $($c.State)"
        if (-not $seen[$key]) {
          $seen[$key] = 1
          $name = (Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue).ProcessName
          @{ local = "$($c.LocalAddress):$($c.LocalPort)"; remote = "$($c.RemoteAddress)"; port = $c.RemotePort; state = "$($c.State)"; process = $name } |
            ConvertTo-Json -Compress | Add-Content -Path $Out
        }
      }
      $rounds++
      Start-Sleep -Milliseconds 250
    }
    Out-Json @{ rounds = $rounds; connections = $seen.Count }
  }
  'find-text' {
    # Every file under these folders changed since $Since that holds $Text, as UTF-8 or UTF-16.
    $since = [DateTime]::Parse($Since)
    $needles = @([Text.Encoding]::UTF8.GetBytes($Text), [Text.Encoding]::Unicode.GetBytes($Text))
    $hits = @(); $searched = 0
    foreach ($dir in ($Dirs -split ';' | Where-Object { $_ -and (Test-Path $_) })) {
      foreach ($f in Get-ChildItem $dir -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $since }) {
        $searched++
        try { $bytes = [IO.File]::ReadAllBytes($f.FullName) } catch { $bytes = [byte[]]@() }
        foreach ($n in $needles) { if ([Dk]::Contains($bytes, $n)) { $hits += $f.FullName; break } }
      }
    }
    Out-Json @{ hits = @($hits); searched = $searched }
  }
  default { Fail "unknown verb $Verb" }
}
