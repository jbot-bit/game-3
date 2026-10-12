param(
    [string]$Pack = (Join-Path $PSScriptRoot '../build/crown-court-0.10.0/CrownCourt.exe'),
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$EvidencePrefix = 'v10-release',
    [switch]$Source
)
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$engine = Join-Path $workspace '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$Pack = [IO.Path]::GetFullPath($Pack)
$evidence = Join-Path $workspace ('build/crown-court-evidence/' + $EvidencePrefix + '-room-powers')
if ((Test-Path -LiteralPath $evidence) -and @(Get-ChildItem -LiteralPath $evidence -Force).Count -gt 0) { throw 'Choose a new EvidencePrefix; prior receipts will not be overwritten.' }
if (@([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | Where-Object Port -eq 30250).Count -gt 0) { throw 'Port30250 is occupied; this verifier will not reuse another relay.' }
if (-not $Source -and -not (Test-Path -LiteralPath $Pack -PathType Leaf)) { throw 'Pack does not exist.' }
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$record = [ordered]@{ok=$false;passed=$false;mode=$(if($Source){'source'}else{'exact embedded pack'});pack=$(if($Source){$null}else{$Pack});pack_sha256_before=$(if($Source){$null}else{(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash});pack_sha256_after=$null;endpoint='ws://127.0.0.1:30250/rooms';started_at=(Get-Date).ToString('o');results=@();error=$null}
$record.source_sha256 = [ordered]@{}
foreach ($file in @('main.gd','hud.gd','world.gd','sim.gd','room_peer.gd','tests/room_powers.gd','relay/server.mjs','verify-room-powers.ps1')) { $record.source_sha256[$file] = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file) -Algorithm SHA256).Hash }
$relay = $null
$game = $null
function Stop-Owned($process) {
    if ($null -eq $process) { return }
    $process.Refresh()
    if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit(5000) | Out-Null }
}
try {
    $saved = @{}
    try {
        foreach ($key in @('HOST','PORT','TLS_CERT','TLS_KEY','TLS_TERMINATED')) { $saved[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
        [Environment]::SetEnvironmentVariable('HOST','127.0.0.1','Process')
        [Environment]::SetEnvironmentVariable('PORT','30250','Process')
        foreach ($key in @('TLS_CERT','TLS_KEY','TLS_TERMINATED')) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
        $relay = Start-Process -FilePath (Get-Command node).Source -ArgumentList ('"'+(Join-Path $PSScriptRoot 'relay/server.mjs')+'"') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $evidence 'relay.stdout.log') -RedirectStandardError (Join-Path $evidence 'relay.stderr.log')
    } finally { foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') } }
    $ready = $false
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while ([DateTime]::UtcNow -lt $deadline) {
        $relay.Refresh()
        if ($relay.HasExited) { throw 'Owned relay exited before readiness.' }
        try { $health = Invoke-RestMethod 'http://127.0.0.1:30250/healthz' -TimeoutSec 1; if ($health.ok -and $health.connections -eq 0 -and $health.rooms -eq 0) { $ready=$true; break } } catch { }
        Start-Sleep -Milliseconds 100
    }
    if (-not $ready) { throw 'Owned relay never became ready.' }
    $arguments = @('--headless','--path',('"'+$PSScriptRoot+'"'))
    if (-not $Source) { $arguments += @('--main-pack',('"'+$Pack+'"')) }
    $arguments += @('--script','res://tests/room_powers.gd','--','--room-url=ws://127.0.0.1:30250/rooms',('"--evidence-dir='+$evidence+'"'))
    $stdout = Join-Path $evidence 'stdout.log'
    $stderr = Join-Path $evidence 'stderr.log'
    $game = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $game.WaitForExit(90000)) { throw 'Power fixture timed out; only owned processes will be stopped.' }
    $game.WaitForExit()
    $report = Get-Content -LiteralPath (Join-Path $evidence 'result.json') -Raw | ConvertFrom-Json
    $logs = (Get-Content -LiteralPath $stdout -Raw) + "`n" + (Get-Content -LiteralPath $stderr -Raw)
    $failed = @($report.checks | Where-Object passed -ne $true).Count
    $clean = $logs -notmatch '(?m)^(SCRIPT ERROR|ERROR:|WARNING:)'
    $record.results = @(@{script='res://tests/room_powers.gd';exit_code=$game.ExitCode;checks=@($report.checks).Count;failed_checks=$failed;clean_log=$clean;result=(Join-Path $evidence 'result.json')})
    if ($game.ExitCode -ne 0 -or -not $report.passed -or $failed -gt 0 -or @($report.checks).Count -ne 27 -or -not $clean) { throw 'Power lifecycle regression failed. See retained logs and result.json.' }
    if (-not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath (Join-Path $evidence 'relay.stderr.log') -Raw))) { throw 'Relay stderr was not empty.' }
    $record.ok = $true
    $record.passed = $true
} catch { $record.error = $_.Exception.Message }
finally {
    Stop-Owned $game
    Stop-Owned $relay
    if (-not $Source) {
        $record.pack_sha256_after = (Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash
        if ($record.pack_sha256_before -ne $record.pack_sha256_after) { $record.ok=$false; $record.passed=$false; $record.error='Pack changed during verification.' }
    }
    $record.completed_at = (Get-Date).ToString('o')
    $record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $evidence 'verification.json') -Encoding UTF8
}
if (-not $record.ok) { throw $record.error }
Write-Output ('ROOM_POWERS_PASS SHA256 '+$record.pack_sha256_after+' evidence='+$evidence)
