param([switch]$RenderSmoke)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$engine = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$template = Join-Path $projectRoot '.tools\templates\windows_release_x86_64.exe'
$buildRoot = Join-Path $projectRoot 'build'
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')
$staging = Join-Path $buildRoot ('staging-' + $stamp)
$evidence = Join-Path $buildRoot ('evidence-' + $stamp)
$release = Join-Path $buildRoot 'hands-full'
$archive = Join-Path $buildRoot 'HandsFull-windows.zip'
foreach ($required in @($engine, $template, (Join-Path $projectRoot 'prototypes\physics_party\README.md'), (Join-Path $projectRoot 'THIRD_PARTY.md'), (Join-Path $projectRoot 'LICENSES\Godot-4.7.2-COPYRIGHT.txt'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required build input missing: $required" }
}
$version = (& $engine --version).Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne '4.7.2.stable.official.ed1daf0bf') { throw "Unexpected Godot version: $version" }
if ((Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash -ne 'D34D36F3BE1A6C49C56525AE86469B92E4F417DDF0B43CF00DD80C385C4B0562') { throw 'Release template differs from the verified official 4.7.2 input.' }
New-Item -ItemType Directory -Path $staging, $evidence -Force | Out-Null

function Invoke-BoundedGodot {
    param([string]$Executable, [string[]]$Arguments, [string]$Label, [string]$WorkingDirectory, [int]$TimeoutSeconds = 120)
    $stdout = Join-Path $evidence ($Label + '.stdout.log')
    $stderr = Join-Path $evidence ($Label + '.stderr.log')
    # Own the process handle from launch. Start-Process on Windows PowerShell
    # can lose ExitCode for a short-lived console launcher even after waiting.
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.Arguments = $Arguments -join ' '
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Cannot start $Label" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $timedOut = $false
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            foreach ($ownedChild in Get-CimInstance Win32_Process -Filter "ParentProcessId = $($process.Id)") {
                if ($ownedChild.Name -like 'Godot*' -and $ownedChild.CommandLine -like ('*' + $WorkingDirectory + '*')) {
                    Stop-Process -Id $ownedChild.ProcessId -Force
                }
            }
            Stop-Process -Id $process.Id -Force
        }
        $process.WaitForExit()
        $errorText = $stderrTask.GetAwaiter().GetResult()
        $normalText = $stdoutTask.GetAwaiter().GetResult()
        [IO.File]::WriteAllText($stdout, $normalText)
        [IO.File]::WriteAllText($stderr, $errorText)
        if ($timedOut) { throw "$Label exceeded its $TimeoutSeconds second limit. See $evidence" }
        if ($process.ExitCode -ne 0 -or ($errorText + $normalText) -match '(SCRIPT ERROR|ERROR:|WARNING:)') {
            throw "$Label failed (exit $($process.ExitCode)). See $evidence"
        }
        Write-Output "$Label passed."
    } finally { $process.Dispose() }
}

