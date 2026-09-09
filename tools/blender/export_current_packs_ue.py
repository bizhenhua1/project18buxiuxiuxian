import unreal,pathlib,json
base=pathlib.Path('F:/GitHub/project18buxiuxiuxian')
mapping=json.loads((base/'tempassets/work/pack-map.json').read_text(encoding='utf8'))
out=base/'tempassets/work/current-fbx';out.mkdir(exist_ok=True)
registry=unreal.AssetRegistryHelpers.get_asset_registry();registry.search_all_assets(True)
results=[]
for path,meta in mapping.items():
 data=registry.get_asset_by_object_path(path+'.'+path.rsplit('/',1)[-1])
 if str(data.asset_class_path.asset_name)!='AnimSequence':continue
 obj=unreal.load_asset(path)
 if not isinstance(obj,unreal.AnimSequence):continue
 key=meta['pack']+'_'+obj.get_name()
 task=unreal.AssetExportTask();task.object=obj;task.filename=str(out/(key+'.fbx'));task.automated=True;task.prompt=False;task.replace_identical=True
 task.options=unreal.FbxExportOption();task.options.ascii=False;task.exporter=unreal.AnimSequenceExporterFBX()
 ok=unreal.Exporter.run_asset_export_task(task)
 results.append(dict(meta,id=key,name=obj.get_name(),ok=ok,file=task.filename,errors=list(task.errors)))
(out/'manifest.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
unreal.log('CURRENT_PACKS_DONE '+str(len(results)))
