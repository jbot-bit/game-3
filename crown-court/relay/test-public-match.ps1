param([Parameter(Mandatory)][string]$Endpoint,[Parameter(Mandatory)][string]$Label,[string]$ClientPack='')
. (Join-Path $PSScriptRoot '../harness.ps1')
if($Endpoint -notmatch '^wss://[A-Za-z0-9.-]+(?::[0-9]+)?/rooms$'){throw 'Use the deployed secure room endpoint'}
if($Label -notmatch '^[A-Za-z0-9_-]+$'){throw 'Use a plain label'}
$folder=Join-Path $evidence $Label
if(Test-Path $folder){throw 'Preserve existing evidence; choose a new label'}
New-Item -ItemType Directory $folder | Out-Null
$windowsPack=Join-Path $root 'CrownCourt.exe'
if(-not $ClientPack){$ClientPack=$windowsPack}
$before=@{windows=(Get-FileHash $windowsPack).Hash;client=(Get-FileHash $ClientPack).Hash}
$jobs=@()
try {
    foreach($role in @('host','peer1','peer2')){
        $roleFolder=Join-Path $folder $role
        New-Item -ItemType Directory $roleFolder | Out-Null
        $pack=if($role -eq 'host'){$windowsPack}else{$ClientPack}
        $arguments=@('--headless','--max-fps','60','--path',$source,'--main-pack',$pack,'--script',(Join-Path $PSScriptRoot 'public_match_driver.gd'),'--',"--room-url=$Endpoint","--evidence-dir=$roleFolder",'--max-seconds=600')
        if($role -eq 'host'){$arguments+='--host'}else{$arguments+="--room-code=$code"}
        $jobs+=Start-GameProcess $engine $arguments ($Label+'-'+$role) ($Label+'-'+$role)
        if($role -eq 'host'){
            $ready=Join-Path $roleFolder 'host-ready.json'
            $deadline=[datetime]::UtcNow.AddSeconds(20)
            while(-not(Test-Path $ready)){
                if([datetime]::UtcNow -gt $deadline -or $jobs[0].Process.HasExited){throw 'Public room host did not become ready'}
                Start-Sleep -Milliseconds 100
            }
            $code=(Get-Content $ready -Raw|ConvertFrom-Json).room_code
        }
    }
    foreach($job in $jobs){Complete-GameProcess $job 650}
    $reports=@()
    foreach($role in @('host','peer1','peer2')){
        $reportName=if($role -eq 'host'){'host.json'}else{'peer.json'}
        $summary=(Get-Content (Join-Path (Join-Path $folder $role) $reportName) -Raw|ConvertFrom-Json).summary
        if(-not $summary.completed -or -not $summary.reward_correct -or $summary.fixture_mutations -or $summary.peak_roster -ne 3){throw "$role did not pass the full public match"}
        $reports+=$summary
    }
    if(@($reports.match_id|Select-Object -Unique).Count -ne 1 -or @($reports.winner|Select-Object -Unique).Count -ne 1){throw 'Peers disagree on completed match'}
    $after=@{windows=(Get-FileHash $windowsPack).Hash;client=(Get-FileHash $ClientPack).Hash}
    if($before.windows -ne $after.windows -or $before.client -ne $after.client){throw 'A package changed during the match'}
    @{passed=$true;endpoint=$Endpoint;packages=$after;reports=$reports;nativeMacExecution=$false;physicalSeparateHouses=$false;scope='Three native Windows processes through public TLS; Windows and Mac exported game data; ordinary input driver, no live-state mutations'} | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $folder 'verification.json')
}finally{
    foreach($job in $jobs){try{if(-not $job.Process.HasExited){$job.Process.Kill($true)}}catch{}}
}
