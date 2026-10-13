param([switch]$SkipTests, [switch]$VerifyExisting, [string]$Version='0.16.0', [string]$EvidencePrefix='v160-release')
. (Join-Path $PSScriptRoot 'harness.ps1')
$destination = Join-Path $root ('build/crown-court-'+$Version)
New-Item -ItemType Directory -Path $destination -Force | Out-Null
if (-not $SkipTests) {
    foreach ($test in @('shot_assist','hoop_camera','hoop_proportions','dunk_counter_hint','movement_stress_v15','client_wall_v15','camera_stress_v15','result_clarity','camera_v14','pacing_v14','slide_recovery','client_slide_prediction','motion_polish','match_feedback_v13','tackle_contacts','tackle_pressure','family_profile','family_visual','family_ui','family_poses','gameplay_v11','v11_input_aim','v11_input_difficulty','presentation_v11','sim_test','terrain_v11','dunk_aim','world_dunk_axis','arena_powers','review_v9_assist_edges','review_v9_ball_mechanics','review_v9_shots','hype_feedback','shot_preview','hazard_prediction','world_ball_transfer','world_projectile','world_court_v9','feel_sim','reference_feel','teamplay_sim','teamplay_match','ground_turn','ball_continuity','client_ground_prediction','review_v7_presentation','review_v8_event_history','review_v8_audio_routing','review_v8_audio_priority','charge_lifecycle','snapshot_recovery','review_v8_terrain_recovery','world_visibility','audio_bank','world_feel','feedback_test','headless_presentation','deck_prediction','deck_edge_prediction','controller_mix','profile_test','match_test','app_smoke','reward_test','session_test','review_v3_network','snapshot_transport_test','network_address_test','network_actions_fixture','review_v3_kickoff','world_visual_review','world_polish')) {
        $arguments = @('--headless','--path',$source,'--script',("res://tests/"+$test+'.gd'))
        if ($test -eq 'world_visual_review') { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-source-world')))) }
        if ($test -in @('tackle_pressure','motion_polish')) { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-source-'+$test)))) }
        if ($test -in @('terrain_v11','dunk_aim','world_dunk_axis','deck_edge_prediction','review_v9_ball_mechanics','review_v9_shots','hype_feedback','world_ball_transfer','world_projectile','world_court_v9','ball_continuity','world_feel','review_v8_audio_routing','snapshot_recovery','world_visibility','review_v8_terrain_recovery')) { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-source-'+$test)))) }
        if ($test -eq 'world_polish') { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-source-polish')))) }
        if ($test -eq 'movement_stress_v15') { $arguments += @('--','--focused-only') }
        Run-GameProcess $engine $arguments ($EvidencePrefix+'-source-'+$test) -ProfileScope $EvidencePrefix
    }
    Run-GameProcess $engine @('--path',$source,'--script','res://tests/arena_review.gd','--','--capture','--expect-scenery',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-source-arena_review')))) ($EvidencePrefix+'-source-arena-review-native') 55 -ProfileScope $EvidencePrefix
}
$exe = Join-Path $destination 'CrownCourt.exe'
if ($VerifyExisting) {
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Existing executable not found' }
} else {
    Run-GameProcess $engine @('--headless','--path',$source,'--editor','--import','--quit') ($EvidencePrefix+'-import') -ProfileScope $EvidencePrefix
    Run-GameProcess $engine @('--headless','--path',$source,'--export-release','Windows Desktop',$exe) ($EvidencePrefix+'-export') -ProfileScope $EvidencePrefix
}
$resourceVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
if ($resourceVersion.FileVersion -ne ($Version+'.0') -or $resourceVersion.ProductVersion -ne $Version) { throw ('Windows executable version does not match release '+$Version) }
foreach ($test in @('shot_assist','hoop_camera','hoop_proportions','dunk_counter_hint','movement_stress_v15','client_wall_v15','camera_stress_v15','result_clarity','camera_v14','pacing_v14','slide_recovery','client_slide_prediction','motion_polish','match_feedback_v13','tackle_contacts','tackle_pressure','family_profile','family_visual','family_ui','family_poses','gameplay_v11','v11_input_aim','v11_input_difficulty','presentation_v11','sim_test','terrain_v11','dunk_aim','world_dunk_axis','arena_powers','review_v9_assist_edges','review_v9_ball_mechanics','review_v9_shots','hype_feedback','shot_preview','hazard_prediction','world_ball_transfer','world_projectile','world_court_v9','feel_sim','reference_feel','teamplay_sim','teamplay_match','ground_turn','ball_continuity','client_ground_prediction','review_v7_presentation','review_v8_event_history','review_v8_audio_routing','review_v8_audio_priority','charge_lifecycle','snapshot_recovery','review_v8_terrain_recovery','world_visibility','audio_bank','world_feel','feedback_test','headless_presentation','deck_prediction','deck_edge_prediction','controller_mix','profile_test','match_test','app_smoke','reward_test','session_test','review_v3_network','snapshot_transport_test','network_address_test','network_actions_fixture','review_v3_kickoff','world_visual_review','world_polish')) {
    $arguments = @('--headless','--path',$source,'--main-pack',$exe,'--script',("res://tests/"+$test+'.gd'))
    if ($test -in @('tackle_pressure','motion_polish')) { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-pack-'+$test)))) }
    if ($test -eq 'world_visual_review') { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-pack-world'))),('--pack-source='+$exe)) }
    if ($test -in @('terrain_v11','dunk_aim','world_dunk_axis','deck_edge_prediction','review_v9_ball_mechanics','review_v9_shots','hype_feedback','world_ball_transfer','world_projectile','world_court_v9','ball_continuity','world_feel','review_v8_audio_routing','snapshot_recovery','world_visibility','review_v8_terrain_recovery')) { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-pack-'+$test))),('--pack-source='+$exe)) }
    if ($test -eq 'world_polish') { $arguments += @('--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-pack-polish'))),('--pack-source='+$exe)) }
    if ($test -eq 'movement_stress_v15') { $arguments += @('--','--focused-only') }
    Run-GameProcess $engine $arguments ($EvidencePrefix+'-pack-'+$test) -ProfileScope $EvidencePrefix
}
Run-GameProcess $engine @('--path',$source,'--main-pack',$exe,'--script','res://tests/arena_review.gd','--','--capture','--expect-scenery',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-pack-arena_review'))),('--pack-source='+$exe)) ($EvidencePrefix+'-pack-arena-review-native') 55 -ProfileScope $EvidencePrefix
Run-GameProcess $engine @('--path',$source,'--main-pack',$exe,'--script','res://tests/input_render.gd') ($EvidencePrefix+'-pack-input-render') 55 -ProfileScope $EvidencePrefix
Run-GameProcess $engine @('--path',$source,'--main-pack',$exe,'--script','res://tests/audio_render.gd','--resolution','1280x800','--',('--evidence-dir='+(Join-Path $evidence ($EvidencePrefix+'-audio-pack'))),('--pack-source='+$exe)) ($EvidencePrefix+'-pack-audio-render') 55 -ProfileScope $EvidencePrefix
$renderEvidence = Join-Path $evidence ($EvidencePrefix+'-pack')
New-Item -ItemType Directory -Path $renderEvidence -Force | Out-Null
Run-GameProcess $engine @('--path',$source,'--main-pack',$exe,'--script','res://tests/feel_input.gd','--',('--evidence-dir='+$renderEvidence)) ($EvidencePrefix+'-pack-feel-input') 55 -ProfileScope $EvidencePrefix
Run-GameProcess $engine @('--path',$source,'--main-pack',$exe,'--script','res://tests/feel_input.gd','--','--route',('--evidence-dir='+$renderEvidence)) ($EvidencePrefix+'-pack-feel-route') 55 -ProfileScope $EvidencePrefix
$controllerEvidence = Join-Path $evidence ($EvidencePrefix+'-controller-pack')
Run-GameProcess $engine @('--path',$source,'--main-pack',$exe,'--script','res://tests/controller_input.gd','--',('--evidence-dir='+$controllerEvidence)) ($EvidencePrefix+'-pack-controller') 55 -ProfileScope $EvidencePrefix
Run-GameProcess $exe @('--quit-after','120','--resolution','1280x800','--position','50,50') ($EvidencePrefix+'-exported-startup') -ProfileScope $EvidencePrefix
foreach ($guide in @('README.md','PLAY_GUIDE.txt','FAMILY-CHARACTERS.md','TACKLING-REVIEW.md','HOUSEHOLD_TEST.txt','INTERNET_PLAY.txt','Check-Internet.cmd','internet-check.ps1','internet.cfg')) {
    Copy-Item -LiteralPath (Join-Path $source $guide) -Destination $destination -Force
}
New-Item -ItemType Directory -Path (Join-Path $destination 'LICENSES') -Force | Out-Null
foreach ($license in @('Godot-4.7.2-LICENSE.txt','Godot-4.7.2-COPYRIGHT.txt')) {
    Copy-Item -LiteralPath (Join-Path $root ('LICENSES/'+$license)) -Destination (Join-Path $destination 'LICENSES') -Force
}
Copy-Item -LiteralPath (Join-Path $source 'assets/audio/LICENSE.txt') -Destination (Join-Path $destination 'LICENSES/Audio-CC0.txt') -Force
[IO.File]::WriteAllText((Join-Path $destination 'Play.cmd'), "@echo off`r`nstart `"`" `"%~dp0CrownCourt.exe`"`r`n")
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
$manifest = @('arena_layout.gd','audio.gd','export_presets.cfg','hud.gd','main.gd','main.tscn','network_address.gd','room_peer.gd','internet.cfg','profile.gd','family_visual.gd','project.godot','sim.gd','world.gd') | ForEach-Object { @{file=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $source $_) -Algorithm SHA256).Hash} }
$manifest += Get-ChildItem -LiteralPath (Join-Path $source 'assets/audio') -File | ForEach-Object { @{file=('assets/audio/'+$_.Name);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} }
$manifest += Get-ChildItem -LiteralPath (Join-Path $source 'assets/characters') -Filter '*.glb' -File | ForEach-Object { @{file=('assets/characters/'+$_.Name);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} }
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-source-manifest.json'))
$playtest = @{executable_sha256=$hash;input=(Get-Content -LiteralPath (Join-Path $renderEvidence 'feel-after.json') -Raw | ConvertFrom-Json);route=(Get-Content -LiteralPath (Join-Path $renderEvidence 'feel-route.json') -Raw | ConvertFrom-Json);controller=(Get-Content -LiteralPath (Join-Path $controllerEvidence 'controller-result.json') -Raw | ConvertFrom-Json)}
$playtest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $evidence ($EvidencePrefix+'-playtest-results.json'))
[IO.File]::WriteAllText((Join-Path $destination 'SHA256.txt'), ($hash+'  CrownCourt.exe'+"`r`n"))
Write-Output ('BUILD_RESULT '+$exe+' SHA256 '+$hash)

