# Powershell
# SPDX-License-Identifier: MIT
#
# This script is used to set up the local environment on Windows. It configures the following:
# 1. WSL2 (Windows Subsystem for Linux)
# 2. Docker Desktop
# 3. Under WSL environment, install Git
# 4. Under WSL environment, checkout this repo
#
# Usage:
# It is recommended to run C:\> setup-windows.bat
#
# NOTE: Designed to run on a fresh Windows 10 install or later

function main {
    AutoExec-Cleanup
}

# Remove the scheduled task we've created to run ourselves again after restart
function AutoExec-Cleanup {
    # Check if the scheduled task already exists
    $existingTask = Get-ScheduledTask -TaskName $AutoExecName -ErrorAction SilentlyContinue
    if ($existingTask) {
        # Remove it
        Write-Host "Scheduled task '$AutoExecName' exists. Removing it..."
        Ensure-Admin "to remove scheduled task '$AutoExecName'"

        Unregister-ScheduledTask -TaskName $AutoExecName -Confirm:$false
        $existingTask = Get-ScheduledTask -TaskName $AutoExecName -ErrorAction SilentlyContinue
        if (-not $existingTask) {
            Write-Host "Scheduled task '$AutoExecName' removed."
        } else {
            Write-Host "Failed to remove '$AutoExecName'."
            exit 1
        }
    }
}

# Ensure we are running with privileges. If not, elevate them by calling our own script recursively.
function Ensure-Admin {
    param (
        [string]$taksName
    )

    Write-Host "Administrative privileges are required $taksName. Checking..."
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {

        Write-Host "You need administrative privileges to perform this task. Elevating..."

        try {
            # Restart the script with administrative privileges
            Start-Process -FilePath "powershell.exe" -ArgumentList `
            "-NoProfile -ExecutionPolicy Bypass -File `"$($global:MyInvocation.MyCommand.Path)`" $global:args" `
            -Verb RunAs
        } catch {
            Write-Host "Elevation failed. Exiting in error..."
            exit 1
        }

        Write-Host "Elevation succeeded. Exiting..."
        exit 0
    }
    else {
        Write-Host "Already running as an administrator. Proceeding..."
    }
}

# Constants
$AutoExecName = "setup_windows"

# Entry point
main

# Helps development, do not close the window immediately.
Write-Host "Press Enter to exit.."
Read-Host
