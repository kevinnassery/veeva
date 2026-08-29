@echo off
REM VERSION 2026.08.29-21
setlocal

REM ============================================================================
REM  Clear the decks before a refresh.
REM
REM  Sets aside every .ps1 and .bat in this folder, so that running refresh.bat
REM  afterwards brings back exactly the current set - and anything that does NOT
REM  come back was yesterday's, and is gone from view.
REM
REM  NOTHING IS DELETED. Files are MOVED into old-<timestamp>\ in this folder.
REM  Delete that folder yourself once you are happy. A cleanup that destroyed the
REM  wrong file in the middle of a migration would be a bad trade for tidiness.
REM
REM  Never touched:
REM     transfer.ini, documents.ini, attachments.ini - your settings
REM     map.csv, sourcedocids.txt                    - your inputs
REM     session.txt                                  - your cached login
REM     every folder, including all results and logs
REM     refresh.bat and this file
REM
REM  Run this, then refresh.bat.
REM ============================================================================

set "D=%~dp0"

REM  A run in progress is reading these files right now.
set "BUSY="
for %%L in ("%D%.run-*.lock") do call :checklock "%%L"
if defined BUSY (
  echo.
  echo   REFUSING - a run is still going. Let it finish first.
  goto :end
)

REM  Timestamp without relying on locale-specific date formatting.
for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%T"
if not defined STAMP set "STAMP=old"
set "OLD=%D%old-%STAMP%"

set "KEEP=refresh.bat starting-cleanup.bat"
set "MOVED=0"

echo Setting aside scripts into old-%STAMP%\
echo.

for %%F in ("%D%*.ps1" "%D%*.bat") do call :consider "%%~nxF"

echo.
if "%MOVED%"=="0" (
  echo   Nothing to set aside - this folder is already clean.
  if exist "%OLD%" rd "%OLD%" 2>nul
) else (
  echo   %MOVED% file^(s^) moved to old-%STAMP%\
  echo.
  echo   Now run:  refresh.bat
  echo   Anything that does not come back was not part of the current set.
)
goto :end

:checklock
REM  A lock only means something if its process is still alive. A crash leaves the file
REM  behind, and making someone delete it by hand to get on with their day is a bad
REM  trade for a guard that is supposed to protect them.
set "LPID="
for /f "tokens=2 delims==" %%P in ('findstr /b /c:"pid=" "%~1"') do set "LPID=%%P"
if not defined LPID goto :stalelock
tasklist /FI "PID eq %LPID%" | findstr /i "powershell.exe" >nul
if errorlevel 1 goto :stalelock
set "BUSY=1"
echo     %~nx1  - pid %LPID% is still running
exit /b
:stalelock
echo   cleared stale lock %~nx1 ^(pid %LPID% is not running^)
del /q "%~1"
exit /b

:consider
echo %KEEP% | findstr /i /c:"%~1" >nul
if not errorlevel 1 exit /b
if not exist "%OLD%" mkdir "%OLD%"
move /y "%D%%~1" "%OLD%" >nul
if errorlevel 1 (
  echo   COULD NOT MOVE  %~1  ^(in use?^)
) else (
  echo   set aside       %~1
  set /a MOVED+=1
)
exit /b

:end
echo.
pause
endlocal
