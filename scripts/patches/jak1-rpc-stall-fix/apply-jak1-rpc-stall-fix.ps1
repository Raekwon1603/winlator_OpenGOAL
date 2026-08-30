<#
.SYNOPSIS
  Patches a Jak 1 install to fix a permanent freeze that can happen when the game
  is waiting on an audio/streaming response that never arrives (seen on Android
  through Wine/Box64). This replaces two compiled game data files with versions
  built from a small, targeted fix: the underlying wait loop now gives up after
  a long timeout instead of spinning forever with no way out.

  This does not change gk.exe or anything about your Winlator setup. It only
  patches game data (ENGINE.CGO and GAME.CGO) inside an already-working Jak 1
  install, PC or device, and backs up the originals first.

.EXAMPLE
  .\apply-jak1-rpc-stall-fix.ps1 -InstallPath "C:\Users\me\Desktop\Jak and Daxter"

  Patches a Jak 1 folder built by prepare-opengoal-game.ps1 (or copied straight
  from a working device install) sitting at that path.
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to your Jak 1 install folder, the one containing 'Jak_and_Daxter_OpenGOAL\versions\...'")]
    [ValidateScript({ Test-Path $_ })]
    [string]$InstallPath
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$isoDir = Get-ChildItem -Path $InstallPath -Recurse -Directory -Filter "iso" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\data\\out\\jak1\\iso$' } |
    Select-Object -First 1

if (-not $isoDir) {
    throw "Couldn't find a 'data\out\jak1\iso' folder anywhere under $InstallPath -- is this a Jak 1 install? (Jak 2/Jak 3 aren't affected by this specific patch.)"
}

$targetEngine = Join-Path $isoDir.FullName "ENGINE.CGO"
$targetGame = Join-Path $isoDir.FullName "GAME.CGO"

foreach ($f in @($targetEngine, $targetGame)) {
    if (-not (Test-Path $f)) {
        throw "Expected to find $f but it's missing. This doesn't look like a complete Jak 1 install."
    }
}

Write-Host "Found Jak 1 game data at: $($isoDir.FullName)" -ForegroundColor Cyan

$alreadyPatchedMarker = Join-Path $isoDir.FullName ".jak1-rpc-stall-fix-applied"
if (Test-Path $alreadyPatchedMarker) {
    Write-Host "This install already has the fix applied (found $([System.IO.Path]::GetFileName($alreadyPatchedMarker))). Nothing to do." -ForegroundColor Yellow
    return
}

$backupSuffix = ".before-rpc-stall-fix"
foreach ($f in @($targetEngine, $targetGame)) {
    $backupPath = "$f$backupSuffix"
    if (-not (Test-Path $backupPath)) {
        Write-Host "Backing up $([System.IO.Path]::GetFileName($f))..."
        Copy-Item $f $backupPath
    } else {
        Write-Host "Backup already exists for $([System.IO.Path]::GetFileName($f)), leaving it alone."
    }
}

Write-Host "Applying patched ENGINE.CGO and GAME.CGO..."
Copy-Item (Join-Path $scriptDir "ENGINE.CGO") $targetEngine -Force
Copy-Item (Join-Path $scriptDir "GAME.CGO") $targetGame -Force

Set-Content -Path $alreadyPatchedMarker -Value "Applied $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding ASCII

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Copy the updated 'data\out\jak1' folder back onto your device (same place it was before) if you patched a PC-side copy rather than a folder already on the device." -ForegroundColor Green
Write-Host "Your originals are saved next to the new files with a '$backupSuffix' suffix if you ever want to revert." -ForegroundColor Yellow
