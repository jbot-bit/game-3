param(
    [string]$Version='0.14.0',
    [string]$Label='family-x86-v13',
    [ValidateRange(1024,65535)][int]$NetworkPort=30262
)
. (Join-Path $PSScriptRoot '../harness.ps1')
if ($Label -notmatch '^[A-Za-z0-9_-]+$' -or $Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid label or version' }
$folder=Join-Path $evidence $Label
if (Test-Path -LiteralPath $folder) { throw 'Evidence already exists; select a fresh label' }
$destination=Join-Path $root ('build/crown-court-'+$Version)
$exe32=Join-Path $destination 'CrownCourt32.exe'
if (Test-Path -LiteralPath $exe32) { throw 'The x86 destination already exists; preserve it and choose another version' }
if ((Get-PSDrive C).Free -lt 350MB) { throw 'Less than 350 MB free for the new x86 executable and export temporary file' }
$clone=Join-Path $folder 'source32'
New-Item -ItemType Directory -Path $clone,(Join-Path $clone 'tests'),$destination -Force | Out-Null
$files=@(Get-ChildItem -LiteralPath $source -File | Where-Object { $_.Extension -eq '.gd' -or $_.Name.EndsWith('.gd.uid') -or $_.Name -in @('main.tscn','project.godot','internet.cfg','export_presets.cfg') })
$files+=@(Get-ChildItem -LiteralPath (Join-Path $source 'assets') -Recurse -File)
$files+=@(Get-ChildItem -LiteralPath (Join-Path $source 'tests') -File | Where-Object { $_.Extension -eq '.gd' -or $_.Name.EndsWith('.gd.uid') })
$sourceManifest=@()
foreach ($file in $files) {
    $relative=[IO.Path]::GetRelativePath($source,$file.FullName)
    $target=Join-Path $clone $relative
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target
    $sourceManifest+=@{file=$relative;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
}
function Assert-FrozenSource {
    foreach ($entry in $sourceManifest) {
        if ((Get-FileHash -LiteralPath (Join-Path $source $entry.file) -Algorithm SHA256).Hash -ne $entry.sha256) { throw ('Source changed after x86 clone: '+$entry.file) }
    }
}
Assert-FrozenSource
$sourceManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $folder 'source-manifest.json')
$preset=Join-Path $clone 'export_presets.cfg'
$text=[IO.File]::ReadAllText($preset).Replace('../.tools/templates/windows_debug_x86_64.exe',(Join-Path $root '.tools/templates/windows_debug_x86_32.exe').Replace('\','/')).Replace('../.tools/templates/windows_release_x86_64.exe',(Join-Path $root '.tools/templates/windows_release_x86_32.exe').Replace('\','/')).Replace('binary_format/architecture="x86_64"','binary_format/architecture="x86_32"')
if ($text -notmatch 'binary_format/architecture="x86_32"' -or $text -notmatch ('application/product_version="'+[regex]::Escape($Version)+'"')) { throw 'x86 preset architecture or frozen source version is incorrect' }
[IO.File]::WriteAllText($preset,$text)
$commands=@()
$importArgs=@('--headless','--path',$clone,'--editor','--import','--quit')
$commands+=@{engine=$engine;arguments=$importArgs}
Run-GameProcess $engine $importArgs ($Label+'-import') 120 ($Label+'-export')
$exportArgs=@('--headless','--path',$clone,'--export-release','Windows Desktop',$exe32)
$commands+=@{engine=$engine;arguments=$exportArgs}
Run-GameProcess $engine $exportArgs ($Label+'-export') 120 ($Label+'-export')
Assert-FrozenSource
$versionInfo=[Diagnostics.FileVersionInfo]::GetVersionInfo($exe32)
if ($versionInfo.FileVersion -ne ($Version+'.0') -or $versionInfo.ProductVersion -ne $Version) { throw 'x86 Windows version resource mismatch' }
$reader=[IO.BinaryReader]::new([IO.File]::OpenRead($exe32))
try {
    $reader.BaseStream.Position=0x3c
    $peOffset=$reader.ReadInt32()
    $reader.BaseStream.Position=$peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) { throw 'Invalid PE signature' }
    $machine=$reader.ReadUInt16()
    if ($machine -ne 0x14c) { throw 'Export is not an x86 executable' }
} finally { $reader.Dispose() }
$hash=(Get-FileHash -LiteralPath $exe32 -Algorithm SHA256).Hash
$engine32=Join-Path $root '.tools/godot32/Godot_v4.7.2-stable_win32_console.exe'
$testReports=@()
foreach ($test in @('result_clarity','camera_v14','pacing_v14','slide_recovery','client_slide_prediction','motion_polish','match_feedback_v13','feedback_test','family_profile','profile_test','family_ui','family_visual','family_poses','sim_test','gameplay_v11','tackle_contacts','tackle_pressure','world_dunk_axis','controller_mix','snapshot_recovery')) {
    $testEvidence=Join-Path $folder $test
    $arguments=@('--headless','--path',$clone,'--main-pack',$exe32,'--script',('res://tests/'+$test+'.gd'),'--',('--evidence-dir='+$testEvidence),('--pack-source='+$exe32))
    $commands+=@{engine=$engine32;arguments=$arguments}
    Run-GameProcess $engine32 $arguments ($Label+'-'+$test) 60 ($Label+'-'+$test)
    $testReports+=@{test=$test;passed=$true;engine_architecture='x86_32';pack_sha256=$hash}
}
$networkLabel=$Label+'-network'
& (Join-Path $PSScriptRoot 'run_family_network.ps1') -Label $networkLabel -Pack $exe32 -EnginePath $engine32 -Port $NetworkPort
$network=Get-Content -LiteralPath (Join-Path $evidence ($networkLabel+'/verification.json')) -Raw | ConvertFrom-Json
if (-not $network.passed -or $network.pack_sha256_before -ne $hash -or $network.pack_sha256_after -ne $hash) { throw 'x86 family network receipt differs from the tested executable' }
Assert-FrozenSource
if ((Get-FileHash -LiteralPath $exe32 -Algorithm SHA256).Hash -ne $hash) { throw 'x86 executable changed during verification' }
$result=@{passed=$true;exe=$exe32;sha256=$hash;bytes=(Get-Item -LiteralPath $exe32).Length;pe_machine='0x014c';architecture='x86_32';engine=$engine32;version=$Version;source_clone=$clone;source_manifest=(Join-Path $folder 'source-manifest.json');fresh_import_cache=$true;source_unchanged=$true;commands=$commands;headless_tests=$testReports;network=$network;native_startup='not run';physical_three_pc='not tested';completed=(Get-Date).ToString('o')}
$result | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath (Join-Path $folder 'verification.json')
Write-Output ('FAMILY_X86_RESULT '+($result | ConvertTo-Json -Depth 9 -Compress))
