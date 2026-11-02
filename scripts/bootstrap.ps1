$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force .deps | Out-Null
$archive=Join-Path $PWD '.deps/gua-godot-addon-v1.2.0.zip'
if (!(Test-Path $archive)) {
  Invoke-WebRequest 'https://github.com/gua-project/gua/releases/download/gua-v1.2.0/gua-godot-addon-v1.2.0.zip' -OutFile $archive
}
if ((Get-FileHash $archive).Hash -ne 'EFFCAD4CFC6083528BEE4E469E171047CD9D2D49547A09D16BE04845FCDA7873') { throw 'Gua hash mismatch' }
Expand-Archive $archive .deps/gua -Force
Copy-Item .deps/gua/addons . -Recurse -Force

& "$PSScriptRoot/verify-gua.ps1"
