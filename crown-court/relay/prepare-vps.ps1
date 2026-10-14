param([string]$OutputDirectory='')
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$buildRoot=Join-Path $repoRoot 'build'
if(-not $OutputDirectory){$OutputDirectory=Join-Path $buildRoot ('crown-court-vps-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))}
$staging=[IO.Path]::GetFullPath($OutputDirectory)
if(-not $staging.StartsWith($buildRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Use a new directory under build'}
if(Test-Path -LiteralPath $staging){throw 'Refusing to replace an existing bundle'}
New-Item -ItemType Directory -Path $staging | Out-Null
$files=@('Dockerfile','.dockerignore','package.json','package-lock.json','server.mjs','THIRD_PARTY_NOTICES.txt','deploy-vps.sh')
foreach($file in $files){
    $content=[IO.File]::ReadAllText((Join-Path $PSScriptRoot $file)).Replace("`r`n","`n")
    [IO.File]::WriteAllText((Join-Path $staging $file),$content,[Text.UTF8Encoding]::new($false))
}
$sums=foreach($file in $files){((Get-FileHash -LiteralPath (Join-Path $staging $file) -Algorithm SHA256).Hash.ToLower()+'  '+$file)}
[IO.File]::WriteAllText((Join-Path $staging 'SHA256SUMS'),($sums -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
$archive=$staging+'.tar.gz'
& tar -czf $archive -C $staging -- @($files+'SHA256SUMS')
if($LASTEXITCODE -ne 0){throw 'Archive creation failed'}
$actual=@(& tar -tzf $archive)
if($LASTEXITCODE -ne 0 -or @(Compare-Object ($files+'SHA256SUMS'|Sort-Object) ($actual|Sort-Object)).Count){throw 'Archive allowlist check failed'}
[pscustomobject]@{Directory=$staging;Archive=$archive;SHA256=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash;Deployed=$false}
