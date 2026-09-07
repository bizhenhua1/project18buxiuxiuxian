class_name SpaceType
extends Resource
## A reusable spatial family. Variants override resources, never renderer branches.
@export var key: StringName
@export var title: String
@export var layout: Script
@export var atmosphere: AtmosphereProfile
@export var ceiling_enabled := false
@export var sky_enabled := true
@export var far_ridge_enabled := true
@export var ground_texture: Texture2D
@export var ground_tint := Color(0.56, 0.61, 0.46)
@export var ambient := Color.WHITE
@export var top_color := Color(0.22, 0.38, 0.56)
@export var ceiling_height := 440.0
@export var shell_width := 724.0
@export var shell_spacing := 210.0
@export var depth_start := 220.0
@export var depth_end := 1750.0
