param(
    [int]$Port=30180,
    [double]$DelayMs=50,
    [double]$JitterMs=10,
    [double]$Loss=.01,
    [int]$Seed=7123,
    [ValidateSet('actions','load','timeout')][string]$Scenario='actions',
    [string]$Label='internet-100ms',
    [string]$Pack='',
    [switch]$Saturated,
    [switch]$SingleSlot
)
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskSource=$PSScriptRoot
$taskEngine=Join-Path $taskRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$taskNode=(Get-Command node -ErrorAction Stop).Source
$taskEvidence=Join-Path $taskRoot ('build/crown-court-evidence/'+$Label)
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Use a plain evidence label'}
if($Port -eq 28888 -or ($Port -le 28888 -and $Port+4 -ge 28888)){throw 'Production port28888 must stay free'}
if(Test-Path -LiteralPath $taskEvidence){throw 'Evidence folder already exists; choose a new -Label'}
$occupied=@(Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -ge $Port -and $_.LocalPort -le $Port+4})
if($occupied.Count){throw ('Isolated UDP range is occupied: '+($occupied.LocalPort -join ','))}
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$sourceBefore=@{}
foreach($name in @('main.gd','sim.gd')){$sourceBefore[$name]=(Get-FileHash -LiteralPath (Join-Path $taskSource $name) -Algorithm SHA256).Hash}
$packBefore=if($Pack){(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash}else{''}
$jobs=[Collections.Generic.List[object]]::new()
function Start-InternetProcess([string]$Executable,[string[]]$Arguments,[string]$Role){
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$Executable
    foreach($argument in $Arguments){$start.ArgumentList.Add($argument)}
    $start.WorkingDirectory=$taskSource
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::new()
    $process.StartInfo=$start
    if(-not $process.Start()){throw ('Could not start '+$Role)}
    $job=@{process=$process;stdout=$process.StandardOutput.ReadToEndAsync();stderr=$process.StandardError.ReadToEndAsync();role=$Role}
    $jobs.Add($job)
    return $job
}
$failure=$null
try{
    & $taskNode (Join-Path $taskSource 'tests/internet_proxy_test.mjs')
    if($LASTEXITCODE -ne 0){throw 'Proxy schedule unit test failed'}
    $effectiveLoss=if($Scenario -eq 'timeout'){1.0}else{$Loss}
    $proxy=Start-InternetProcess $taskNode @((Join-Path $taskSource 'tests/internet_proxy.mjs'),('--port='+$Port),('--delay='+$DelayMs),('--jitter='+$JitterMs),('--loss='+$effectiveLoss),('--seed='+$Seed),('--scenario='+$Scenario),('--output='+$taskEvidence)) 'proxy'
    $wait=[Diagnostics.Stopwatch]::StartNew()
    while(-not (Test-Path -LiteralPath (Join-Path $taskEvidence 'proxy-ready.json'))){
        if($proxy.process.HasExited -or $wait.Elapsed.TotalSeconds -gt 10){throw 'Proxy did not become ready'}
        Start-Sleep -Milliseconds 100
    }
    $script='res://tests/internet_'+$Scenario+'.gd'
    $common=@('--headless','--path',$taskSource)
    if($Pack){$common+=@('--main-pack',[IO.Path]::GetFullPath($Pack))}
    $common+=@('--script',$script,'--',('--port='+$Port),('--output='+$taskEvidence))
    if($Saturated){$common+='--saturated'}
    if($SingleSlot){$common+='--single-slot'}
    $hostJob=Start-InternetProcess $taskEngine ($common+'--role=host') 'host'
    Start-Sleep -Milliseconds 700
    $first=Start-InternetProcess $taskEngine ($common+'--role=client1') 'client1'
    Start-Sleep -Milliseconds 250
    $second=Start-InternetProcess $taskEngine ($common+'--role=client2') 'client2'
    $wait.Restart()
    while(-not ($hostJob.process.HasExited -and $first.process.HasExited -and $second.process.HasExited)){
        if($wait.Elapsed.TotalSeconds -gt 90){throw 'Three-process internet test exceeded90seconds'}
        Start-Sleep -Milliseconds 200
    }
}catch{$failure=$_.Exception.Message}
finally{
    [IO.File]::WriteAllText((Join-Path $taskEvidence 'stop-proxy'),'stop')
    foreach($job in $jobs){
        if(-not $job.process.HasExited -and -not $job.process.WaitForExit(3000)){$job.process.Kill($true);$job.process.WaitForExit()}
        $normal=$job.stdout.GetAwaiter().GetResult()
        $errors=$job.stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $taskEvidence ($job.role+'.stdout.log')),$normal)
        [IO.File]::WriteAllText((Join-Path $taskEvidence ($job.role+'.stderr.log')),$errors)
        if($job.process.ExitCode -ne 0 -or ($normal+$errors) -match '(SCRIPT ERROR|ERROR:|WARNING:)'){
            $failure=($failure+' '+$job.role+' failed; inspect saved logs').Trim()
        }
        $job.process.Dispose()
    }
}
$reports=@{}
foreach($role in @('host','client1','client2')){
    $file=Join-Path $taskEvidence ($role+'.json')
    if(Test-Path -LiteralPath $file){$reports[$role]=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json;if(-not $reports[$role].ok){$failure=($failure+' '+$role+' reported failure').Trim()}}
    else{$failure=($failure+' Missing '+$role+' report').Trim()}
}
$proxyFile=Join-Path $taskEvidence 'proxy-stats.json'
$proxyStats=if(Test-Path -LiteralPath $proxyFile){Get-Content -LiteralPath $proxyFile -Raw | ConvertFrom-Json}else{$null}
$receipt=[ordered]@{ok=($null -eq $failure);failure=$failure;label='SIMULATED_INTERNET';scenario=$Scenario;ports=@($Port..($Port+4));nominal_rtt_ms=@((2*($DelayMs-$JitterMs)),(2*($DelayMs+$JitterMs)));loss_probability_each_direction=$effectiveLoss;seed=$Seed;source_sha256=@{};reports=$reports;proxy=$proxyStats;physical_cross_home_verified=$false}
foreach($name in @('main.gd','sim.gd')){$receipt.source_sha256[$name]=(Get-FileHash -LiteralPath (Join-Path $taskSource $name) -Algorithm SHA256).Hash}
$receipt['source_sha256_before']=$sourceBefore
$receipt['source_unchanged']=($sourceBefore['main.gd'] -eq $receipt.source_sha256['main.gd'] -and $sourceBefore['sim.gd'] -eq $receipt.source_sha256['sim.gd'])
$receipt['pack']=$Pack
$receipt['pack_sha256_before']=$packBefore
$receipt['pack_sha256_after']=if($Pack){(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash}else{''}
$receipt['saturated_transport_fixture']=$Saturated.IsPresent
$receipt['old_single_slot_test_fixture']=$SingleSlot.IsPresent
if((-not $Pack -and -not $receipt.source_unchanged) -or ($Pack -and $receipt.pack_sha256_after -ne $packBefore)){$failure=($failure+' Loaded code changed during test').Trim();$receipt.ok=$false;$receipt.failure=$failure}
$receipt | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $taskEvidence 'internet-result.json')
if($failure){throw ($failure+'; evidence '+$taskEvidence)}
Write-Output ('INTERNET_RESULT PASS simulated '+$Scenario+'; evidence '+$taskEvidence)
foreach($role in @('host','client1','client2')){
    $result=$reports[$role]
    Write-Output ($role+' '+($result.snapshot_arrival_gap_ms | ConvertTo-Json -Compress)+' RTT '+($result.application_probe_rtt_ms | ConvertTo-Json -Compress))
}
