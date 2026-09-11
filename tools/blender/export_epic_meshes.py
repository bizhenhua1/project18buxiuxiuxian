import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
jobs=json.loads((root/'tempassets/work/epic-mesh-jobs.json').read_text())
for job in jobs:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.fbx(filepath=job['source'])
 for obj in bpy.context.scene.objects:
  if obj.type=='MESH':
   obj.data.materials.clear()
 bpy.ops.export_scene.gltf(filepath=job['output'],export_format='GLB',export_animations=False,export_materials='NONE')
 print('MESH_EXPORTED',job['output'],flush=True)
