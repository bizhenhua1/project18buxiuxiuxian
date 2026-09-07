param([switch]$Editor, [switch]$Spaces, [switch]$Battle, [switch]$World, [switch]$Forest, [switch]$Adventure, [switch]$Style2, [switch]$ForestLab, [switch]$Endless)
$ErrorActionPreference = 'Stop'
$forkEngineCommand = Get-Command godot.exe -ErrorAction SilentlyContinue
if (-not $forkEngineCommand) {
    $forestLocalEngine = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
    if (Test-Path -LiteralPath $forestLocalEngine) { $forkEngineCommand = [pscustomobject]@{ Source = $forestLocalEngine } }
}
if (-not $forkEngineCommand) {
    throw 'Godot executable not found. Add the tested Godot 4.7.1 executable to PATH.'
}
$forkLaunchArgs = @('--path', ('"' + $PSScriptRoot + '"'))
if ($Editor) { $forkLaunchArgs += '--editor' }
if ($Endless) { $forkLaunchArgs += @('res://scenes/endless_forest.tscn','--','--style2') }
elseif ($ForestLab) { $forkLaunchArgs += @('res://scenes/forest_lab.tscn','--','--style2') }
elseif ($Style2) { $forkLaunchArgs += @('res://scenes/style2_preview.tscn','--','--style2') }
elseif ($Adventure) { $forkLaunchArgs += 'res://scenes/adventure_preview.tscn' }
elseif ($Spaces) { $forkLaunchArgs += 'res://scenes/space_study.tscn' }
elseif ($Battle) { $forkLaunchArgs += 'res://scenes/battle_study.tscn' }
elseif ($World) { $forkLaunchArgs += 'res://scenes/world_study.tscn' }
elseif ($Forest) { $forkLaunchArgs += 'res://scenes/main.tscn' }
# Interactive game/editor explicitly requested by the user.
Start-Process -FilePath $forkEngineCommand.Source -ArgumentList $forkLaunchArgs
