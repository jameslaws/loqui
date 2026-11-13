# Drives the real Windows desktop for the acceptance and screen checks:
# installs the test build, starts it, clicks the loqui icon by the clock, reads
# and chooses menu items (Recent's too), reads and clicks loqui's windows
# through Windows' accessibility interface, presses keys, switches Windows
# between light and dark, and takes screenshots. Every action is a real mouse
# click, key press or a question to Windows; nothing reaches inside loqui.
#
# Usage: powershell -File desktop.ps1 <verb> [args]. Each verb prints one JSON
# line, and exits non-zero with {"error": ...} when it can't do its job.
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Verb,
  [string]$Installer,
  [string]$Exe,
  [int]$ProcessId,
  [string]$Item,
  [string]$Shot,
  [string]$Pids,
  [string]$Title,
  [string]$Name,
  [string]$Keys,
  [string]$Mode,
  [int]$Wait = 10000
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, WindowsBase, System.Drawing, System.Windows.Forms
Add-Type -ReferencedAssemblies System.Drawing, System.Windows.Forms -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public static class Desk {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] struct NOTIFYICONIDENTIFIER { public uint cbSize; public IntPtr hWnd; public uint uID; public Guid guidItem; }
  delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);

  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("shell32.dll")] static extern int Shell_NotifyIconGetRect(ref NOTIFYICONIDENTIFIER id, out RECT rect);

  /// The hidden window loqui's tray icon is registered under.
  public static IntPtr TrayWindow(int pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate (IntPtr h, IntPtr l) {
      var cls = new StringBuilder(256);
      GetClassName(h, cls, 256);
      uint owner;
      GetWindowThreadProcessId(h, out owner);
      if (owner == (uint)pid && cls.ToString() == "tray_icon_app") { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }

  /// Asks the shell where the icon is. Succeeds only while the icon is in the notification area.
  public static bool IconRect(IntPtr hwnd, uint uid, out RECT rect) {
    var id = new NOTIFYICONIDENTIFIER();
    id.cbSize = (uint)Marshal.SizeOf(typeof(NOTIFYICONIDENTIFIER));
    id.hWnd = hwnd;
    id.uID = uid;
    return Shell_NotifyIconGetRect(ref id, out rect) == 0;
  }

  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern int GetMenuItemCount(IntPtr menu);
  [DllImport("user32.dll")] static extern uint GetMenuState(IntPtr menu, uint item, uint flags);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetMenuString(IntPtr menu, uint item, StringBuilder text, int max, uint flags);
  [DllImport("user32.dll")] static extern bool GetMenuItemRect(IntPtr hwnd, IntPtr menu, uint item, out RECT rect);

  /// Every open pop-up menu's window, the newest (a submenu) first.
  public static System.Collections.Generic.List<IntPtr> MenuWindows() {
    var found = new System.Collections.Generic.List<IntPtr>();
    EnumWindows(delegate (IntPtr h, IntPtr l) {
      var cls = new StringBuilder(64);
      GetClassName(h, cls, 64);
      if (cls.ToString() == "#32768" && IsWindowVisible(h)) found.Add(h);
      return true;
    }, IntPtr.Zero);
    return found;
  }

  public static IntPtr MenuWindow() {
    var all = MenuWindows();
    return all.Count == 0 ? IntPtr.Zero : all[all.Count - 1];
  }

  static IntPtr MenuOf(IntPtr w) {
    return w == IntPtr.Zero ? IntPtr.Zero : SendMessage(w, 0x01E1, IntPtr.Zero, IntPtr.Zero); // MN_GETHMENU
  }

  static IntPtr OpenMenu() { return MenuOf(MenuWindow()); }

  /// The newest open menu: a submenu if one is open.
  public static string[] SubmenuItems() {
    var all = MenuWindows();
    return all.Count < 2 ? new string[0] : ItemsOf(MenuOf(all[0]));
  }

  /// The open menu's items as "name|enabled", separators left out.
  public static string[] MenuItems() { return ItemsOf(OpenMenu()); }

  static string[] ItemsOf(IntPtr menu) {
    var items = new System.Collections.Generic.List<string>();
    if (menu == IntPtr.Zero) return items.ToArray();
    int count = GetMenuItemCount(menu);
    for (uint i = 0; i < count; i++) {
      uint state = GetMenuState(menu, i, 0x400);           // MF_BYPOSITION
      if ((state & 0x800) != 0) continue;                  // MF_SEPARATOR
      var text = new StringBuilder(256);
      GetMenuString(menu, i, text, 256, 0x400);
      bool enabled = (state & 0x3) == 0;                   // not MF_GRAYED or MF_DISABLED
      items.Add(text.ToString() + "|" + (enabled ? "1" : "0"));
    }
    return items.ToArray();
  }

  /// Clicks the item with this name in any open menu, newest first. False if there is none.
  public static bool ClickMenuItem(string name) {
    foreach (var w in MenuWindows()) {
      IntPtr menu = MenuOf(w);
      if (menu == IntPtr.Zero) continue;
      int count = GetMenuItemCount(menu);
      for (uint i = 0; i < count; i++) {
        var text = new StringBuilder(256);
        GetMenuString(menu, i, text, 256, 0x400);
        RECT r;
        if (text.ToString() == name && GetMenuItemRect(IntPtr.Zero, menu, i, out r)) {
          Click((r.Left + r.Right) / 2, (r.Top + r.Bottom) / 2);
          return true;
        }
      }
    }
    return false;
  }

  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hwnd, int cmd);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);

  /// Brings a window to the front: an unassigned key pressed under Alt first
  /// lets this process hand over the foreground (a bare Alt would open menus).
  public static void Front(IntPtr h) {
    if (GetForegroundWindow() == h) return;
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    keybd_event(0xE8, 0, 0, UIntPtr.Zero);
    keybd_event(0xE8, 0, 2, UIntPtr.Zero);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
    ShowWindow(h, 9);   // SW_RESTORE
    SetForegroundWindow(h);
    System.Threading.Thread.Sleep(300);
  }

  /// Presses keys together and lets them go, like a person: "ctrl+alt+d".
  public static void Chord(byte[] vks) {
    foreach (var vk in vks) keybd_event(vk, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(40);
    for (int i = vks.Length - 1; i >= 0; i--) keybd_event(vks[i], 0, 2, UIntPtr.Zero);
  }

  /// Tells every program the light or dark setting changed, as Settings does.
  public static void ThemeChanged() {
    IntPtr result;
    SendMessageTimeout((IntPtr)0xFFFF, 0x001A, IntPtr.Zero, "ImmersiveColorSet", 0x0002, 5000, out result);
  }

  public static void Click(int x, int y) {
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(80);
    mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
    mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
  }

  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string name);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
  [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

  /// True when the taskbar is showing and nothing covers it, so the desktop is in use.
  public static bool TaskbarOnTop() {
    IntPtr bar = FindWindow("Shell_TrayWnd", null);
    RECT r;
    if (bar == IntPtr.Zero || !IsWindowVisible(bar) || !GetWindowRect(bar, out r)) return false;
    var p = new POINT();
    p.X = (r.Left + r.Right) / 2; p.Y = (r.Top + r.Bottom) / 2;
    return GetAncestor(WindowFromPoint(p), 2) == bar;   // GA_ROOT
  }

  public static void Enter() {
    keybd_event(0x0D, 0, 0, UIntPtr.Zero);
    keybd_event(0x0D, 0, 2, UIntPtr.Zero);
  }

  public static void Escape() {
    keybd_event(0x1B, 0, 0, UIntPtr.Zero);
    keybd_event(0x1B, 0, 2, UIntPtr.Zero);
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
[void][Desk]::SetProcessDPIAware()

$UIA = [System.Windows.Automation.AutomationElement]
$Tree = [System.Windows.Automation.TreeScope]
$Prop = [System.Windows.Automation.AutomationElement]

function Out-Json($value) { $value | ConvertTo-Json -Compress -Depth 6; exit 0 }
function Fail($message) {
  try { if ($Shot) { [Desk]::Screenshot(($Shot -replace '\.png$', '-failed.png')) } } catch {}
  @{ error = $message } | ConvertTo-Json -Compress; exit 1
}

function Wait-Until([int]$ms, [scriptblock]$probe) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $ms) {
    $r = & $probe
    if ($r) { return $r }
    Start-Sleep -Milliseconds 40
  }
  return $null
}

