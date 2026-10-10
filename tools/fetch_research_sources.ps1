param([string[]]$Names = @('picode-ragdoll', 'netfox'))
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$referenceRoot = Join-Path $projectRoot '.tools\research'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'research-sources.json') -Raw | ConvertFrom-Json
foreach ($name in $Names) {
    $source = @($manifest.sources | Where-Object { $_.name -eq $name })
    if ($source.Count -ne 1) { throw "Unknown reference: $name" }
    $source = $source[0]
    $destination = Join-Path $referenceRoot $source.name
    $safeDirectory = 'safe.directory=' + $destination.Replace('\', '/')
    if (-not (Test-Path -LiteralPath $destination)) {
        New-Item -ItemType Directory -Path $referenceRoot -Force | Out-Null
        $cloneArgs = @('-c', 'core.hooksPath=NUL', 'clone', '--depth', '1')
        if ($source.sparse) { $cloneArgs += @('--filter=blob:none', '--sparse') }
        $cloneArgs += @('--branch', $source.branch, $source.url, $destination)
        & git @cloneArgs
        if ($LASTEXITCODE -ne 0) { throw "Clone failed: $name" }
        $actual = & git -c $safeDirectory -C $destination rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect: $name" }
        if ($actual -ne $source.commit) {
            & git -c $safeDirectory -c core.hooksPath=NUL -C $destination fetch --depth 1 origin $source.commit
            if ($LASTEXITCODE -ne 0) { throw "Pinned revision unavailable: $name" }
            & git -c $safeDirectory -c core.hooksPath=NUL -C $destination checkout --detach $source.commit
            if ($LASTEXITCODE -ne 0) { throw "Cannot check out pinned revision: $name" }
        }
        if ($source.sparse) {
            & git -c $safeDirectory -c core.hooksPath=NUL -C $destination sparse-checkout set @($source.sparse)
            if ($LASTEXITCODE -ne 0) { throw "Sparse checkout failed: $name" }
        }
    }
    $actual = & git -c $safeDirectory -C $destination rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $actual -ne $source.commit) {
        throw "Existing reference differs from pin; preserved without changes: $destination"
    }
    Write-Output "$name $actual $destination"
}
