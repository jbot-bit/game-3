$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $root 'crown-court'
$engine = Join-Path $root '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$evidence = Join-Path $root 'build/crown-court-evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
function Start-GameProcess([string]$Exe, [string[]]$Arguments, [string]$Label, [string]$ProfileScope='') {
    $si = [Diagnostics.ProcessStartInfo]::new()
    $si.FileName = $Exe
    foreach ($argument in $Arguments) { $si.ArgumentList.Add($argument) }
    $si.WorkingDirectory = $source
    # Process-only isolation: test saves/settings cannot touch the household profile.
    $sandbox = Join-Path $evidence 'test-user-data'
    if ($ProfileScope) {
        if ($ProfileScope -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid test profile scope' }
        $sandbox = Join-Path $sandbox $ProfileScope
    }
    foreach ($kind in @('Roaming','Local')) { New-Item -ItemType Directory -Path (Join-Path $sandbox $kind) -Force | Out-Null }
    $si.Environment['APPDATA'] = Join-Path $sandbox 'Roaming'
    $si.Environment['LOCALAPPDATA'] = Join-Path $sandbox 'Local'
    $si.UseShellExecute = $false
    $si.CreateNoWindow = $true
    $si.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $si.RedirectStandardOutput = $true
    $si.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $si
    if (-not $process.Start()) { throw "Could not start $Label" }
    return @{ Process=$process; Output=$process.StandardOutput.ReadToEndAsync(); Error=$process.StandardError.ReadToEndAsync(); Label=$Label }
}
function Complete-GameProcess($Job, [int]$Seconds=55) {
    $p = $Job.Process
    if (-not $p.WaitForExit($Seconds*1000)) {
        $p.Kill($true)
        throw "$($Job.Label) timed out"
    }
    $normal = $Job.Output.GetAwaiter().GetResult()
    $errors = $Job.Error.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $evidence ($Job.Label + '.stdout.log')), $normal)
    [IO.File]::WriteAllText((Join-Path $evidence ($Job.Label + '.stderr.log')), $errors)
    if ($p.ExitCode -ne 0 -or ($normal + $errors) -match '(SCRIPT ERROR|ERROR:|WARNING:)') {
        throw "$($Job.Label) failed (exit $($p.ExitCode))`n$normal`n$errors"
    }
    Write-Output "$($Job.Label): PASS"
    foreach ($line in ($normal -split "`n" | Where-Object { $_ -match '(RESULT|PASS)' })) {
        if ($line.Length -gt 1200) { Write-Output ($line.Substring(0,600)+' ... [full result in '+$Job.Label+'.stdout.log]') }
        else { Write-Output $line }
    }
    $p.Dispose()
}
function Run-GameProcess([string]$Exe, [string[]]$Arguments, [string]$Label, [int]$Seconds=55, [string]$ProfileScope='') {
    $job = Start-GameProcess $Exe $Arguments $Label $ProfileScope
    Complete-GameProcess $job $Seconds
}
