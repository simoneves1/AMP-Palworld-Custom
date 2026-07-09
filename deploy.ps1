# ============================================================
#  deploy.ps1  —  Copy AMP-Palworld-Custom files to your server
#
#  Run this script ON THE SERVER that hosts AMP.
#  Edit the two path variables below first.
# ============================================================

# --- EDIT THESE TWO PATHS ---------------------------------------------------

# Full path to your AMP Palworld instance root folder
# (the folder that contains PalServer.exe)
$InstanceRoot = "C:\AMPDatastore\Instances\Palworld01"

# Full path to where this project lives (the folder containing this script)
$ProjectRoot  = $PSScriptRoot

# ----------------------------------------------------------------------------

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "    [OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "    [WARN] $Msg" -ForegroundColor Yellow }

Write-Step "Validating paths..."

if (-not (Test-Path $InstanceRoot)) {
    Write-Host "ERROR: Instance root not found: $InstanceRoot" -ForegroundColor Red
    Write-Host "Edit the `$InstanceRoot variable at the top of this script."
    exit 1
}
Write-OK "Instance root: $InstanceRoot"

# --- 1. Copy the console wrapper script -------------------------------------
Write-Step "Installing console wrapper script..."

$ScriptDest = Join-Path $InstanceRoot "scripts"
if (-not (Test-Path $ScriptDest)) {
    New-Item -ItemType Directory -Path $ScriptDest -Force | Out-Null
}

Copy-Item -Path (Join-Path $ProjectRoot "scripts\start-palworld.ps1") `
          -Destination (Join-Path $ScriptDest "start-palworld.ps1") -Force
Write-OK "Copied start-palworld.ps1 to $ScriptDest"

# --- 2. Back up and apply AMPConfig override --------------------------------
Write-Step "Applying AMPConfig override..."

$AmpConfigDest = Join-Path $InstanceRoot "AMPConfig.conf"
if (Test-Path $AmpConfigDest) {
    $Backup = "$AmpConfigDest.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $AmpConfigDest $Backup
    Write-Warn "Backed up existing AMPConfig.conf to: $Backup"
}

$OverrideSrc = Join-Path $ProjectRoot "config\AMPConfig-override.conf"

# Merge (append) the override into any existing AMPConfig.conf, or create it fresh
$OverrideContent = Get-Content $OverrideSrc -Raw
if (Test-Path $AmpConfigDest) {
    Add-Content -Path $AmpConfigDest -Value "`n; === AMP-Palworld-Custom override (added by deploy.ps1) ===`n$OverrideContent"
} else {
    Copy-Item $OverrideSrc $AmpConfigDest
}
Write-OK "AMPConfig.conf updated."

# --- 3. Copy the settings template for reference ----------------------------
Write-Step "Copying settings template..."

$SettingsDest = Join-Path $InstanceRoot "Pal\Saved\Config\WindowsServer"
if (-not (Test-Path $SettingsDest)) {
    New-Item -ItemType Directory -Path $SettingsDest -Force | Out-Null
}

Copy-Item -Path (Join-Path $ProjectRoot "config\PalWorldSettings.ini.template") `
          -Destination (Join-Path $SettingsDest "PalWorldSettings.ini.template") -Force
Write-OK "Settings template copied to $SettingsDest"

# --- 4. Remind about AMP UI change ------------------------------------------
Write-Step "Manual step required in AMP Web UI"
Write-Host @"

  After running this script you MUST update the startup command in AMP:

  1. Open AMP Web UI and go to your Palworld instance
  2. Navigate to:  Configuration > Application Settings (or the Startup tab)
  3. Set 'Executable' to:
       powershell.exe
  4. Set 'Arguments' / 'Startup Parameters' to:
       -ExecutionPolicy Bypass -NonInteractive -File "scripts\start-palworld.ps1"
  5. Save and restart the instance.

  The AMP console will now show the full Palworld server log in real time.

"@ -ForegroundColor White

Write-Host "Deploy complete!" -ForegroundColor Green
