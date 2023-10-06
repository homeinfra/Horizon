:: CMD
:: SPDX-License-Identifier: MIT
::
:: Entry point for setup-windows.ps1
:: This is a helper to make sure the scripts can be launched successfully on a fresh Winodws install
:: when the execution policy is restricted

@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0\setup-windows.ps1" %*
