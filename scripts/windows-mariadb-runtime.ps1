$WindowsMariaDbVersion = '11.8.9'
$WindowsMariaDbArchiveSha256 = '830C46727D9278EAE212AE3ECA44EEB9E71B2A68704E95F344A64FBA7B1963F5'

function Assert-WindowsMariaDbRuntime {
    param([Parameter(Mandatory)][string]$RuntimeRoot)

    $bin = Join-Path $RuntimeRoot 'bin'
    foreach ($tool in @('mariadbd', 'mariadb', 'mariadb-admin', 'mariadb-dump',
                       'mariadb-install-db', 'mariadb-upgrade', 'mariadb-check')) {
        if (-not (Test-Path -LiteralPath (Join-Path $bin "$tool.exe") -PathType Leaf)) {
            throw "Incomplete Windows MariaDB runtime at '$RuntimeRoot'. Missing $tool.exe."
        }
    }

    $version = & (Join-Path $bin 'mariadbd.exe') --no-defaults --version
    $expected = [regex]::Escape($WindowsMariaDbVersion)
    if ($LASTEXITCODE -ne 0 -or $version -notmatch "\b$expected-MariaDB\b") {
        throw "Windows MariaDB runtime at '$RuntimeRoot' must be $WindowsMariaDbVersion. Move the stale runtime out of the repository and restore the pinned archive."
    }
}
