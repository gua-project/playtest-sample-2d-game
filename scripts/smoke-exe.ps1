param([string]$Dotnet='dotnet')
# One packaged EXE: official version/title only. Playtest owns E2E orchestration.
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$priorAppData=$env:APPDATA
$priorPort=$env:GUA_BRIDGE_PORT
try {
  $env:APPDATA="$PWD/output/smoke-appdata"
  $env:GUA_BRIDGE_PORT='8793'
  $env:DOTNET_GENERATE_ASPNET_CERTIFICATE='false'
  New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
  $process=Start-Process -FilePath "$PWD/output/guild.exe" -ArgumentList '--headless','--',"--save-path=`"$PWD/output/smoke-save.json`"" -WindowStyle Hidden -PassThru -RedirectStandardOutput output/smoke-exe.log -RedirectStandardError output/smoke-exe-error.log
  try {
    & $Dotnet test tests/Guild.Regression/Guild.Regression.csproj --no-restore --filter 'FullyQualifiedName~DistributionSmoke' --logger 'trx;LogFileName=distribution-smoke.trx' --results-directory output/smoke-results
    if ($LASTEXITCODE) { throw 'Limited distribution smoke failed' }
    [xml]$result=Get-Content output/smoke-results/distribution-smoke.trx
    $counts=$result.TestRun.ResultSummary.Counters
    if ([int]$counts.executed -ne 1 -or [int]$counts.passed -ne 1) { throw 'Smoke requires exactly one executed passing title/version check' }
    $listeners=@(Get-NetTCPConnection -LocalPort 8793 -State Listen -ErrorAction SilentlyContinue)
    if ($listeners.Count -ne 1 -or $listeners[0].OwningProcess -ne $process.Id) {
      throw 'Smoke bridge is not owned by the launched EXE; title/version results cannot be attributed to this build'
    }
    [ordered]@{scope='version/title only';launchedPid=$process.Id;bridgePid=$listeners[0].OwningProcess;port=8793;exeSha256=(Get-FileHash output/guild.exe).Hash;trx='smoke-results/distribution-smoke.trx'} |
      ConvertTo-Json | Set-Content -Encoding utf8 output/smoke-process.json
  } finally {
    if (!$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit(10000) | Out-Null }
  }
} finally { $env:APPDATA=$priorAppData; $env:GUA_BRIDGE_PORT=$priorPort }
