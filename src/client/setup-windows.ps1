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
    # Initialization
    Install-Dependencies
    Start-Logging

    Install-WSL2

    # Test registerting of the scheduled task
    # Set-AutoExec

    # Restart-Host

    # Cleanup tasks (If we reach here, we have done everything we watned succesfully)
    Reset-AutoExec
}

function Install-WSL2 {
    Write-Log -Level 'INFO' -Message "Check for WSL..."

    try {
        # wsl --list --quiet 2>&1
        $wslStatus = wsl --status
        if ($null -eq $wslStatus) {
            Write-Log -Level 'WARNING' -Message "WSL is not installed or not running."
        } else {
            Write-Log -Level 'INFO' -Message "WSL is already installed and running."
            
            # Set WSL 2 as the default version
            wsl --set-default-version 2
            
            return
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Failure to check for WSL status."
        exit 1
    }

    Assert-Admin "to change windows optional features"

    $doINeedToRestart = $false

    # Check for depedency
    $status = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -eq "VirtualMachinePlatform"
    if ($status.State -eq "Enabled") {
        Write-Log -Level 'INFO' -Message "VirtualMachinePlatform is installed."
    } else {
        Write-Log -Level 'WARNING' -Message "Virtual Machine Platform is NOT installed."

        $ProgPref = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $results = Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform `
                    -Online -NoRestart -WarningAction SilentlyContinue
        $ProgressPreference = $ProgPref
        if ($results.RestartNeeded -eq $true) {
            Write-Log -Level 'INFO' -Message "VirtualMachinePlatform requests a restart."
            $doINeedToRestart = $true
        }
    }

    $status = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -eq "Microsoft-Windows-Subsystem-Linux"
    if ($status.State -eq "Enabled") {
        Write-Log -Level 'INFO' -Message "Microsoft-Windows-Subsystem-Linux is installed."
    } else {
        Write-Log -Level 'WARNING' -Message "Microsoft-Windows-Subsystem-Linux is NOT installed."

        $ProgPref = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $results = Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux `
                    -Online -NoRestart -WarningAction SilentlyContinue
        $ProgressPreference = $ProgPref
        if ($results.RestartNeeded -eq $true) {
            Write-Log -Level 'INFO' -Message "Microsoft-Windows-Subsystem-Linux requests a restart."
            $doINeedToRestart = $true
        }
    }

    # Handle the request restart
    if ($true -eq $doINeedToRestart) {
        Write-Log -Level 'INFO' -Message "WSL is now installed. Restart is required"
        Set-AutoExec
        Restart-Host
    } else {
        Write-Log -Level 'INFO' -Message "WSL is now installed. Restart is NOT required"
    }

    Write-Host "Press Enter to continue.."
    Read-Host
}

function Restart-Host {
    # This function does NOT require privilege elevation
    Write-Log -Level 'INFO' -Message "Ask user if it's ok to restart the computer"

    Add-Type -AssemblyName PresentationCore,PresentationFramework
    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    $MessageIcon = [System.Windows.MessageBoxImage]::Question
    # Create a TextBlock with line breaks
    $MessageBody = "Is it OK to restart the computer now?" + [Environment]::NewLine + [Environment]::NewLine `
                 + "Regardless of your answer, this script will resume on the next logon to finish the configuration." `
                 + " If you answer 'No', simply restart your computer manually when you are ready to proceed with " `
                 + "the next configuration steps."
    $MessageTitle = "Restart confirmation"
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

    if ($Result -eq [System.Windows.MessageBoxResult]::Yes) {
        Write-Log -Level 'INFO' -Message "User said it's ok to restart"
    } else {
        Write-Log -Level 'ERROR' -Message "User refused the restart. Exiting..."
        exit 1
    }

    # Do we need privileges for this?
    Restart-Computer -Force
}

function Set-AutoExec {
    # Check if the scheduled task already exists
    $existingTask = Get-ScheduledTask -TaskName $AutoExecName -ErrorAction SilentlyContinue
    if (-not $existingTask) {
        Assert-Admin "to create scheduled task '$AutoExecName'"
        try {
            # Define the action to run your script on startup
            $Action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$($global:MyInvocation.MyCommand.Path)`""

            # Define the trigger for the task (at startup)
            $Trigger = New-ScheduledTaskTrigger -AtLogOn

            # Register the scheduled task
            Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName $AutoExecName -User $env:USERNAME -Force
        } catch {
            Write-Log -Level 'ERROR'-Message "Failed to create '{0}'" -Arguments $AutoExecName
            exit 1
        }

        $existingTask = Get-ScheduledTask -TaskName $AutoExecName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Log -Level 'INFO' -Message "Scheduled task '{0}' created successfully" -Arguments $AutoExecName
        } else {
            Write-Log -Level 'ERROR' -Message "Scheduled task '{0}' could not be created" -Arguments $AutoExecName
            exit 1
        }
    } else {
        Write-Log -Level 'INFO' -Message "Scheduled task '{0}' already exists" -Arguments $AutoExecName
    }
}    

