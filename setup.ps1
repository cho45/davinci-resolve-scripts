<#
.SYNOPSIS
    DaVinci Resolve Setup/Uninstall Script

.DESCRIPTION
    This script sets up or removes the development environment for DaVinci Resolve.
    It uses Directory Symbolic Links (/D) to allow cross-drive linking (e.g., from D: to C:).
    NOTE: Administrator privileges are required to create symbolic links on Windows.

    Usage:
    Install:   powershell -ExecutionPolicy Bypass -File .\setup.ps1
    Uninstall: powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Uninstall
#>

param (
    [Parameter(Mandatory=$false)]
    [Switch]$Uninstall
)

# Set Output Encoding
$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Admin Privilege Check ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "Administrator privileges are required to manage symbolic links. Please run PowerShell as administrator."
    exit 1
}

# --- Configuration ---
$MenuName = "MyScripts"
$PluginMenuName = "MyPlugins"

# --- Paths ---

$resolveAppData = "$env:PROGRAMDATA\Blackmagic Design\DaVinci Resolve"

# 1. Developer SDK (Reference)
$sdkSource = Join-Path $resolveAppData "Support\Developer"
$sdkDest   = Join-Path $PSScriptRoot "Developer"

# 2. Scripts (Installation)
$scriptsSourceBase = Join-Path $PSScriptRoot "src\Scripts"
$scriptsDestBase   = Join-Path $resolveAppData "Fusion\Scripts"

# 3. Workflow Integration (Installation)
$pluginsSourceBase = Join-Path $PSScriptRoot "src\Workflow_Integration"
$pluginsDestBase   = Join-Path $resolveAppData "Support\Workflow Integration Plugins"
# --- Functions ---

function Get-LinkTarget {
    param ([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path
        if ($item.Attributes -match "ReparsePoint") {
            # Works for both Junctions and Symlinks
            $target = $item.Target | ForEach-Object { (Get-Item -LiteralPath $_).FullName }
            if ($null -eq $target) {
                # Fallback for some symlink types
                $target = (Get-Item -LiteralPath $Path).LinkTarget
            }
            return $target
        }
    }
    return $null
}

function Create-Symlink {
    param (
        [string]$Source,
        [string]$Destination,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warning "Source not found ($Description): $Source"
        return
    }
    
    $fullSource = (Get-Item -LiteralPath $Source).FullName

    if (Test-Path -LiteralPath $Destination) {
        $currentTarget = Get-LinkTarget $Destination
        if ($currentTarget -eq $fullSource) {
            Write-Host "Already linked correctly: $Description ($Destination)" -ForegroundColor Cyan
        } else {
            Write-Warning "Already linked to a different location: $Destination"
            Write-Host "  Current: $currentTarget"
            Write-Host "  Expected: $fullSource"
            Write-Host "  Tip: Use -Uninstall to clear existing links."
        }
    } else {
        Write-Host "Creating symbolic link: $Description..." -ForegroundColor Yellow
        try {
            $parentDir = Split-Path -Parent $Destination
            if (-not (Test-Path -LiteralPath $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            # Use /d for directory symbolic link
            cmd /c mklink /d "$Destination" "$fullSource" | Out-Null
            Write-Host "Success: $Description installed." -ForegroundColor Green
        } catch {
            Write-Error "Failed to create symbolic link: $_"
        }
    }
}

function Remove-Link {
    param (
        [string]$Path,
        [string]$ExpectedTarget,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Not found, skipping: $Description" -ForegroundColor Gray
        return
    }

    $item = Get-Item -LiteralPath $Path
    if (-not ($item.Attributes -match "ReparsePoint")) {
        Write-Warning "Not a link, skipping: $Description ($Path)"
        return
    }

    $actualTarget = Get-LinkTarget $Path
    $normalizedExpected = (Get-Item -LiteralPath $ExpectedTarget).FullName

    if ($actualTarget -eq $normalizedExpected) {
        Write-Host "Removing link: $Description..." -ForegroundColor Yellow
        try {
            # rmdir is safe for both junctions and directory symlinks
            cmd /c rmdir "$Path"
            Write-Host "Success: $Description removed." -ForegroundColor Green
        } catch {
            Write-Error "Failed to remove link: $_"
        }
    } else {
        Write-Warning "Target mismatch, skipping for safety: $Description"
        Write-Host "  Actual: $actualTarget"
        Write-Host "  Expected: $normalizedExpected"
    }
}

# --- Main ---

if ($Uninstall) {
    Write-Host "--- DaVinci Resolve Environment Cleanup (Uninstall) ---" -ForegroundColor White -BackgroundColor DarkRed

    Remove-Link -Path $sdkDest      -ExpectedTarget $sdkSource      -Description "SDK_Reference"

    if (Test-Path -LiteralPath $pluginsSourceBase) {
        Write-Host "Uninstalling plugins..." -ForegroundColor Yellow
        Get-ChildItem -Directory -Path $pluginsSourceBase | ForEach-Object {
            $destPath = Join-Path $pluginsDestBase $_.Name
            if (Test-Path -LiteralPath $destPath) {
                # Remove physical directory structure instead of Link
                Remove-Item -Path $destPath -Recurse -Force
                Write-Host "Success: Plugin $($_.Name) removed." -ForegroundColor Green
            }
        }
    }

    $scriptFolders = @("Comp", "Deliver", "Edit", "Color", "Utility")
    foreach ($folder in $scriptFolders) {
        $srcPath = Join-Path $scriptsSourceBase $folder
        $destPath = Join-Path (Join-Path $scriptsDestBase $folder) $MenuName
        Remove-Link -Path $destPath -ExpectedTarget $srcPath -Description "Scripts_Link_$folder"
    }

    Write-Host "`nCleanup completed." -ForegroundColor Green
} else {
    Write-Host "--- DaVinci Resolve Environment Setup (Install) ---" -ForegroundColor White -BackgroundColor Blue

    Create-Symlink -Source $sdkSource      -Destination $sdkDest      -Description "SDK_Reference"

    if (Test-Path -LiteralPath $pluginsSourceBase) {
        Write-Host "Installing plugins (Copying due to Electron sandbox restrictions)..." -ForegroundColor Yellow
        Get-ChildItem -Directory -Path $pluginsSourceBase | ForEach-Object {
            $srcPath = $_.FullName
            $destPath = Join-Path $pluginsDestBase $_.Name
            
            # Use robocopy to mirror the directory. It safely skips locked files (like WorkflowIntegration.node)
            # /MIR: Mirror a directory tree
            # /NFL /NDL /NJH /NJS /nc /ns /np: Suppress most output for cleaner logs
            cmd /c robocopy `"$srcPath`" `"$destPath`" /MIR /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
            
            Write-Host "Success: Plugin $($_.Name) synced." -ForegroundColor Green
        }
    }

    $scriptFolders = @("Comp", "Deliver", "Edit", "Color", "Utility")
    foreach ($folder in $scriptFolders) {
        $srcPath = Join-Path $scriptsSourceBase $folder
        $destPath = Join-Path (Join-Path $scriptsDestBase $folder) $MenuName
        
        if (Test-Path -LiteralPath $srcPath) {
            Create-Symlink -Source $srcPath -Destination $destPath -Description "Scripts_Link_$folder"
        }
    }

    Write-Host "`nSetup completed." -ForegroundColor Green
}
