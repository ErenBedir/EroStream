# Windows version of tool/fetch_tdlib.sh.
# Usage: powershell -ExecutionPolicy Bypass -File tool\fetch_tdlib.ps1 [android] [web]
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$lock = @{}
Get-Content tool/tdlib.lock | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object {
  $k, $v = $_ -split '=', 2; $lock[$k] = $v
}
$repo = if ($env:EROSTREAM_REPO) { $env:EROSTREAM_REPO } else { 'ErenBedir/EroStream' }
$base = "https://github.com/$repo/releases/download/$($lock.TDLIB_TAG)"
$targets = if ($args.Count) { $args } else { @('android', 'web') }
$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("tdlib-" + [guid]::NewGuid()))
try {
  foreach ($t in $targets) {
    Write-Host "tdlib $($lock.TDLIB_TAG): $t"
    $file = Join-Path $tmp "$t.tar.gz"
    Invoke-WebRequest "$base/tdlib-$t.tar.gz" -OutFile $file
    switch ($t) {
      'android' {
        $dst = 'android/app/src/main'
        if (Test-Path "$dst/jniLibs") { Remove-Item -Recurse -Force "$dst/jniLibs" }
        New-Item -ItemType Directory -Force $dst | Out-Null
        tar -xzf $file -C $dst
      }
      'web' { tar -xzf $file -C web }
      default { throw "unknown target $t" }
    }
  }
} finally {
  Remove-Item -Recurse -Force $tmp
}
