# The install, update and uninstall checks' hands on GitHub's Windows
# computers: runs loqui's installers, clicks through the real uninstaller the
# way a person would, and reads what Windows has: files, Start, Installed
# apps, the sign-in entry and running copies. Nothing reaches inside loqui.
#
# Usage: powershell -File installer.ps1 <verb> [args]. Each verb prints one JSON
# line, and exits non-zero with {"error": ...} when it can't do its job.
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Verb,
  [string]$Installer,
  [string]$Shot,
  [switch]$Delete,
  [string]$Out,
  [string]$StopFile,
  [int]$Wait = 120000
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing, System.Windows.Forms
$UIA = [System.Windows.Automation.AutomationElement]
$Tree = [System.Windows.Automation.TreeScope]

function Out-Json($value) { $value | ConvertTo-Json -Compress -Depth 6; exit 0 }
function Fail($message) {
  try { if ($Shot) { Screenshot ($Shot -replace '\.png$', '-failed.png') } } catch {}
  @{ error = $message } | ConvertTo-Json -Compress; exit 1
}
function Screenshot([string]$path) {
  $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
function Wait-Until([int]$ms, [scriptblock]$probe) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $ms) {
    $r = & $probe
    if ($r) { return $r }
    Start-Sleep -Milliseconds 100
  }
  return $null
}

$Programs = Join-Path $env:LOCALAPPDATA 'Programs\loqui'
$Data = Join-Path $env:LOCALAPPDATA 'Loqui'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\loqui'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'

function Modified([string]$path) {
  if (Test-Path $path) { (Get-Item $path).LastWriteTimeUtc.ToString('o') } else { $null }
}

