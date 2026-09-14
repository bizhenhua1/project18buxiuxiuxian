extends "res://scripts/spaces/layouts/biome_layout.gd"
# Native connected regions own only their interval. The legacy layout keeps its
# original start rule for side-by-side visual comparison.
func include_shell(region:RouteRegion,s:float)->bool:
 return s>=region.start
