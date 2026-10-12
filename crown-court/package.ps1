param([string]$Version='0.11.0', [string]$EvidencePrefix='v11-release', [string]$NetworkRecording='v11-release-room', [string]$MatchRecording='v11-release-match')
. (Join-Path $PSScriptRoot 'harness.ps1')
$destination = Join-Path $root ('build/crown-court-'+$Version)
$exe = Join-Path $destination 'CrownCourt.exe'
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
$exe32 = Join-Path $destination 'CrownCourt32.exe'
$hash32 = (Get-FileHash -LiteralPath $exe32 -Algorithm SHA256).Hash
$compatibility = Join-Path $evidence 'v11-compat-rea'
$native32 = Get-Content -LiteralPath (Join-Path $compatibility 'v11-final-native32-menu.json') -Raw | ConvertFrom-Json
$mixed = Get-Content -LiteralPath (Join-Path $compatibility 'v11-final-mixed-network.json') -Raw | ConvertFrom-Json
$cpu32 = Get-Content -LiteralPath (Join-Path $compatibility 'v11-final32-cpu-tests.json') -Raw | ConvertFrom-Json
if (-not $native32.passed -or $native32.sha256_before -ne $hash32 -or $native32.sha256_after -ne $hash32 -or -not $mixed.passed -or -not $mixed.winner_score_match_id_agreement -or $mixed.candidate_sha256 -ne $hash32 -or $mixed.original_sha256 -ne $hash) { throw '32-bit startup or mixed-architecture evidence does not match the release' }
if ($cpu32.reports.Count -ne 6 -or @($cpu32.reports | Where-Object { -not $_.passed -or $_.pack_sha256 -ne $hash32 }).Count) { throw '32-bit packaged regressions are incomplete' }
$network = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-network-verified.json')) -Raw | ConvertFrom-Json
$playtest = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-playtest-results.json')) -Raw | ConvertFrom-Json
if ($network.sha256 -ne $hash -or $playtest.executable_sha256 -ne $hash) { throw 'Verification does not match this executable' }
if ($playtest.input.failures.Count -or $playtest.route.failures.Count -or -not $playtest.route.route_scored -or $playtest.route.kickoff_respawns -ne 1) { throw 'Rendered gameplay verification is incomplete' }
if (-not $playtest.controller.passed -or $playtest.controller.display_server -eq 'headless' -or $playtest.controller.checks.Count -lt 63) { throw 'Rendered controller flow verification is incomplete' }
$audio = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-audio-pack/result.json')) -Raw | ConvertFrom-Json
if (-not $audio.passed -or $audio.display -eq 'headless' -or $audio.checks.Count -lt 14 -or $audio.pack_sha256.ToUpper() -ne $hash) { throw 'Native audio/input verification does not match this executable' }
foreach ($dunkProbe in @(@{name='dunk_aim';count=64},@{name='world_dunk_axis';count=9})) {
    $dunkResult = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-pack-'+$dunkProbe.name+'/result.json')) -Raw | ConvertFrom-Json
    if (-not $dunkResult.passed -or $dunkResult.pack_sha256.ToUpper() -ne $hash -or $dunkResult.checks.Count -lt $dunkProbe.count -or @($dunkResult.checks | Where-Object { -not $_.passed }).Count) { throw ('Changing-aim dunk verification is incomplete or belongs to another executable: '+$dunkProbe.name) }
}
$deckResult = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-pack-deck_edge_prediction/result.json')) -Raw | ConvertFrom-Json
if (-not $deckResult.passed -or $deckResult.pack_sha256.ToUpper() -ne $hash -or $deckResult.checks.Count -lt 27 -or @($deckResult.checks | Where-Object { -not $_.passed }).Count) { throw 'Deck-edge packet/presentation verification is incomplete or belongs to another executable' }
$arena = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-pack-arena_review/result.json')) -Raw | ConvertFrom-Json
if (-not $arena.passed -or $arena.pack_sha256.ToUpper() -ne $hash -or $arena.metrics.warm_follow.display -eq 'headless' -or -not $arena.metrics.multimesh_readback.available -or $arena.metrics.scenery.unavailable_multimesh_instances -ne 0 -or $arena.metrics.terrain.wrong_front_faces -ne 0 -or $arena.checks.Count -lt 37 -or @($arena.captures.PSObject.Properties).Count -lt 9) { throw 'Native terrain/stadium/sightline verification is incomplete or belongs to another executable' }
foreach ($capture in $arena.captures.PSObject.Properties) {
    if (-not (Test-Path -LiteralPath $capture.Value.path) -or (Get-FileHash -LiteralPath $capture.Value.path -Algorithm SHA256).Hash -ne $capture.Value.sha256) { throw 'Native arena evidence image is missing or changed' }
}
foreach ($roomProbe in @('rpc','wan')) {
    $roomFolder = if ($roomProbe -eq 'wan') { 'tcp' } else { 'rpc' }
    $room = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-room-'+$roomFolder+'/'+$roomProbe+'-result.json')) -Raw | ConvertFrom-Json
    if (-not $room.ok -or $room.implementation_sha256_before -ne $hash -or $room.implementation_sha256_after -ne $hash) { throw ('Room probe does not match this executable: '+$roomProbe) }
}
$roomApp = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-room-application/verification.json')) -Raw | ConvertFrom-Json
if (-not $roomApp.ok -or $roomApp.pack_sha256_before -ne $hash -or $roomApp.pack_sha256_after -ne $hash) { throw 'Room application verification does not match this executable' }
if ($roomApp.results.Count -ne 2 -or @($roomApp.results | Where-Object { -not $_.passed }).Count -or ($roomApp.results | Where-Object name -eq 'application').checks -ne 25 -or ($roomApp.results | Where-Object name -eq 'ui').checks -ne 84) { throw 'Room application or rendered menu coverage is incomplete' }
$roomPowers = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-room-powers/verification.json')) -Raw | ConvertFrom-Json
if (-not $roomPowers.ok -or $roomPowers.mode -ne 'exact embedded pack' -or $roomPowers.pack_sha256_before -ne $hash -or $roomPowers.pack_sha256_after -ne $hash -or $roomPowers.results.Count -ne 1 -or $roomPowers.results[0].checks -lt 27 -or $roomPowers.results[0].failed_checks -ne 0 -or -not $roomPowers.results[0].clean_log) { throw 'Joined-client power lifecycle verification is incomplete or belongs to another executable' }
foreach ($scenario in @('actions','load','timeout')) {
    $internet = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-internet-'+$scenario+'/internet-result.json')) -Raw | ConvertFrom-Json
    if (-not $internet.ok -or $internet.pack_sha256_before -ne $hash -or $internet.pack_sha256_after -ne $hash -or $internet.old_single_slot_test_fixture) { throw ('Internet simulation verification does not match this executable: '+$scenario) }
    if ($scenario -eq 'load' -and -not $internet.saturated_transport_fixture) { throw 'Oversized snapshot load was not verified' }
}
$activeNetwork = Get-Content -LiteralPath (Join-Path $evidence ($NetworkRecording+'/recording.json')) -Raw | ConvertFrom-Json
if ($activeNetwork.pack_sha256 -ne $hash -or $activeNetwork.smoke_only -or -not $activeNetwork.view.completed -or -not $activeNetwork.host.completed -or -not $activeNetwork.peer.completed) { throw 'Complete recorded three-client match does not match this executable' }
if ($activeNetwork.transport -ne 'room-websocket' -or $activeNetwork.humans -ne 3 -or $activeNetwork.opponent_bots -ne 3) { throw 'Expected a natural three-client room match against three bots' }
foreach ($playerReport in @($activeNetwork.view,$activeNetwork.host,$activeNetwork.peer)) {
    if ($playerReport.fixture_mutations -or -not $playerReport.reward_correct -or $playerReport.peak_roster -ne 3) { throw 'Recorded room match reward or roster proof is incomplete' }
}
$activeMatch = Get-Content -LiteralPath (Join-Path $evidence ($MatchRecording+'/recording.json')) -Raw | ConvertFrom-Json
$activeSummary = (Get-Content -LiteralPath (Join-Path $evidence ($MatchRecording+'/active-play.json')) -Raw | ConvertFrom-Json).summary
if ($activeMatch.pack_sha256 -ne $hash -or -not $activeSummary.completed -or $activeSummary.fixture_mutations -or $activeSummary.sanity_only -or -not $activeSummary.reward_correct -or -not $activeSummary.reward_eligible_at_finish) { throw 'Recorded active-opponent match or reward verification is incomplete or does not match this executable' }
foreach ($recording in @($activeNetwork,$activeMatch)) {
    if (-not (Test-Path -LiteralPath $recording.video) -or (Get-FileHash -LiteralPath $recording.video -Algorithm SHA256).Hash -ne $recording.video_sha256) { throw 'Recorded video is missing or differs from its verification manifest' }
}
$manifest = Get-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-source-manifest.json')) -Raw | ConvertFrom-Json
foreach ($entry in $manifest) {
    if ((Get-FileHash -LiteralPath (Join-Path $source $entry.file) -Algorithm SHA256).Hash -ne $entry.sha256) { throw ('Source changed after export: '+$entry.file) }
}
foreach ($guide in @('README.md','PLAY_GUIDE.txt','HOUSEHOLD_TEST.txt','INTERNET_PLAY.txt','Check-Internet.cmd','internet-check.ps1','internet.cfg','CHANGELOG.md','VERIFICATION.md','REFERENCE.md','REFERENCE-0.9.md','BALL-MECHANICS-0.9.md','REVIEW-0.9-APP.md','REVIEW-0.9-WORLD.md','ARENA-0.11.md','REVIEW-0.11.md','ARENA-0.10.md','REVIEW-0.10-ARENA.md','REVIEW-0.10-WORLD.md','REVIEW-0.10-MATCHES.md','VERIFICATION-0.9-held.md','REFERENCE-0.5.md','REFERENCE-0.7.md','REVIEW-0.5.md','REVIEW-0.6.md','REVIEW-0.6-AUDIT.md','REVIEW-0.7.md','REVIEW-0.8.md','REVIEW-0.8-AUDIT.md')) {
    Copy-Item -LiteralPath (Join-Path $source $guide) -Destination $destination -Force
}
$releases = Join-Path $root 'build/crown-court-release'
New-Item -ItemType Directory -Path $releases -Force | Out-Null
$zip = Join-Path $releases ('CrownCourt-Windows-'+$Version+'.zip')
if (Test-Path -LiteralPath $zip) { throw ('Release already exists; choose a new version: '+$zip) }
Compress-Archive -Path (Join-Path $destination '*') -DestinationPath $zip -CompressionLevel Optimal
$unpacked = Join-Path $releases ('verify-'+$Version+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
$unpackedExe = Join-Path $unpacked 'CrownCourt.exe'
if ((Get-FileHash -LiteralPath $unpackedExe -Algorithm SHA256).Hash -ne $hash) { throw 'Extracted executable differs from the verified build' }
Run-GameProcess $unpackedExe @('--quit-after','120','--resolution','1280x800','--position','50,50') ($EvidencePrefix+'-extracted-startup')
$unpacked32 = Join-Path $unpacked 'CrownCourt32.exe'
if ((Get-FileHash -LiteralPath $unpacked32 -Algorithm SHA256).Hash -ne $hash32) { throw 'Extracted 32-bit executable differs from the verified build' }
Run-GameProcess $unpacked32 @('--quit-after','120','--max-fps','30','--resolution','1280x800','--position','50,50') ($EvidencePrefix+'-extracted32-startup') -ProfileScope 'x86-package'
$zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
[IO.File]::WriteAllText(($zip+'.sha256'),$zipHash+'  '+[IO.Path]::GetFileName($zip)+"`r`n")
$result = @{version=$Version;exe=$exe;exe_sha256=$hash;exe32=$exe32;exe32_sha256=$hash32;extracted32_startup='passed';zip=$zip;zip_sha256=$zipHash;zip_bytes=(Get-Item -LiteralPath $zip).Length;extracted=$unpackedExe;extracted_startup='passed';network=$network;household_playtest='not performed'}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-release-results.json'))
Write-Output ('PACKAGE_RESULT '+($result | ConvertTo-Json -Depth 5 -Compress))
