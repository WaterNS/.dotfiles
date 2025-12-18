@echo off
REM --- ls shim for cmd.exe / PowerShell-aware --------------------------------
REM Behavior:
REM - If running under PowerShell (parent or grandparent process is powershell.exe or pwsh.exe)
REM     * If args contain known Unix ls flags then call msls %*
REM     * Else if args contain known Get-ChildItem flags then call Get-ChildItem %*
REM     * Else with no flags call Get-ChildItem %*   default in PowerShell
REM - If running under cmd.exe
REM     * If msls exists then call msls --color=auto -alhpF %*
REM     * Else call dir %*
REM ---------------------------------------------------------------------------

setlocal EnableExtensions EnableDelayedExpansion

REM Detect msls
where msls >nul 2>nul
set "HAVE_MSLS=0"
if %ERRORLEVEL% EQU 0 set "HAVE_MSLS=1"

REM Compute whether this CMD was started with /c which indicates a one-shot trampoline call
REM Use string substitution instead of piping CMDCMDLINE to findstr to avoid noise from quotes and meta chars
set "IS_CMD_C=0"
set "CMDCMD=%CMDCMDLINE%"
set "CMDCMD=%CMDCMD:"=%"
REM strip quotes so /c" becomes /c
set "CMDCMD=%CMDCMD% "
REM pad trailing space so end-of-line matches become ' /c '
if not "%CMDCMD: /c =%"=="%CMDCMD%" set "IS_CMD_C=1"
if not "%CMDCMD: /C =%"=="%CMDCMD%" set "IS_CMD_C=1"

REM Detect if invoked from PowerShell. Prefer CIM via PowerShell or pwsh. Keep WMIC fallback.
set "IN_POWERSHELL=0"
set "SELF=%~f0"

REM Prefer pwsh, then Windows PowerShell
set "PSHOST="
where pwsh >nul 2>nul && set "PSHOST=pwsh"
if not defined PSHOST ( where powershell >nul 2>nul && set "PSHOST=powershell" )

if defined PSHOST (
  "%PSHOST%" -NoProfile -NoLogo -ExecutionPolicy Bypass -Command ^
    "$pp=(Get-CimInstance Win32_Process -Filter ('ProcessId={0}' -f $PID)).ParentProcessId;" ^
    "$me=Get-CimInstance Win32_Process -Filter ('ProcessId={0}' -f $pp);" ^
    "$p =Get-CimInstance Win32_Process -Filter ('ProcessId={0}' -f $me.ParentProcessId);" ^
    "if ($p.Name -eq 'conhost.exe') { $p=Get-CimInstance Win32_Process -Filter ('ProcessId={0}' -f $p.ParentProcessId) }" ^
    "if ($p.Name -match '^(pwsh|powershell)\.exe$') { exit 0 } else { exit 1 }" >nul

  REM Use delayed expansion and only treat as PowerShell when this CMD was started with /c
  if !ERRORLEVEL! EQU 0 if "!IS_CMD_C!"=="1" set "IN_POWERSHELL=1"
)

