@echo off
REM VERSION 2026.08.27-13
setlocal

REM ============================================================================
REM  Pull the latest scripts from GitHub, overwriting the copies in this folder.
REM
REM  To get THIS file in the first place:
REM
REM  curl.exe -sLo refresh.bat https://raw.githubusercontent.com/kevinnassery/veeva/main/refresh.bat
REM
REM  Overwritten every time: the .ps1 and .bat scripts, README.md
REM
REM  Downloads are pinned to a commit SHA. raw.githubusercontent.com caches the
REM  branch URL for five minutes and ignores no-cache, so pulling from /main can
REM  hand back the PREVIOUS version of a file - which looks exactly like a fix
REM  that did not work. A SHA-pinned URL is immutable and always current.
REM  Never touched:          documents.ini, transfer.ini, sourcedocids.txt, session.txt,
REM                          anything in OutputRoot
REM
REM  documents.ini is yours. If you ever want a fresh default copy, rename the one
REM  you have out of the way and fetch it by hand:
REM
REM  curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/document-transfer/documents.ini
REM ============================================================================

set "REPO=kevinnassery/veeva"
set "D=%~dp0"

REM One API call for the head commit. This endpoint returns the bare SHA and is
REM not behind the five-minute raw cache.
set "SHA="
for /f %%S in ('curl.exe -s -H "Accept: application/vnd.github.sha" https://api.github.com/repos/%REPO%/commits/main') do set "SHA=%%S"

echo %SHA%| findstr /r /c:"^[0-9a-f][0-9a-f]*$" >nul
if errorlevel 1 (
  echo   WARNING: could not read the head commit - falling back to the main branch.
  echo   Files may be up to five minutes out of date. Check the versions below.
  set "B=https://raw.githubusercontent.com/%REPO%/main"
) else (
  set "B=https://raw.githubusercontent.com/%REPO%/%SHA%"
  echo Commit : %SHA%
)

REM  A run in progress reads its script file from this folder, and the parallel
REM  supervisor launches each worker from it - so replacing files mid-run means new
REM  workers running different code from the process that started them. The scripts
REM  drop a .run-*.lock here while they work.
set "BUSY="
for %%L in ("%D%.run-*.lock") do set "BUSY=1"
if defined BUSY (
  if /i not "%~1"=="-force" (
    echo   REFUSING TO REFRESH - a run looks active:
    echo.
    for %%L in ("%D%.run-*.lock") do (
      echo     %%~nxL
      type "%%L" 2^>nul
      echo.
    )
    echo   Let it finish, or if that run is already over the lock is stale -
    echo   delete the .run-*.lock file, or re-run: refresh.bat -force
    goto :end
  )
  echo   -force given: refreshing over an apparently active run.
  echo.
)

REM  Files from an earlier layout that nothing loads any more. Left in place they are
REM  just confusing - two scripts that look like they do the same job, one of them dead.
call :retire Transfer-VaultAttachments.ps1

echo Refreshing from %B%
echo.

call :get document-transfer/login.bat                     login.bat
call :get document-transfer/Get-VaultSession.ps1          Get-VaultSession.ps1
call :get document-transfer/probe.bat                     probe.bat
call :get document-transfer/Probe-Vault.ps1               Probe-Vault.ps1
call :get document-transfer/transfer.bat                  transfer.bat
call :get document-transfer/Transfer-VaultDocuments.ps1   Transfer-VaultDocuments.ps1
call :get attachments/attachments.bat                     attachments.bat
call :get attachments/Sync-VaultAttachments.ps1           Sync-VaultAttachments.ps1
call :get starting-cleanup.bat                            starting-cleanup.bat
call :get refresh.bat                                     refresh.bat
call :get README.md                                       README.md

if not exist "%D%attachments.ini" (
  echo.
  echo   NOTE: no attachments.ini here. Fetch one with:
  echo         curl.exe -sLO %B%/attachments/attachments.ini
)
if not exist "%D%transfer.ini" (
  echo.
  echo   NOTE: no transfer.ini here. Fetch one with:
  echo         curl.exe -sLO %B%/document-transfer/transfer.ini
)

echo.
if defined SKEW (
  echo   WARNING: the files here are NOT all the same version. A download probably
  echo   failed above. Run refresh.bat again before running anything else - a mixed
  echo   set is worse than an old one.
) else (
  if defined FIRSTVER echo All files at version %FIRSTVER%.
)

echo.
echo Done.
goto :end

REM  %1 = path in the repo, %2 = file name to write here. The repo groups scripts
REM  into folders; this folder stays flat.
:get
curl.exe -sfL -o "%D%%~2" "%B%/%~1"
if errorlevel 1 (echo   FAILED    %~2 & set "SKEW=1" & exit /b)
set "VER=?"
for /f "tokens=2 delims='" %%V in ('findstr /b /c:"$ScriptVersion = " "%D%%~2" 2^>nul') do set "VER=%%V"
for /f "tokens=3" %%V in ('findstr /b /c:"REM VERSION " "%D%%~2" 2^>nul') do set "VER=%%V"
echo   updated   %~2  [%VER%]
REM  Each test is its own statement, NOT wrapped in parentheses: inside a block cmd
REM  expands %FIRSTVER% when it parses the whole block, which is before the set above
REM  has run - so the first file would always look like a mismatch.
if "%VER%"=="?" exit /b
if not defined FIRSTVER set "FIRSTVER=%VER%"
if not "%VER%"=="%FIRSTVER%" set "SKEW=1"
exit /b

:retire
if exist "%D%%~1" (
  del /q "%D%%~1"
  echo   removed   %~1  ^(no longer used^)
)
exit /b

:end
echo.
pause
endlocal
