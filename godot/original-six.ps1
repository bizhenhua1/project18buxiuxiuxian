param([ValidateSet('2D','3D')][string]$Mode='3D')
$ErrorActionPreference='Stop'
$sixEngine=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $sixEngine)) { throw "Godot not found: $sixEngine" }
& $sixEngine --path $PSScriptRoot 'res://scenes/original_six_hub.tscn' -- "--original-six-$($Mode.ToLowerInvariant())"
