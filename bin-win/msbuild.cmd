@echo off
rem ---------------------------------------------------------------------------
rem msbuild.cmd - file-based shim that locates and invokes the preferred MSBuild
rem Priority:
rem   (1) 64-bit (amd64) first, then 32-bit
rem   (2) Visual Studio (Community) before Build Tools
rem   (3) Newest installation (by year folder, e.g., 2025 > 2022 > 2019)
rem
rem Always verbose:
rem   - This shim unconditionally enables MSBUILD_SHIM_VERBOSE=1.
rem Optional toggle:
rem   - Set MSBUILD_ARCH=x86 to prefer 32-bit first (default is x64)
rem ---------------------------------------------------------------------------
setlocal
set "MSBUILD_SHIM_VERBOSE=1"

rem Choose architecture preference (default x64/amd64)
set "ARCHPAT=amd64"
if /i "%MSBUILD_ARCH%"=="x86" set "ARCHPAT="

rem Locate vswhere (installed with VS 2017+). If absent, we'll do manual search.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  for %%V in (vswhere.exe) do set "VSWHERE=%%~$PATH:V"
)

rem --- Try vswhere-based discovery first -----------------------------------------
if exist "%VSWHERE%" (
  rem Visual Studio (Community/Pro/Enterprise) first
  call :FIND_MSBUILD "Microsoft.VisualStudio.Product.Enterprise Microsoft.VisualStudio.Product.Professional Microsoft.VisualStudio.Product.Community" "%ARCHPAT%" MSBUILD
  if defined MSBUILD goto :RUN

  rem Build Tools next
  call :FIND_MSBUILD "Microsoft.VisualStudio.Product.BuildTools" "%ARCHPAT%" MSBUILD
  if defined MSBUILD goto :RUN

  rem If x64-first failed, retry allowing 32-bit under the same products
  if /i not "%MSBUILD_ARCH%"=="x86" (
    call :FIND_MSBUILD "Microsoft.VisualStudio.Product.Enterprise Microsoft.VisualStudio.Product.Professional Microsoft.VisualStudio.Product.Community" "" MSBUILD
    if defined MSBUILD goto :RUN

    call :FIND_MSBUILD "Microsoft.VisualStudio.Product.BuildTools" "" MSBUILD
    if defined MSBUILD goto :RUN
  )
)

rem --- Manual ("legacy") search by explicit path patterns, dynamic year ------------
rem Matches these types of paths (year is dynamic: 20*), newest year first:
rem   C:\Program Files\Microsoft Visual Studio\<YEAR>\Community\MSBuild\Current\Bin\amd64\MSBuild.exe
rem   C:\Program Files\Microsoft Visual Studio\<YEAR>\Community\MSBuild\Current\Bin\MSBuild.exe
rem   C:\Program Files (x86)\Microsoft Visual Studio\<YEAR>\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe
rem   C:\Program Files (x86)\Microsoft Visual Studio\<YEAR>\BuildTools\MSBuild\Current\Bin\MSBuild.exe
call :FIND_MSBUILD_MANUAL "%ARCHPAT%" MSBUILD
if defined MSBUILD goto :RUN

rem If we preferred x64 and didn't find it, try 32-bit equivalents for the same patterns
if /i not "%MSBUILD_ARCH%"=="x86" (
  call :FIND_MSBUILD_MANUAL "" MSBUILD
  if defined MSBUILD goto :RUN
)

rem --- Final fallback to legacy .NET Framework MSBuild ----------------------------
:LEGACY
set "MSBUILD=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"
if exist "%MSBUILD%" goto :RUN
set "MSBUILD=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
if exist "%MSBUILD%" goto :RUN

>&2 echo [msbuild.cmd] ERROR: Unable to locate MSBuild.exe.
exit /b 9009

:RUN
if defined MSBUILD_SHIM_VERBOSE echo [msbuild.cmd] Using: "%MSBUILD%"
"%MSBUILD%" %*
set "code=%errorlevel%"
exit /b %code%

rem ------------------------------------------------------------------------------
rem :FIND_MSBUILD <products> <archpat> <outvar>
rem Uses vswhere to find the newest instance with MSBuild, optionally preferring amd64.
rem ------------------------------------------------------------------------------
:FIND_MSBUILD
setlocal
set "PRODUCTS=%~1"
set "ARCHPAT=%~2"
set "OUTVAR=%~3"

if defined ARCHPAT (
  for /f "usebackq delims=" %%P in ( `
    "%VSWHERE%" -latest -products %PRODUCTS% -requires Microsoft.Component.MSBuild ^
      -find MSBuild\**\Bin\amd64\MSBuild.exe
  ` ) do (
    endlocal & set "%OUTVAR%=%%P" & goto :EOF
  )
)

for /f "usebackq delims=" %%P in ( `
  "%VSWHERE%" -latest -products %PRODUCTS% -requires Microsoft.Component.MSBuild ^
    -find MSBuild\**\Bin\MSBuild.exe
` ) do (
  endlocal & set "%OUTVAR%=%%P" & goto :EOF
)

endlocal & set "%OUTVAR%=" & goto :EOF

rem ------------------------------------------------------------------------------
rem :FIND_MSBUILD_MANUAL <archpat> <outvar>
rem Manual path search by the specific patterns requested, with dynamic year folder.
rem Checks Community (Program Files) first, then Build Tools (Program Files x86).
rem Within each, prefers amd64 (if ARCHPAT is set), then 32-bit, and years newest first.
rem ------------------------------------------------------------------------------
:FIND_MSBUILD_MANUAL
setlocal
set "ARCHPAT=%~1"
set "OUTVAR=%~2"

rem --- 1) Community under Program Files ------------------------------------------
for /f "usebackq delims=" %%Y in ( `
  dir /b /ad /o-n "%ProgramFiles%\Microsoft Visual Studio\20*" 2^>nul
` ) do (
  if defined ARCHPAT (
    if exist "%ProgramFiles%\Microsoft Visual Studio\%%Y\Community\MSBuild\Current\Bin\amd64\MSBuild.exe" (
      endlocal & set "%OUTVAR%=%ProgramFiles%\Microsoft Visual Studio\%%Y\Community\MSBuild\Current\Bin\amd64\MSBuild.exe" & goto :EOF
    )
  )
  if exist "%ProgramFiles%\Microsoft Visual Studio\%%Y\Community\MSBuild\Current\Bin\MSBuild.exe" (
    endlocal & set "%OUTVAR%=%ProgramFiles%\Microsoft Visual Studio\%%Y\Community\MSBuild\Current\Bin\MSBuild.exe" & goto :EOF
  )
)

rem --- 2) Build Tools under Program Files (x86) ----------------------------------
if defined ProgramFiles(x86) (
  for /f "usebackq delims=" %%Y in ( `
    dir /b /ad /o-n "%ProgramFiles(x86)%\Microsoft Visual Studio\20*" 2^>nul
  ` ) do (
    if defined ARCHPAT (
      if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\%%Y\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe" (
        endlocal & set "%OUTVAR%=%ProgramFiles(x86)%\Microsoft Visual Studio\%%Y\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe" & goto :EOF
      )
    )
    if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\%%Y\BuildTools\MSBuild\Current\Bin\MSBuild.exe" (
      endlocal & set "%OUTVAR%=%ProgramFiles(x86)%\Microsoft Visual Studio\%%Y\BuildTools\MSBuild\Current\Bin\MSBuild.exe" & goto :EOF
    )
  )
)

endlocal & set "%OUTVAR%=" & goto :EOF
