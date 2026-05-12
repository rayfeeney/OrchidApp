@echo off
setlocal

set "APP_NAME=OrchidApp"
set "APP_EXE=OrchidApp.Launcher.exe"

set "APP_DIR=%~dp0"
set "APP_PATH=%APP_DIR%%APP_EXE%"

if not exist "%APP_PATH%" (
    echo.
    echo ERROR: Could not find %APP_EXE%
    echo.
    echo This file must be in the same folder as %APP_EXE%.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "$appName = '%APP_NAME%';" ^
    "$appPath = '%APP_PATH%';" ^
    "$appDir = '%APP_DIR%';" ^
    "$shell = New-Object -ComObject WScript.Shell;" ^
    "$desktopPath = [Environment]::GetFolderPath('Desktop');" ^
    "$desktopShortcutPath = Join-Path $desktopPath ($appName + '.lnk');" ^
    "$desktopShortcut = $shell.CreateShortcut($desktopShortcutPath);" ^
    "$desktopShortcut.TargetPath = $appPath;" ^
    "$desktopShortcut.WorkingDirectory = $appDir;" ^
    "$desktopShortcut.IconLocation = $appPath + ',0';" ^
    "$desktopShortcut.Description = 'Start OrchidApp';" ^
    "$desktopShortcut.Save();" ^
    "$startMenuProgramsPath = [Environment]::GetFolderPath('Programs');" ^
    "$startMenuFolder = Join-Path $startMenuProgramsPath $appName;" ^
    "if (-not (Test-Path $startMenuFolder)) { New-Item -ItemType Directory -Path $startMenuFolder | Out-Null }" ^
    "$startMenuShortcutPath = Join-Path $startMenuFolder ($appName + '.lnk');" ^
    "$startMenuShortcut = $shell.CreateShortcut($startMenuShortcutPath);" ^
    "$startMenuShortcut.TargetPath = $appPath;" ^
    "$startMenuShortcut.WorkingDirectory = $appDir;" ^
    "$startMenuShortcut.IconLocation = $appPath + ',0';" ^
    "$startMenuShortcut.Description = 'Start OrchidApp';" ^
    "$startMenuShortcut.Save();"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to create OrchidApp shortcuts.
    echo.
    pause
    exit /b 1
)

echo.
echo OrchidApp shortcuts created successfully.
echo.
echo Desktop shortcut:
echo %USERPROFILE%\Desktop\OrchidApp.lnk
echo.
echo Start Menu shortcut:
echo OrchidApp
echo.
echo Keep this OrchidApp folder in place.
echo If you move or rename it later, run Create-Shortcut.cmd again.
echo.
pause

endlocal