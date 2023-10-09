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
    Install-Dependencies -moduleName 'Logging'
    Install-Dependencies -moduleName 'Wsl'
    Start-Logging

    Write-Host "Waiting for user to press Enter"
    Read-Host

    # Install WSL
    Install-WSL2
    Install-WSLDistro
    Wait-User

    # Install Docker
    Install-Docker

    # Checkout repo
    Get-Repo

    # Cleanup tasks (If we reach here, we have done everything we watned succesfully)
    Reset-AutoExec
}

function Get-Repo {
    $homeDir = Invoke-WslCommand -Name $distroName -Command "cd ~ && pwd"
    $repos = "$homeDir/repos"
    $repo = "$repos/$repoDir"

    # Make sure the full path exists
    Invoke-WslCommand -Name "$distroName" -WorkingDirectory "$homeDir" -Command "mkdir -p $repo"

    # Check if the repo already exists
    $isGit = ""
    try {
        $isGit = Invoke-WslCommand -Name "$distroName"  -WorkingDirectory "$repo" `
                -Command "git rev-parse --is-inside-work-tree"
    } catch {
        $isGit = "false"
    }
    if ("true" -eq $isGit) {
        Write-Log -Level 'DEBUG' -Message "Repository {0} is already cloned" -Arguments $repoDir
    } else {
        # Not found, we must clone...
        Write-Log -Level 'INFO' -Message "Cloning repository {0}..." -Arguments $repoDir
        Invoke-WslCommand -Name "$distroName" -WorkingDirectory "$repo" `
                -Command "git clone $repoUrl --branch $repoBranch ."

        # Check again if we have a repo this time
        try {
            $isGit = Invoke-WslCommand -Name "$distroName"  -WorkingDirectory "$repo" `
                    -Command "git rev-parse --is-inside-work-tree"
        } catch {
            $isGit = "false"
        }
        if ("true" -eq $isGit) {
            Write-Log -Level 'INFO' -Message "Repository {0} was cloned succesfully" -Arguments $repoDir
        } else {
            Write-Log -Level 'ERROR' -Message "Failed to clone repository" -Arguments $repoDir
            exit 1
        }
    }
}

function Reset-Path {
    [Environment]::SetEnvironmentVariable("PATH", [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine), [System.EnvironmentVariableTarget]::Process)
}

function Install-Docker {
    $packageName = "Docker.DockerDesktop"
    $doINeedToRestart = $false

    $packageExists = (winget list --accept-source-agreements) -match "$packageName"
    if ($false -eq $packageExists) {
        Write-Log -Level 'INFO' -Message "Installing {0}..." -Arguments $packageName

        # Raise privileges immediately. They will be needed anyway during install and we don't want
        # a new PowerShell session for reboot at the end. We need to stay in context during the whole install
        Assert-Admin "to install Docker"

        winget install --accept-package-agreements --accept-source-agreements -e --id $packageName --Silent

        $packageExists = (winget list --accept-source-agreements) -match "$packageName"
        if ($false -eq $packageExists) {
            Write-Log -Level 'ERROR' -Message "{0} failed to install" -Arguments $packageName
            exit 1
        } else {
            $doINeedToRestart = $true
            Write-Log -Level 'INFO' -Message "{0} installed successfully" -Arguments $packageName
        }
    } else {
        Write-Log -Level 'DEBUG' -Message "{0} is already installed" -Arguments $packageName
    }

    # The PATH will have changed on the OS
    Reset-Path

    try {
        docker --version
    } catch {
        Write-Log -Level 'ERROR' -Message "There is a problem with the installation of docker"
        exit 1
    }

    # Handle the request restart
    if ($true -eq $doINeedToRestart) {
        Write-Log -Level 'INFO' -Message "Docker is now installed. A restart is required"
        Set-AutoExec
        Restart-Host
    }
}

function Wait-User {
    $noUser = "root"

    while ($true) {
        try {
          $global:wslUser = Invoke-WslCommand -Name $distroName -Command "whoami"
        } catch {
          $global:wslUser = $noUser
          Write-Log -Level 'WARNING' -Message "Failure to check for user account on {0}" -Arguments $distroName
        }
        Write-Log -Level 'INFO' -Message "Waiting for user to configure his account on {0}" -Arguments $distroName

        if ($global:wslUser -ne $noUser) {
            break
        }

        Start-Sleep -Seconds 1  # Sleep for 1 second before the next iteration
    }

    Write-Log -Level 'INFO' -Message "User '{0}' has been found" -Arguments $global:wslUser
}

function Install-WSLDistro {
    # Check if the distribution is already installed
    $WslDistribution = Get-WslDistribution $distroName
    if (-not $WslDistribution) {
        Write-Log -Level 'INFO' -Message "{0} is not installed. Installing..." -Arguments $distroName
        wsl --install -d $distroName
        Start-Sleep -Seconds 5

        Write-Log -Level 'INFO' -Message "Waiting for {0} to be ready" -Arguments $distroName

        # Wait for WSL to be installed
        $maxRetries = 300
        $retryInterval = 5
        $currentRetry = 0

        while ($currentRetry -lt $maxRetries) {
            $WslDistribution = Get-WslDistribution $distroName
            if ($null -ne $WslDistribution) {
                $state = $WslDistribution.State
                Write-Log -Level 'DEBUG' -Message "{0} is in state {1}" -Arguments $distroName, $state

                # Check if the state is "Stopped" or "Running"
                if ($state -eq "Stopped" -or $state -eq "Running") {
                    Write-Log -Level 'INFO' -Message "We are done waiting for {0} to be ready" -Arguments $distroName
                    break
                }
            }

            # Increment the retry count and wait for the specified interval
            $currentRetry++
            Start-Sleep -Seconds $retryInterval
        }

        $WslDistribution = Get-WslDistribution $distroName
        if ($null -eq $WslDistribution) {
            Write-Log -Level 'ERROR' -Message "Failed to install {0}" -Arguments $distroName
            exit 1
        }
    } else {
        Write-Log -Level 'DEBUG' -Message "{0} is installed" -Arguments $distroName
    }

    # Check if it's runnnig WSL 2
    if ($WslDistribution.Version -ne 2) {
        Write-Log -Level 'WARNING' -Message "{0} is running WSL version {1}. Attempting an upgrade..." `
        -Arguments $distroName, $WslDistribution.Version

        Set-WslDistribution $distroName -Version 2

        $WslDistribution = Get-WslDistribution $distroName
        if ($WslDistribution.Version -ne 2) {
            Write-Log -Level 'ERROR' -Message "Failed to upgrade {0}" -Arguments $distroName
            exit 1
        }
    } else {
        Write-Log -Level 'DEBUG' -Message "{0} is running WSL version {1}" `
        -Arguments $distroName, $WslDistribution.Version
    }

    # Check if Default
    if ($true -ne $WslDistribution.Default) {
        Write-Log -Level 'WARNING' -Message "{0} is NOT the default distro. Attemptiong to change that..." `
        -Arguments $distroName

        Set-WslDistribution $distroName -Default

        $WslDistribution = Get-WslDistribution $distroName
        if ($true -ne $WslDistribution.Default) {
            Write-Log -Level 'ERROR' -Message "Failed to set {0} as default." -Arguments $distroName
            exit 1
        }
    } else {
        Write-Log -Level 'DEBUG' -Message "{0} is the default distro" -Arguments $distroName
    }
}

function Install-WSL2 {
    Write-Log -Level 'INFO' -Message "Check for WSL..."

    try {
        $wslStatus = wsl --status --quiet 2>&1
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

function Install-NuGetProvider {
    # Check if NuGet provider is installed
    $providerInstalled = Get-PackageProvider | Where-Object { $_.Name -eq 'NuGet' }

    if ($null -eq $providerInstalled) {
        Write-Host "NuGet provider is not installed. Installing..."
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
        Write-Host "Check if NuGet is property installed..."
        $providerInstalled = Get-PackageProvider | Where-Object { $_.Name -eq 'NuGet' }
        if ($null -eq $providerInstalled) {
            Write-Host "NuGet provider failed to install."
            exit 1
        } else {
            Write-Host "NuGet provider installed successfully."
        }
    } else {
        Write-Host "NuGet provider is already installed."
    }
}

function Install-Dependencies {
    param (
        [string]$moduleName
    )

    # Check if the Log4Posh module is installed
    $moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }
    if ($null -eq $moduleInstalled) {
        # First, we will need NuGet
        Install-NuGetProvider

        Write-Host "$moduleName module is not installed. Installing..."
        # Install the Log4Posh module from the OttoMatt repository
        Install-Module -Name $moduleName -Scope CurrentUser -Force
        Write-Host "Check if $moduleName module is property installed..."
        $moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }
        if ($null -eq $moduleInstalled) {
            Write-Host "Failed to install $moduleName module."
            exit 1
        } else {
            Write-Host "$moduleName module installed successfully."
        }
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

#############
# Constants #
#############
$AutoExecName = "setup_windows"
$distroName = "Ubuntu-22.04"
$wslUser = $null
$repoDir = "Horizon"
$repoUrl = "https://github.com/homeinfra/Horizon.git"
$repoBranch = "main"

##################
# Determine ROOT #
##################
$ROOT = Get-Item -Path $(Join-Path -Path $PSScriptRoot -ChildPath "..\..")
# If we do NOT find a .gitignore file, we assume the file is alone.
# This is not the full git repository (exported or not). Set ROOT at our level instead.
if (-Not (Test-Path "$ROOT\.gitignore")) {
    $ROOT = $PSScriptRoot
}

###############
# Entry Point #
###############
main

Write-Log -Level 'INFO' -Message "Script execution has completed succesfully"
Wait-Logging

# Helps development, do not close the window immediately.
Write-Host "Press Enter to exit.."
Read-Host
