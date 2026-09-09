import bpy
from mathutils import Vector
from pathlib import Path
out=Path('F:/GitHub/project18buxiuxiuxian/art/3d/lantern-investigator')
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=800;scene.render.resolution_y=1000
for name,pos in [('front',(3.5,-7,3.4)),('rear',(-3.5,7,3.2)),('face',(.9,-4,3.2))]:
    scene.camera.location=pos
    target=Vector((0,0,1.65 if name!='face' else 2.87))
    scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera.data.ortho_scale=4.1 if name!='face' else 1.18
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('PREVIEW_RENDERS_COMPLETE')
