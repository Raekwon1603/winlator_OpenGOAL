<#
.SYNOPSIS
  Builds a self-contained folder for one OpenGOAL game (Jak 1, Jak 2, or Jak 3),
  ready to copy onto a Winlator device. See the "Setting up an OpenGOAL game"
  section of the README for the full walkthrough this script is part of.

.EXAMPLE
  .\prepare-opengoal-game.ps1 -OpenGoalPath "C:\Users\me\Downloads\Jak_and_Daxter_OpenGOAL\versions\official\v0.3.5" -Game jak3 -OutputPath "C:\Users\me\Desktop\Jak 3"

  Run this AFTER that game has already been extracted/decompiled/compiled
  (Step 2 in the README, via either extractor.exe or the OpenGOAL Launcher's
  own Compile/Decompile buttons, both work) this script only copies files,
  it does not extract/decompile/compile anything itself.
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the versioned OpenGOAL folder containing gk.exe, e.g. C:\path\to\OpenGOAL\versions\official\v0.3.5")]
    [ValidateScript({ Test-Path $_ })]
    [string]$OpenGoalPath,

    [Parameter(Mandatory = $true, HelpMessage = "Type one of: jak1, jak2, jak3")]
    [ValidateSet("jak1", "jak2", "jak3")]
    [Alias("Game")]
    [string]${Game (jak1,jak2 or jak3)},

    [Parameter(Mandatory = $true, HelpMessage = "Folder where the finished game folder should be created, e.g. C:\Users\you\Desktop")]
    [string]$OutputPath
)

$Game = ${Game (jak1,jak2 or jak3)}

$ErrorActionPreference = "Stop"

$gameFolderNames = @{ jak1 = "Jak and Daxter"; jak2 = "Jak 2"; jak3 = "Jak 3" }
$innerFolderNames = @{ jak1 = "Jak_and_Daxter_OpenGOAL"; jak2 = "Jak_2"; jak3 = "Jak_3" }

$gameFolderName = $gameFolderNames[$Game]
$innerFolderName = $innerFolderNames[$Game]
$versionName = Split-Path $OpenGoalPath -Leaf

$dataPath = Join-Path $OpenGoalPath "data"
if (-not (Test-Path $dataPath)) {
    throw "No 'data' folder found under $OpenGoalPath -- did you point this at the right versions\official\<version> folder?"
}

# If decmompiled via the launcher run this instead of the standalone extractor.exe, the compiled data will be in a different location. Check for that and use it if present.
$requiredGameData = Join-Path $dataPath "out\$Game"
if (-not (Test-Path $requiredGameData) -or (Get-ChildItem $requiredGameData -ErrorAction SilentlyContinue).Count -eq 0) {
    $openGoalRoot = Split-Path (Split-Path (Split-Path $OpenGoalPath -Parent) -Parent) -Parent
    $activeDataPath = Join-Path $openGoalRoot "active\$Game\data"
    $activeGameData = Join-Path $activeDataPath "out\$Game"

    if ((Test-Path $activeGameData) -and (Get-ChildItem $activeGameData -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Host "Using Launcher-managed data folder: $activeDataPath" -ForegroundColor Cyan
        $dataPath = $activeDataPath
    } else {
        throw "Couldn't find compiled data for $Game in either 'data\out\$Game' (standalone extractor.exe layout) or 'active\$Game\data\out\$Game' (OpenGOAL Launcher layout). Run extractor.exe for $Game first (Step 2 in the README), or use the Launcher to install/decompile/compile $Game, before using this script."
    }
}

$destRoot = Join-Path $OutputPath $gameFolderName
$destVersioned = Join-Path $destRoot "$innerFolderName\versions\official\$versionName"
$destData = Join-Path $destVersioned "data"

Write-Host "Building $Game folder at: $destRoot" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $destData | Out-Null

Write-Host "Copying gk.exe / goalc.exe..."
Copy-Item (Join-Path $OpenGoalPath "gk.exe") $destVersioned -Force
Copy-Item (Join-Path $OpenGoalPath "goalc.exe") $destVersioned -Force

# Shared engine assets/config -- not game-specific, but always required.
$sharedItems = @("game", "imgui.ini", "launcher", "decompiler")
foreach ($item in $sharedItems) {
    $src = Join-Path $dataPath $item
    if (Test-Path $src) {
        Write-Host "Copying shared: $item"
        Copy-Item $src (Join-Path $destData $item) -Recurse -Force
    }
}

# Shared goal_src pieces (common code, not per-game) plus this game's own folder.
$goalSrcDest = Join-Path $destData "goal_src"
New-Item -ItemType Directory -Force -Path $goalSrcDest | Out-Null
$sharedGoalSrc = @("common", "user", "goal-lib.gc", "goos-lib.gs")
foreach ($item in $sharedGoalSrc) {
    $src = Join-Path $dataPath "goal_src\$item"
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $goalSrcDest $item) -Recurse -Force
    }
}
Copy-Item (Join-Path $dataPath "goal_src\$Game") (Join-Path $goalSrcDest $Game) -Recurse -Force

# Per-game folders produced by extraction/decompilation/compilation.
$perGameItems = @("iso_data", "decompiler_out", "out", "custom_assets")
foreach ($item in $perGameItems) {
    $src = Join-Path $dataPath "$item\$Game"
    if (Test-Path $src) {
        Write-Host "Copying $Game data: $item\$Game"
        New-Item -ItemType Directory -Force -Path (Join-Path $destData $item) | Out-Null
        Copy-Item $src (Join-Path $destData "$item\$Game") -Recurse -Force
    }
}

# Launch script.
$batContent = @"
@echo off
cd /d "F:\$gameFolderName\$innerFolderName"
versions\official\$versionName\gk.exe -v --proj-path "versions\official\$versionName\data" --game $Game -- -boot -fakeiso
pause
"@
$batPath = Join-Path $destRoot "launch_$($Game)_winlator.bat"
Set-Content -Path $batPath -Value $batContent -Encoding ASCII

Write-Host ""
Write-Host "Done. Folder ready at: $destRoot" -ForegroundColor Green
Write-Host "Copy this whole folder onto your device's storage, then run '$([System.IO.Path]::GetFileName($batPath))' from inside Winlator." -ForegroundColor Green
Write-Host "If your device maps shared storage to a different drive letter than F:, edit the .bat file's 'cd /d' line to match." -ForegroundColor Yellow
