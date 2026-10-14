param([string]$Version='0.17.0', [string]$EvidencePrefix='mac-release')
. (Join-Path $PSScriptRoot 'harness.ps1')
if ($EvidencePrefix -notmatch '^[A-Za-z0-9_-]+$') { throw 'Use a plain evidence prefix' }
$template=Join-Path $root '.tools/templates/macos.zip'
if (-not(Test-Path -LiteralPath $template)) { throw 'Install the verified matching Godot macos.zip export template in .tools/templates first.' }
$templateDir=Join-Path $evidence "test-user-data/$EvidencePrefix/Roaming/Godot/export_templates/4.7.2.stable"
New-Item -ItemType Directory -Force $templateDir | Out-Null
Copy-Item -LiteralPath $template -Destination $templateDir
$destination=Join-Path $root ('build/crown-court-'+$Version+'-mac')
New-Item -ItemType Directory -Force $destination | Out-Null
$archive=Join-Path $destination 'CrownCourt-macOS.zip'
Run-GameProcess $engine @('--headless','--path',$source,'--export-release','macOS',$archive) ($EvidencePrefix+'-export') 120 $EvidencePrefix
Get-FileHash -LiteralPath $archive -Algorithm SHA256
Write-Output 'Mac ZIP exported with universal architecture and ad-hoc signing. This Windows host has not executed the native Mac app.'
