<#
  EroStream web - Windows installer.

  Downloads the latest web build from GitHub releases into %LOCALAPPDATA%\EroStream,
  adds Start menu / desktop shortcuts and a small local web server (no Python or Node needed).

  Usage:
    install-web.ps1               install or update
    install-web.ps1 -Port 9000    use another port (keep it fixed: login is stored per address)
    install-web.ps1 -Uninstall    remove app, shortcuts and settings file
#>
param(
  [int]$Port = 8787,
  [switch]$Uninstall,
  [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo    = 'ErenBedir/EroStream'
$Dest    = Join-Path $env:LOCALAPPDATA 'EroStream'
$WebDir  = Join-Path $Dest 'web'
$Shell   = New-Object -ComObject WScript.Shell
$Links   = @(
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'EroStream.lnk'),
  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'EroStream.lnk')
)

function Say($msg) { Write-Host "  $msg" }

if ($Uninstall) {
  foreach ($l in $Links) { if (Test-Path $l) { Remove-Item $l -Force } }
  if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
  Say 'EroStream removed. Browser data (login, libraries) stays in the browser until you clear site data.'
  return
}

Write-Host ''
Write-Host '  EroStream web setup' -ForegroundColor Yellow
Write-Host ''

# 1. Latest release with a web build
Say 'Looking for the latest release...'
$releases = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$Repo/releases" -Headers @{ 'User-Agent' = 'erostream-installer' }
$release = $releases | Where-Object { $_.tag_name -like 'v*' -and ($_.assets | Where-Object { $_.name -like '*-web.zip' }) } | Select-Object -First 1
if (-not $release) { throw 'No release with a web build found.' }
$asset = $release.assets | Where-Object { $_.name -like '*-web.zip' } | Select-Object -First 1
$version = $release.tag_name.TrimStart('v')

$installed = ''
$verFile = Join-Path $Dest 'version.txt'
if (Test-Path $verFile) { $installed = (Get-Content $verFile -Raw).Trim() }
if ($installed -eq $version -and (Test-Path (Join-Path $WebDir 'index.html'))) {
  Say "Version $version is already installed."
} else {
  # 2. Download and unpack
  Say "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)..."
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  $zip = Join-Path $env:TEMP $asset.name
  Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zip
  if (Test-Path $WebDir) { Remove-Item $WebDir -Recurse -Force }
  Expand-Archive -Path $zip -DestinationPath $WebDir -Force
  Remove-Item $zip -Force
  Set-Content -Path $verFile -Value $version -Encoding ASCII
  Say "Installed version $version."
}

# 3. Local web server (HttpListener on localhost, no admin rights needed)
$server = @'
param([int]$Port = __PORT__)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'web'))
$mime = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.mjs' = 'text/javascript; charset=utf-8'
  '.json' = 'application/json'; '.css' = 'text/css'; '.wasm' = 'application/wasm'; '.png' = 'image/png'
  '.jpg' = 'image/jpeg'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.ttf' = 'font/ttf'; '.otf' = 'font/otf'
  '.woff' = 'font/woff'; '.woff2' = 'font/woff2'; '.webmanifest' = 'application/manifest+json'; '.map' = 'application/json'
  '.bin' = 'application/octet-stream'; '.frag' = 'text/plain'
}
$url = "http://localhost:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
try {
  $listener.Start()
} catch {
  Write-Host ''
  Write-Host "  Port $Port is in use. If EroStream is already running, use the open window." -ForegroundColor Red
  Write-Host "  Otherwise reinstall with another port: install-web.ps1 -Port 9000"
  Read-Host '  Press Enter to close'
  exit 1
}
$Host.UI.RawUI.WindowTitle = "EroStream - $url"
Write-Host ''
Write-Host "  EroStream is running at $url" -ForegroundColor Yellow
Write-Host '  Close this window to stop it.'
Start-Process $url
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($rel -eq '') { $rel = 'index.html' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
    $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
      if ($ext -ne '') { $res.StatusCode = 404; continue }
      $full = Join-Path $root 'index.html'   # app routes
      $ext = '.html'
    }
    $bytes = [IO.File]::ReadAllBytes($full)
    $type = $mime[$ext]
    if (-not $type) { $type = 'application/octet-stream' }
    $res.ContentType = $type
    $res.Headers['Cache-Control'] = 'no-cache'
    $res.ContentLength64 = $bytes.Length
    if ($ctx.Request.HttpMethod -ne 'HEAD') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
  } catch {
    try { $res.StatusCode = 500 } catch {}
  } finally {
    try { $res.Close() } catch {}
  }
}
'@
$serverPath = Join-Path $Dest 'serve.ps1'
Set-Content -Path $serverPath -Value ($server -replace '__PORT__', $Port) -Encoding UTF8

$launcher = Join-Path $Dest 'EroStream.cmd'
Set-Content -Path $launcher -Encoding ASCII -Value @"
@echo off
start "EroStream" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
"@

# 4. Shortcuts
foreach ($l in $Links) {
  $s = $Shell.CreateShortcut($l)
  $s.TargetPath = $launcher
  $s.WorkingDirectory = $Dest
  $s.WindowStyle = 7
  $s.Description = 'EroStream'
  $s.Save()
}
Say 'Shortcuts added to the Start menu and desktop.'
Say "Address: http://localhost:$Port/  (keep this port; login and libraries are stored per address)"
Say 'Telegram API ID / hash and TMDB key: enter them in Settings inside the app.'
Write-Host ''

if (-not $NoStart) { Start-Process $launcher }