# Windows' own record of loqui's tray icon: Explorer adds an entry under
# NotifyIconSettings for each program's icon as soon as it is shown.
function Icon-Settings {
  Get-ChildItem 'HKCU:\Control Panel\NotifyIconSettings' -ErrorAction SilentlyContinue |
    Where-Object { (Get-ItemProperty $_.PSPath).ExecutablePath -like '*\loqui.exe' }
}

# The shell's answer for loqui's icon. Where it is, when the shell will say
# (on the taskbar, or the hidden icons arrow), and whether Windows has it at all.
function Find-Icon([int]$procId) {
  $hwnd = [Desk]::TrayWindow($procId)
  if ($hwnd -eq [IntPtr]::Zero) { return $null }
  foreach ($uid in 0..8) {
    $rect = New-Object Desk+RECT
    if ([Desk]::IconRect($hwnd, $uid, [ref]$rect)) {
      return @{ how = 'shell position'; rect = $rect }
    }
  }
  if (Icon-Settings) { return @{ how = 'shell record'; rect = $null } }
  return $null
}

# What the taskbar shows, for failure messages.
function Taskbar-Names {
  $taskbar = Find-Taskbar
  if (-not $taskbar) { return 'no taskbar found' }
  $names = $taskbar.FindAll($Tree::Descendants, [System.Windows.Automation.Condition]::TrueCondition) |
    ForEach-Object { $_.Current.Name } | Where-Object { $_ }
  return ($names -join ' | ')
}