REM Legacy WMIC fallback only if not already determined
if "!IN_POWERSHELL!"=="0" (
  set "PPID="
  set "PPNAME="
  set "GPPID="
  set "GPPNAME="

  where wmic >nul 2>nul
  if !ERRORLEVEL! EQU 0 (
    REM Find our current cmd.exe row by matching the command line with our script path
    for /f "skip=1 tokens=1,2,*" %%A in ('
      wmic process where "name='cmd.exe'" get ProcessId^,ParentProcessId^,CommandLine /format:table
    ') do (
      REM Columns: ProcessId  ParentProcessId  CommandLine
      echo(%%C | findstr /I /C:"%SELF%" >nul
      if not errorlevel 1 set "PPID=%%B"
    )
    if defined PPID (
      for /f "tokens=2 delims==" %%N in ('
        wmic process where "ProcessId=%PPID%" get Name /value ^| findstr "="
      ') do set "PPNAME=%%N"

      REM If parent is conhost.exe, walk up one more level to check its parent
      if /I "!PPNAME!"=="conhost.exe" (
        for /f "tokens=2 delims==" %%N in ('
          wmic process where "ProcessId=%PPID%" get ParentProcessId /value ^| findstr "="
        ') do set "GPPID=%%N"
        if defined GPPID (
          for /f "tokens=2 delims==" %%N in ('
            wmic process where "ProcessId=!GPPID!" get Name /value ^| findstr "="
          ') do set "GPPNAME=%%N"
        )
      )

      REM Only mark PowerShell when parent or grandparent is PS and this CMD was started with /c
      if /I "!PPNAME!"=="powershell.exe"  if "!IS_CMD_C!"=="1" set "IN_POWERSHELL=1"
      if /I "!PPNAME!"=="pwsh.exe"        if "!IS_CMD_C!"=="1" set "IN_POWERSHELL=1"
      if /I "!GPPNAME!"=="powershell.exe" if "!IS_CMD_C!"=="1" set "IN_POWERSHELL=1"
      if /I "!GPPNAME!"=="pwsh.exe"       if "!IS_CMD_C!"=="1" set "IN_POWERSHELL=1"
    )
  )
)

REM PowerShell-aware branch
if "!IN_POWERSHELL!"=="1" (
  REM Known GCI switches including common parameters
  set "GCI_LIST= Path LiteralPath Filter Include Exclude Recurse Force Depth Hidden Directory File Name Attributes System ReadOnly ErrorAction ErrorVariable OutVariable OutBuffer Verbose Debug WarningAction WarningVariable InformationAction InformationVariable WhatIf Confirm PipelineVariable "

  REM Known Unix long options to recognize
  set "UNIX_LONG= --color --all --long --human-readable --group-directories-first --classify --almost-all --time-style --quoting-style "

  set "HAS_UNIX=0"
  set "HAS_GCI=0"

  for %%A in (%*) do (
    set "arg=%%~A"
    if "!arg:~0,1!"=="-" (
      if "!arg:~0,2!"=="--" (
        for /f "tokens=1 delims==" %%K in ("!arg!") do set "opt=%%K"
        echo !UNIX_LONG! | findstr /I /C:" !opt! " >nul && set "HAS_UNIX=1"
      ) else (
        set "token=!arg:~1!"
        for /f "tokens=1 delims=:" %%K in ("!token!") do set "tname=%%K"
        echo !GCI_LIST! | findstr /I /C:" !tname! " >nul && set "HAS_GCI=1"
        if "!HAS_GCI!"=="0" (
          echo(!tname!| findstr /R "^[A-Za-z0-9][A-Za-z0-9]*$" >nul && set "HAS_UNIX=1"
        )
      )
    )
  )

  REM Choose runner for GCI
  set "PSRUN=!PSHOST!"
  if not defined PSRUN set "PSRUN=powershell"

  REM If Unix-style flags were used and msls exists, let msls handle them
  if "!HAVE_MSLS!"=="1" if "!HAS_UNIX!"=="1" (
    msls --color=auto -alhpF %*
    exit /b !ERRORLEVEL!
  )

  REM If GCI-style flags present, call Get-ChildItem
  if "!HAS_GCI!"=="1" (
    "!PSRUN!" -NoProfile -ExecutionPolicy Bypass -File "%~dp0ls-gci.ps1" %*
    exit /b !ERRORLEVEL!
  )

  REM Default in PowerShell context is Get-ChildItem
  "!PSRUN!" -NoProfile -ExecutionPolicy Bypass -File "%~dp0ls-gci.ps1" %*
  exit /b !ERRORLEVEL!
)

REM Plain cmd.exe branch
if "%HAVE_MSLS%"=="1" (
  msls --color=auto -alhpF %*
  exit /b !ERRORLEVEL!
)

dir %*
exit /b !ERRORLEVEL!
