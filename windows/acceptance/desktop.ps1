# Drives the real Windows desktop for the WINBASE acceptance tests: installs the
# test build, starts it, clicks the loqui icon by the clock, reads and chooses
# menu items, reads the About window and takes screenshots. Every action is a
# real mouse click or a question to Windows; nothing reaches inside loqui.
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
  [string]$Pids
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

  public static void Click(int x, int y) {
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(80);
    mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
    mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
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

# The shell's answer for loqui's icon: its window, its id and where it is.
function Find-Icon([int]$procId) {
  $hwnd = [Desk]::TrayWindow($procId)
  if ($hwnd -eq [IntPtr]::Zero) { return $null }
  foreach ($uid in 0..8) {
    $rect = New-Object Desk+RECT
    if ([Desk]::IconRect($hwnd, $uid, [ref]$rect)) {
      return @{ hwnd = $hwnd.ToInt64(); uid = $uid; rect = $rect }
    }
  }
  return $null
}

function Named($root, [string]$name) {
  $cond = New-Object System.Windows.Automation.PropertyCondition($Prop::NameProperty, $name)
  return $root.FindFirst($Tree::Descendants, $cond)
}

function Click-Element($el) {
  $r = $el.Current.BoundingRectangle
  [Desk]::Click([int]($r.X + $r.Width / 2), [int]($r.Y + $r.Height / 2))
}

function Open-Menu {
  $existing = Find-Menu
  if ($existing) { return @{ how = 'already open' } }

  # Prefer the icon itself, where the shell says it is.
  $icon = Find-Icon $ProcessId
  if (-not $icon) { Fail 'loqui has no icon in the notification area' }
  $r = $icon.rect
  $x = [int](($r.Left + $r.Right) / 2); $y = [int](($r.Top + $r.Bottom) / 2)
  $at = $UIA::FromPoint((New-Object System.Windows.Point($x, $y)))
  if ($at -and $at.Current.Name -eq 'loqui') {
    [Desk]::Click($x, $y)
    if (Wait-Until 3000 { Find-Menu }) { return @{ how = 'icon on the taskbar' } }
  }

  # A new icon may sit behind "Show hidden icons".
  $taskbar = $UIA::RootElement.FindFirst($Tree::Children,
    (New-Object System.Windows.Automation.PropertyCondition($Prop::ClassNameProperty, 'Shell_TrayWnd')))
  $loqui = if ($taskbar) { Named $taskbar 'loqui' }
  if (-not $loqui) {
    $chevron = if ($taskbar) { Named $taskbar 'Show hidden icons' }
    if (-not $chevron) { Fail "can't find loqui's icon or the hidden icons button (icon rect $($r.Left),$($r.Top),$($r.Right),$($r.Bottom); element there: '$($at.Current.Name)')" }
    Click-Element $chevron
    $loqui = Wait-Until 8000 { Named $UIA::RootElement 'loqui' }
    if (-not $loqui) { Fail 'opened the hidden icons, but loqui is not among them' }
    $how = 'hidden icons'
  } else { $how = 'icon found by name' }
  Click-Element $loqui
  if (-not (Wait-Until 3000 { Find-Menu })) { Fail "clicked loqui's icon ($how) but no menu opened" }
  return @{ how = $how }
}

function Find-Menu {
  $cond = New-Object System.Windows.Automation.PropertyCondition($Prop::ClassNameProperty, '#32768')
  return $UIA::RootElement.FindFirst($Tree::Children, $cond)
}

function Menu-Items($menu) {
  $cond = New-Object System.Windows.Automation.PropertyCondition($Prop::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::MenuItem)
  $items = @()
  foreach ($el in $menu.FindAll($Tree::Descendants, $cond)) {
    if ($el.Current.Name) { $items += @{ name = $el.Current.Name; enabled = $el.Current.IsEnabled } }
  }
  return ,$items
}

function Process-Tree([int]$root) {
  $all = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name
  $ids = @($root); $grew = $true
  while ($grew) {
    $grew = $false
    foreach ($p in $all) {
      if ($ids -contains $p.ParentProcessId -and -not ($ids -contains $p.ProcessId)) { $ids += $p.ProcessId; $grew = $true }
    }
  }
  return ,@($all | Where-Object { $ids -contains $_.ProcessId } | ForEach-Object { @{ pid = $_.ProcessId; name = $_.Name } })
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
    if (-not $icon) { Fail "no icon in the notification area 10 seconds after starting (pid $($p.Id))" }
    Out-Json @{ pid = $p.Id; ms = $ms; uid = $icon.uid }
  }
  'open-menu' {
    $how = Open-Menu
    Start-Sleep -Milliseconds 300
    if ($Shot) { [Desk]::Screenshot($Shot) }
    Out-Json @{ how = $how.how; items = (Menu-Items (Find-Menu)) }
  }
  'choose' {
    $menu = Find-Menu
    if (-not $menu) { Fail 'no menu is open' }
    $el = Named $menu $Item
    if (-not $el) { Fail "the menu has no '$Item'" }
    Click-Element $el
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
    $taskbar = $UIA::RootElement.FindFirst($Tree::Children,
      (New-Object System.Windows.Automation.PropertyCondition($Prop::ClassNameProperty, 'Shell_TrayWnd')))
    $iconOnTaskbar = [bool]($taskbar -and (Named $taskbar 'loqui'))
    $trayWindow = ([Desk]::TrayWindow($ProcessId) -ne [IntPtr]::Zero)
    if ($Shot) { [Desk]::Screenshot($Shot) }
    Out-Json @{ alive = $alive; iconOnTaskbar = $iconOnTaskbar; trayWindow = $trayWindow }
  }
  default { Fail "unknown verb $Verb" }
}
