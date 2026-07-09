# AMP Custom Palworld Module

Fixes two problems with the default AMP Palworld setup:
1. **Console is blank** — because Palworld writes output to a log file, not to stdout. AMP misses it entirely.
2. **Settings are cryptic** — `PalStomachDecreaceRate`, `bEnableInvaderEnemy`, etc. are hard to know at a glance.

---

## What's included

| File | Purpose |
|------|---------|
| `scripts/start-palworld.ps1` | Wrapper that starts `PalServer.exe` and tails its log to AMP's console in real time |
| `config/AMPConfig-override.conf` | AMP instance config that points to the wrapper + color-codes console output |
| `config/PalWorldSettings.ini.template` | Every setting explained in plain English with valid values and ranges |
| `deploy.ps1` | Copies everything to your server automatically |

---

## Setup

### Step 1 — Copy the project to your server

Copy this entire folder to the server running AMP. It doesn't matter where; somewhere like `C:\AMP-Palworld-Custom\` is fine.

### Step 2 — Edit deploy.ps1

Open `deploy.ps1` and change the two variables at the top:

```powershell
$InstanceRoot = "C:\AMPDatastore\Instances\Palworld01"  # ← your instance folder
$ProjectRoot  = $PSScriptRoot                            # ← leave as-is
```

> **Finding your instance folder:** In AMP Web UI → Instance → Configuration → scroll to "Instance Directory". It ends in something like `Palworld01\`.

### Step 3 — Run deploy.ps1

Open PowerShell **as Administrator** on the server and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd "C:\AMP-Palworld-Custom"
.\deploy.ps1
```

### Step 4 — Update AMP's startup command

The script will tell you this too, but:

1. AMP Web UI → your Palworld instance → **Configuration** → **Startup**
2. **Application / Executable**: `powershell.exe`
3. **Arguments / Parameters**: `-ExecutionPolicy Bypass -NonInteractive -File "scripts\start-palworld.ps1"`
4. Save → restart the instance.

You should immediately see the Palworld log streaming in AMP's **Console** tab.

---

## Configuring server settings

Use `config/PalWorldSettings.ini.template` as your reference. It has every option explained.

The actual file the server reads is at:
```
<InstanceRoot>\Pal\Saved\Config\WindowsServer\PalWorldSettings.ini
```

> ⚠️ All settings must be on **one single line** inside `OptionSettings=(...)`. Use the template's comment block at the bottom as a starting point.

### Quick-reference: most-changed settings

| What you want to change | Setting key |
|------------------------|-------------|
| Server name | `ServerName` |
| Max players | `ServerPlayerMaxNum` |
| Join password | `ServerPassword` |
| Admin password | `AdminPassword` |
| XP speed | `ExpRate` |
| Catching Pals easier | `PalCaptureRate` |
| Item drop rate | `EnemyDropItemRate` |
| Faster days | `DayTimeSpeedRate` |
| Faster nights | `NightTimeSpeedRate` |
| What you drop on death | `DeathPenalty` (`None`/`Item`/`ItemAndEquipment`/`All`) |
| Pal work speed at base | `WorkSpeedRate` |
| Enable PvP | `bIsPvP` |
| Enable RCON | `RCONEnabled` / `RCONPort` |
| Disable base raids | `bEnableInvaderEnemy=False` |

---

## Troubleshooting

**Console still blank after setup**
- Make sure the instance actually restarted with the new startup command.
- Check that `PalServer.exe` creates a log at `Pal\Saved\Logs\PalServer.log`. If the path differs, edit the `$LogFile` variable at the top of `start-palworld.ps1`.

**"File not found" on startup**
- Confirm the `scripts\` folder is in your AMP instance root (same level as `PalServer.exe`).
- Check that the AMP startup Arguments path uses backslashes and matches exactly.

**Player count / online list not updating in AMP**
- This is a known limitation of running via a wrapper. Enable RCON (`RCONEnabled=True`) and configure AMP's RCON port — AMP will use RCON for player queries automatically when the process path changes.
