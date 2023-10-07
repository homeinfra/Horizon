:: CMD
:: SPDX-License-Identifier: MIT
::
:: Entry point for setup-windows.ps1
:: This is a helper to make sure the scripts can be launched successfully on a fresh Winodws install
:: when the execution policy is restricted

@echo off
setlocal enabledelayedexpansion

:: This is the file to download to setup the development environment up to a repo checked out in WSL
set scriptUrl="https://github.com/homeinfra/Horizon/blob/feature/docker/src/client/setup-windows.ps1"

:: This is the filename
for %%i in (%scriptURL%) do set "scriptName=%%~nxi"

:: This is the work directory
set pwd=%~dp0

:: If we don't have the file, download it!
if not exist "%pwd%\%scriptName%" (
    :: Use powershel for the download
    powershell.exe -ExecutionPolicy Bypass -command "(New-Object System.Net.WebClient).DownloadFile('%scriptURL%', '%pwd%\%scriptName%')"

    :: Check the download result
    if %errorlevel% neq 0 (
        echo Error: Failed to download %scriptName%.
        exit /b 1
    )
)

:: Execute the script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0\setup-windows.ps1" %*

endlocal