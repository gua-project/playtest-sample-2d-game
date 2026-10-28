param([string]$Bun='bun',[switch]$Gui,[string[]]$Modes=@('normal','restore','cancel_charge','double_reward','sort_target'))
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$priorAppData=$env:APPDATA
$priorPort=$env:GUA_BRIDGE_PORT
$priorMode=$env:GUILD_TEST_MODE
try {
$env:APPDATA="$PWD/output/appdata"
$env:GUA_BRIDGE_PORT='8793'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
foreach($mode in $Modes) {
  $env:GUILD_TEST_MODE=$mode
  $arguments=@()
  if (!$Gui) { $arguments+='--headless' }
  $saveMode=if ($mode -eq 'restore') {'normal'} else {$mode}
  $arguments+=@('--',"--save-path=`"$PWD/output/save-$saveMode.json`"")
  if ($mode -notin @('normal','restore')) { $arguments+="--bug=$mode" }
  $process=Start-Process -FilePath "$PWD/output/guild.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "output/exe-$mode.log" -RedirectStandardError "output/exe-$mode-error.log"
  try {
    Start-Sleep -Seconds 2
    & $Bun tests/exe-test.ts
    if ($LASTEXITCODE) { throw "EXE test failed: $mode" }
  } finally { if (!$process.HasExited) { Stop-Process -Id $process.Id } }
}
} finally {
  $env:APPDATA=$priorAppData
  $env:GUA_BRIDGE_PORT=$priorPort
  $env:GUILD_TEST_MODE=$priorMode
}
