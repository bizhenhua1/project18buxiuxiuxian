"""Production entry point: prepare a family-specific brief, inspect assets, run real cases.

An inspection success is NOT scene acceptance. Every output retains stage and
source hashes so future models cannot turn a file-presence test into visual approval.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import re
import subprocess
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FAMILIES = ROOT / "scene-production/families.json"
RULES = ROOT / "scene-production/production-rules.json"


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def family(key):
    return next(item for item in read(FAMILIES)["families"] if item["id"] == key)


def prepare(args):
    f = family(args.family)
    rules = read(RULES)
    kit = rules["families"][args.family]
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,63}", args.name):
        raise ValueError("Name must be a stable lowercase scene id")
    dest = ROOT / "scene-production/jobs" / args.name
    if dest.exists():
        raise ValueError("Job already exists; edit it explicitly instead of overwriting")
    dest.mkdir(parents=True)
    slots = []
    for index, role in enumerate(f["slots"]):
        prompt = (
            f"项目：黑暗童话绘本游戏。新场景风格：{args.style}\n"
            f"空间族：{f['title']}。本张唯一用途：{role}。\n"
            f"结构限制：{f['top_rule']}\n撒布用途：{f['scatter_rule']}\n"
            f"岔路要求：{f['junction_rule']}\n"
            f"具体内容：{kit['examples'][index]}。至少{kit['variants'][index]}个真正不同的轮廓或材质。\n"
            f"表达方式：{kit['representations'][index]}。\n"
            f"支撑/挂点：{kit['root_policy']}\n拼组：{kit['assembly']}\n光效：{kit['light_fx']}\n"
            f"光照裁决优先：{rules['shared']['lighting_closure_override']}\n"
            "只制作指定部件或材质，不画整幅走廊背景，不烘焙消失点，不夹带人物。"
            "构件完整保留支撑端、挂点及连接边；结构连接件必须指定正面/侧面/转角。"
            "材质须无方向性投影、无道具且可平铺；独立物件须透明底、完整轮廓、无文字无水印。"
            "沿用参考图的线条与材料笔触，颜色由新风格决定；不能仅把参考改色。\n"
            "生成前必须查看并绑定对应参考图片，填写下列槽位的物理尺寸、视角和拆件方案。"
            "此提示仅是工单起点；缺少具体内容、尺寸和参考时不得调用生成或发布。\n"
        )
        prompt_path = dest / f"{index+1:02d}-prompt.txt"
        prompt_path.write_text(prompt, encoding="utf-8")
        slots.append({"id":f"slot_{index+1}","purpose":role,"prompt":prompt_path.name,
                      "assets":[],"references":[],"required_variants":kit['variants'][index],
                      "representation":kit['representations'][index],
                      "status":"needs_specification"})
    job = {"schema_version":1,"id":args.name,"family":args.family,"style":args.style,
           "stage":"draft","family_sha256":digest(FAMILIES),"slots":slots,
           "assemblies":[],"runtime_evidence":[],"visual_review":None,
           "rules":f,"production_rules_sha256":digest(RULES),"kit":kit,"publication_allowed":False}
    write(dest/"job.json",job)
    print(dest/"job.json")


def inspect_asset(asset, base):
    from PIL import Image, ImageChops, ImageStat
    errors = []
    required = ["path","representation","size_m","anchor_uv","view_policy","contact","sha256"]
    errors += [f"missing {key}" for key in required if key not in asset]
    path = (base/asset.get("path", "")).resolve()
    if not path.is_file():return {"errors":errors+["image missing"],"metrics":{}}
    if asset.get("sha256") != digest(path):errors.append("image hash changed; annotations require review")
    try:
        image = Image.open(path).convert("RGBA")
    except Exception as exc:
        return {"errors":errors+[f"invalid image: {exc}"],"metrics":{}}
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda v:255 if v>=128 else 0).getbbox()
    if not bounds:errors.append("empty visible silhouette")
    size = asset.get("size_m",[])
    if len(size)!=2 or any(not isinstance(v,(float,int)) or not math.isfinite(v) or v<=0 for v in size):
        errors.append("size_m must be positive visible metres")
    anchor = asset.get("anchor_uv",[])
    if len(anchor)!=2 or any(not isinstance(v,(float,int)) or not 0<=v<=1 for v in anchor):
        errors.append("anchor_uv invalid")
    contact = asset.get("contact")
    if contact=="grounded":
        if not asset.get("support_points_m"):errors.append("ground support points missing")
        polygons = asset.get("footprints_m",[])
        if not polygons:errors.append("hard footprint missing")
        for p in polygons:
            if not isinstance(p,list) or len(p)<3:errors.append("footprint has fewer than three points");continue
            if any(not isinstance(v,list) or len(v)!=2 or any(not isinstance(n,(int,float)) or not math.isfinite(n) for n in v) for v in p):
                errors.append("footprint coordinates invalid");continue
            area=abs(sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p))))/2
            if area<0.0001:errors.append("degenerate footprint")
    elif contact=="suspended":
        if not asset.get("sockets_m"):errors.append("hanging attachment missing")
        if "lowest_point_m" not in asset:errors.append("hanging lowest point missing")
        if asset.get("footprints_m"):errors.append("suspended object cannot fake a grounded footprint")
    elif contact!="surface":errors.append("unsupported contact")
    if asset.get("representation")=="surface_texture":
        if alpha.getextrema()!=(255,255):errors.append("continuous surface texture has alpha gaps")
        rgb=image.convert("RGB");w,h=rgb.size
        dx=ImageStat.Stat(ImageChops.difference(rgb.crop((0,0,1,h)),rgb.crop((w-1,0,w,h)))).mean
        dy=ImageStat.Stat(ImageChops.difference(rgb.crop((0,0,w,1)),rgb.crop((0,h-1,w,h)))).mean
        seam=max(sum(dx)/3,sum(dy)/3)
    else:seam=None
    if bounds:
        visible_px=min(bounds[2]-bounds[0],bounds[3]-bounds[1])
        if visible_px<float(asset.get("max_projected_short_axis_px",0))*1.5:
            errors.append("insufficient resolution for declared near-camera use")
    if not asset.get("semantic_review"):errors.append("semantic/view review missing; alpha bounds alone are not physical supports")
    return {"errors":errors,"metrics":{"pixels":list(image.size),"alpha_bounds":bounds,
            "edge_mean_difference_255":seam,"seam_note":"metric is diagnostic, never automatic artistic acceptance"}}


def inspect(args):
    path=Path(args.job).resolve();job=read(path);errors=[];results=[]
    if job.get("family_sha256")!=digest(FAMILIES):errors.append("family rules changed; review job against current rules")
    if job.get("production_rules_sha256")!=digest(RULES):errors.append("production rules changed or not bound")
    f=family(job["family"])
    declared={s.get("purpose") for s in job.get("slots",[])}
    errors += ["missing required slot: "+s for s in f["slots"] if s not in declared]
    for slot in job.get("slots",[]):
        if not slot.get("references"):errors.append(slot["id"]+": visual reference missing")
        for reference in slot.get('references',[]):
            if not isinstance(reference,dict) or 'path' not in reference or 'sha256' not in reference:
                errors.append(slot['id']+': reference needs path and hash');continue
            refpath=(path.parent/reference['path']).resolve()
            if not refpath.is_file() or digest(refpath)!=reference['sha256']:errors.append(slot['id']+': missing or changed reference')
        required=slot.get("required_variants")
        if not isinstance(required,int) or required<1:errors.append(slot["id"]+": variant requirement unspecified")
        assets=slot.get("assets",[])
        if not assets:errors.append(slot["id"]+": needs assets")
        hashes={a.get("sha256") for a in assets if a.get("sha256")}
        if isinstance(required,int) and len(hashes)<required:errors.append(slot["id"]+": distinct asset count insufficient")
        for a in assets:
            result=inspect_asset(a,path.parent);result["slot"]=slot["id"];results.append(result)
            errors += [slot["id"]+": "+error for error in result["errors"]]
    for group in job.get("assemblies",[]):
        if not group.get("members"):errors.append("empty assembly")
        if group.get("hanging"):
            for key in f["hanging"]["required"]:
                if key not in group:errors.append("hanging assembly missing "+key)
    report={"job":job["id"],"assets_checked":not errors,"publication_allowed":False,"errors":errors,"assets":results}
    write(path.parent/"asset-check.json",report)
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return 1 if errors else 0


def capture(args):
    key=args.family;f=family(key);dest=Path(args.output).resolve()
    if dest.exists():raise ValueError("Capture output must be new")
    dest.mkdir(parents=True)
    cases=args.cases.split(",")
    results=[]
    for case in cases:
        if case not in f["cases"]:raise ValueError("Unsupported case: "+case)
        actual="junction" if case.startswith("junction") else case
        actual="entry" if case=="entry" else actual
        exits=2 if case in ["entry","junction2"] else 3
        command=[str(Path(args.godot).resolve()),"--path",str(ROOT/"godot"),"--script",
                 "res://tests/capture_fairytale_3d_representative.gd","--",key,
                 "--run-dir="+str(dest/case),"--case="+actual,"--exits="+str(exits),"--frames=30"]
        if getattr(args,'recipe',None):command.append('--production-recipe='+str(Path(args.recipe).resolve()))
        try:
            result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=90)
            log=result.stdout+result.stderr
            ok=result.returncode==0 and "REP_CAPTURE_COMPLETE" in log and "SCRIPT ERROR" not in log
        except subprocess.TimeoutExpired:
            ok=False;log="capture timeout; no pass claimed"
        (dest/(case+".log")).write_text(log,encoding="utf-8")
        results.append({"case":case,"captured":ok,"visual_accepted":False})
        write(dest/"results.json",{"family":key,"cases":results,"workflow_verified":False})
        print(f"{key}/{case}: {'captured' if ok else 'FAILED'}",flush=True)
    return 0 if all(r["captured"] for r in results) else 1


def check_evidence(directory):
    """Reject stale or mismatched evidence; this does not judge visual quality."""
    directory=Path(directory);errors=[]
    try:
        manifest=read(directory/'manifest.json');settings=read(directory/'settings.json')
    except (OSError,ValueError) as exc:return [f'missing/invalid capture evidence: {exc}']
    if manifest.get('actual_scene')!=settings.get('scene'):errors.append('wrong scene captured')
    if not manifest.get('asset_sha256'):errors.append('no source asset hashes; recapture required')
    for section in ['source_sha256','asset_sha256','settings_sha256']:
        for relative,expected in manifest.get(section,{}).items():
            path=(ROOT/'godot'/relative[6:]) if relative.startswith('res://') else (directory/relative if section=='settings_sha256' else ROOT/relative)
            if not path.is_file() or digest(path)!=expected:errors.append('stale or missing '+relative)
    if {c.get('kind') for c in manifest.get('captures',[])}!={'beauty','diagnostic'}:errors.append('paired beauty/diagnostic evidence missing')
    for capture_item in manifest.get('captures',[]):
        image=directory/capture_item.get('image','')
        if not image.is_file() or digest(image)!=capture_item.get('sha256'):errors.append('capture image changed')
    if settings.get('case')=='junction' and settings.get('phase')!='choose':errors.append('junction not captured during choice')
    if settings.get('case')=='battle' and settings.get('phase')!='battle':errors.append('battle state absent')
    if settings.get('case') in ['left','right','center'] and settings.get('branch')!={'left':-1,'right':1,'center':2}[settings['case']]:errors.append('wrong selected branch')
    return errors


def evidence(args):
    errors=check_evidence(args.directory)
    report={'directory':str(Path(args.directory).resolve()),'provenance_valid':not errors,'visual_accepted':False,'publication_allowed':False,'errors':errors}
    write(Path(args.directory)/'evidence-check.json',report)
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return int(bool(errors))


def freeze(args):
    """Archive a reviewed job; never silently install or approve its artwork."""
    from types import SimpleNamespace
    path=Path(args.job).resolve();job=read(path);errors=[]
    if inspect(SimpleNamespace(job=str(path))):errors.append('asset inspection failed')
    by_case={}
    for item in job.get('runtime_evidence',[]):
        directory=(path.parent/item['directory']).resolve()
        problems=check_evidence(directory)
        errors.extend(problems)
        if problems:continue
        settings=read(directory/'settings.json')
        case='junction'+str(settings['exits']) if settings['case']=='junction' else settings['case']
        if settings['scene']!=job.get('runtime_scene',job['family']):errors.append('capture belongs to another scene')
        by_case[case]=directory
    errors.extend('missing runtime case '+case for case in family(job['family'])['cases'] if case not in by_case)
    # Reviews are explicit accountable decisions bound to evidence, not boolean
    # flags in a manifest. Algorithms cannot approve artistic correspondence.
    for domain in ['visual_review','junction_review','ground_review','hanging_review','effects_review','transition_review','performance_review']:
        review=job.get(domain,{}) or {}
        if review.get('decision') not in ['accepted','not_applicable'] or not review.get('reason') or not review.get('reviewer'):
            errors.append(domain+': explicit decision, reason and reviewer required');continue
        if review['decision']=='not_applicable' and domain not in ['hanging_review','effects_review','transition_review']:
            errors.append(domain+': cannot skip this domain')
        evidence_items=review.get('evidence',[])
        if not evidence_items:errors.append(domain+': supporting evidence missing')
        for item in evidence_items:
            file=(path.parent/item.get('path','')).resolve()
            if not file.is_file() or digest(file)!=item.get('sha256'):errors.append(domain+': stale review evidence')
    if job.get('open_blockers'):errors.append('unresolved blockers remain')
    result={'job':job['id'],'publication_allowed':not errors,'errors':errors,'job_sha256':digest(path),'installation_performed':False}
    write(path.parent/'release-check.json',result)
    if not errors:write(path.parent/'frozen-recipe.json',{'job':job,'release':result})
    print(json.dumps(result,ensure_ascii=False,indent=2));return int(bool(errors))


def catalog(args):
    """Individual source art + actual runtime usage, never inferred semantic roots."""
    from PIL import Image
    directory=Path(args.directory).resolve();usage=read(directory/'asset-usage.json')
    dest=Path(args.output).resolve()
    if dest.exists():raise ValueError('Catalog output must be new')
    dest.mkdir(parents=True);rows=[];records=[]
    for i,(resource,values) in enumerate(sorted(usage.items())):
        source=ROOT/'godot'/resource.removeprefix('res://')
        if not source.is_file():continue
        with Image.open(source) as im:
            im=im.convert('RGBA');alpha=im.getchannel('A');bounds=alpha.point(lambda v:255 if v>=128 else 0).getbbox()
            record={'source':resource,'sha256':digest(source),'pixels':list(im.size),'alpha_bounds':bounds,'runtime_usage':values,
                    'support_points_m':None,'footprints_m':None,'sockets_m':None,'status':'requires_semantic_annotation'}
            im.thumbnail((380,260));back=Image.new('RGBA',im.size,(78,83,90,255));back.alpha_composite(im);back.convert('RGB').save(dest/f'{i}.jpg')
        records.append(record)
        rows.append(f'<article><img src="{i}.jpg"><h3>{html.escape(resource)}</h3><p>实例 {values["count"]}；运行画布高度 {values["canvas_height_m_min"]:.2f}–{values["canvas_height_m_max"]:.2f} m</p><p>尺寸 {record["pixels"]}；透明轮廓 {bounds}</p><b>语义支点、占地、挂点尚需逐图标注</b></article>')
    write(dest/'catalog.json',records)
    (dest/'index.html').write_text('<meta charset="utf-8"><title>单资产审查</title><style>body{background:#20252a;color:#eee;font:15px sans-serif}main{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}article{padding:14px;background:#30373b;overflow-wrap:anywhere}img{max-width:100%;height:260px;object-fit:contain}b{color:#e9c780}</style><h1>源图与实际撒布尺寸</h1><p>下列高度是画布高度，不是实体净高。透明包围盒不等于脚点或占地。</p><main>'+''.join(rows)+'</main>',encoding='utf-8')
    print(dest/'index.html')


def frame_fit(spec):
    """Compute feasibility before scattering. Fractions must be semantic annotations."""
    keys=['image_width_px','image_height_px','visible_height_fraction','opening_width_fraction','required_opening_m','ceiling_height_m']
    if any(not isinstance(spec.get(k),(int,float)) or not math.isfinite(spec[k]) or spec[k]<=0 for k in keys):
        raise ValueError('Frame dimensions and annotated opening must be finite and positive')
    if spec['visible_height_fraction']>1 or spec['opening_width_fraction']>1:
        raise ValueError('Annotated fractions must not exceed one')
    ratio=spec['image_width_px']/spec['image_height_px']
    minimum=spec['required_opening_m']/(ratio*spec['opening_width_fraction'])
    maximum=spec['ceiling_height_m']/spec['visible_height_fraction']
    ok=minimum<=maximum
    return {'uniform_scale_feasible':ok,'minimum_canvas_height_m':minimum,'maximum_canvas_height_m':maximum,
            'opening_at_max_height_m':maximum*ratio*spec['opening_width_fraction'],
            'decision':'choose height within calculated interval, then test both supports against every route' if ok else 'split supports and span, or regenerate source with a wider aperture; do not squash or change the camera',
            'runtime_verified':False}


def fit_frame(args):
    source=Path(args.spec).resolve();result=frame_fit(read(source))
    write(source.with_name(source.stem+'-fit.json'),result)
    print(json.dumps(result,ensure_ascii=False,indent=2));return int(not result['uniform_scale_feasible'])


def compile_recipe(args):
    """Compile a compatible art kit onto a proven family layout; fail closed."""
    from PIL import Image
    path=Path(args.recipe).resolve();recipe=read(path);f=family(recipe['family']);bindings={};hashes={}
    if not re.fullmatch(r'[a-z][a-z0-9_]{2,63}',recipe.get('id','')):raise ValueError('Invalid recipe id')
    if not recipe.get('style'):raise ValueError('Style description required')
    if recipe.get('adapter')!=f['adapter']:raise ValueError('Wrong family adapter; do not swap forest and indoor algorithms')
    for binding in recipe.get('assets',[]):
        source=ROOT/'godot'/binding['source'].removeprefix('res://')
        target=ROOT/'godot'/binding['target'].removeprefix('res://')
        for image in [source,target]:
            if not image.resolve().is_relative_to((ROOT/'godot/assets').resolve()):raise ValueError('Asset must be inside Godot assets')
            if not image.is_file():raise ValueError('Missing '+str(image))
        if digest(source)!=binding['source_sha256'] or digest(target)!=binding['target_sha256']:raise ValueError('Changed asset; repeat inspection')
        with Image.open(source) as a,Image.open(target) as b:
            if abs((a.width/a.height)/(b.width/b.height)-1)>.005:raise ValueError('Canvas aspect differs; cannot inherit reference placement')
        if source.resolve()!=target.resolve():
            metadata=binding.get('metadata',{})
            errors=inspect_asset(metadata,path.parent)['errors']
            if errors:raise ValueError('Replacement asset rejected: '+str(errors))
            if (path.parent/metadata['path']).resolve()!=target.resolve():raise ValueError('Metadata belongs to a different target')
            if not binding.get('layout_compatibility_review'):raise ValueError('Explicit support/opening/anchor compatibility review required')
        if binding['source'] in bindings:raise ValueError('Duplicate source binding')
        bindings[binding['source']]=binding['target'];hashes[binding['target']]=digest(target)
    if not bindings:raise ValueError('Recipe must explicitly bind its reference assets')
    output=ROOT/'godot/data/scene_production'/ (recipe['id']+'.json')
    compiled={'schema_version':1,'id':recipe['id'],'family':recipe['family'],'style':recipe['style'],'bindings':bindings,'asset_sha256':hashes,'recipe_sha256':digest(path),'adapter_sha256':digest(ROOT/f['adapter']),'status':'preview_candidate','publication_allowed':False}
    write(output,compiled);print(output)


def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest="action",required=True)
    keys=[f["id"] for f in read(FAMILIES)["families"]]
    p=sub.add_parser("prepare");p.add_argument("--family",choices=keys,required=True);p.add_argument("--name",required=True);p.add_argument("--style",required=True)
    p=sub.add_parser("inspect");p.add_argument("job")
    p=sub.add_parser("evidence");p.add_argument("directory")
    p=sub.add_parser("catalog");p.add_argument("directory");p.add_argument("--output",required=True)
    p=sub.add_parser("fit-frame");p.add_argument("spec")
    p=sub.add_parser("freeze");p.add_argument("job")
    p=sub.add_parser("compile");p.add_argument("recipe")
    p=sub.add_parser("capture");p.add_argument("--family",choices=keys,required=True);p.add_argument("--godot",required=True);p.add_argument("--output",required=True);p.add_argument("--recipe");p.add_argument("--cases",default="entry,junction2,junction3,left,right,center,battle,departure")
    args=parser.parse_args()
    return {"prepare":prepare,"inspect":inspect,"capture":capture,"evidence":evidence,"catalog":catalog,"fit-frame":fit_frame,"freeze":freeze,"compile":compile_recipe}[args.action](args) or 0


if __name__=="__main__":raise SystemExit(main())
