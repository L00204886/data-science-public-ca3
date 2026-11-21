@echo off
setlocal EnableExtensions

pushd "%~dp0" >nul

set "TARGET_SCRIPT=scripts\run_all.R"
if /i "%~1"=="--check" set "TARGET_SCRIPT=scripts\check_packages.R"
if /i "%~1"=="-c" set "TARGET_SCRIPT=scripts\check_packages.R"
if /i "%~1"=="check" set "TARGET_SCRIPT=scripts\check_packages.R"

call :find_rscript
if not defined RSCRIPT (
    echo.
    echo [ERROR] R was not found on this computer.
    echo.
    echo To install R on Windows, choose either option:
    echo   1. Run in PowerShell:  winget install RProject.R
    echo   2. Download from CRAN: https://cran.r-project.org/bin/windows/base/
    echo.
    echo After installing R, run run.bat again. No PATH setup is required.
    echo.
    set "exit_code=1"
    goto :done
)

echo Using Rscript: "%RSCRIPT%"
"%RSCRIPT%" "%TARGET_SCRIPT%"
set "exit_code=%ERRORLEVEL%"

:done
popd >nul

rem Pause only when double-clicked from Windows Explorer (cmd.exe /c ""full\path\run.bat" ")
set "SHOULD_PAUSE=0"
if not defined CI if not defined NO_PAUSE (
    set "CMD_CLEAN=%CMDCMDLINE:"='%"
    if /i "%CMD_CLEAN%"=="%COMSPEC% /c ''%~f0' '" set "SHOULD_PAUSE=1"
)
if "%SHOULD_PAUSE%"=="1" (
    echo.
    if "%exit_code%"=="0" (
        echo Done. Press any key to close this window...
    ) else (
        echo Run failed with exit code %exit_code%. Press any key to close this window...
    )
    pause >nul
)

exit /b %exit_code%

:find_rscript
set "RSCRIPT="

rem 1. Check PATH first
for /f "delims=" %%I in ('where Rscript.exe 2^>nul') do (
    if not defined RSCRIPT set "RSCRIPT=%%I"
)
if defined RSCRIPT exit /b 0

rem 2. Check Windows Registry (current user, then local machine)
for %%K in ("HKCU\SOFTWARE\R-core\R" "HKLM\SOFTWARE\R-core\R") do (
    if not defined RSCRIPT (
        for /f "skip=2 tokens=2,*" %%A in ('reg query %%K /v InstallPath 2^>nul') do (
            call :try_r_home "%%B"
        )
    )
)
if defined RSCRIPT exit /b 0

rem 3. Scan standard Windows installation folders (newest version first)
for %%D in ("%ProgramFiles%\R" "%LOCALAPPDATA%\Programs\R" "%ProgramFiles(x86)%\R") do (
    if not defined RSCRIPT if exist "%%~D" (
        for /f "delims=" %%V in ('dir /b /ad /o-n "%%~D\R-*" 2^>nul') do (
            if not defined RSCRIPT call :try_r_home "%%~D\%%V"
        )
    )
)
exit /b 0

:try_r_home
if exist "%~1\bin\x64\Rscript.exe" (
    set "RSCRIPT=%~1\bin\x64\Rscript.exe"
    exit /b 0
)
if exist "%~1\bin\Rscript.exe" (
    set "RSCRIPT=%~1\bin\Rscript.exe"
    exit /b 0
)
exit /b 0
