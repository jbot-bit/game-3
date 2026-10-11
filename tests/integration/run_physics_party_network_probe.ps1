param(
    [int]$Port = 24697,
    [int]$TimeoutSeconds = 240,
    [string]$ExportedPack = '',
    [switch]$VerboseEngine
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$engine = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$launchDirectory = $projectRoot
$probeScript = 'res://tests/integration/physics_party_network_probe.gd'
$packArguments = @()
if ($ExportedPack) {
    $packPath = [IO.Path]::GetFullPath($ExportedPack)
    if (-not (Test-Path -LiteralPath $packPath)) { throw "Exported pack not found: $packPath" }
    $launchDirectory = Split-Path -Parent $packPath
    $probeScript = Join-Path $projectRoot 'tests\integration\physics_party_network_probe.gd'
    # Official release templates forbid external script/path overrides. Use the
    # matching engine against the EXACT embedded pack, without source fallback.
    # The builder separately runs the actual executable for startup/render smoke.
    $packArguments = @('--main-pack', ('"' + $packPath + '"'))
}
if (-not (Test-Path -LiteralPath $engine)) { throw "Godot not found: $engine" }
$runKey = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '_' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$outputDirectory = Join-Path $projectRoot ('.tools\physics-party-network-probe\' + $runKey)
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$ownedProcesses = @{}
try {
    foreach ($role in @('host', 'client1', 'client2')) {
        $arguments = @('--headless', '--path', ('"' + $launchDirectory + '"'), '--script', ('"' + $probeScript + '"'), '--', ('--probe-role=' + $role), ('--probe-output="' + $outputDirectory + '"'), ('--probe-key=' + $runKey), ('--probe-port=' + $Port))
        $arguments = $packArguments + $arguments
        if ($VerboseEngine) { $arguments = @('--verbose') + $arguments }
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $engine
        $startInfo.Arguments = $arguments -join ' '
        $startInfo.WorkingDirectory = $launchDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) { throw "Unable to start $role" }
        # Drain both pipes concurrently; write log files only after EOF. A process
        # exit alone does not guarantee Start-Process's file redirection is done.
        $ownedProcesses[$role] = @{
            Process = $process
            Output = $process.StandardOutput.ReadToEndAsync()
            Error = $process.StandardError.ReadToEndAsync()
        }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $running = @($ownedProcesses.Values | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited })
        $failures = @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*_fail.json')
        if ($failures.Count -gt 0) { break }
        if ($running.Count -eq 0) { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    $results = foreach ($role in @('host', 'client1', 'client2')) {
        $child = $ownedProcesses[$role]
        $process = $child.Process
        $process.Refresh()
        $forcedStop = -not $process.HasExited
        if ($forcedStop) { $process.Kill() }
        if (-not $process.WaitForExit(5000)) { throw "$role did not exit after cancellation" }
        $process.WaitForExit()
        $outputText = $child.Output.GetAwaiter().GetResult()
        $errorText = $child.Error.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $outputDirectory ($role + '.stdout.log')), $outputText)
        [IO.File]::WriteAllText((Join-Path $outputDirectory ($role + '.stderr.log')), $errorText)
        $passFile = Join-Path $outputDirectory ($role + '_pass.json')
        [pscustomobject]@{
            Role = $role
            Pid = $process.Id
            Exited = $process.HasExited
            ExitCode = $(if ($process.HasExited) { $process.ExitCode } else { $null })
            Pass = (Test-Path -LiteralPath $passFile)
            ForcedStop = $forcedStop
            EngineErrors = [bool](($errorText + $outputText) -match '(SCRIPT ERROR|ERROR:|WARNING:)')
            Result = $(if (Test-Path -LiteralPath $passFile) { Get-Content -LiteralPath $passFile -Raw | ConvertFrom-Json } else { $null })
        }
    }
    $results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputDirectory 'summary.json')
    $results | Format-Table Role, Pid, Exited, ExitCode, Pass, ForcedStop, EngineErrors -AutoSize
    Write-Output "Evidence: $outputDirectory"
    if (@($results | Where-Object { -not $_.Pass -or -not $_.Exited -or $_.ExitCode -ne 0 -or $_.ForcedStop -or $_.EngineErrors }).Count -gt 0) {
        foreach ($role in @('host', 'client1', 'client2')) {
            Write-Output "$role output:"
            Get-Content -LiteralPath (Join-Path $outputDirectory ($role + '.stdout.log')) -Tail 12
            Get-Content -LiteralPath (Join-Path $outputDirectory ($role + '.stderr.log')) -Tail 12
        }
        throw 'Three-process network probe did not pass. See preserved logs.'
    }
} finally {
    # Only stop the exact local child processes launched by this invocation.
    foreach ($child in $ownedProcesses.Values) {
        $process = $child.Process
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }
        $process.Dispose()
    }
}
