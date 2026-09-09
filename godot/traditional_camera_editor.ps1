$ErrorActionPreference='Stop'
$editorEngine=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64.exe'
& $editorEngine --path $PSScriptRoot 'res://scenes/traditional_camera_editor.tscn'
