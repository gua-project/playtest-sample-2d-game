param([Parameter(Mandatory)][string]$Godot)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force output | Out-Null
$steps=@(
  @{Name='import'; Args=@('--headless','--editor','--import','--quit')},
  @{Name='model'; Args=@('--headless','--script','tests/model_test.gd')},
  @{Name='export'; Args=@('--headless','--export-release','"Windows Desktop"','output/guild.exe')}
)
foreach($step in $steps) {
  $process=Start-Process -FilePath $Godot -ArgumentList $step.Args -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "output/$($step.Name).log" -RedirectStandardError "output/$($step.Name)-error.log"
  Get-Content "output/$($step.Name).log"
  $errors=Get-Content "output/$($step.Name)-error.log" -Raw
  if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR:|ERROR:') { throw "$($step.Name) failed: $errors" }
}
if (!(Test-Path output/guild.exe) -or !(Test-Path output/gua_godot.windows.release.x86_64.dll)) { throw 'Missing distribution files' }
if ((Get-Content output/model.log -Raw) -notmatch 'MODEL CHECKS 26 FAILURES 0') { throw 'Model completion evidence missing' }
