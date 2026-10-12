param([string]$Pack=(Join-Path $PSScriptRoot '../build/crown-court-0.10.0/CrownCourt.exe'), [string]$Address='127.0.0.1', [string]$EvidencePrefix='v10-release')
$ErrorActionPreference = 'Stop'
$Pack = [IO.Path]::GetFullPath($Pack)
$before = (Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash
$cases = @(
    @{Mode='teams';Humans=2},
    @{Mode='teams';Humans=3;Late=$true},
    @{Mode='coop';Humans=3;Address=$Address},
    @{Mode='teams';Humans=3;Address=$Address},
    @{Mode='teams';Humans=3;Unbalanced=$true},
    @{Mode='coop';Humans=2},
    @{Mode='coop';Humans=3;Late=$true},
    @{Mode='versus';Humans=3}
)
foreach ($scenario in $cases) { & (Join-Path $PSScriptRoot 'test-network.ps1') @scenario -Pack $Pack -LabelPrefix ($EvidencePrefix+'-') }
& (Join-Path $PSScriptRoot 'network_actions.ps1') -Pack $Pack -Address $Address -LabelPrefix ($EvidencePrefix+'-')
$after = (Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash
if ($before -ne $after) { throw 'Executable changed during verification' }
$record = @{sha256=$after;pack=$Pack;address=$Address;scenarios=8;action_checkpoints=11;completed_at=(Get-Date).ToString('o')}
$record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot ('../build/crown-court-evidence/'+$EvidencePrefix+'-network-verified.json'))
Write-Output ('RELEASE_NETWORK_MATRIX_PASS SHA256 '+$after)
