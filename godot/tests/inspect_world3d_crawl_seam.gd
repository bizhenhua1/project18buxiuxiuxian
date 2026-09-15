extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/world3d/actor.gd").new();root.add_child(actor);actor.setup("composer.glb");actor.play("crawl")
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--clip="):
   for entry in actor.catalog.clips:
    if entry.id==argument.trim_prefix("--clip="):actor.library.clips.crawl=entry;actor.cache.erase("crawl");actor.play("crawl")
 if "--in-place-height" in OS.get_cmdline_user_args():
  var stride:int=3+actor.catalog.bones.size()*4
  var frames:int=actor.retarget.frames
  var drift:float=actor.retarget.data[(frames-1)*stride+1]-actor.retarget.data[1]
  actor.retarget.data=actor.retarget.data.duplicate()
  for i in frames:actor.retarget.data[i*stride+1]-=drift*i/(frames-1)
 var duration:float=(actor.library.clips.crawl.frames-1)/actor.library.clips.crawl.fps
 var previous:Array=[];var first:Array=[];var peak:=0.0
 for frame in 121:
  actor.retarget.apply(frame*duration/120)
  var current:Array=[]
  for name in ["頭","腰","手首.L","手首.R","足首.L","足首.R"]:
   var bone:int=actor.rig.find_bone(name)
   current.append((actor.body.transform*actor.rig.get_bone_global_pose(bone)).origin)
  if frame==0:first=current.duplicate()
  else:
   for i in current.size():peak=maxf(peak,current[i].distance_to(previous[i]))
  previous=current
 var seam:=0.0
 for i in first.size():seam=maxf(seam,first[i].distance_to(previous[i]))
 print("CRAWL_SEAM duration=",duration," seam=",seam," sample_peak=",peak)
 assert(seam<.0001,"Crawling must wrap without a root or limb teleport")
 quit()
