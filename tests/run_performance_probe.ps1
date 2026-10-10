param(
    [ValidatePattern('^[a-z0-9-]+$')][string]$Label = 'final',
    [ValidateRange(3,20)][int]$SampleSeconds = 15,
    [ValidateRange(45,180)][int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$startInfo.Arguments = '--path "' + $projectRoot + '" --script res://tests/performance_probe.gd -- --perf-label=' + $Label + ' --perf-seconds=' + $SampleSeconds
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$owned = [Diagnostics.Process]::new()
$owned.StartInfo = $startInfo
$forcedStop = $false
try {
    if (-not $owned.Start()) { throw 'Cannot start native performance probe' }
    $stdout = $owned.StandardOutput.ReadToEndAsync()
    $stderr = $owned.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $owned.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $owned.Refresh()
    }
    if (-not $owned.HasExited) {
        $forcedStop = $true
        # The Godot console launcher owns a separate native engine child.
        foreach ($child in Get-CimInstance Win32_Process -Filter "ParentProcessId = $($owned.Id)") {
            if ($child.CommandLine -like '*res://tests/performance_probe.gd*') { Stop-Process -Id $child.ProcessId }
        }
        if (-not $owned.WaitForExit(2000)) { $owned.Kill() }
    }
    $owned.WaitForExit()
    $outputText = $stdout.GetAwaiter().GetResult()
    $errorText = $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $projectRoot "logs\performance-$Label.log"), $outputText)
    [IO.File]::WriteAllText((Join-Path $projectRoot "logs\performance-$Label-errors.log"), $errorText)
    $report = Join-Path $projectRoot "logs\performance-$Label.json"
    $ok = -not $forcedStop -and $owned.ExitCode -eq 0 -and $outputText.Contains('PERFORMANCE_PROBE_OK') -and ($outputText + $errorText) -notmatch '(SCRIPT ERROR|ERROR:|WARNING:)'
    [pscustomobject]@{ Passed=$ok; ExitCode=$owned.ExitCode; ForcedStop=$forcedStop; Report=$report } | ConvertTo-Json
    if (-not $ok) { throw "Native performance probe failed; inspect logs/performance-$Label*.log" }
} finally {
    $owned.Dispose()
}
