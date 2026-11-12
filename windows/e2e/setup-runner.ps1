# Gets a GitHub Windows computer ready for the dictation checks: a virtual
# sound cable (VB-CABLE) as its microphone, and Windows' microphone switch for
# desktop apps turned on. CI only; every download is pinned by SHA-256.
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:RUNNER_TEMP 'vbcable'
New-Item -ItemType Directory -Force $work | Out-Null

# The driver from VB-Audio, plus the installer tool and VB-Audio's signing
# certificate from LABSN/sound-ci-helpers at a fixed commit.
$helpers = 'https://raw.githubusercontent.com/LABSN/sound-ci-helpers/e9d6ba52163a3283714a68412036ddf33f78d49c/windows'
$files = @(
  @{ url = 'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack43.zip'; name = 'vbcable.zip'; sha256 = '66fd0a4d9f4896ff41632b7e3d53892c085c4561f53e8ae8d0f0bc10eedd1cdd' },
  @{ url = "$helpers/devcon.exe"; name = 'devcon.exe'; sha256 = '97cff42f8c0fe4fbdf991273159516bf78090625a933c3983ebd6f62284e329a' },
  @{ url = "$helpers/vbcable.cer"; name = 'vbcable.cer'; sha256 = 'db9f6f54a13ef2ede5a8a7ba69dc841dc0711ba77ae7b173dd093e8455a4ed7e' }
)
foreach ($f in $files) {
  $path = Join-Path $work $f.name
  Invoke-WebRequest $f.url -OutFile $path
  $actual = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $f.sha256) { throw "$($f.url) has SHA-256 $actual, expected $($f.sha256)" }
}

Set-Service Audiosrv -StartupType Automatic
Start-Service Audiosrv
Expand-Archive -LiteralPath (Join-Path $work 'vbcable.zip') -DestinationPath (Join-Path $work 'driver') -Force
certutil -addstore TrustedPublisher (Join-Path $work 'vbcable.cer') | Out-Null
& (Join-Path $work 'devcon.exe') install (Join-Path $work 'driver\vbMmeCable64_win7.inf') VBAudioVACWDM
if ($LASTEXITCODE) { throw "devcon couldn't install VB-CABLE ($LASTEXITCODE)" }
Start-Sleep 5

# "Let apps access your microphone" and "Let desktop apps access your microphone".
foreach ($root in 'HKLM:', 'HKCU:') {
  $key = "$root\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
  New-Item -Path "$key\NonPackaged" -Force | Out-Null
  Set-ItemProperty -Path $key -Name Value -Value Allow
  Set-ItemProperty -Path "$key\NonPackaged" -Name Value -Value Allow
}

Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Format-Table Status, FriendlyName, InstanceId -AutoSize
