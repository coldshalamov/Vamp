@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "GAME_DIR=%~dp0"
pushd "%GAME_DIR%"
set "GAME_DIR=%CD%"
popd
set "PROJECT_FILE=%GAME_DIR%\project.godot"

if not exist "%PROJECT_FILE%" (
  echo [Launcher] ERROR: project.godot was not found at "%PROJECT_FILE%".
  echo [Launcher] Run this script from the Vampire City project root.
  exit /b 1
)

set "CHECK_ONLY=0"
if /I "%~1"=="--check" (
  set "CHECK_ONLY=1"
  shift
) else if /I "%~1"=="/check" (
  set "CHECK_ONLY=1"
  shift
) else if /I "%~1"=="-check" (
  set "CHECK_ONLY=1"
  shift
)

set "SAFE_VISUALS=0"
if /I "%~1"=="--safe" (
  set "SAFE_VISUALS=1"
  shift
) else if /I "%~1"=="/safe" (
  set "SAFE_VISUALS=1"
  shift
) else if /I "%~1"=="--safe-visuals" (
  set "SAFE_VISUALS=1"
  shift
) else if /I "%~1"=="--full-visuals" (
  set "SAFE_VISUALS=0"
  shift
) else if /I "%~1"=="/full-visuals" (
  set "SAFE_VISUALS=0"
  shift
)
if /I "%VAMP_SAFE_MODE%"=="1" set "SAFE_VISUALS=1"
if /I "%VAMP_SAFE_MODE%"=="true" set "SAFE_VISUALS=1"
if /I "%VAMP_SAFE_MODE%"=="yes" set "SAFE_VISUALS=1"
if /I "%VAMP_SAFE_MODE%"=="on" set "SAFE_VISUALS=1"
if /I "%VAMP_FULL_VISUALS%"=="1" set "SAFE_VISUALS=0"
if /I "%VAMP_FULL_VISUALS%"=="true" set "SAFE_VISUALS=0"
if /I "%VAMP_FULL_VISUALS%"=="yes" set "SAFE_VISUALS=0"
if /I "%VAMP_FULL_VISUALS%"=="on" set "SAFE_VISUALS=0"

set "GODOT_EXE=%VAMP_GODOT_EXE%"
if defined GODOT_EXE if not exist "%GODOT_EXE%" set "GODOT_EXE="
if defined GODOT_EXE (
  call :validate_godot "%GODOT_EXE%"
  if errorlevel 1 set "GODOT_EXE="
)

if not defined GODOT_EXE (
  for %%F in (godot.exe godot4.exe godot4.7.exe godot4.6.exe godot4.5.exe godot4.4.exe godot4.3.exe) do (
    for /f "delims=" %%G in ('where %%F 2^>nul') do (
      call :validate_godot "%%G"
      if not errorlevel 1 (
        set "GODOT_EXE=%%G"
        goto :found_godot
      )
    )
  )
)

if not defined GODOT_EXE (
  if exist "%ProgramFiles%\Godot" (
    for /r "%ProgramFiles%\Godot" %%G in (Godot*.exe) do (
      if not defined GODOT_EXE (
        call :validate_godot "%%~fG"
        if not errorlevel 1 set "GODOT_EXE=%%~fG"
      )
    )
  )
  if not defined GODOT_EXE if exist "%ProgramFiles(x86)%\Godot" (
    for /r "%ProgramFiles(x86)%\Godot" %%G in (Godot*.exe) do (
      if not defined GODOT_EXE (
        call :validate_godot "%%~fG"
        if not errorlevel 1 set "GODOT_EXE=%%~fG"
      )
    )
  )
  if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Programs\Godot" (
    for /r "%LOCALAPPDATA%\Programs\Godot" %%G in (Godot*.exe) do (
      if not defined GODOT_EXE (
        call :validate_godot "%%~fG"
        if not errorlevel 1 set "GODOT_EXE=%%~fG"
      )
    )
  )
  if not defined GODOT_EXE if exist "%USERPROFILE%\scoop\apps\godot\current" (
    for /r "%USERPROFILE%\scoop\apps\godot\current" %%G in (Godot*.exe) do (
      if not defined GODOT_EXE (
        call :validate_godot "%%~fG"
        if not errorlevel 1 set "GODOT_EXE=%%~fG"
      )
    )
  )
  if not defined GODOT_EXE if exist "%USERPROFILE%\bin" (
    for /r "%USERPROFILE%\bin" %%G in (Godot*.exe) do (
      if not defined GODOT_EXE (
        call :validate_godot "%%~fG"
        if not errorlevel 1 set "GODOT_EXE=%%~fG"
      )
    )
  )
)

:found_godot
if not defined GODOT_EXE (
  echo [Launcher] ERROR: Could not find a Godot executable.
  echo [Launcher] Install Godot 4.x and either:
  echo [Launcher]   - add `godot.exe` to PATH, or
  echo [Launcher]   - set VAMP_GODOT_EXE to the full path.
  echo [Launcher] Example:
  echo [Launcher]   setx VAMP_GODOT_EXE "C:\Path\To\Godot\Godot_v4.7-stable_win64.exe"
  exit /b 1
)

if "%CHECK_ONLY%"=="1" (
  echo [Launcher] Project: "%PROJECT_FILE%"
  echo [Launcher] Godot : "%GODOT_EXE%"
  "%GODOT_EXE%" --version
  exit /b %errorlevel%
)

if "%SAFE_VISUALS%"=="1" (
	set "VAMP_SAFE_MODE=1"
	set "VAMP_FULL_VISUALS=0"
	if not defined VAMP_MAX_FPS set "VAMP_MAX_FPS=30"
	echo [Launcher] Reduced visual profile requested: optional presentation systems are disabled.
) else (
	set "VAMP_SAFE_MODE=0"
	set "VAMP_FULL_VISUALS=1"
	if not defined VAMP_MAX_FPS set "VAMP_MAX_FPS=60"
	echo [Launcher] Normal game profile active: full presentation enabled.
	echo [Launcher] Emergency reduced visuals remain available with: PlayGame.bat --safe
)

echo [Launcher] Launching Vampire City...
"%GODOT_EXE%" --path "%GAME_DIR%" %1 %2 %3 %4 %5 %6 %7 %8 %9
set "LAUNCH_CODE=%errorlevel%"

if %LAUNCH_CODE% neq 0 (
  echo [Launcher] Launch returned %LAUNCH_CODE%.
  exit /b %LAUNCH_CODE%
)

exit /b 0

:validate_godot
setlocal
set "CANDIDATE=%~1"
if not exist "%CANDIDATE%" exit /b 1
set "VER_LOG=%TEMP%\_vamp_godot_version_%RANDOM%.txt"
if exist "%VER_LOG%" del "%VER_LOG%" >nul 2>&1
"%CANDIDATE%" --version > "%VER_LOG%" 2>&1
if errorlevel 1 (
  del "%VER_LOG%" >nul 2>&1
  exit /b 1
)
findstr /i /c:"Invalid wrapper executable name." "%VER_LOG%" >nul 2>&1
if not errorlevel 1 (
  del "%VER_LOG%" >nul 2>&1
  exit /b 1
)
del "%VER_LOG%" >nul 2>&1
exit /b 0
