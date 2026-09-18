extends SceneTree
const Bridge=preload("res://scripts/world3d/model_bridge.gd")
var stage
var model:BattleModel
func _initialize():call_deferred("run")
func position_for(unit:Dictionary)->Vector3:
	var at:=profile(unit)
	return stage.world_point(Vector3(at.x/8,0,8.5-(at.depth-31)/8))
func profile(unit:Dictionary)->Dictionary:
	return {"x":(unit.index-(model.enemy.size()-1)*.5)*46.0,"depth":226.0+8*(unit.index%2),"height":54.0}
func run():
	root.size=Vector2i(1440,900);set_meta("world3d_theme","snow_mirror")
	var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
	while not shell.stage or not shell.stage.ready_stage:await process_frame
	stage=shell.stage;stage.set_process(false);stage.preview.hide();stage.set_inspection_expanded(false)
	model=BattleModel.new();model.enemy.clear()
	for card in FairytaleCatalog.roster("snow_mirror"):
		model.enemy.append(model.rules.create_unit(card,"enemy",model.enemy.size(),0))
	var adapter=Bridge.new();adapter.bind(model);adapter.sync(position_for)
	var view=preload("res://scripts/world3d/model_cutouts.gd").new();stage.add_child(view);view.setup(adapter,profile)
	stage._process(0);view.sync(stage.bridge,stage.camera)
	assert(view.bindings.size()==3)
	for unit in model.enemy:
		assert(view.bindings[unit.uid].source.resource_path=="res://"+unit.art)
		assert(view.bindings[unit.uid].node.position.is_equal_approx(position_for(unit)))
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tempassets/work/world3d-original-tale-enemies.png")
	var dead:Dictionary=model.enemy[0];dead.hp=0;dead.status="corpse";adapter.sync(position_for)
	model.elapsed=4.99;view.sync(stage.bridge,stage.camera);assert(view.bindings[dead.uid].node.modulate.a==1)
	model.elapsed=5.6;view.sync(stage.bridge,stage.camera);assert(view.bindings[dead.uid].node.modulate.a<1)
	assert(view.smoke.multimesh.visible_instance_count>0)
	dead.reviveLeft=1000;adapter.sync(position_for);view.sync(stage.bridge,stage.camera)
	assert(view.bindings[dead.uid].node.modulate.a==1)
	dead.hp=dead.maxHp;dead.status="alive";dead.reviveLeft=0
	adapter.sync(position_for);view.sync(stage.bridge,stage.camera)
	assert(view.bindings[dead.uid].node.modulate.a==1)
	assert(view.geometry.size()==3,"Geometry must be cached per asset, not per frame")
	adapter.release();print("ORIGINAL_ENEMY_ART_PASS true 3D positions, original card art, cached feet, delayed smoke, revive preservation");quit()
