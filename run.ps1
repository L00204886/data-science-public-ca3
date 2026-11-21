<#
.SYNOPSIS
    Run the CA3 Airline Passenger Satisfaction R pipeline on Windows (PowerShell).

.DESCRIPTION
    Automatically locates Rscript.exe (PATH, Windows Registry, or standard install folders)
    without requiring manual PATH configuration, ensures required CRAN packages are
    installed as precompiled binaries, and executes the pipeline from the project root.

.PARAMETER Check
    Only check/install required R packages (runs scripts/check_packages.R) without
    running the full analysis.

.EXAMPLE
    .\run.ps1

.EXAMPLE
    .\run.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

function Resolve-RscriptFromHome {
    param([string]$RHome)
    if ([string]::IsNullOrWhiteSpace($RHome)) { return $null }

    foreach ($rel in @('bin\x64\Rscript.exe', 'bin\Rscript.exe')) {
        $candidate = Join-Path $RHome $rel
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    return $null
}

function Find-Rscript {
    # 1. Check PATH first
    $cmd = Get-Command Rscript.exe -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Path -LiteralPath $cmd.Source -PathType Leaf)) {
        return $cmd.Source
    }

    # 2. Check Windows Registry (Current User, then Local Machine)
    foreach ($regPath in @('HKCU:\SOFTWARE\R-core\R', 'HKLM:\SOFTWARE\R-core\R')) {
        if (Test-Path -LiteralPath $regPath) {
            $props = Get-ItemProperty -LiteralPath $regPath -Name InstallPath -ErrorAction SilentlyContinue
            if ($props -and $props.InstallPath) {
                $found = Resolve-RscriptFromHome -RHome $props.InstallPath
                if ($found) { return $found }
            }
        }
    }

    # 3. Scan standard Windows installation directories (newest R version first)
    $roots = @(
        (Join-Path $env:ProgramFiles 'R'),
        (Join-Path $env:LOCALAPPDATA 'Programs\R')
    )
    if (${env:ProgramFiles(x86)}) {
        $roots += (Join-Path ${env:ProgramFiles(x86)} 'R')
    }

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

        $dirs = Get-ChildItem -LiteralPath $root -Directory -Filter 'R-*' -ErrorAction SilentlyContinue |
            Sort-Object {
                $verText = $_.Name -replace '^R-', ''
                $parsed = $null
                if ([version]::TryParse($verText, [ref]$parsed)) { $parsed } else { [version]'0.0' }
            } -Descending

        foreach ($dir in $dirs) {
            $found = Resolve-RscriptFromHome -RHome $dir.FullName
            if ($found) { return $found }
        }
    }

    return $null
}

$rscript = Find-Rscript
if (-not $rscript) {
    Write-Host ''
    Write-Host '[ERROR] R was not found on this computer.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'To install R on Windows, choose either option:'
    Write-Host '  1. Run in PowerShell:  winget install RProject.R'
    Write-Host '  2. Download from CRAN: https://cran.r-project.org/bin/windows/base/'
    Write-Host ''
    Write-Host 'After installing R, run .\run.ps1 again. No PATH setup is required.'
    Write-Host ''
    exit 1
}

$targetScript = if ($Check) { 'scripts\check_packages.R' } else { 'scripts\run_all.R' }

Push-Location -LiteralPath $PSScriptRoot
try {
    Write-Host "Using Rscript: `"$rscript`""
    & $rscript $targetScript
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

exit $exitCode
