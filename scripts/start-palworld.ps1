# ============================================================
#  AMP Console Wrapper for Palworld Server
#  Place this in your AMP Palworld instance's root directory.
#  Configure AMP to run this instead of PalServer.exe.
#
#  What it does:
#    1. Starts PalServer.exe as a hidden process
#    2. Monitors Pal/Saved/Logs/PalServer.log in real time
#    3. Writes each log line to stdout so AMP's console shows it
#    4. Exits cleanly when the server shuts down
# ============================================================

param(
    # Any extra command-line arguments you want passed to PalServer.exe
    [string]$ExtraArgs = ""
)

# --- Configuration -----------------------------------------------------------
$ServerExe    = ".\PalServer.exe"
$LogFile      = ".\Pal\Saved\Logs\PalServer.log"
$LogDir       = ".\Pal\Saved\Logs"
$PollMs       = 200   # How often (ms) to check the log for new lines
$StartTimeout = 30    # Seconds to wait for log file to appear before warning
# -----------------------------------------------------------------------------

function Write-AMP {
    param([string]$Msg, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts][$Level][AMP-Wrapper] $Msg"
}

# Ensure the log directory exists so the server can write to it immediately
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Wipe the log so we start with a clean slate each launch
if (Test-Path $LogFile) { Clear-Content $LogFile }

Write-AMP "Launching $ServerExe $ExtraArgs"

# Start the server — hide its own window so AMP is the only console
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName               = (Resolve-Path $ServerExe).Path
$psi.Arguments              = $ExtraArgs
$psi.WorkingDirectory       = (Get-Location).Path
$psi.UseShellExecute        = $false
$psi.WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden
$psi.RedirectStandardOutput = $false   # Palworld uses its own UE logging, not stdout
$psi.RedirectStandardError  = $false

try {
    $Server = [System.Diagnostics.Process]::Start($psi)
} catch {
    Write-AMP "FAILED to start server: $_" "ERROR"
    exit 1
}

Write-AMP "Server started. PID=$($Server.Id)"
Write-AMP "Waiting for log file: $LogFile"

# Wait for the log file to be created by the server
$waited = 0
while (-not (Test-Path $LogFile)) {
    if ($Server.HasExited) {
        Write-AMP "Server exited before creating log file. Exit code: $($Server.ExitCode)" "ERROR"
        exit $Server.ExitCode
    }
    Start-Sleep -Milliseconds 500
    $waited += 0.5
    if ($waited -ge $StartTimeout) {
        Write-AMP "Log file not found after ${StartTimeout}s — console output may be missing." "WARN"
        break
    }
}

Write-AMP "Log monitoring active."

# --- Main loop: tail the log and echo new lines to AMP's console -------------
$logPos = 0
$reader = $null

try {
    while (-not $Server.HasExited) {
        if (Test-Path $LogFile) {
            # Open with FileShare.ReadWrite so Palworld can still write to it
            if ($null -eq $reader) {
                $fs     = [System.IO.File]::Open($LogFile, 'Open', 'Read', 'ReadWrite')
                $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
                $logPos = 0
            }

            $reader.BaseStream.Seek($logPos, 'Begin') | Out-Null
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ($null -ne $line -and $line.Trim().Length -gt 0) {
                    Write-Host $line
                }
            }
            $logPos = $reader.BaseStream.Position
        }
        Start-Sleep -Milliseconds $PollMs
    }
} finally {
    if ($null -ne $reader) { $reader.Dispose() }

    # Final flush — capture any lines written right before exit
    if (Test-Path $LogFile) {
        $fs     = [System.IO.File]::Open($LogFile, 'Open', 'Read', 'ReadWrite')
        $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
        $reader.BaseStream.Seek($logPos, 'Begin') | Out-Null
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($null -ne $line -and $line.Trim().Length -gt 0) { Write-Host $line }
        }
        $reader.Dispose()
    }

    Write-AMP "Server exited. Exit code: $($Server.ExitCode)"
    exit $Server.ExitCode
}
