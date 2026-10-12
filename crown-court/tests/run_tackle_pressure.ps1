param([string]$Label='tackle-pressure', [string]$EnginePath='')
. (Join-Path $PSScriptRoot '../harness.ps1')
if ($EnginePath) { $engine=(Get-Item -LiteralPath $EnginePath -ErrorAction Stop).FullName }
if ($Label -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid evidence label' }
$folder=Join-Path $evidence $Label
if (Test-Path -LiteralPath $folder) { throw 'Evidence exists; use a fresh label' }
New-Item -ItemType Directory -Path $folder | Out-Null
$simPath=Join-Path $source 'sim.gd'
$before=(Get-FileHash -LiteralPath $simPath -Algorithm SHA256).Hash
$suites=@('tackle_pressure','tackle_contacts','sim_test','gameplay_v11','teamplay_sim','teamplay_match','reference_feel')
$results=@()
foreach ($suite in $suites) {
    $runLabel=$Label+'-'+$suite
    $arguments=@('--headless','--path',$source,'--script',('res://tests/'+$suite+'.gd'),'--',('--evidence-dir='+$folder))
    Run-GameProcess $engine $arguments $runLabel 55 $runLabel
    $results+=@{suite=$suite;passed=$true;profile_scope=$runLabel;stdout=(Join-Path $evidence ($runLabel+'.stdout.log'));stderr=(Join-Path $evidence ($runLabel+'.stderr.log'))}
}
$after=(Get-FileHash -LiteralPath $simPath -Algorithm SHA256).Hash
if ($before -ne $after) { throw 'Simulation changed during regression run; use a fresh label after source freezes' }
$focused=Get-Content -LiteralPath (Join-Path $folder 'result.json') -Raw | ConvertFrom-Json
if (-not $focused.passed) { throw 'Focused tackle pressure checks failed' }
@{passed=$true;sim_sha256=$after;engine=$engine;engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash;focused_checks=$focused.checks.Count;suites=$results;completed=(Get-Date).ToString('o');scope='CPU source regressions with isolated profiles; fixture evidence, not native match balance or household playtesting'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $folder 'verification.json')
Write-Output "Tackle pressure evidence: $folder"