# Everything Windows has about loqui now.
function Facts {
  $key = Get-ItemProperty $UninstallKey -ErrorAction SilentlyContinue
  $run = (Get-ItemProperty $RunKey -ErrorAction SilentlyContinue).loqui
  $links = @(Get-ChildItem $StartMenu -Recurse -Filter 'loqui*.lnk' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
  $procs = @(Get-CimInstance Win32_Process -Filter "Name = 'loqui.exe'" | ForEach-Object { @{ pid = $_.ProcessId; path = $_.ExecutablePath } })
  $dataFiles = @()
  if (Test-Path $Data) {
    $dataFiles = @(Get-ChildItem $Data -Recurse -File | ForEach-Object {
      @{ name = $_.FullName.Substring($Data.Length + 1); sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
    })
  }
  return @{
    exe = (Test-Path (Join-Path $Programs 'loqui.exe'))
    folder = (Test-Path $Programs)
    appInDataFolder = (Test-Path (Join-Path $Data 'loqui.exe'))
    installed = if ($key) { @{ name = $key.DisplayName; version = $key.DisplayVersion; uninstall = $key.UninstallString; location = $key.InstallLocation } } else { $null }
    run = $run
    startMenu = $links
    processes = $procs
    model = @{
      version = if (Test-Path "$Programs\models\version.txt") { (Get-Content "$Programs\models\version.txt" -Raw) } else { $null }
      encoder = (Modified "$Programs\models\parakeet\encoder.int8.onnx")
      vad = (Modified "$Programs\models\silero_vad.onnx")
    }
    engine = @(Get-ChildItem "$Programs\engine" -Filter *.dll -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    data = $dataFiles
  }
}

function Find-Uninstaller {
  $cond = New-Object System.Windows.Automation.PropertyCondition($UIA::NameProperty, 'loqui Uninstall')
  return $UIA::RootElement.FindFirst($Tree::Children, $cond)
}
function Named($root, [string]$name) {
  $cond = New-Object System.Windows.Automation.PropertyCondition($UIA::NameProperty, $name)
  return $root.FindFirst($Tree::Descendants, $cond)
}
function Press($el) {
  $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
}

switch ($Verb) {
  'facts' { Out-Json (Facts) }
  'install' {
    # A silent install, as a script would run it; the person's choices are the defaults.
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $Installer -ArgumentList '/S' -PassThru -Wait
    Out-Json @{ exitCode = $p.ExitCode; ms = $sw.ElapsedMilliseconds; facts = (Facts) }
  }
  'run-level' {
    # What the installer asks Windows for: asInvoker means no administrator prompt.
    $bytes = [IO.File]::ReadAllBytes($Installer)
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    $m = [regex]::Match($text, 'requestedExecutionLevel\s+level="(\w+)"')
    if (-not $m.Success) { Fail "no requestedExecutionLevel in $Installer" }
    Out-Json @{ level = $m.Groups[1].Value }
  }
  'uninstall' {
    # As from Installed apps: the uninstaller with its window, answered by clicking.
    $key = Get-ItemProperty $UninstallKey -ErrorAction SilentlyContinue
    if (-not $key) { Fail 'loqui is not in Installed apps' }
    $exe = $key.UninstallString.Trim('"')
    Start-Process -FilePath $exe | Out-Null
    $win = Wait-Until 20000 { Find-Uninstaller }
    if (-not $win) { Fail 'no loqui Uninstall window appeared' }
    $box = Wait-Until 10000 { Named $win 'Also delete my dictation history, dictionary, settings and stats' }
    if (-not $box) { Fail 'the uninstaller does not ask about your data' }
    $toggle = $box.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
    $before = "$($toggle.Current.ToggleState)"
    if ($Delete) { $toggle.Toggle() }
    $asked = "$($toggle.Current.ToggleState)"
    if ($Shot) { Screenshot $Shot }
    Press (Named $win 'Uninstall')
    $close = Wait-Until $Wait {
      $w = Find-Uninstaller
      if (-not $w) { return 'gone' }
      $c = Named $w 'Close'
      if ($c -and $c.Current.IsEnabled) { $c }
    }
    if (-not $close) { Fail 'the uninstaller never finished' }
    if ($close -ne 'gone') { Press $close }
    [void](Wait-Until 10000 { -not (Find-Uninstaller) })
    Start-Sleep -Milliseconds 500
    Out-Json @{ boxAtFirst = $before; boxWhenUninstalled = $asked; facts = (Facts) }
  }
  'net-watch' {
    # Every 200 ms until $StopFile appears: each new TCP connection owned by
    # any loqui (they change as it updates) or the web views it started, one
    # JSON line each, with when it was first seen.
    $seen = @{}
    while (-not (Test-Path $StopFile)) {
      $all = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name
      $ids = @($all | Where-Object { $_.Name -eq 'loqui.exe' } | ForEach-Object { $_.ProcessId })
      $grew = $true
      while ($grew) {
        $grew = $false
        foreach ($p in $all) {
          if ($ids -contains $p.ParentProcessId -and -not ($ids -contains $p.ProcessId)) { $ids += $p.ProcessId; $grew = $true }
        }
      }
      foreach ($c in Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $ids -contains $_.OwningProcess }) {
        $key = "$($c.LocalAddress):$($c.LocalPort)>$($c.RemoteAddress):$($c.RemotePort)"
        if (-not $seen[$key]) {
          $seen[$key] = 1
          $name = ($all | Where-Object { $_.ProcessId -eq $c.OwningProcess } | Select-Object -First 1).Name
          @{ at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); remote = "$($c.RemoteAddress)"; port = $c.RemotePort; process = $name } |
            ConvertTo-Json -Compress | Add-Content -Path $Out
        }
      }
      Start-Sleep -Milliseconds 200
    }
    Out-Json @{ connections = $seen.Count }
  }
  'names' {
    # The names Windows looked up, for each address: which hosts the connections went to.
    $names = @{}
    foreach ($r in Get-DnsClientCache -ErrorAction SilentlyContinue) {
      if ($r.Data) { $names["$($r.Data)"] = @(@($names["$($r.Data)"]) + "$($r.Entry)" | Where-Object { $_ } | Select-Object -Unique) }
    }
    Out-Json $names
  }
  default { Fail "unknown verb $Verb" }
}
