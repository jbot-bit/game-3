[CmdletBinding()]
param(
    [ValidatePattern('^[a-z][a-z0-9-]{4,62}$')]
    [string]$AppName = 'crown-court-jbot-rooms',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$buildRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'build'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    $OutputDirectory = Join-Path $buildRoot ('crown-court-relay-hosting-prepared-' + $stamp)
}
$staging = [IO.Path]::GetFullPath($OutputDirectory)
$buildPrefix = $buildRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $staging.StartsWith($buildPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be a fresh directory inside this repository build directory.'
}
$archive = $staging + '.zip'
if ((Test-Path -LiteralPath $staging) -or (Test-Path -LiteralPath $archive)) {
    throw 'Refusing to overwrite an existing staging directory or ZIP. Choose a fresh output path.'
}

# A literal allowlist prevents unrelated source, tests, node_modules and secrets
# from entering staging. There is no account, network, build or deployment step.
$sourceFiles = @('.dockerignore', 'Dockerfile', 'package.json', 'package-lock.json', 'server.mjs', 'THIRD_PARTY_NOTICES.txt', 'INTERNET-HOSTING-PLAN.md')
foreach ($name in $sourceFiles + @('fly.example.toml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) {
        throw ('Missing allowlisted relay file: ' + $name)
    }
}
$template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fly.example.toml'))
if (-not $template.Contains('replace-with-approved-room-service-name')) { throw 'Unexpected Fly template app placeholder.' }
$config = $template.Replace('replace-with-approved-room-service-name', $AppName)
foreach ($required in @('primary_region = "syd"', 'memory = "256mb"', 'cpu_kind = "shared"', 'cpus = 1', 'auto_stop_machines = "off"', 'min_machines_running = 1')) {
    if (-not $config.Contains($required)) { throw ('Fly template no longer matches reviewed service: ' + $required) }
}

New-Item -ItemType Directory -Path $staging | Out-Null
foreach ($name in $sourceFiles) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $staging $name)
}
[IO.File]::WriteAllText((Join-Path $staging 'fly.toml'), $config, [Text.UTF8Encoding]::new($false))
$payloadFiles = @($sourceFiles + 'fly.toml' | Sort-Object)
$entries = @(
    foreach ($name in $payloadFiles) {
        $path = Join-Path $staging $name
        [ordered]@{ path = $name; bytes = (Get-Item -LiteralPath $path).Length; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    }
)
$manifest = [ordered]@{
    schema = 1
    preparedUtc = [DateTime]::UtcNow.ToString('o')
    approvalPending = $true
    externalActionsPerformed = $false
    appNameCandidate = $AppName
    appNameReserved = $false
    organization = $null
    proposedService = [ordered]@{ machines = 1; region = 'syd'; cpuKind = 'shared'; vcpus = 1; memoryMb = 256; volumes = 0; databases = 0; remoteBuilder = $false }
    dockerContextAllowlist = @('Dockerfile', 'package.json', 'package-lock.json', 'server.mjs')
    files = $entries
}
[IO.File]::WriteAllText((Join-Path $staging 'manifest.json'), ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($staging, $archive, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @($payloadFiles + 'manifest.json' | Sort-Object)
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $actual = @($zip.Entries | ForEach-Object { $_.FullName } | Sort-Object)
    if (@(Compare-Object -ReferenceObject $expected -DifferenceObject $actual).Count -ne 0) {
        throw 'ZIP contents differ from the exact allowlist.'
    }
    foreach ($entry in $zip.Entries) {
        $stream = $entry.Open()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $zipHash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '') }
        finally { $hasher.Dispose(); $stream.Dispose() }
        $stagedHash = (Get-FileHash -LiteralPath (Join-Path $staging $entry.FullName) -Algorithm SHA256).Hash
        if ($zipHash -ne $stagedHash) { throw ('ZIP byte verification failed: ' + $entry.FullName) }
    }
}
finally { $zip.Dispose() }

[pscustomobject]@{
    StagingDirectory = $staging
    Zip = $archive
    Bytes = (Get-Item -LiteralPath $archive).Length
    SHA256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    VerifiedEntries = $expected.Count
    ApprovalPending = $true
    ExternalActionsPerformed = $false
}
