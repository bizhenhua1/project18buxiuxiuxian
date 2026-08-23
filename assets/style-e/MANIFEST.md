# style-e 量产第一批（低级）

画风：风格五 · 敦煌矿物平涂。原图纯品红 `#FF00FF`，本地 `generate2dsprite.py` 抠成透明 PNG（threshold 80 / edge 170）。

- 成品：`assets/style-e/style-e-{type}-{id}.png`（768 透明）
- 品红原图：`assets/style-e/raw/`
- 处理中间件：`assets/style-e/process/{id}/`

| ID | 类型 | 中文 | 说明 |
| --- | --- | --- | --- |
| `char-daotong` | 主角 | 道童 | 男性年轻道修，石绿道袍，腰间桃木剑，无金圆、无光环 |
| `artifact-taomu-jian` | 法宝 | 桃木剑 | 短木剑，朱砂符绦 |
| `artifact-waci-yin` | 法宝 | 瓦瓷印 | 方印，云纹，非梵文 |
| `artifact-masuo` | 法宝 | 麻索 | 麻绳盘，朱结，不绕身 |
| `artifact-tongjing` | 法宝 | 铜镜 | 圆铜镜，云纹边 |
| `artifact-xiaohulu` | 法宝 | 小葫芦 | 双腹葫芦，石绿绳 |
| `monster-huoli` | 怪物 | 火狸 | 小狐精，单尾 |
| `monster-caoshe` | 怪物 | 草蛇 | 石绿小蛇 |
| `monster-yewu` | 怪物 | 野乌 | 乌鸦精，非金翅大鹏 |
| `monster-jinchan` | 怪物 | 金蟾 | 蟾蜍精，无散钱 |
| `monster-shujing` | 怪物 | 鼠精 | 后腿站立，石绿布带 |
| `monster-yezhu` | 怪物 | 野猪 | 幼野猪精 |
| `monster-xiaoqiao` | 怪物 | 小蛟 | 幼河蛟，盘成图标 |
| `monster-shanyang` | 怪物 | 山羊 | 山山羊精 |
| `monster-huangfeng` | 怪物 | 黄蜂 | 单只黄风蜂，非蜂群 |
| `monster-shitoujing` | 怪物 | 石头精 | 矮石精，非夜叉金刚 |

卡面方案 2 只引用本目录成品，不要用 `raw/` 或 `style-e-adapt-*.png` 整图。
