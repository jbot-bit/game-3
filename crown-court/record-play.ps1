param(
    [string]$Label='v3-baseline',
    [string]$Pack='',
    [string]$Mode='coop',
    [ValidateSet(30,60)][int]$CaptureRate=60,
    [string]$Encoder=''
)
function Resolve-FFmpeg([string]$Override='') {
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        if (Test-Path -LiteralPath $Override -PathType Leaf) { return (Get-Item -LiteralPath $Override).FullName }
        $command = Get-Command -Name $Override -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
        throw ('FFmpeg override was not found: '+$Override)
    }
    $command = Get-Command -Name ffmpeg -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $packages = Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Packages'
        $candidates = @(Get-ChildItem -LiteralPath $packages -Directory -Filter '*FFmpeg*' -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -File -Filter 'ffmpeg.exe' -Recurse -ErrorAction SilentlyContinue
        } | Sort-Object LastWriteTimeUtc,FullName -Descending)
        if ($candidates.Count) { return $candidates[0].FullName }
    }
    throw 'FFmpeg was not found. Install it on PATH or pass -Encoder with its executable path.'
}
. (Join-Path $PSScriptRoot 'harness.ps1')
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Label must be a simple file name' }
$folder = Join-Path $evidence $Label
if (Test-Path -LiteralPath $folder) { throw ('Recording already exists: '+$folder) }
New-Item -ItemType Directory -Path $folder | Out-Null
$movie = Join-Path $folder 'match.avi'
$driverHash = (Get-FileHash -LiteralPath (Join-Path $source 'tests/active_play.gd') -Algorithm SHA256).Hash
$arguments = @('--path',$source)
if ($Pack) {
    $Pack = [IO.Path]::GetFullPath($Pack)
    $arguments += @('--main-pack',$Pack)
}
$arguments += @('--script',(Join-Path $source 'tests/active_play.gd'),'--resolution','1280x800','--write-movie',$movie,'--fixed-fps',[string]$CaptureRate,'--disable-vsync','--',('--mode='+$Mode),('--evidence-dir='+$folder))
$job = Start-GameProcess $engine $arguments $Label
$completed = $false
try {
    if (-not $job.Process.WaitForExit(900000)) { throw 'Recorded match timed out' }
    $normal = $job.Output.GetAwaiter().GetResult()
    $errors = $job.Error.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $folder 'stdout.log'),$normal)
    [IO.File]::WriteAllText((Join-Path $folder 'stderr.log'),$errors)
    # Godot warns about free disk before recording. Decode the finished movie
    # below; this advisory alone does not mean the recording failed.
    $diagnostics = ($normal+$errors) -replace 'WARNING: Current available space on disk is low[^\r\n]*',''
    if ($job.Process.ExitCode -ne 0 -or $diagnostics -match '(SCRIPT ERROR|ERROR:|WARNING:)') { throw ('Recorded game failed: '+$normal+$errors) }
    $completed = $true
} finally {
    if (-not $completed -and -not $job.Process.HasExited) { $job.Process.Kill($true) }
    if ($job.Process.HasExited) { $job.Process.Dispose() }
}
if (-not (Test-Path -LiteralPath (Join-Path $folder 'active-play.json'))) { throw 'Missing active match telemetry' }
$report = Get-Content -LiteralPath (Join-Path $folder 'active-play.json') -Raw | ConvertFrom-Json
if (-not $report.summary.completed -or $report.summary.sanity_only -or $report.summary.fixture_mutations) { throw 'Recorded playtest did not complete a real match' }
$Encoder = Resolve-FFmpeg $Encoder
$mp4 = Join-Path $folder 'match.mp4'
& $Encoder -hide_banner -loglevel error -n -i $movie -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart $mp4
if ($LASTEXITCODE -ne 0) { throw 'Recording conversion failed; native AVI retained' }
$manifest = @{label=$Label;mode=$Mode;input='Godot InputEvent keyboard/mouse; active opponents';movie_clock=('fixed '+$CaptureRate+' fps; not a performance benchmark');video=$mp4;video_sha256=(Get-FileHash -LiteralPath $mp4 -Algorithm SHA256).Hash;pack=$Pack;recorded_at=(Get-Date).ToString('o')}
$manifest.driver_sha256 = $driverHash
if ($Pack) { $manifest.pack_sha256=(Get-FileHash -LiteralPath $Pack -Algorithm SHA256).Hash }
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'recording.json')
Write-Output ('RECORDING_RESULT '+($manifest | ConvertTo-Json -Compress))
