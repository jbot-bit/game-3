param(
    [string]$Label='v3-network-active',
    [string]$Pack='',
    [string]$RoomUrl='',
    [int]$MaxSeconds=600,
    [int]$CaptureFps=12,
    [switch]$HeadlessSmoke,
    [switch]$FamilyCharacters,
    [string]$Encoder=''
)
function Resolve-FFmpeg([string]$Override='') {
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        if (Test-Path -LiteralPath $Override -PathType Leaf) { return (Get-Item -LiteralPath $Override).FullName }
        $command = Get-Command -Name $Override -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
        throw ('FFmpeg override was not found: '+$Override)
    }
    $command = Get-Command -Name ffmpeg -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $packages = Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Packages'
        $candidates = @(Get-ChildItem -LiteralPath $packages -Directory -Filter '*FFmpeg*' -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -File -Filter 'ffmpeg.exe' -Recurse -ErrorAction SilentlyContinue
        } | Sort-Object LastWriteTimeUtc,FullName -Descending)
        if ($candidates.Count) { return $candidates[0].FullName }
    }
    throw 'FFmpeg was not found. Install it on PATH or pass -Encoder with its executable path.'
}
. (Join-Path $PSScriptRoot 'harness.ps1')
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Label must be a simple file name' }
if ($CaptureFps -lt 1 -or $CaptureFps -gt 30) { throw 'CaptureFps must be 1-30' }
if ($MaxSeconds -lt 30 -or $MaxSeconds -gt 900) { throw 'MaxSeconds must be 30-900' }
if ($RoomUrl) {
    $roomEndpoint = [Uri]$RoomUrl
    if ($roomEndpoint.Scheme -ne 'ws' -or $roomEndpoint.Host -ne '127.0.0.1' -or $roomEndpoint.AbsolutePath -ne '/rooms' -or $roomEndpoint.Query -or $roomEndpoint.Fragment) { throw 'Room recording uses an owned loopback relay: ws://127.0.0.1:PORT/rooms' }
    if (Get-NetTCPConnection -LocalPort $roomEndpoint.Port -State Listen -ErrorAction SilentlyContinue) { throw 'The room recording relay port is already in use' }
} elseif (Get-NetUDPEndpoint -LocalPort 28888 -ErrorAction SilentlyContinue) { throw 'UDP 28888 is already in use. Close the previous court before this run.' }
$folder = Join-Path $evidence $Label
if (Test-Path -LiteralPath $folder) { throw ('Recording already exists: '+$folder) }
New-Item -ItemType Directory -Path $folder | Out-Null
$viewFolder = Join-Path $folder 'view'
New-Item -ItemType Directory -Path $viewFolder | Out-Null
$base = @('--path',$source,'--max-fps','60')
if ($Pack) {
    $Pack = [IO.Path]::GetFullPath($Pack)
    $base += @('--main-pack',$Pack)
}
$common = @(('--evidence-dir='+$folder),('--max-seconds='+$MaxSeconds))
if ($RoomUrl) { $common += '--room-url='+$RoomUrl }
if ($HeadlessSmoke) { $common += '--sanity' }
$jobs = @()
$relayProcess = $null
$driverHashes = @{}
foreach ($driver in @('active_play.gd','active_network_host.gd','active_network_peer.gd')) {
    $driverHashes[$driver] = (Get-FileHash -LiteralPath (Join-Path $source ('tests/'+$driver)) -Algorithm SHA256).Hash
}
function Get-RecordingRuntimeHashes {
    $runtimeFiles=@(Get-ChildItem -LiteralPath $source -File | Where-Object { $_.Extension -eq '.gd' -or $_.Name -in @('project.godot','main.tscn','internet.cfg') })
    $runtimeFiles+=@(Get-ChildItem -LiteralPath (Join-Path $source 'assets') -Recurse -File)
    $hashes=@{}
    foreach ($file in $runtimeFiles) { $hashes[[IO.Path]::GetRelativePath($source,$file.FullName).Replace('\','/')]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    return $hashes
}
if (-not $Pack) { $runtimeHashesBefore=Get-RecordingRuntimeHashes }
try {
    if ($RoomUrl) {
        $relayInfo = [Diagnostics.ProcessStartInfo]::new()
        $relayInfo.FileName = (Get-Command node -ErrorAction Stop).Source
        $relayInfo.ArgumentList.Add((Join-Path $source 'relay/server.mjs'))
        $relayInfo.WorkingDirectory = $source
        $relayInfo.UseShellExecute = $false
        $relayInfo.CreateNoWindow = $true
        $relayInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
        $relayInfo.RedirectStandardOutput = $true
        $relayInfo.RedirectStandardError = $true
        $relayInfo.Environment['PORT'] = [string]$roomEndpoint.Port
        $relayInfo.Environment['HOST'] = '127.0.0.1'
        $relayProcess = [Diagnostics.Process]::new()
        $relayProcess.StartInfo = $relayInfo
        if (-not $relayProcess.Start()) { throw 'Could not start the owned loopback room relay' }
        $relayOutput = $relayProcess.StandardOutput.ReadToEndAsync()
        $relayError = $relayProcess.StandardError.ReadToEndAsync()
        $deadline = [datetime]::UtcNow.AddSeconds(10)
        while ($true) {
            if ($relayProcess.HasExited) { throw 'Room relay exited before readiness' }
            try {
                $health = Invoke-RestMethod ('http://127.0.0.1:'+$roomEndpoint.Port+'/healthz') -TimeoutSec 1
                if ($health.ok) { break }
            } catch { }
            if ([datetime]::UtcNow -gt $deadline) { throw 'Room relay did not become ready' }
            Start-Sleep -Milliseconds 100
        }
    }
    $hostArgs = $base + @('--headless','--script',(Join-Path $source 'tests/active_network_peer.gd'),'--','--host') + $common
    if ($FamilyCharacters) { $hostArgs += '--character=evie' }
    $hostJob = Start-GameProcess $engine $hostArgs ($Label+'-host') ($Label+'-host')
    $jobs += $hostJob
    $deadline = [datetime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath (Join-Path $folder 'host-ready.json'))) {
        if ($hostJob.Process.HasExited) { Complete-GameProcess $hostJob 1; throw 'Host exited before readiness' }
        if ([datetime]::UtcNow -gt $deadline) { throw 'Host did not become ready' }
        Start-Sleep -Milliseconds 100
    }
    $ready = Get-Content -LiteralPath (Join-Path $folder 'host-ready.json') -Raw | ConvertFrom-Json
    if ($RoomUrl -and ($ready.transport -ne 'room' -or $ready.room_code.Length -ne 26)) { throw 'Room host did not return a registered room code' }
    $peerArgs = $base + @('--headless','--script',(Join-Path $source 'tests/active_network_peer.gd'),'--') + $common
    $peerArgs += '--wait-for-view'
    if ($FamilyCharacters) { $peerArgs += '--character=tyler' }
    if ($RoomUrl) { $peerArgs += '--room-code='+$ready.room_code }
    $peerJob = Start-GameProcess $engine $peerArgs ($Label+'-peer') ($Label+'-peer')
    $jobs += $peerJob
    $viewArgs = $base + @('--script',(Join-Path $source 'tests/active_play.gd'),'--resolution','1280x800')
    if ($HeadlessSmoke) { $viewArgs += '--headless' }
    $viewLimit = if ($HeadlessSmoke) { 12 } else { $MaxSeconds }
    $viewNickname = if ($FamilyCharacters) { 'Dad' } else { 'PLAY VIEW' }
    $viewArgs += @('--',('--nickname='+$viewNickname),('--evidence-dir='+$viewFolder),('--max-seconds='+$viewLimit))
    if ($FamilyCharacters) { $viewArgs += '--character=dad' }
    if ($RoomUrl) { $viewArgs += @(('--room-url='+$RoomUrl),('--room-code='+$ready.room_code)) }
    else { $viewArgs += '--join=127.0.0.1' }
    if ($HeadlessSmoke) { $viewArgs += '--sanity' }
    else { $viewArgs += '--capture-fps='+$CaptureFps }
    $viewJob = Start-GameProcess $engine $viewArgs ($Label+'-view') ($Label+'-view')
    $jobs += $viewJob
    Complete-GameProcess $viewJob ($MaxSeconds+45)
    Complete-GameProcess $peerJob 30
    Complete-GameProcess $hostJob 30
} finally {
    foreach ($job in $jobs) {
        try { if (-not $job.Process.HasExited) { $job.Process.Kill($true) } } catch { }
    }
    if ($relayProcess) {
        if (-not $relayProcess.HasExited) { $relayProcess.Kill($true) }
        $relayProcess.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $folder 'relay.stdout.log'),$relayOutput.GetAwaiter().GetResult())
        [IO.File]::WriteAllText((Join-Path $folder 'relay.stderr.log'),$relayError.GetAwaiter().GetResult())
        $relayProcess.Dispose()
    }
}
if (-not $Pack) {
    $runtimeHashesAfter=Get-RecordingRuntimeHashes
    $runtimeChanged=@($runtimeHashesBefore.Keys | Where-Object { $runtimeHashesBefore[$_] -ne $runtimeHashesAfter[$_] })
    $runtimeAdded=@($runtimeHashesAfter.Keys | Where-Object { -not $runtimeHashesBefore.ContainsKey($_) })
    $runtimeProvenance=@{unchanged=($runtimeChanged.Count -eq 0 -and $runtimeAdded.Count -eq 0);before=$runtimeHashesBefore;after=$runtimeHashesAfter;changed=$runtimeChanged;added=$runtimeAdded;scope='source runtime scripts, project/scene/settings and all authored assets'}
    $runtimeProvenance | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $folder 'runtime-provenance.json')
    if (-not $runtimeProvenance.unchanged) { throw 'Source runtime changed while recording; provenance receipt retained' }
}
$hostReport = (Get-Content -LiteralPath (Join-Path $folder 'host.json') -Raw | ConvertFrom-Json).summary
$peerReport = (Get-Content -LiteralPath (Join-Path $folder 'peer.json') -Raw | ConvertFrom-Json).summary
$viewReport = (Get-Content -LiteralPath (Join-Path $viewFolder 'active-play.json') -Raw | ConvertFrom-Json).summary
$reports = @($hostReport,$peerReport,$viewReport)
foreach ($report in $reports) {
    if ($report.fixture_mutations -or $report.peak_roster -ne 3) { throw 'Expected three connected humans with no fixture changes' }
    if (-not $HeadlessSmoke -and (-not $report.completed -or -not $report.reward_correct -or -not $report.reward_eligible_at_finish)) { throw 'A process did not complete its real result/reward path' }
}
if ($hostReport.opponent_bots -ne 3 -or $peerReport.opponent_bots -ne 3 -or $viewReport.initial_bots -ne 3) { throw 'Expected three opponent bots' }
if ($FamilyCharacters) {
    $familyRoles = @(
        @{role='host';character='evie';report=$hostReport},
        @{role='peer';character='tyler';report=$peerReport},
        @{role='view';character='dad';report=$viewReport}
    )
    $familySeats = @{}
    foreach ($owner in $familyRoles) {
        if ($owner.report.character -ne $owner.character) { throw ('Wrong selected character for '+$owner.role) }
        $seat = [string]$owner.report.seat
        if ($seat -notin @('1','2','3') -or $familySeats.ContainsKey($seat)) { throw 'Family characters must occupy three distinct human seats' }
        $familySeats[$seat] = $owner.character
        $authoritative = $hostReport.cosmetics.PSObject.Properties[$seat].Value
        if (-not $authoritative -or $authoritative.character -ne $owner.character) { throw ('Authoritative final snapshot is missing '+$owner.character) }
        foreach ($report in $reports) {
            $appearance = $report.cosmetics.PSObject.Properties[$seat].Value
            if (-not $appearance -or $appearance.character -ne $owner.character -or $appearance.outfit -ne $authoritative.outfit -or $appearance.accessory -ne $authoritative.accessory) { throw ('Processes disagree about final family equipment for seat '+$seat) }
        }
    }
}
if (-not $HeadlessSmoke) {
    $score = $hostReport.scores | ConvertTo-Json -Compress
    foreach ($report in $reports) {
        if ($report.match_id -ne $hostReport.match_id -or $report.winner -ne $hostReport.winner -or (($report.scores | ConvertTo-Json -Compress) -ne $score)) { throw 'Processes disagree about the final round, winner, or score' }
    }
}
$manifest = @{label=$Label;mode='coop';humans=3;opponent_bots=3;smoke_only=[bool]$HeadlessSmoke;pack=$Pack;clock='real network time; no fixed-fps or movie mode';input='rendered client InputEvents, host and second client normal submit inputs';recorded_at=(Get-Date).ToString('o');host=$hostReport;peer=$peerReport;view=$viewReport}
$manifest.transport = if ($RoomUrl) { 'room-websocket' } else { 'enet-udp' }
if ($RoomUrl) { $manifest.relay = @{url=$RoomUrl;owned_loopback=$true;server_sha256=(Get-FileHash -LiteralPath (Join-Path $source 'relay/server.mjs') -Algorithm SHA256).Hash} }
$manifest.driver_sha256 = $driverHashes
if (-not $Pack) { $manifest.runtime_provenance=$runtimeProvenance }
if ($FamilyCharacters) {
    $manifest.family_characters = @{host='evie';peer='tyler';view='dad'}
    $manifest.family_seats = $familySeats
    $manifest.final_family_cosmetics_agree = $true
}
if (-not $HeadlessSmoke) {
    $Encoder = Resolve-FFmpeg $Encoder
    $capture = Get-Content -LiteralPath (Join-Path $viewFolder 'capture-timestamps.json') -Raw | ConvertFrom-Json
    if ($capture.frames.Count -lt 2) { throw 'Too few captured frames' }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('ffconcat version 1.0')
    for ($i=0; $i -lt $capture.frames.Count; $i++) {
        $frame = $capture.frames[$i]
        $framePath = (Join-Path $viewFolder $frame.file).Replace('\','/')
        $lines.Add("file '$framePath'")
        $duration = if ($i+1 -lt $capture.frames.Count) { [double]$capture.frames[$i+1].time-[double]$frame.time } else { 1.0/$CaptureFps }
        $lines.Add('duration '+$duration.ToString('0.000000',[Globalization.CultureInfo]::InvariantCulture))
    }
    $lastPath = (Join-Path $viewFolder $capture.frames[-1].file).Replace('\','/')
    $lines.Add("file '$lastPath'")
    $concat = Join-Path $folder 'frames.ffconcat'
    [IO.File]::WriteAllLines($concat,$lines,[Text.UTF8Encoding]::new($false))
    $video = Join-Path $folder 'joined-client.mp4'
    & $Encoder -hide_banner -loglevel error -n -f concat -safe 0 -i $concat -fps_mode vfr -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -movflags +faststart $video
    if ($LASTEXITCODE -ne 0) { throw 'VFR video conversion failed; JPEG frames retained' }
    $manifest.video = $video
    $manifest.video_sha256 = (Get-FileHash -LiteralPath $video -Algorithm SHA256).Hash
    $manifest.frame_count = $capture.frames.Count
    $manifest.audio = $false
    $manifest.capture_duration_seconds = [double]$capture.frames[-1].time-[double]$capture.frames[0].time
}
if ($Pack) { $manifest.pack_sha256=(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash }
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $folder 'recording.json')
Write-Output ('ACTIVE_NETWORK_RECORDING_RESULT '+($manifest | ConvertTo-Json -Depth 12 -Compress))