function Find-Taskbar {
  $UIA::RootElement.FindFirst($Tree::Children,
    (New-Object System.Windows.Automation.PropertyCondition($Prop::ClassNameProperty, 'Shell_TrayWnd')))
}

function Named($root, [string]$name) {
  $cond = New-Object System.Windows.Automation.PropertyCondition($Prop::NameProperty, $name,
    [System.Windows.Automation.PropertyConditionFlags]::IgnoreCase)
  return $root.FindFirst($Tree::Descendants, $cond)
}

function Click-Element($el) {
  $r = $el.Current.BoundingRectangle
  [Desk]::Click([int]($r.X + $r.Width / 2), [int]($r.Y + $r.Height / 2))
}

function Open-Menu {
  if (Find-Menu) { return @{ how = 'already open' } }
  $icon = Find-Icon $ProcessId
  if (-not $icon) { Fail "loqui has no icon in the notification area. Taskbar: $(Taskbar-Names)" }

  # Windows 11 puts a new program's icon behind the hidden icons arrow. Ask it
  # to show loqui's on the taskbar, as the taskbar settings page would.
  foreach ($entry in Icon-Settings) { Set-ItemProperty $entry.PSPath -Name IsPromoted -Value 1 -Type DWord }
  Start-Sleep -Milliseconds 500
  $shown = Wait-Until 3000 { $i = Find-Icon $ProcessId; if ($i.rect) { $i } }
  if ($shown) {
    $r = $shown.rect
    [Desk]::Click([int](($r.Left + $r.Right) / 2), [int](($r.Top + $r.Bottom) / 2))
    if (Wait-Until 2000 { Find-Menu }) { return @{ how = 'on the taskbar, where the shell says it is' } }
  }
  $loqui = Wait-Until 2000 { $t = Find-Taskbar; if ($t) { Named $t 'loqui' } }
  $how = 'on the taskbar'

  if (-not $loqui) {
    # Still hidden: open the hidden icons and pick loqui there.
    $taskbar = Find-Taskbar
    $arrow = if ($taskbar) { Named $taskbar 'Show hidden icons' }
    if ($arrow) { Click-Element $arrow }
    elseif ($icon.rect) {
      # The shell reports a hidden icon's position as the arrow's.
      $r = $icon.rect
      [Desk]::Click([int](($r.Left + $r.Right) / 2), [int](($r.Top + $r.Bottom) / 2))
    }
    else { Fail "can't find loqui's icon or the hidden icons arrow. Taskbar: $(Taskbar-Names)" }
    $loqui = Wait-Until 8000 { Named $UIA::RootElement 'loqui' }
    if (-not $loqui) { Fail "opened the hidden icons, but loqui is not among them. Taskbar: $(Taskbar-Names)" }
    $how = 'in the hidden icons'
  }
  Click-Element $loqui
  if (-not (Wait-Until 3000 { Find-Menu })) { Fail "clicked loqui's icon ($how) but no menu opened" }
  return @{ how = $how }
}

