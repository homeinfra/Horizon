# Powershell
# SPDX-License-Identifier: MIT
#
# This script is used to set up the local client environment on Windows. It configures the following:
# 1. WSL2 (Windows Subsystem for Linux)
# 2. Docker Desktop
# 3. Under WSL environment, checkout this repo
#
# Usage:
# It is recommended to run C:\> setup-windows.bat
#
# Todo:
# - Generalize this script by making the repo to be checked out a parameter/argument
# - Turn this script (and accompanying .bat file) into a Powershell module in it's own git repo
#
# NOTE: Designed to run on a fresh Windows 10 install or later

# Main function where the real execution begins
function main {
  # Initialization
  Install-Dependencies -moduleName 'Logging'
  Install-Dependencies -moduleName 'Wsl'
  Start-Logging

  # Install WSL
  Install-WSL2
  Install-WSLDistro
  Wait-User

  # Install Docker
  Install-Docker

  # Checkout repo
  Get-Repo

  # Cleanup tasks (If we reach here, we have done everything we wanted succesfully)
  Reset-AutoExec
}

# Checkout the repo defined in the 'constants' section
function Get-Repo {
  # Find out the user's 'home' directory inside the Ubuntu distro
  $homeDir = Invoke-WslCommand -Name $distroName -Command "cd ~ && pwd"

  # Get directory name from URL
  $repoDir = [System.IO.Path]::GetFileNameWithoutExtension($repoUrl.Split("/")[-1])

  # Directory where the git repo will be cloned
  $repos = "$homeDir/repos"  # All repositorys are cloned inside "~/repos"
  $repo = "$repos/$repoDir"

  # Make sure the full path exists (mkdir directories)
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

# Reset the PATH environment variable in the current process using the one from the OS.
# This is useful so newly installed programs that add themselves to PATH are working within the current process
# that instaleld them
function Reset-Path {
  [Environment]::SetEnvironmentVariable("PATH", [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine), [System.EnvironmentVariableTarget]::Process)
}

# Install DockerDesktop
function Install-Docker {
  $packageName = "Docker.DockerDesktop"
  $doINeedToRestart = $false

  # Check if package is already installed
  $packageExists = (winget list --accept-source-agreements) -match "$packageName"
  if ($false -eq $packageExists) {
    Write-Log -Level 'INFO' -Message "Installing {0}..." -Arguments $packageName

    # Raise privileges immediately. They will be needed anyway during install and we don't want
    # a new PowerShell session for reboot at the end. We need to stay in context during the whole install
    Assert-Admin "to install Docker"

    winget install --accept-package-agreements --accept-source-agreements -e --id $packageName --Silent

    # Perform the same check to make sure Docker properly installed
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

  # The PATH will have changed on the OS. Reload it so the next check works
  Reset-Path

  # Try calling Docker, to make sure it really installed
  try {
    docker --version
  } catch {
    Write-Log -Level 'ERROR' -Message "There is a problem with the installation of docker"
    exit 1
  }

  # Handle the request restart
  if ($true -eq $doINeedToRestart) {
    Write-Log -Level 'INFO' -Message "Package {0} is now installed. A restart is required" -Arguments $packageName
    Set-AutoExec
    Restart-Host
  }
}

# This function waits until the WSL Distro has been configured with a local user.
# This waits for manual internvention to be over, providing an account username and password.
# A console session will have popped-up automatically at the end of Ubuntu install,
# prompting the user for account details.
function Wait-User {
  $noUser = "root" # As long as the user is not created, the default one will be 'root'

  # Wait indefinitely for a new user to be created
  while ($true) {
    # It was observed in a few occastion that calling a command on the container would cause an exception.
    # Perhaps a race-condition? Just catch the exception and try again if it happens.
    try {
      $global:wslUser = Invoke-WslCommand -Name $distroName -Command "whoami" # Retrieve the current default user
    } catch {
      $global:wslUser = $noUser # Reset to default on exception
      Write-Log -Level 'WARNING' -Message "Failure to check for user account on {0}" -Arguments $distroName
    }
    Write-Log -Level 'INFO' -Message "Waiting for user to configure his account on {0}" -Arguments $distroName

    # If returned user is different than 'root' for 'whoami', then the user was created successfully.
    # Break the infinite loop
    if ($global:wslUser -ne $noUser) {
      break
    }

    Start-Sleep -Seconds 1  # Sleep for 1 second before the next iteration
  }

  Write-Log -Level 'INFO' -Message "User '{0}' has been found" -Arguments $global:wslUser
}

# This function installs Ubuntu-22.04 on WSL2, make sure the proper backend version is running, and that it is the
# default distribution
function Install-WSLDistro {

  # Check if the distribution is already installed
  $WslDistribution = Get-WslDistribution $distroName
  if (-not $WslDistribution) {
      Write-Log -Level 'INFO' -Message "{0} is not installed. Installing..." -Arguments $distroName
      wsl --install -d $distroName

      # Just a little buffer to avoid possible race condition between distro install and bootiung up.
      Start-Sleep -Seconds 5
      Write-Log -Level 'INFO' -Message "Waiting for {0} to be ready" -Arguments $distroName

      # Wait for WSL to be installed
      $maxRetries = 300 # 300 * 5s = 25 minutes. Timeout waiting for Ubuntu-22.04 to be in a stable state
      $retryInterval = 5
      $currentRetry = 0

      while ($currentRetry -lt $maxRetries) {
        # Get attirbutes of Distro
        $WslDistribution = Get-WslDistribution $distroName
        if ($null -ne $WslDistribution) {
          $state = $WslDistribution.State
          Write-Log -Level 'DEBUG' -Message "{0} is in state {1}" -Arguments $distroName, $state

          # Check if the state is "Stopped" or "Running"
          if ($state -eq "Stopped" -or $state -eq "Running") {
            Write-Log -Level 'INFO' -Message "We are done waiting for {0} to be ready" -Arguments $distroName
            break # WSL distro in a stable state. Exit loop.
          }
        }

        # Increment the retry count and wait for the specified interval
        $currentRetry++
        Start-Sleep -Seconds $retryInterval
      }

      # Just a last confirmation that the distro is installed
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

# Install Windows Feature: Windows-Subsystem-For-Linux (WSL)
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

  # Before doing anything, make sure we already are an admin so the following actions are atomic prior to restart
  # and not restarted mid-way in a new Powershell session.
  Assert-Admin "to change windows optional features"

  $doINeedToRestart = $false

  # Check for depedency VirtualMachinePlatform
  $status = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -eq "VirtualMachinePlatform"
  if ($status.State -eq "Enabled") {
    Write-Log -Level 'INFO' -Message "VirtualMachinePlatform is installed."
  } else {
    Write-Log -Level 'WARNING' -Message "Virtual Machine Platform is NOT installed."

    $ProgPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue' # Hide progress bar
    $results = Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform `
                -Online -NoRestart -WarningAction SilentlyContinue
    $ProgressPreference = $ProgPref
    if ($results.RestartNeeded -eq $true) {
      Write-Log -Level 'INFO' -Message "VirtualMachinePlatform requests a restart."
      $doINeedToRestart = $true
    }
  }

  # Check for feature: WSL
  $status = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -eq "Microsoft-Windows-Subsystem-Linux"
  if ($status.State -eq "Enabled") {
    Write-Log -Level 'INFO' -Message "Microsoft-Windows-Subsystem-Linux is installed."
  } else {
    Write-Log -Level 'WARNING' -Message "Microsoft-Windows-Subsystem-Linux is NOT installed."

    $ProgPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue' # Hide progress bar
    $results = Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux `
                -Online -NoRestart -WarningAction SilentlyContinue
    $ProgressPreference = $ProgPref
    if ($results.RestartNeeded -eq $true) {
      Write-Log -Level 'INFO' -Message "Microsoft-Windows-Subsystem-Linux requests a restart."
      $doINeedToRestart = $true
    }
  }

  # Handle the request for restart
  if ($true -eq $doINeedToRestart) {
    Write-Log -Level 'INFO' -Message "WSL is now installed. Restart is required"
    Set-AutoExec
    Restart-Host
  } else {
    Write-Log -Level 'INFO' -Message "WSL is now installed. Restart is NOT required"
  }
}

# Performs a restart of the computer (asking the user first if it's OK to do so now)
function Restart-Host {
  # This function does NOT require privilege elevation
  Write-Log -Level 'INFO' -Message "Ask user if it's ok to restart the computer"

  # Ask user if it's OK to reboot using a Yes/No MessageBox
  Add-Type -AssemblyName PresentationCore,PresentationFramework
  $ButtonType = [System.Windows.MessageBoxButton]::YesNo
  $MessageIcon = [System.Windows.MessageBoxImage]::Question
  # Create a TextBlock with line breaks
  $MessageBody = "Is it OK to restart the computer now?" + [Environment]::NewLine + [Environment]::NewLine `
                + "Regardless of your answer, this script will resume on the next logon to finish the configuration. " `
                + "If you answer 'No', simply restart your computer manually when you are ready to proceed with " `
                + "the next configuration steps."
  $MessageTitle = "Restart confirmation"
  $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

  if ($Result -eq [System.Windows.MessageBoxResult]::Yes) {
    Write-Log -Level 'INFO' -Message "User said it's ok to restart"
  } else {
    Write-Log -Level 'ERROR' -Message "User refused the restart. Exiting..."
    exit 1
  }

  # Perform the restart
  Restart-Computer -Force
}

# Configure this script to run automatically at LogOn (useful before restarting the computer)
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

    # Confirm the task really was created successfully
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

# Remove the scheduled task we've created to run ourselves again after restart. It is no longer needed...
function Reset-AutoExec {
  # Check if the scheduled task already exists
  $existingTask = Get-ScheduledTask -TaskName $AutoExecName -ErrorAction SilentlyContinue
  if ($existingTask) {
    # Remove it
    Write-Log -Level 'INFO' -Message "Scheduled task '{0}' exists. Removing it..." -Arguments $AutoExecName
    Assert-Admin "to remove scheduled task '$AutoExecName'"

    Unregister-ScheduledTask -TaskName $AutoExecName -Confirm:$false

    # Confirm the task no longer exists
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

  # First check if we are already running as an admin or not
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

# In order to install some packages using Install-Module, we need NuGet first
function Install-NuGetProvider {
  # Check if NuGet provider is installed
  $providerInstalled = Get-PackageProvider | Where-Object { $_.Name -eq 'NuGet' }
  if ($null -eq $providerInstalled) {
    Write-Host "NuGet provider is not installed. Installing..."
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser

    # Check again to make sure the provider really installed
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

# Install dependency modules reuiqred by this script (Logging and Wsl)
function Install-Dependencies {
  param (
    [string]$moduleName
  )

  # Check if the module is installed
  $moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }
  if ($null -eq $moduleInstalled) {
    # First, we will need NuGet
    Install-NuGetProvider

    Write-Host "$moduleName module is not installed. Installing..."
    # Install the module
    Install-Module -Name $moduleName -Scope CurrentUser -Force

    # Check for the module again
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

# Configure the logger for the rest of this script's execution
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

# Ending log, and make sure everything is flushed before exiting
Write-Log -Level 'INFO' -Message "Script execution has completed succesfully"
Wait-Logging

# Pause the script here before closing, so the user can review what happened
Write-Host "Press Enter to exit.."
Read-Host