Invoke-BoundedGodot -Executable $engine -Arguments @('--headless', '--path', ('"' + $projectRoot + '"'), '--editor', '--quit', '--import') -Label 'import' -WorkingDirectory $projectRoot
$stagedExe = Join-Path $staging 'HandsFull.exe'
Invoke-BoundedGodot -Executable $engine -Arguments @('--headless', '--path', ('"' + $projectRoot + '"'), '--export-release', '"Hands Full"', ('"' + $stagedExe + '"')) -Label 'export-release' -WorkingDirectory $projectRoot
if (-not (Test-Path -LiteralPath $stagedExe) -or (Test-Path -LiteralPath (Join-Path $staging 'HandsFull.pck'))) { throw 'Expected a standalone executable with embedded PCK.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'prototypes\physics_party\README.md') -Destination $staging
New-Item -ItemType Directory -Path (Join-Path $staging 'LICENSES') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSES\Godot-4.7.2-COPYRIGHT.txt') -Destination (Join-Path $staging 'LICENSES')
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSES\Godot-4.7.2-LICENSE.txt') -Destination (Join-Path $staging 'LICENSES')
Copy-Item -LiteralPath (Join-Path $projectRoot 'prototypes\physics_party\vendor\picode\LICENSE') -Destination (Join-Path $staging 'LICENSES\PiCode9560-MIT.txt')
# Inspect the exported filesystem itself, not just the preset's exclude list.
$inspector = Join-Path $evidence 'inspect_embedded_pack.gd'
$resourceReport = Join-Path $evidence 'embedded-resources.json'
@'
extends SceneTree
var paths: Array[String] = []
func _initialize() -> void:
    scan("res://")
    var forbidden: Array[String] = ["res://game/", "res://assets/", "res://addons/", "res://tests/", "res://docs/", "res://tools/", "res://.tools/", "res://.superpowers/", "res://.git/", "res://logs/", "res://build/", "res://LICENSES/"]
    for path: String in paths:
        for prefix: String in forbidden:
            if path.begins_with(prefix):
                push_error("Forbidden development resource in export: " + path)
                quit(1)
                return
    for required in ["main.tscn", "main.gd", "party_session.gd", "puppet.tscn", "puppet.gd", "party_world.gd", "party_counterweight_world.gd", "party_courses.gd", "party_hud.gd", "party_rules.gd", "party_audio.gd", "party_presentation.gd", "vendor/picode/Character.glb"]:
        if not ResourceLoader.exists("res://prototypes/physics_party/" + required):
            push_error("Export is missing a runtime dependency: " + required)
            quit(1)
            return
    var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
    file.store_string(JSON.stringify(paths, "  "))
    file.close()
    print("PACK_INSPECTION_PASS ", paths.size(), " resources; no development directories")
    quit(0)
func scan(folder: String) -> void:
    var directory: DirAccess = DirAccess.open(folder)
    if directory == null: return
    directory.include_hidden = true
    for filename: String in directory.get_files(): paths.append(folder.path_join(filename))
    for child: String in directory.get_directories(): scan(folder.path_join(child))
'@ | Set-Content -LiteralPath $inspector -Encoding utf8
Invoke-BoundedGodot -Executable $engine -Arguments @('--headless', '--path', ('"' + $staging + '"'), '--main-pack', ('"' + $stagedExe + '"'), '--script', ('"' + $inspector + '"'), '--', ('"' + $resourceReport + '"')) -Label 'inspect-pack' -WorkingDirectory $staging
if (-not (Test-Path -LiteralPath $resourceReport)) { throw 'Embedded resource inspection did not complete.' }

# Start the actual release from its clean output folder, without editor/project paths.
# Menu-only smoke does not open, overwrite or migrate any household save.
Invoke-BoundedGodot -Executable $stagedExe -Arguments @('--headless', '--quit-after', '90') -Label 'clean-folder-headless' -WorkingDirectory $staging -TimeoutSeconds 30
if ($RenderSmoke) {
    Invoke-BoundedGodot -Executable $stagedExe -Arguments @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--quit-after', '120') -Label 'clean-folder-rendered' -WorkingDirectory $staging -TimeoutSeconds 45
}

# Preserve the previous known output; never mix stale files into a new package.
if (Test-Path -LiteralPath $release) {
    $previous = Join-Path $buildRoot ('hands-full-previous-' + $stamp)
    foreach ($checkedPath in @($release, $previous)) {
        if (-not [IO.Path]::GetFullPath($checkedPath).StartsWith($buildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Build path escaped the workspace build directory.' }
    }
    Move-Item -LiteralPath $release -Destination $previous
}
Move-Item -LiteralPath $staging -Destination $release
if (Test-Path -LiteralPath $archive) {
    $previousZip = Join-Path $buildRoot ('HandsFull-previous-' + $stamp + '.zip')
    foreach ($checkedPath in @($archive, $previousZip)) {
        if (-not [IO.Path]::GetFullPath($checkedPath).StartsWith($buildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'ZIP path escaped the workspace build directory.' }
    }
    Move-Item -LiteralPath $archive -Destination $previousZip
}
Compress-Archive -LiteralPath $release -DestinationPath $archive -CompressionLevel Optimal -Force
$hashes = @(
    Get-FileHash -LiteralPath (Join-Path $release 'HandsFull.exe') -Algorithm SHA256
    Get-FileHash -LiteralPath $archive -Algorithm SHA256
)
$hashes | Select-Object Path, Hash | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'release-hashes.json')
Write-Output "Release: $release"
Write-Output "ZIP: $archive"
Write-Output "Evidence: $evidence"
$hashes | Format-List Path, Hash
