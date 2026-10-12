param(
    [string]$Pack='C:/game-3/build/crown-court-0.5.0/CrownCourt.exe',
    [string]$Label='v5-room-runtime-probe',
    [int]$Port=30240
)
. (Join-Path $PSScriptRoot 'harness.ps1')
if ($Label -notmatch '^[a-zA-Z0-9_-]+$' -or $Port -lt 1024 -or $Port -gt 65535) { throw 'Invalid probe label or port' }
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw 'Probe relay port is already in use' }
$folder=Join-Path $evidence $Label
if (Test-Path -LiteralPath $folder) { throw 'Probe evidence already exists' }
$viewFolder=Join-Path $folder 'view'
New-Item -ItemType Directory -Path $viewFolder -Force | Out-Null
$Pack=[IO.Path]::GetFullPath($Pack)
$base=@('--path',$source,'--main-pack',$Pack,'--max-fps','60')
$url='ws://127.0.0.1:'+$Port+'/rooms'
$common=@(('--evidence-dir='+$folder),('--room-url='+$url),'--max-seconds=70')
$jobs=@()
$relay=$null
try {
    $relayInfo=[Diagnostics.ProcessStartInfo]::new()
    $relayInfo.FileName=(Get-Command node -ErrorAction Stop).Source
    $relayInfo.ArgumentList.Add((Join-Path $source 'relay/server.mjs'))
    $relayInfo.UseShellExecute=$false
    $relayInfo.CreateNoWindow=$true
    $relayInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $relayInfo.RedirectStandardOutput=$true
    $relayInfo.RedirectStandardError=$true
    $relayInfo.Environment['HOST']='127.0.0.1'
    $relayInfo.Environment['PORT']=[string]$Port
    $relay=[Diagnostics.Process]::new()
    $relay.StartInfo=$relayInfo
    if (-not $relay.Start()) { throw 'Relay failed to start' }
    $relayOutput=$relay.StandardOutput.ReadToEndAsync()
    $relayError=$relay.StandardError.ReadToEndAsync()
    $deadline=[datetime]::UtcNow.AddSeconds(10)
    while ($true) {
        try { if ((Invoke-RestMethod ('http://127.0.0.1:'+$Port+'/healthz') -TimeoutSec 1).ok) { break } } catch {}
        if ($relay.HasExited -or [datetime]::UtcNow -gt $deadline) { throw 'Relay failed readiness check' }
        Start-Sleep -Milliseconds 100
    }
    $hostJob=Start-GameProcess $engine ($base+@('--headless','--script',(Join-Path $source 'tests/runtime_probe_peer.gd'),'--','--probe-host')+$common) ($Label+'-host')
    $jobs+=$hostJob
    $deadline=[datetime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath (Join-Path $folder 'host-ready.json'))) {
        if ($hostJob.Process.HasExited) { Complete-GameProcess $hostJob 1; throw 'Host exited early' }
        if ([datetime]::UtcNow -gt $deadline) { throw 'Host registration timed out' }
        Start-Sleep -Milliseconds 100
    }
    $code=(Get-Content -LiteralPath (Join-Path $folder 'host-ready.json') -Raw | ConvertFrom-Json).room_code
    $peerJob=Start-GameProcess $engine ($base+@('--headless','--script',(Join-Path $source 'tests/runtime_probe_peer.gd'),'--',('--room-code='+$code))+$common) ($Label+'-peer')
    $jobs+=$peerJob
    $viewJob=Start-GameProcess $engine ($base+@('--script',(Join-Path $source 'tests/runtime_probe_view.gd'),'--resolution','1280x800','--',('--evidence-dir='+$viewFolder),('--room-url='+$url),('--room-code='+$code),'--nickname=PROBE VIEW','--max-seconds=35','--sanity')) ($Label+'-view')
    $jobs+=$viewJob
    Complete-GameProcess $viewJob 75
    Complete-GameProcess $peerJob 20
    Complete-GameProcess $hostJob 20
} finally {
    foreach ($job in $jobs) {
        try { if (-not $job.Process.HasExited) { $job.Process.Kill($true); $job.Process.WaitForExit() } } catch {}
        [IO.File]::WriteAllText((Join-Path $evidence ($job.Label+'.stdout.log')),$job.Output.GetAwaiter().GetResult())
        [IO.File]::WriteAllText((Join-Path $evidence ($job.Label+'.stderr.log')),$job.Error.GetAwaiter().GetResult())
    }
    if ($relay) {
        if (-not $relay.HasExited) { $relay.Kill($true) }
        $relay.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $folder 'relay.stdout.log'),$relayOutput.GetAwaiter().GetResult())
        [IO.File]::WriteAllText((Join-Path $folder 'relay.stderr.log'),$relayError.GetAwaiter().GetResult())
        $relay.Dispose()
    }
}
$reports=@{}
foreach ($role in @('host','peer','view')) {
    $path=if ($role -eq 'view') { Join-Path $viewFolder 'runtime-view.json' } else { Join-Path $folder ('runtime-'+$role+'.json') }
    $reports[$role]=(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).summary
    if ($reports[$role].frames -lt 100 -or $reports[$role].wall_span -lt 30) { throw 'Insufficient runtime probe frames' }
}
$manifest=@{pack=$Pack;pack_sha256=(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash;transport='owned loopback WebSocket relay';capture=$false;fixture_mutations=$false;reports=$reports}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $folder 'runtime-probe.json')
$manifest | ConvertTo-Json -Depth 10
