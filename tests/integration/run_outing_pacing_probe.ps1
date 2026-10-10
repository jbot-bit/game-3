param([int]$TimeoutSeconds = 150)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$engine = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$runKey = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '_' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$outputDirectory = Join-Path $projectRoot ('.tools\outing-pacing-probe\' + $runKey)
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$resultFile = Join-Path $outputDirectory 'result.json'
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $engine
$startInfo.Arguments = '--headless --path "' + $projectRoot + '" --script res://tests/integration/outing_pacing_probe.gd -- --output="' + $resultFile + '"'
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
try {
    if (-not $process.Start()) { throw 'Unable to start outing probe' }
    $standardOutput = $process.StandardOutput.ReadToEndAsync()
    $standardError = $process.StandardError.ReadToEndAsync()
    $naturalExit = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $naturalExit) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }
    $stdout = $standardOutput.GetAwaiter().GetResult()
    $stderr = $standardError.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'stdout.log'), $stdout)
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'stderr.log'), $stderr)
    $result = if (Test-Path -LiteralPath $resultFile) { Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json } else { $null }
    $engineErrors = [bool](($stdout + $stderr) -match '(SCRIPT ERROR|ERROR:|WARNING:)')
    [pscustomobject]@{ Pid=$process.Id; ExitCode=$process.ExitCode; NaturalExit=$naturalExit; EngineErrors=$engineErrors; Result=$result } |
        ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $outputDirectory 'summary.json')
    Write-Output "Evidence: $outputDirectory"
    if (-not $naturalExit -or $process.ExitCode -ne 0 -or $engineErrors -or $null -eq $result -or -not $result.ok) {
        Get-Content -LiteralPath (Join-Path $outputDirectory 'stdout.log') -Tail 8
        Get-Content -LiteralPath (Join-Path $outputDirectory 'stderr.log') -Tail 8
        throw 'Earned outing probe failed. See preserved evidence.'
    }
    $result | Select-Object ok,checks,wall_s,path_metres,night_wait_skipped_s | Format-List
    $result.stages | Select-Object label,run_elapsed_s,coins,lifetime_banked | Format-Table
} finally {
    # This exact child is the only process this runner may stop.
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }
    $process.Dispose()
}
