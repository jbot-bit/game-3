# Read-only: no firewall, router, account or network setting changes.
$ErrorActionPreference = 'Continue'
Write-Output 'Crown Court connection check'
$configPath = Join-Path $PSScriptRoot 'internet.cfg'
$endpoint = ''
if (Test-Path -LiteralPath $configPath) {
    foreach ($line in Get-Content -LiteralPath $configPath) {
        if ($line -match '^\s*url\s*=\s*"([^"]*)"\s*$') { $endpoint = $Matches[1] }
    }
}
if (-not $endpoint) { Write-Output 'Public room service is not configured. Practice and LAN are available.' }
elseif ($endpoint -notmatch '^wss://[A-Za-z0-9.-]+(?::[0-9]{1,5})?/rooms$') { Write-Output 'Room service URL is invalid. Use the configuration supplied with the internet release.' }
else {
    $health = $endpoint.Replace('wss://','https://').Replace('/rooms','/healthz')
    try {
        $result = Invoke-RestMethod -Uri $health -TimeoutSec 12
        Write-Output ('Room service health: '+$result.ok+'; protocol '+$result.protocol)
    } catch { Write-Output 'Room service did not answer. Check your internet connection or try again later.' }
}
Write-Output 'LAN addresses:'
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } | Select-Object InterfaceAlias,IPAddress | Format-Table -AutoSize
Write-Output 'Game host listening on UDP 28888:'
$listeners = @(Get-NetUDPEndpoint -LocalPort 28888 -ErrorAction SilentlyContinue)
if ($listeners.Count) { $listeners | Select-Object LocalAddress,LocalPort,OwningProcess | Format-Table -AutoSize }
else { Write-Output 'No LAN host is running.' }
Write-Output 'A health response is not a full game test. Ask a friend to join and finish a match.'