# Remove the scheduled task we've created to run ourselves again after restart
function Reset-AutoExec {
    # Check if the scheduled task already exists
    $existingTask = Get-ScheduledTask -TaskName $AutoExecName -ErrorAction SilentlyContinue
    if ($existingTask) {
        # Remove it
        Write-Log -Level 'INFO' -Message "Scheduled task '{0}' exists. Removing it..." -Arguments $AutoExecName
        Assert-Admin "to remove scheduled task '$AutoExecName'"

        Unregister-ScheduledTask -TaskName $AutoExecName -Confirm:$false
        $existingTask = Get-ScheduledTask -TaskName $AutoExecName -ErrorAction SilentlyContinue
        if (-not $existingTask) {
            Write-Log -Level 'INFO' -Message "Scheduled task '{0}' removed" -Arguments $AutoExecName
        } else {
            Write-Log -Level 'ERROR' -Message "Scheduled task '{0}' could not be removed" -Arguments $AutoExecName
            exit 1
        }
    }
}

# Ensure we are running with privileges. If not, elevate them by calling our own script recursively.
function Assert-Admin {
    param (
        [string]$taksName
    )

    Write-Log -Level 'DEBUG' -Message "Administrative privileges are required {0}. Checking..." -Arguments $taksName
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {

        Write-Log -Level 'WARNING' -Message "You need administrative privileges to perform this task. Elevating..."
        try {
            # Restart the script with administrative privileges
            Start-Process -FilePath "powershell.exe" -ArgumentList `
            "-NoProfile -ExecutionPolicy Bypass -File `"$($global:MyInvocation.MyCommand.Path)`" $global:args" `
            -Verb RunAs
        } catch {
            Write-Log -Level 'ERROR' -Message "Elevation failed. Exiting in error..."
            exit 1
        }

        Write-Log -Level 'INFO' -Message "Elevation succeeded. Exiting..."
        exit 0
    }
    else {
        Write-Log -Level 'DEBUG' -Message "Already running as an administrator. Proceeding..."
    }
}

function Install-Dependencies {
    $moduleName = 'Logging'

    # Check if the Log4Posh module is installed
    $moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }

    if ($null -eq $moduleInstalled) {
        Write-Host "$moduleName module is not installed. Installing..."

        # Install the Log4Posh module from the OttoMatt repository
        Install-Module -Name $moduleName -Scope CurrentUser -Force

        Write-Host "$moduleName module installed successfully."
    } else {
        Write-Host "$moduleName module is already installed."
    }
}

function Start-Logging {
    # Import the module
    $moduleName = 'Logging'
    Import-Module -Name  $moduleName

    # Path where logs should be stored
    $logDirectory = Join-Path -Path $ROOT -ChildPath "\.log"

    try {
        # Ensure the log directory exists
        if (-not (Test-Path -Path $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory
        }

        # Generate the log filename
        $filename = Get-Date -Format 'yyyy-MM-dd_HHmmss'
        $filename = [System.IO.Path]::GetFileNameWithoutExtension($global:MyInvocation.MyCommand.Name) + "_" + $filename
        $filename = $filename + ".log"

        Add-LoggingTarget -Name File -Configuration @{
            Path            = "$logDirectory\$filename"
            PrintBody       = $true
            PrintException  = $true 
            Append          = $true
            Encoding        = 'utf8'
            Format          = "%{timestamp:+yyyy-MM-dd HH:mm:ss} [%{level:-7}] %{message}"
        }
        
        Add-LoggingTarget -Name Console -Configuration @{
            Format          = "%{timestamp:+yyyy-MM-dd HH:mm:ss} [%{level:-7}] %{message}"
            PrintException  = $true
        }
    } catch {
        Write-Error "Error: $($_.Exception.Message)"
        exit 1
    }

    # Default Level
    Set-LoggingDefaultLevel -Level DEBUG

    # Log the first message
    Write-Log -Level 'INFO' -Message "Logging is configured and started"
}

# Constants
$ROOT = Get-Item -Path $(Join-Path -Path $PSScriptRoot -ChildPath "..\..")
$AutoExecName = "setup_windows"

# Entry point
main

# Helps development, do not close the window immediately.
Write-Log -Level 'INFO' -Message "Script execution has completed succesfully"
Wait-Logging
Write-Host "Press Enter to exit.."
Read-Host