function Find-Menu { [Desk]::MenuWindow() -ne [IntPtr]::Zero }

function Menu-Items {
  $items = @()
  foreach ($entry in [Desk]::MenuItems()) {
    $name, $enabled = $entry -split '\|'
    $items += @{ name = $name; enabled = ($enabled -eq '1') }
  }
  return ,$items
}

# Windows' first sign-in screens (the privacy choices) can still be up on a
# fresh GitHub machine. Click through them the way a person would.
function Has-Taskbar { [Desk]::TaskbarOnTop() }

function Ready-Desktop {
  $did = @()
  foreach ($round in 1..6) {
    if (Has-Taskbar) { [Desk]::Escape(); return @{ did = $did; taskbar = $true } }   # Escape closes Start if it opened
    $button = $null
    foreach ($label in 'Accept', 'Next', 'Skip', 'Not now', 'Done') {
      $b = Named $UIA::RootElement $label
      if ($b -and $b.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button) { $button = $b; break }
    }
    if ($button) { Click-Element $button; $did += "clicked $($button.Current.Name)" }
    else { [Desk]::Enter(); $did += 'pressed Enter' }   # the screen's main button has focus
    Start-Sleep -Milliseconds 2500
  }
  if (Has-Taskbar) { return @{ did = $did; taskbar = $true } }

  # Still on the first sign-in screens: close them and start the desktop.
  $setup = Get-Process -Name WWAHost, CloudExperienceHostBroker, CloudExperienceHost -ErrorAction SilentlyContinue
  $setup | Stop-Process -Force -ErrorAction SilentlyContinue
  $did += "closed $(@($setup).Count) setup processes"
  if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe; $did += 'started explorer' }
  [void](Wait-Until 15000 { Has-Taskbar })
  return @{ did = $did; taskbar = (Has-Taskbar) }
}

function Window-Owners {
  (Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object { "$($_.ProcessName): $($_.MainWindowTitle)" }) -join ' | '
}

# loqui and everything it started; a child only counts if it started after
# its parent, because Windows reuses process numbers.
function Process-Tree([int]$root) {
  $all = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CreationDate
  $born = @{}; foreach ($p in $all) { $born[[int]$p.ProcessId] = $p.CreationDate }
  $ids = @($root); $grew = $true
  while ($grew) {
    $grew = $false
    foreach ($p in $all) {
      if ($ids -contains $p.ParentProcessId -and -not ($ids -contains $p.ProcessId) -and $p.CreationDate -ge $born[[int]$p.ParentProcessId]) {
        $ids += $p.ProcessId; $grew = $true
      }
    }
  }
  return ,@($all | Where-Object { $ids -contains $_.ProcessId } | ForEach-Object { @{ pid = $_.ProcessId; name = $_.Name } })
}

# One of loqui's windows, by its title.
function Find-Window([string]$title) {
  $cond = New-Object System.Windows.Automation.AndCondition(
    (New-Object System.Windows.Automation.PropertyCondition($Prop::ProcessIdProperty, $ProcessId)),
    (New-Object System.Windows.Automation.PropertyCondition($Prop::NameProperty, $title)))
  return $UIA::RootElement.FindFirst($Tree::Children, $cond)
}

# The element with this name to click: a button if there is one (a switch's
# visible label and the switch itself share a name).
function Clickable($root, [string]$name) {
  $cond = New-Object System.Windows.Automation.PropertyCondition($Prop::NameProperty, $name,
    [System.Windows.Automation.PropertyConditionFlags]::IgnoreCase)
  $all = @($root.FindAll($Tree::Descendants, $cond))
  $button = $all | Where-Object { $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button } | Select-Object -First 1
  if ($button) { return $button }
  return $all | Select-Object -First 1
}

# What a window shows: every named element, and its buttons with whether they can be used.
function Window-Contents($win) {
  $all = @($win.FindAll($Tree::Descendants, [System.Windows.Automation.Condition]::TrueCondition))
  $texts = @($all | ForEach-Object { $_.Current.Name } | Where-Object { $_ })
  $buttons = @($all | Where-Object { $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -and $_.Current.Name } |
    ForEach-Object { @{ name = $_.Current.Name; enabled = $_.Current.IsEnabled } })
  return @{ title = $win.Current.Name; texts = $texts; buttons = $buttons }
}

