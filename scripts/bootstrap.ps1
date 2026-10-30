$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force .deps | Out-Null
$archive=Join-Path $PWD '.deps/gua-godot-addon-v1.1.2.zip'
if (!(Test-Path $archive)) {
  Invoke-WebRequest 'https://github.com/gua-project/gua/releases/download/gua-v1.1.2/gua-godot-addon-v1.1.2.zip' -OutFile $archive
}
if ((Get-FileHash $archive).Hash -ne '19F89058CA60E48C74A7327DA31C0E011B4C053ACFDA8E5B8E2E2B1FC90AE8C4') { throw 'Gua hash mismatch' }
Expand-Archive $archive .deps/gua -Force
Copy-Item .deps/gua/addons . -Recurse -Force
