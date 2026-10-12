param([string]$Mode='coop', [int]$Humans=3, [string]$Address='127.0.0.1', [switch]$Late, [switch]$Unbalanced, [string]$Pack='', [string]$LabelPrefix='')
. (Join-Path $PSScriptRoot 'harness.ps1')
$base = @('--headless','--path',$source)
if ($Pack) { $base += @('--main-pack',$Pack) }
$base += @('--script','res://tests/network_test.gd','--',('--mode='+$Mode),('--humans='+$Humans),('--address='+$Address))
if ($Late) { $base += '--late' }
if ($Unbalanced) { $base += '--unbalanced' }
$jobs = @()
$label = $LabelPrefix+'net-'+$Mode+'-'+$Humans
if ($Address -ne '127.0.0.1') { $label += '-lan' }
if ($Late) { $label += '-late' }
if ($Unbalanced) { $label += '-unbalanced' }
$jobs += Start-GameProcess $engine ($base + '--role=host') ($label+'-host')
Start-Sleep -Milliseconds 1800
for ($i=1; $i -lt $Humans; $i++) {
    if ($Late -and $i -eq 2) { Start-Sleep -Seconds 4 }
    $jobs += Start-GameProcess $engine ($base + ('--role=client'+$i)) ($label+'-client'+$i)
}
$failed = @()
foreach ($job in $jobs) {
    try { Complete-GameProcess $job 55 } catch { $failed += $_.Exception.Message }
}
if ($failed.Count) { throw ($failed -join "`n") }
