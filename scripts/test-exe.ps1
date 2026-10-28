param([string]$Bun='bun',[switch]$Gui,[string[]]$Modes=@('normal','cancel_charge','double_reward','sort_target'))
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:APPDATA="$PWD/output/appdata"
$env:GUA_BRIDGE_PORT='8793'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
foreach($mode in $Modes) {
  $env:GUILD_TEST_MODE=$mode
  $arguments=@()
  if (!$Gui) { $arguments+='--headless' }
  $arguments+=@('--',"--save-path=$PWD/output/save-$mode.json")
  if ($mode -ne 'normal') { $arguments+="--bug=$mode" }
  $process=Start-Process -FilePath "$PWD/output/guild.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "output/exe-$mode.log" -RedirectStandardError "output/exe-$mode-error.log"
  try {
    Start-Sleep -Seconds 2
    & $Bun tests/exe-test.ts
    if ($LASTEXITCODE) { throw "EXE test failed: $mode" }
  } finally { if (!$process.HasExited) { Stop-Process -Id $process.Id } }
}
