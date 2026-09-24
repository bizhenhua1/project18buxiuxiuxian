"""Build a self-contained review page and contact sheets from actual captures."""
import argparse
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from scene_production import read, write, check_evidence

NAMES={'forest':'森林','swamp':'沼泽','crystal':'矿洞','sewer':'下水道','whale':'鲸腹','palace':'宫殿','red_cottage':'低顶室内'}
CASES={'entry':'入口 / 前进','junction2':'两岔路口','junction3':'三岔路口','left':'选择左路','right':'选择右路','center':'选择中路','battle':'战斗机位','departure':'战后继续前进'}

def build(root):
    root=Path(root).resolve();items=[];errors=[];font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',24)
    for family,title in NAMES.items():
        sheet=Image.new('RGB',(1440,1960),'#141e20');draw=ImageDraw.Draw(sheet)
        for i,(case,label) in enumerate(CASES.items()):
            path=root/family/case
            if not (path/'manifest.json').exists():errors.append(f'{family}/{case}: missing');continue
            problems=check_evidence(path);errors.extend(f'{family}/{case}: {e}' for e in problems)
            manifest=read(path/'manifest.json');settings=read(path/'settings.json')
            item={'family':family,'title':title,'case':case,'label':label,'beauty':f'{family}/{case}/beauty.png','diagnostic':f'{family}/{case}/diagnostic.png',
                  'phase':settings['phase'],'branch':settings['branch'],'seed':settings['seed'],'source_valid':not problems,
                  'manifest':f'{family}/{case}/manifest.json','test_victory':settings.get('test_victory_triggered',False),
                  'image_hashes':{c['kind']:c['sha256'] for c in manifest['captures']}}
            items.append(item)
            with Image.open(path/'beauty.png') as im:
                im=im.convert('RGB');im.thumbnail((716,447));x=(i%2)*720;y=(i//2)*490
                draw.text((x+12,y+8),title+' · '+label,font=font,fill='#ded4b6');sheet.paste(im,(x,y+40))
        sheet.save(root/(family+'-overview.jpg'),quality=92)
    payload=json.dumps(items,ensure_ascii=False).replace('</','<\\/')
    template='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>七类场景 · 关键镜头审查</title>
<style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#101719;color:#e6e3da;font:16px system-ui,"Microsoft YaHei"}header{padding:22px 28px;background:#1a272a;border-bottom:1px solid #56635c}h1{font-size:25px;margin:0 0 8px}p{color:#b3c1bc;margin:6px 0;line-height:1.6}nav{display:flex;gap:9px;flex-wrap:wrap;padding:15px 28px;background:#152125;position:sticky;top:0;z-index:2}select,button,textarea{font:inherit;background:#26383b;color:#f5eddb;border:1px solid #60726a;border-radius:5px;padding:8px 12px}button{cursor:pointer}button:hover{background:#36514f}a{color:#d5bb7c}main{padding:16px 28px}.images{display:grid;grid-template-columns:1fr;gap:14px}.images.split{grid-template-columns:1fr 1fr}figure{margin:0}figure img{width:100%;display:block;background:#050808;cursor:zoom-in}figcaption{padding:9px;background:#233336;color:#b9cec3}aside{display:grid;grid-template-columns:230px 1fr;gap:16px;margin-top:18px}textarea{width:100%;min-height:100px}#meta{font:13px monospace;overflow-wrap:anywhere}#thumbs{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:24px 0}#thumbs img{width:100%}#thumbs button{text-align:left;padding:4px}#thumbs .active{outline:2px solid #d5bb7c}.badge{color:#dcc28b}dialog{width:96vw;max-width:none;background:#101719;border:1px solid #667}dialog img{max-width:100%;height:auto}dialog::backdrop{background:#000d}@media(max-width:800px){main,header,nav{padding:12px}.images.split,aside{grid-template-columns:1fr}#thumbs{grid-template-columns:repeat(2,1fr)}}
</style><header><h1>七类场景 · 关键镜头审查</h1><p>__COUNT__ 个真实状态 · 正式光照 / 开灯诊断。截图完成不代表视觉已通过，请直接标记需要调整的镜头。</p><p>暗场允许自然的背景与雾衔接；诊断露空不自动判失败。战后镜头由测试触发真实胜利流程，不代表自动打赢战斗。</p></header>
<nav><select id="family"></select><select id="shot"></select><select id="mode"><option value="beauty">正式光照</option><option value="diagnostic">开灯诊断</option><option value="split">并排对照</option></select><button id="prev">上一镜头</button><button id="next">下一镜头</button><a id="original" target="_blank">打开原图</a><a id="overview" target="_blank">本类八镜头总览</a><button id="export">导出审查意见</button></nav>
<main><div id="images" class="images"></div><p id="meta"></p><aside><div><p>这个镜头的意见</p><select id="decision"><option value="unreviewed">尚未审查</option><option value="accepted">可以接受</option><option value="changes">需要调整</option><option value="question">需要解释</option></select><p class="badge">意见只保存在本机浏览器；导出后可发给后续执行者。</p></div><textarea id="note" placeholder="例如：左转时拱肩太低；正式光照可接受，不用补诊断图中的顶缝。"></textarea></aside><div id="thumbs"></div></main><dialog id="zoom"><button onclick="this.parentElement.close()">关闭</button><img></dialog>
<script>const data=__DATA__;const titles=__TITLES__, labels=__LABELS__;const $=id=>document.getElementById(id);let notes={};try{notes=JSON.parse(localStorage.getItem('scene-workflow-review-v1')||'{}')}catch(e){};for(const [k,v]of Object.entries(titles))$('family').add(new Option(v,k));for(const[k,v]of Object.entries(labels))$('shot').add(new Option(v,k));
function current(){return data.find(x=>x.family===$('family').value&&x.case===$('shot').value)}function key(){return $('family').value+'/'+$('shot').value}function save(){notes[key()]={decision:$('decision').value,note:$('note').value,image_hashes:current()?.image_hashes};try{localStorage.setItem('scene-workflow-review-v1',JSON.stringify(notes))}catch(e){}}
function show(){let item=current();if(!item){$('images').textContent='此镜头尚未成功采集';return}const modes=$('mode').value==='split'?['beauty','diagnostic']:[$('mode').value];$('images').className='images'+(modes.length===2?' split':'');$('images').replaceChildren();for(let mode of modes){let f=document.createElement('figure'),im=new Image(),cap=document.createElement('figcaption');im.src=item[mode];im.alt=item.title+' '+item.label;cap.textContent=item.title+' · '+item.label+' · '+(mode==='beauty'?'正式光照':'开灯诊断');im.onclick=()=>{$('zoom').querySelector('img').src=im.src;$('zoom').showModal()};f.append(im,cap);$('images').append(f)}$('meta').textContent='状态 '+item.phase+' · 分支 '+item.branch+' · 种子 '+item.seed+' · '+(item.source_valid?'源文件校验通过':'源文件已变化：需要重验');$('original').href=item[$('mode').value==='diagnostic'?'diagnostic':'beauty'];$('overview').href=item.family+'-overview.jpg';$('decision').value=notes[key()]?.decision||'unreviewed';$('note').value=notes[key()]?.note||'';$('thumbs').replaceChildren();for(const x of data.filter(x=>x.family===item.family)){const b=document.createElement('button'),im=new Image();im.src=x.beauty;im.loading='lazy';b.append(im,document.createTextNode(x.label));b.className=x.case===item.case?'active':'';b.onclick=()=>{$('shot').value=x.case;show()};$('thumbs').append(b)}}
for(const id of ['family','shot','mode'])$(id).onchange=show;$('decision').onchange=save;$('note').oninput=save;function advance(n){let keys=Object.keys(labels),i=keys.indexOf($('shot').value);$('shot').value=keys[(i+n+keys.length)%keys.length];show()}$('prev').onclick=()=>advance(-1);$('next').onclick=()=>advance(1);$('export').onclick=()=>{const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify({created:new Date().toISOString(),reviews:notes},null,2)],{type:'application/json'}));a.download='场景镜头审查.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};show();</script></html>'''
    template=template.replace('__DATA__',payload).replace('__COUNT__',str(len(items))).replace('__TITLES__',json.dumps(NAMES,ensure_ascii=False)).replace('__LABELS__',json.dumps(CASES,ensure_ascii=False))
    (root/'index.html').write_text(template,encoding='utf-8')
    write(root/'review-manifest.json',{'shots':len(items),'expected_shots':len(NAMES)*len(CASES),'source_checks_passed':not errors,'errors':errors,'visual_accepted':False,'items':items})
    print(root/'index.html');print(f'{len(items)} shots, {len(errors)} provenance/missing errors')
    return int(bool(errors))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',required=True);raise SystemExit(build(p.parse_args().input))
