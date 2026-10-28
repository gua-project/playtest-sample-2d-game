param([Parameter(Mandatory)][string]$Godot)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force output | Out-Null
$steps=@(
  # Immediate --import --quit crashes on the first GDExtension scan in Godot 4.7.
  # Let the headless editor finish several frames; still require a zero exit.
  @{Name='import'; Args=@('--headless','--editor','--quit-after','180','--max-fps','60')},
  @{Name='model'; Args=@('--headless','--script','tests/model_test.gd')},
  @{Name='export'; Args=@('--headless','--export-release','"Windows Desktop"','output/guild.exe')}
)
foreach($step in $steps) {
  $startInfo=[System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName=$Godot
  $startInfo.Arguments=$step.Args -join ' '
  $startInfo.WorkingDirectory=$PWD.Path
  $startInfo.UseShellExecute=$false
  $startInfo.CreateNoWindow=$true
  $startInfo.RedirectStandardOutput=$true
  $startInfo.RedirectStandardError=$true
  $process=[System.Diagnostics.Process]::new()
  $process.StartInfo=$startInfo
  [void]$process.Start()
  $stdout=$process.StandardOutput.ReadToEndAsync()
  $stderr=$process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $stdout.Result | Set-Content "output/$($step.Name).log"
  $errors=$stderr.Result
  $errors | Set-Content "output/$($step.Name)-error.log"
  Write-Output $stdout.Result
  $exitCode=$process.ExitCode
  $process.Dispose()
  if ($exitCode -ne 0 -or $errors -match 'SCRIPT ERROR:|ERROR:') { throw "$($step.Name) failed (exit $exitCode): $errors" }
}
if (!(Test-Path output/guild.exe) -or !(Test-Path output/gua_godot.windows.release.x86_64.dll)) { throw 'Missing distribution files' }
if ((Get-Content output/model.log -Raw) -notmatch 'MODEL CHECKS 26 FAILURES 0') { throw 'Model completion evidence missing' }
