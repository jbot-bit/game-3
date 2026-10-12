param(
    [string]$Label='family-network',
    [string]$Pack='',
    [string]$EnginePath='',
    [ValidateRange(1024,65535)][int]$Port=30262
)
. (Join-Path $PSScriptRoot '../harness.ps1')
if ($EnginePath) { $engine=(Get-Item -LiteralPath $EnginePath -ErrorAction Stop).FullName }
if ($Pack) {
    $Pack=(Get-Item -LiteralPath $Pack -ErrorAction Stop).FullName
    $packHashBefore=(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash
}
if ($Label -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid evidence label' }
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw "TCP $Port already in use" }
$folder=Join-Path $evidence $Label
if (Test-Path -LiteralPath $folder) { throw 'Evidence exists; use a fresh label' }
New-Item -ItemType Directory -Path $folder | Out-Null
$savedPort=$env:PORT
$savedHost=$env:HOST
$relayJob=$null
$job=$null
try {
    $env:PORT=[string]$Port
    $env:HOST='127.0.0.1'
    $relayJob=Start-GameProcess (Get-Command node).Source @((Join-Path $source 'relay/server.mjs')) ($Label+'-relay') $Label
    $env:PORT=$savedPort
    $env:HOST=$savedHost
    $deadline=[datetime]::UtcNow.AddSeconds(10)
    while ($true) {
        try { if ((Invoke-RestMethod "http://127.0.0.1:$Port/healthz" -TimeoutSec 1).ok) { break } } catch {}
        if ([datetime]::UtcNow -gt $deadline) { throw 'Isolated relay not ready' }
        Start-Sleep -Milliseconds 100
    }
    $arguments=@('--headless','--max-fps','60','--path',$source)
    if ($Pack) { $arguments+=@('--main-pack',$Pack) }
    $arguments+=@('--script',(Join-Path $source 'tests/family_network.gd'),'--',('--evidence-dir='+$folder),("--room-url=ws://127.0.0.1:$Port/rooms"))
    $job=Start-GameProcess $engine $arguments $Label $Label
    Complete-GameProcess $job 55
    $report=Get-Content (Join-Path $folder 'family-network-result.json') -Raw | ConvertFrom-Json
    if (-not $report.passed) { throw 'Family network verification failed' }
    $verification=@{passed=$true;engine=$engine;engine_sha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash;pack=$Pack;relay_port=$Port;profile_scope=$Label;checks=$report.checks.Count;scope=$report.scope;completed=(Get-Date).ToString('o')}
    if ($Pack) {
        $verification.pack_sha256_before=$packHashBefore
        $verification.pack_sha256_after=(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash
        if ($verification.pack_sha256_after -ne $packHashBefore) { throw 'Exported pack changed during family network verification' }
    }
    $verification | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $folder 'verification.json')
    Write-Output "Family network evidence: $folder"
} finally {
    $env:PORT=$savedPort
    $env:HOST=$savedHost
    if ($job) { try { if (-not $job.Process.HasExited) { $job.Process.Kill($true) } } catch {} }
    if ($relayJob) {
        if (-not $relayJob.Process.HasExited) { $relayJob.Process.Kill($true) }
        $relayJob.Process.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $folder 'relay.stdout.log'),$relayJob.Output.GetAwaiter().GetResult())
        [IO.File]::WriteAllText((Join-Path $folder 'relay.stderr.log'),$relayJob.Error.GetAwaiter().GetResult())
        $relayJob.Process.Dispose()
    }
}
