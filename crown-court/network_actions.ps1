param([string]$Address='127.0.0.1', [string]$Pack='', [string]$LabelPrefix='')
. (Join-Path $PSScriptRoot 'harness.ps1')
$base = @('--headless','--path',$source)
if ($Pack) { $base += @('--main-pack',$Pack) }
$base += @('--script','res://tests/network_actions.gd','--',('--address='+$Address))
$jobs = @()
$jobs += Start-GameProcess $engine ($base + '--role=host') ($LabelPrefix+'network-actions-host')
Start-Sleep -Milliseconds 1800
$jobs += Start-GameProcess $engine ($base + '--role=client1') ($LabelPrefix+'network-actions-client1')
Start-Sleep -Milliseconds 500
$jobs += Start-GameProcess $engine ($base + '--role=client2') ($LabelPrefix+'network-actions-client2')
$failed = @()
foreach ($job in $jobs) {
    try { Complete-GameProcess $job 75 } catch { $failed += $_.Exception.Message }
}
if ($failed.Count) { throw ($failed -join "`n") }
