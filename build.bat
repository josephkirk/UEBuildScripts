@echo off
setlocal enabledelayedexpansion

REM Get the directory of this batch file
set "SCRIPT_DIR=%~dp0"

REM Define default values
set "BUILD_TARGET=Editor"
set "CONFIG=Development"
set "CLEAN="
set "FAST="

REM Parse command line arguments
:arg_loop
if "%1"=="" goto continue
if "%1"=="-target" (
    set "BUILD_TARGET=%2"
    shift
    shift
    goto arg_loop
)
if "%1"=="-config" (
    set "CONFIG=%2"
    shift
    shift
    goto arg_loop
)
if "%1"=="-clean" (
    set "CLEAN=-Clean"
    shift
    goto arg_loop
)
if "%1"=="-fast" (
    set "FAST=-Fast"
    shift
    goto arg_loop
)
shift
goto arg_loop

:continue
REM Auto-detect UE path from registry
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\EpicGames\Unreal Engine" /v "InstalledDirectory"') do set "UE_ROOT=%%b"

REM Auto-detect .uproject file in parent directory
for /f "tokens=*" %%a in ('dir /b /s "..\*.uproject" 2^>nul') do set "PROJECT_PATH=%%a"

if "%PROJECT_PATH%"=="" (
    echo Error: No .uproject file found in parent directory.
    exit /b 1
)

if "%UE_ROOT%"=="" (
    echo Error: Unreal Engine installation not found.
    exit /b 1
)

REM Execute PowerShell script with execution policy bypass
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command ^
    "& '%SCRIPT_DIR%Build-Wrapper.ps1' -Target '%BUILD_TARGET%' -ProjectPath '%PROJECT_PATH%' -EnginePath '%UE_ROOT%' -Config '%CONFIG%' %CLEAN% %FAST%"

if %ERRORLEVEL% NEQ 0 (
    echo Build failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

exit /b 0