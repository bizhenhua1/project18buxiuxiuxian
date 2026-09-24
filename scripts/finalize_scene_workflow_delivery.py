"""Refresh delivery status from actual review evidence; never grant visual acceptance."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'art/scene-workflow-review/2026-09-21'
manifest = json.loads((REVIEW / 'review-manifest.json').read_text(encoding='utf-8'))
families = list(dict.fromkeys(i['family'] for i in manifest['items']))
status = {
    'status': 'seven_reference_workflows_executed_visual_acceptance_pending',
    'scope': 'Seven existing families and compatible asset recipes; not arbitrary geometry or mixed-theme certification',
    'review': REVIEW.relative_to(ROOT).as_posix() + '/index.html',
    'key_states': manifest['shots'], 'paired_pngs': manifest['shots'] * 2,
    'source_checks_passed': manifest['source_checks_passed'],
    'generated_asset_examples': 1,
    'new_recipe_runtime_example': 'room_oak_study',
    'families': [], 'open_issues': 'OPEN-ISSUES.md', 'accepted': False,
}
for family in families:
    items = [i for i in manifest['items'] if i['family'] == family]
    profile = json.loads((REVIEW / 'performance' / (family + '.json')).read_text(encoding='utf-8'))
    status['families'].append({'family': family, 'recipe': 'godot/data/scene_production/reference_' + family + '.json',
                             'captured_states': [i['case'] for i in items],
                             'source_valid': all(i['source_valid'] for i in items),
                             'performance_smoke': profile, 'accepted': False})
(ROOT / 'scene-production/current-status.json').write_text(json.dumps(status, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
readme = ROOT / 'scene-production/README.md'
s = readme.read_text(encoding='utf-8')
s = s.replace('**工作流接入与验证中**', '**七类参考配方和八镜头回放已执行，视觉验收待审查**')
s = s.replace('七个阶段', '八个阶段').replace('七例成功', '八例成功').replace('七种状态', '八种状态').replace('十种检查正反例', '十二种检查正反例')
s = s.replace('角色与相机的完整动画扫掠检查仍须补齐', '静态挂饰已合为两批，路线相机采样净空已检查；任意相机与角色完整动画扫掠仍须补齐')
s += '\n## 本轮实际交付（2026-09-21）\n\n优先阅读 [完整执行手册](WORKFLOW-RUNBOOK.md) 和 `types/` 下七份专用工作单。真实配方在 `recipes/`，编译结果在 `godot/data/scene_production/`。\n\n截图审查页：`art/scene-workflow-review/2026-09-21/index.html`，共56状态、112张1440×900正式/诊断原图，源文件校验均通过。七类各有八镜头总览；页面可记录和导出意见。\n\n新生成木材图也已通过 `room_oak_study` 配方完成独立运行截图，证明资产到配方再到运行时的链路；不将材质替换例称为独立完成的新美术场景。\n\n每类完成120帧预热、300帧行进/左岔采样。p95约12.1–21.2ms，森林超过16.67ms，单帧峰值59–90ms；这不是全程无卡顿或50怪物技能压测达标证明。原始记录随截图保存。\n\n低顶室内仍有空旷、顶面边界生硬的问题；七类均未自动标成视觉通过。跨主题顶归属、任意形状资产自动接入、连续过程及完整负载验收仍按问题表管理。\n'
readme.write_text(s, encoding='utf-8')
print('Delivery status updated from', manifest['shots'], 'actual states')
