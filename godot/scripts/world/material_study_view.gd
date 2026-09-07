extends IslandView3D
## Art variants only: retains A's original BoxMesh and full diamond footprint.
var atlas_path := ""
func rebuild() -> void:
	super()
	if atlas_path.is_empty(): return
	for tile in tiles.values():
		var path: String = tile.cell.base
		var row := 0
		if "leaf_" in path: row = 1
		elif "rock_" in path: row = 2
		elif "water_" in path: row = 3
		var pair := IslandMaterialLibrary.texture_pair(atlas_path,row)
		var arrays: Array = tile.top.mesh.surface_get_arrays(0)
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		tile.top.mesh = mesh
		tile.top.material_override.shader = preload("res://shaders/material_study_top.gdshader")
		tile.top.material_override.set_shader_parameter("atlas",pair[0])
		tile.top.material_override.set_shader_parameter("material_row",float(row))
		tile.body.material_override.shader = preload("res://shaders/material_study_cliff.gdshader")
		tile.body.material_override.set_shader_parameter("atlas",pair[1])
		tile.body.material_override.set_shader_parameter("material_row",float(row))
