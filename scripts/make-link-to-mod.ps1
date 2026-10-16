<#
.SYNOPSIS
    Links the mod folder from this repository into Project Zomboid's Workshop
    folder, so the game loads the mod directly from the source tree.

.DESCRIPTION
    Creates <Zomboid>\Workshop\ProximityInventoryDumpSomewhere as a link to
    <repository>\src\ProximityInventoryDumpSomewhere.

    A symbolic link is used when the environment allows it (Developer Mode or
    an elevated shell); otherwise it falls back to a junction, which needs no
    special rights. Either way the link is transparent to the game: changes
    made in the repository are immediately visible, and files the game writes
    (e.g. saved settings) land right in the repository.

    The existing link is never replaced automatically. If a link is already in
    place and points elsewhere, pass -Force to replace it. A real (non-link)
    directory at the target path is never touched.

.PARAMETER ZomboidDir
    Project Zomboid data directory. Defaults to %PROJECT_ZOMBOID_HOME% when
    that environment variable is set, otherwise to %USERPROFILE%\Zomboid.

.PARAMETER Force
    Replace an existing link at the destination when it points to a different
    target.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\make-link-to-mod.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\make-link-to-mod.ps1 -ZomboidDir 'D:\Games\Zomboid' -Force
#>

[CmdletBinding()]
param(
    [string]$ZomboidDir,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$modName = 'ProximityInventoryDumpSomewhere'

# ---------------------------------------------------------------- locations --
if (-not $PSScriptRoot) {
    Write-Error ('Run this script as a file so it can locate the repository: ' +
                 'powershell -ExecutionPolicy Bypass -File scripts\make-link-to-mod.ps1') -ErrorAction Stop
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$target   = Join-Path (Join-Path $repoRoot 'src') $modName

if (-not (Test-Path -LiteralPath $target -PathType Container)) {
    Write-Error "Mod folder not found: $target" -ErrorAction Stop
}

if (-not $ZomboidDir) { $ZomboidDir = $env:PROJECT_ZOMBOID_HOME }
if (-not $ZomboidDir) { $ZomboidDir = Join-Path $env:USERPROFILE 'Zomboid' }

$workshopDir = Join-Path $ZomboidDir 'Workshop'
$link        = Join-Path $workshopDir $modName

if (-not (Test-Path -LiteralPath $ZomboidDir -PathType Container)) {
    Write-Warning ("Zomboid data folder '$ZomboidDir' does not exist yet and will be created. " +
                   'If the game keeps its data elsewhere, pass -ZomboidDir <path>.')
}

# ----------------------------------------------------------- existing links --
if (Test-Path -LiteralPath $link) {
    $existing = Get-Item -LiteralPath $link -Force

    if (-not $existing.LinkType) {
        Write-Error ("'$link' already exists and is a real directory, not a link. " +
                     'Remove or rename it yourself, then run this script again.') -ErrorAction Stop
    }

    $existingTarget = [string]@($existing.Target)[0]
    if (-not $existingTarget) {
        Write-Error "Could not read the target of the existing link at '$link'." -ErrorAction Stop
    }

    $current = [System.IO.Path]::GetFullPath($existingTarget).TrimEnd('\')
    $wanted  = [System.IO.Path]::GetFullPath($target).TrimEnd('\')

    if ($current -ieq $wanted) {
        Write-Host "OK: '$link' is already a link to '$target'. Nothing to do."
        exit 0
    }

    if (-not $Force) {
        Write-Error ("'$link' exists and points to '$current', not to this repository. " +
                     'Use -Force to replace it.') -ErrorAction Stop
    }

    cmd /c rmdir "$link"    # removes the link itself, never its target
    if (Test-Path -LiteralPath $link) {
        Write-Error "Failed to remove the existing link at '$link'." -ErrorAction Stop
    }
}

# ---------------------------------------------------------------- create it --
New-Item -ItemType Directory -Path $workshopDir -Force | Out-Null

$linkType = $null
try {
    New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
    $linkType = 'SymbolicLink'
} catch {
    $noRights = ($_.Exception -is [System.UnauthorizedAccessException]) -or
                ($_.Exception.Message -match 'privilege|administrator|elevated')
    if (-not $noRights) { throw }
    Write-Host 'No permission for a symbolic link (needs Developer Mode or an elevated shell); creating a junction instead.'
    New-Item -ItemType Junction -Path $link -Target $target -ErrorAction Stop | Out-Null
    $linkType = 'Junction'
}

# ----------------------------------------------------------------- summary --
$item = Get-Item -LiteralPath $link -Force
if (@(Get-ChildItem -LiteralPath $target -Force).Count -eq 0) {
    Write-Warning ("The mod folder '$target' is empty. The link is created, " +
                   'but there is nothing for the game to load yet.')
}

Write-Host ''
Write-Host "Created: $link [$linkType]"
Write-Host "     --> $target"