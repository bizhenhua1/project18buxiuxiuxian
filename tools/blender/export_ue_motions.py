import unreal, pathlib, json
out=pathlib.Path('F:/GitHub/project18buxiuxiuxian/tempassets/work/fbx');out.mkdir(parents=True,exist_ok=True)
results=[]
paths=unreal.EditorAssetLibrary.list_assets('/Game/EvilMagician/Animations',recursive=True)
paths.append('/Game/EvilMagician/Characters/Meshes/SK_Mannequin')
for path in paths:
    obj=unreal.load_asset(path)
    if not isinstance(obj,(unreal.AnimSequence,unreal.SkeletalMesh)):continue
    task=unreal.AssetExportTask();task.object=obj;task.filename=str(out/(obj.get_name()+'.fbx'));task.automated=True;task.prompt=False;task.replace_identical=True
    task.options=unreal.FbxExportOption();task.options.ascii=False
    task.exporter=unreal.AnimSequenceExporterFBX() if isinstance(obj,unreal.AnimSequence) else unreal.SkeletalMeshExporterFBX()
    ok=unreal.Exporter.run_asset_export_task(task)
    results.append({'name':obj.get_name(),'ok':ok,'errors':list(task.errors)})
(out/'manifest.json').write_text(json.dumps(results,indent=2))
unreal.log('MOTION_EXPORT_DONE '+json.dumps(results))
