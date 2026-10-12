param([string]$Label='v6-network-performance-baseline',[string]$Pack='C:/game-3/build/crown-court-0.5.0/CrownCourt.exe')
. (Join-Path $PSScriptRoot '../harness.ps1')
if (Get-NetTCPConnection -LocalPort 30250 -State Listen -ErrorAction SilentlyContinue) { throw '30250 already in use' }
$folder=Join-Path $evidence $Label
if (Test-Path $folder) { throw 'Evidence exists' }
New-Item -ItemType Directory -Path $folder | Out-Null
$savedPort=$env:PORT
$savedHost=$env:HOST
$env:PORT='30250'; $env:HOST='127.0.0.1'
$relayJob=Start-GameProcess (Get-Command node).Source @((Join-Path $source 'relay/server.mjs')) ($Label+'-relay')
$env:PORT=$savedPort; $env:HOST=$savedHost
$jobs=@()
try {
    $deadline=[datetime]::UtcNow.AddSeconds(10)
    while($true) {
        try { if((Invoke-RestMethod http://127.0.0.1:30250/healthz -TimeoutSec 1).ok){break} } catch {}
        if([datetime]::UtcNow -gt $deadline){throw 'Relay not ready'}
        Start-Sleep -Milliseconds 100
    }
    $base=@('--headless','--max-fps','60','--path',$source)
    if($Pack){$base+=@('--main-pack',$Pack)}
    $base+=@('--script',(Join-Path $source 'tests/performance_network.gd'),'--',('--evidence-dir='+$folder),'--room-url=ws://127.0.0.1:30250/rooms')
    $hostJob=Start-GameProcess $engine ($base+@('--role=host')) ($Label+'-host')
    $jobs+=$hostJob
    $deadline=[datetime]::UtcNow.AddSeconds(15)
    while(-not(Test-Path (Join-Path $folder 'host-ready.json'))){if([datetime]::UtcNow -gt $deadline){throw 'Host not ready'};Start-Sleep -Milliseconds 100}
    $code=(Get-Content (Join-Path $folder 'host-ready.json') -Raw|ConvertFrom-Json).room_code
    foreach($role in @('peer','peer2')){$jobs+=Start-GameProcess $engine ($base+@(('--role='+$role),('--room-code='+$code))) ($Label+'-'+$role)}
    foreach($job in $jobs){Complete-GameProcess $job 45}
    foreach($role in @('host','peer','peer2')) {
        $report=Get-Content (Join-Path $folder ($role+'.json')) -Raw|ConvertFrom-Json
        if($report.summary.played -lt 12 -or $report.summary.peak_roster -ne 3 -or $report.summary.opponent_bots -ne 3){throw "$role did not complete the active three-player profiling window"}
    }
}finally{
    foreach($job in $jobs){try{if(-not$job.Process.HasExited){$job.Process.Kill($true)}}catch{}}
    if(-not$relayJob.Process.HasExited){$relayJob.Process.Kill($true)}
    $relayJob.Process.WaitForExit()
    [IO.File]::WriteAllText((Join-Path $folder 'relay.stdout.log'),$relayJob.Output.GetAwaiter().GetResult())
    [IO.File]::WriteAllText((Join-Path $folder 'relay.stderr.log'),$relayJob.Error.GetAwaiter().GetResult())
}
