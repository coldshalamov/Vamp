param(
  [string]$Select = "",
  [int]$MemoryLimitMB = 2048,
  [switch]$AllowFullSuite
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Godot = $env:VAMP_GODOT_EXE

if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
  $Candidates = @(
    "$env:USERPROFILE\bin\Godot_v4.7-stable_win64_console.exe",
    "$env:USERPROFILE\bin\Godot_v4.7-stable_win64.exe",
    "$env:ProgramFiles\Godot\Godot_v4.7-stable_win64_console.exe",
    "$env:ProgramFiles\Godot\Godot_v4.7-stable_win64.exe"
  )
  $Godot = $Candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

if (-not $Godot) {
  throw "Godot executable not found. Set VAMP_GODOT_EXE to the full Godot path."
}

$env:VAMP_SAFE_MODE = "1"
$env:VAMP_MAX_FPS = "15"
if ($AllowFullSuite) {
  $env:VAMP_ALLOW_FULL_GUT = "1"
} else {
  Remove-Item Env:\VAMP_ALLOW_FULL_GUT -ErrorAction SilentlyContinue
}

$Args = @(
  "--headless",
  "--display-driver", "headless",
  "--audio-driver", "Dummy",
  "--path", $Root,
  "-s", "res://addons/gut/gut_cmdln.gd",
  "-gexit"
)

if ($Select) {
  $Args += "-gselect=$Select"
}

$Proc = Start-Process -FilePath $Godot -ArgumentList $Args -WorkingDirectory $Root -PassThru -WindowStyle Hidden
try {
  while (-not $Proc.HasExited) {
    Start-Sleep -Seconds 1
    $Proc.Refresh()
    $PrivateMB = [math]::Round($Proc.PrivateMemorySize64 / 1MB, 1)
    if ($PrivateMB -gt $MemoryLimitMB) {
      Stop-Process -Id $Proc.Id -Force
      throw "Godot exceeded ${MemoryLimitMB}MB private memory and was stopped at ${PrivateMB}MB."
    }
  }
  exit $Proc.ExitCode
} finally {
  if (-not $Proc.HasExited) {
    Stop-Process -Id $Proc.Id -Force
  }
}
