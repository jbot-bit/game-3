param(
    [string]$Pack = (Join-Path $PSScriptRoot '../build/crown-court-0.10.0/CrownCourt.exe'),
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$EvidencePrefix = 'v10-release'
)
$ErrorActionPreference = 'Stop'
$Pack = [IO.Path]::GetFullPath($Pack)
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$engine = Join-Path $workspace '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$relaySource = Join-Path $PSScriptRoot 'relay/server.mjs'
$node = (Get-Command node -ErrorAction Stop).Source
$evidence = Join-Path $workspace ('build/crown-court-evidence/' + $EvidencePrefix + '-room-application')
if (Test-Path -LiteralPath $evidence) {
    if (@(Get-ChildItem -LiteralPath $evidence -Force).Count -gt 0) { throw 'Evidence folder must be new or empty; choose another EvidencePrefix.' }
}
foreach ($required in @($Pack,$engine,$relaySource,(Join-Path $PSScriptRoot 'relay/node_modules/ws/package.json'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw ('Missing required file: ' + $required) }
}
if (@([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | Where-Object { $_.Port -eq 30220 }).Count -gt 0) {
    throw 'TCP 30220 is already in use; this wrapper will not stop or reuse another relay.'
}
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$before = (Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash
$sourceHashes = [ordered]@{}
foreach ($relative in @('relay/server.mjs','relay/package.json','relay/package-lock.json','room_peer.gd','tests/room_application.gd','tests/room_ui.gd','tests/controller_app.gd','verify-rooms.ps1')) {
    $sourceHashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $relative) -Algorithm SHA256).Hash
}
$record = [ordered]@{
    ok = $false
    passed = $false
    scope = 'Exact embedded pack: local WebSocket application RPC fixture and rendered UI/controller-event checks; no public TLS, WAN, physical controller or natural-match claim.'
    pack = $Pack
    pack_sha256_before = $before
    pack_sha256_after = $null
    started_at = (Get-Date).ToString('o')
    endpoint = 'ws://127.0.0.1:30220/rooms'
    source_sha256 = $sourceHashes
    source_hash_scope = 'Companion source provenance only; tests execute embedded res:// scripts under the recorded executable hash.'
    results = @()
    error = $null
}
$ownedRelay = $null
$ownedGame = $null
$failure = $null

function Stop-OwnedProcess($Process) {
    if ($null -eq $Process) { return }
    try {
        $Process.Refresh()
        if (-not $Process.HasExited) {
            $Process.Kill($true)
            $Process.WaitForExit(5000) | Out-Null
        }
    } catch { Write-Warning ('Owned process cleanup: ' + $_.Exception.Message) }
}

try {
    $savedEnvironment = @{}
    try {
        foreach ($key in @('HOST','PORT','TLS_CERT','TLS_KEY','TLS_TERMINATED')) { $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
        [Environment]::SetEnvironmentVariable('HOST','127.0.0.1','Process')
        [Environment]::SetEnvironmentVariable('PORT','30220','Process')
        foreach ($key in @('TLS_CERT','TLS_KEY','TLS_TERMINATED')) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
        $ownedRelay = Start-Process -FilePath $node -ArgumentList ('"' + $relaySource + '"') -WorkingDirectory (Join-Path $PSScriptRoot 'relay') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $evidence 'relay.stdout.log') -RedirectStandardError (Join-Path $evidence 'relay.stderr.log')
    } finally {
        foreach ($key in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key,$savedEnvironment[$key],'Process') }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    $ready = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        $ownedRelay.Refresh()
        if ($ownedRelay.HasExited) { throw 'Owned room relay exited before readiness.' }
        try {
            $health = Invoke-RestMethod -Uri 'http://127.0.0.1:30220/healthz' -TimeoutSec 1
            if ($health.ok -eq $true -and $health.protocol -eq 1 -and $health.rooms -eq 0 -and $health.connections -eq 0) { $ready = $true; break }
        } catch { }
        Start-Sleep -Milliseconds 100
    }
    if (-not $ready) { throw 'Owned room relay did not become healthy within 12 seconds.' }
    $record.relay_pid = $ownedRelay.Id

    foreach ($test in @(
        @{Name='application'; Script='res://tests/room_application.gd'; Report='room-application-result.json'; Headless=$true; ExpectedChecks=25; Timeout=90},
        @{Name='ui'; Script='res://tests/room_ui.gd'; Report='room-ui-result.json'; Headless=$false; ExpectedChecks=84; Timeout=60}
    )) {
        $testDirectory = Join-Path $evidence $test.Name
        New-Item -ItemType Directory -Path $testDirectory | Out-Null
        $arguments = @('--path',('"' + $PSScriptRoot + '"'),'--main-pack',('"' + $Pack + '"'),'--script',$test.Script)
        if ($test.Headless) { $arguments = @('--headless') + $arguments }
        $arguments += @('--','--room-url=ws://127.0.0.1:30220/rooms',('"--evidence-dir=' + $testDirectory + '"'))
        $stdout = Join-Path $testDirectory 'stdout.log'
        $stderr = Join-Path $testDirectory 'stderr.log'
        $ownedGame = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if (-not $ownedGame.WaitForExit($test.Timeout * 1000)) { throw ($test.Name + ' timed out; only its owned process will be stopped.') }
        $ownedGame.WaitForExit()
        $exitCode = $ownedGame.ExitCode
        $ownedGame = $null
        $reportPath = Join-Path $testDirectory $test.Report
        if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw ($test.Name + ' produced no result JSON. See retained logs.') }
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $count = @($report.checks).Count
        $failed = @($report.checks | Where-Object { $_.passed -ne $true }).Count
        $logs = (Get-Content -LiteralPath $stdout -Raw) + "`n" + (Get-Content -LiteralPath $stderr -Raw)
        $clean = $logs -notmatch '(?m)^(SCRIPT ERROR|ERROR:|WARNING:)'
        $images = @()
        if (-not $test.Headless) {
            foreach ($imageName in @('01-unconfigured.png','02-configured.png','03-room-keyboard.png','04-room-teams.png')) {
                $imagePath = Join-Path $testDirectory $imageName
                if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf) -or (Get-Item -LiteralPath $imagePath).Length -eq 0) { throw ('Rendered UI image missing: ' + $imageName) }
                $images += @{path=$imagePath;sha256=(Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash}
            }
        }
        $passed = $exitCode -eq 0 -and $report.passed -eq $true -and $failed -eq 0 -and $count -eq $test.ExpectedChecks -and $clean
        $record.results += @{name=$test.Name;script=$test.Script;exit_code=$exitCode;passed=$passed;checks=$count;failed_checks=$failed;clean_log=$clean;result=$reportPath;images=$images}
        if (-not $passed) { throw ($test.Name + ' failed its exact-pack checks. See retained JSON and logs.') }
    }
    $relayErrors = Get-Content -LiteralPath (Join-Path $evidence 'relay.stderr.log') -Raw
    if (-not [string]::IsNullOrWhiteSpace($relayErrors)) { throw 'Relay wrote stderr; review retained log before accepting verification.' }
    $record.passed = $true
    $record.ok = $true
} catch {
    $failure = $_
    $record.error = $_.Exception.Message
} finally {
    Stop-OwnedProcess $ownedGame
    Stop-OwnedProcess $ownedRelay
    $record.pack_sha256_after = (Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash
    if ($record.pack_sha256_before -ne $record.pack_sha256_after) { $record.passed = $false; $record.ok = $false; $record.error = 'Executable changed during verification.' }
    $record.completed_at = (Get-Date).ToString('o')
    $record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $evidence 'verification.json') -Encoding UTF8
}
if (-not $record.passed) { if ($failure) { throw $failure }; throw $record.error }
Write-Output ('RELEASE_ROOMS_PASS SHA256 ' + $record.pack_sha256_after + ' evidence=' + $evidence)
