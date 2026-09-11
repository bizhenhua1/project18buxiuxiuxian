extends RefCounted
const THEMES := ["forest", "crystal", "swamp", "sewer", "whale", "palace"]
static func apply(cells: Array, index: int) -> void:
	var options:Array=THEMES.duplicate()
	for scene in FairytaleCatalog.scenes:options.append(scene.id)
	var theme: String = FairytaleCatalog.world_override if not FairytaleCatalog.world_override.is_empty() else options[posmod(index, options.size())]
	var folder := ("assets/fairytales/" if FairytaleCatalog.has_scene(theme) else "assets/world-six/")+theme+"/"
	for cell in cells:
		cell.theme = theme
		cell.base = folder+"ground.png"
		cell.cliff = folder+"cliff.png"
		if cell.feat == null: continue
		var source: String = cell.feat.src
		if source.begins_with("assets/world-six/"): continue
		var variant := posmod(int(cell.c)*7+int(cell.r)*13,4)
		if FairytaleCatalog.has_scene(theme):
			variant = posmod(int(cell.c)*7+int(cell.r)*13,5)
			cell.feat={"src":folder+("structure.png" if variant==0 else "prop-%d.png"%(variant-1)),"w":.66 if variant==0 else .38,"kind":"deco"}
			continue
		var tree := theme == "forest" and ("tree" in source or "grove" in source)
		cell.feat = {"src":folder+("tree.png" if tree else "prop-%d.png" % variant), "w":0.72 if tree else 0.40, "kind":"deco"}