$vk = @{ ctrl = 0x11; shift = 0x10; alt = 0x12; space = 0x20; escape = 0x1B; enter = 0x0D; tab = 0x09; win = 0x5B }
function Key-Codes([string]$spec) {
  [byte[]]@(foreach ($part in $spec.ToLower() -split '\+') {
    if ($vk.ContainsKey($part)) { $vk[$part] }
    elseif ($part -match '^f(\d+)$') { 0x6F + [int]$Matches[1] }
    else { [byte][char]$part.ToUpper() }
  })
}

switch ($Verb) {
  'install' {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $Installer -ArgumentList '/S' -PassThru -Wait
    $candidates = @("$env:LOCALAPPDATA\loqui\loqui.exe", "$env:LOCALAPPDATA\Programs\loqui\loqui.exe")
    $exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    Out-Json @{ exitCode = $p.ExitCode; ms = $sw.ElapsedMilliseconds; exe = $exe; running = @(Get-Process loqui -ErrorAction SilentlyContinue).Count }
  }
  'start' {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $Exe -PassThru
    $icon = Wait-Until 10000 { Find-Icon $p.Id }
    $ms = $sw.ElapsedMilliseconds
    if (-not $icon) {
      $tray = [Desk]::TrayWindow($p.Id) -ne [IntPtr]::Zero
      Fail "no icon in the notification area 10 seconds after starting (pid $($p.Id), tray window: $tray, running: $(-not $p.HasExited)). Taskbar: $(Taskbar-Names)"
    }
    Out-Json @{ pid = $p.Id; ms = $ms; how = $icon.how }
  }
  'open-menu' {
    $how = Open-Menu
    Start-Sleep -Milliseconds 300
    if ($Shot) { [Desk]::Screenshot($Shot) }
    Out-Json @{ how = $how.how; items = (Menu-Items) }
  }
  'choose' {
    if (-not (Find-Menu)) { Fail 'no menu is open' }
    if (-not [Desk]::ClickMenuItem($Item)) { Fail "the menu has no '$Item' (it has: $([Desk]::MenuItems() -join ', '))" }
    Out-Json @{ chose = $Item }
  }
  'dismiss' {
    [Desk]::Escape()
    $gone = Wait-Until 2000 { -not (Find-Menu) }
    Out-Json @{ closed = [bool]$gone }
  }
  'about' {
    $cond = New-Object System.Windows.Automation.AndCondition(
      (New-Object System.Windows.Automation.PropertyCondition($Prop::ProcessIdProperty, $ProcessId)),
      (New-Object System.Windows.Automation.PropertyCondition($Prop::NameProperty, 'About loqui')))
    $win = Wait-Until 10000 { $UIA::RootElement.FindFirst($Tree::Children, $cond) }
    if (-not $win) { Fail 'no About loqui window appeared' }
    # The page is drawn by the web view, which can take a moment on first open.
    $texts = Wait-Until 15000 {
      $found = @($win.FindAll($Tree::Descendants, [System.Windows.Automation.Condition]::TrueCondition) |
        ForEach-Object { $_.Current.Name } | Where-Object { $_ })
      if ($found -match '^Version ') { ,$found }
    }
    if ($Shot) { [Desk]::Screenshot($Shot) }
    Out-Json @{ title = $win.Current.Name; texts = @($texts) }
  }
  'ready-desktop' {
    $result = Ready-Desktop
    if ($Shot) { [Desk]::Screenshot($Shot) }
    if (-not $result.taskbar) {
      Fail "the desktop has no taskbar after: $($result.did -join ', '). Explorer running: $([bool](Get-Process explorer -ErrorAction SilentlyContinue)). Windows: $(Window-Owners)"
    }
    Out-Json $result
  }
  'screenshot' {
    [Desk]::Screenshot($Shot)
    Out-Json @{ saved = $Shot }
  }
  'tree' {
    Out-Json @{ processes = (Process-Tree $ProcessId) }
  }
  'after-quit' {
    $ids = $Pids -split ',' | ForEach-Object { [int]$_ }
    $alive = @(Get-Process -Id $ids -ErrorAction SilentlyContinue | ForEach-Object { @{ pid = $_.Id; name = $_.ProcessName } })
    $taskbar = Find-Taskbar
    $iconOnTaskbar = [bool]($taskbar -and (Named $taskbar 'loqui'))
    $trayWindow = ([Desk]::TrayWindow($ProcessId) -ne [IntPtr]::Zero)
    if ($Shot) { [Desk]::Screenshot($Shot) }
    Out-Json @{ alive = $alive; iconOnTaskbar = $iconOnTaskbar; trayWindow = $trayWindow }
  }
  'submenu' {
    # Opens a submenu of the open menu ("Recent") and reads it.
    if (-not (Find-Menu)) { Fail 'no menu is open' }
    if (-not [Desk]::ClickMenuItem($Item)) { Fail "the menu has no '$Item'" }
    if (-not (Wait-Until 3000 { [Desk]::MenuWindows().Count -ge 2 })) { Fail "'$Item' opened no submenu" }
    Start-Sleep -Milliseconds 300
    if ($Shot) { [Desk]::Screenshot($Shot) }
    $items = @()
    foreach ($entry in [Desk]::SubmenuItems()) {
      $n, $enabled = $entry -split '\|'
      $items += @{ name = $n; enabled = ($enabled -eq '1') }
    }
    Out-Json @{ items = $items }
  }
  'window' {
    # Waits for one of loqui's windows and reads it; with -Name, until that text shows.
    $win = Wait-Until $Wait { Find-Window $Title }
    if (-not $win) { Fail "no '$Title' window appeared. Windows: $(Window-Owners)" }
    $contents = Wait-Until $Wait {
      $c = Window-Contents $win
      if ($c.texts.Count -gt 1 -and (-not $Name -or $c.texts -contains $Name)) { $c }
    }
    if (-not $contents) {
      $seen = Window-Contents $win
      if ($Name) { Fail "'$Title' never showed '$Name'. It shows: $($seen.texts -join ' | ')" }
      $contents = $seen
    }
    if ($Shot) { [Desk]::Front([IntPtr]$win.Current.NativeWindowHandle); Start-Sleep -Milliseconds 400; [Desk]::Screenshot($Shot) }
    Out-Json $contents
  }
  'no-window' {
    # True if the window doesn't show within -Wait ms.
    $win = Wait-Until $Wait { Find-Window $Title }
    Out-Json @{ appeared = [bool]$win }
  }
  'click' {
    # Clicks the element with this name in one of loqui's windows, as a person would.
    $win = Wait-Until $Wait { Find-Window $Title }
    if (-not $win) { Fail "no '$Title' window" }
    [Desk]::Front([IntPtr]$win.Current.NativeWindowHandle)
    $el = Wait-Until $Wait { Clickable $win $Name }
    if (-not $el) { Fail "'$Title' has no '$Name'. It shows: $((Window-Contents $win).texts -join ' | ')" }
    # Scrolled into view first, as a person would scroll to it.
    try {
      $el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern).ScrollIntoView()
      Start-Sleep -Milliseconds 300
    } catch {}
    Click-Element $el
    Start-Sleep -Milliseconds 400
    Out-Json @{ clicked = $Name }
  }
  'press' {
    # Keys pressed together, into whatever has the keyboard.
    [Desk]::Chord((Key-Codes $Keys))
    Start-Sleep -Milliseconds 400
    Out-Json @{ pressed = $Keys }
  }
  'close-window' {
    $win = Find-Window $Title
    if ($win) {
      $pattern = $win.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
      $pattern.Close()
      [void](Wait-Until 5000 { -not (Find-Window $Title) })
    }
    Out-Json @{ closed = $true }
  }
  'theme' {
    # Windows' light or dark setting for apps and the taskbar, as Settings changes it.
    $light = [int]($Mode -eq 'light')
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty $key -Name AppsUseLightTheme -Value $light -Type DWord
    Set-ItemProperty $key -Name SystemUsesLightTheme -Value $light -Type DWord
    [Desk]::ThemeChanged()
    Start-Sleep -Milliseconds 1500
    Out-Json @{ mode = $Mode }
  }
  default { Fail "unknown verb $Verb" }
}
