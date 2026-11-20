# 09 · 美术与音频生成提示词（人物 / 场景 / 音乐 / 音效）

本文档面向 AI 生成工具（图像：Midjourney / SD / 即梦 等；音乐：Suno / Udio 等；音效：ElevenLabs SFX 等）。
图像与音乐提示词用英文（多数生成器对英文理解更稳定），每条附中文说明。

所有人物、场景和事件都与当前代码一一对应（`src/campaign.py`、`data/campaign_scenarios.json`、`src/office_fengshui.py`），文件名按 Godot 资源路径约定给出，生成后放到对应目录即可接入。

---

## 0. 统一风格基准（每条图像提示词都要带上）

**美术方向：新中式极简商业**。两层视觉：
- **数据层**：现代金融终端，深色底、细线、等宽数字、K线与报表。
- **玄学层**：水墨罗盘，宣纸质感、朱砂与鎏金点缀，气流与五行以墨色晕染表现。

**色板**

| 名称 | 色值 | 用途 |
|---|---|---|
| 宣纸米白 | `#F3EEE3` | 玄学层底色、卡牌底 |
| 墨黑 | `#1C1C1C` | 线稿、文字 |
| 终端深蓝黑 | `#0E1116` | 数据层底色 |
| 朱砂红 | `#C8372D` | 危机、亏损、印章 |
| 鎏金 | `#B8955A` | 吉位、通关、强调 |
| 青黛 | `#3D5A6C` | 中性信息、水 |
| 琥珀 | `#E8A33D` | 终端数据高亮 |

**五行配色**（人物服饰点缀、图标、宫位地图通用）

| 五行 | 主色 | 对应八门 | 对应宫位 |
|---|---|---|---|
| 木 | 竹青 `#4E7D5B` | 伤门、杜门 | 震三、巽四 |
| 火 | 朱砂 `#C8372D` | 景门 | 离九 |
| 土 | 赭石 `#A0743F` | 生门、死门 | 坤二、艮八、中五 |
| 金 | 月白/鎏金 `#D9D4C7` / `#B8955A` | 开门、惊门 | 乾六、兑七 |
| 水 | 玄青 `#2B3A4A` | 休门 | 坎一 |

**通用风格后缀**（复制到每条图像提示词末尾）

```
modern Chinese minimalist style, ink wash texture blended with clean flat vector shapes, rice paper grain, restrained palette of off-white, ink black, cinnabar red and muted gold, soft studio lighting, high detail, cohesive game art
```

**通用负面提示词**

```
text, letters, watermark, signature, logo, brand names, real company logos, extra fingers, deformed hands, cluttered background, neon cyberpunk, anime chibi, photorealistic skin pores, low resolution
```

**规格约定（Godot）**

| 类型 | 尺寸 | 格式 | 路径 |
|---|---|---|---|
| 人物立绘（半身） | 1024×1024，**品红平涂底生成 → 工具抠成透明底** | PNG（RGBA） | `res://assets/portraits/{角色id}_{表情}.png` |
| 事件/决策卡插画 | 1920×1080（16:9） | PNG/WebP | `res://assets/events/{决策点id}.png` |
| 场景背景 | 1920×1080 | PNG/WebP | `res://assets/scenes/{场景id}.png` |
| 等轴测地块/道具 | 地块 256×128（2:1），道具 256×256，透明底 | PNG | `res://assets/office/{物件id}.png` |
| 图标 | 256×256，透明底 | PNG（或 SVG） | `res://assets/icons/{类别}_{id}.png` |
| 音乐 | 可循环，-14 LUFS | OGG | `res://assets/music/{曲目id}.ogg` |
| 音效 | 0.1–3 秒，-16 LUFS | OGG/WAV | `res://assets/sfx/{音效id}.ogg` |

---

## 1. 人物立绘

### 1.1 表情规范

每个主要角色出 **4 个表情**，对应游戏内状态：

| 表情 id | 触发条件 | 提示词片段 |
|---|---|---|
| `neutral` | 默认 | `calm confident expression` |
| `pleased` | 决策成功、通关 | `subtle satisfied smile` |
| `stressed` | 压力 > 60 | `tired eyes, slight frown, loosened collar` |
| `angry` | 内耗冲突（伤杜相争等） | `tense jaw, sharp glare, arms crossed` |

**立绘通用前缀**：

```
half-body character portrait of a Chinese business executive, facing three-quarter view, isolated on a solid flat pure magenta (#FF00FF) background, no ink splashes or shadows on the background, consistent character design sheet,
```

**透明底流程**：大多数生成器输不出真正的透明通道，所以统一在**品红平涂底**上生成，再用工具抠掉：

```bash
python3 tools/remove_background.py --mode chroma 生成图/*.png --out assets/portraits
```

- 用品红而不用绿幕：伤门、杜门角色穿绿色（赵勇、张博、陈默），绿幕会把衣服一起抠掉。
- 水墨晕染只画在人物本身上，背景不要有泼墨，否则会粘在人物边缘抠不干净。同一角色的 4 个表情背景完全一致。
- 立绘风格后缀里的 `rice paper grain` 对立绘要去掉，以免背景出现纸纹；决策卡、场景保留。
- 旧的宣纸底图可以用 `--mode paper` 应急抠图，但粘在人物边缘的墨点去不干净；`--trim 31` 能去掉细碎墨点，但会连发簪之类的细长道具一起削掉，只对有粘连墨点的图使用。

### 1.2 常驻主角团（跨多个战役出场，形象必须统一）

#### 苏清墨（`su_qingmo`）· 景门 · 火
关卡一 CMO / 关卡三 CMO→CEO。品牌官，审美极强，关卡三中被扶正为 CEO。

```
[前缀] woman in her early 30s, elegant and visionary brand director, sleek low bun with a slim jade hairpin, tailored ivory blazer with subtle cinnabar-red cloud embroidery on the lapel, small red seal-shaped brooch, holding a tablet showing a mood board, warm red accent lighting, [表情], [风格后缀]
```
中文说明：景门属火、主审美与传播，红色点缀；气质是"有想法的品牌人"，不要过于妩媚。

#### 沈务本（`shen_wuben`）· 生门 · 土
关卡一、二、三都是 CFO。全游戏出场最多的角色，玩家最熟悉的"管钱的人"。

```
[前缀] man in his mid 40s, meticulous chief financial officer, round wire-rimmed glasses, neat side-parted hair with slight grey at temples, ochre-brown mandarin-collar suit, a tiny gold abacus tie clip, holding a leather ledger, warm earthy lighting, [表情], [风格后缀]
```
中文说明：生门属土、主财，赭石色调；可靠但有点抠门，"卡报销"的那种严谨。

#### 赵勇（`zhao_yong`）· 伤门 · 木
关卡一拓展 VP / 关卡三 CEO（被降为 VP 或被挖走）。狼性销售，冲劲大、易起冲突。

```
[前缀] man in his late 30s, aggressive sales vice president, short cropped hair, sleeves rolled up, open-collar dark green shirt under a charcoal vest, wristwatch, leaning forward with a pointing gesture, dynamic angular lighting, [表情], [风格后缀]
```
中文说明：伤门属木、主攻伐，竹青色；`angry` 表情要特别做好，关卡三开局就是这个状态。

### 1.3 关卡角色

#### 林凡（`lin_fan`）· 景门 · 火 —— 关卡一 CEO

```
[前缀] man around 40, founder and CEO of a modern Chinese bakery chain, clean short hair, charcoal suit with a cinnabar pocket square, holding a small elegant pastry gift box, optimistic gaze, [表情], [风格后缀]
```

#### 李道（`li_dao`）· 开门 · 金 —— 关卡二 CEO

```
[前缀] man in his mid 30s, determined founder of an AI education startup, minimalist white shirt and light grey jacket, silver-rimmed glasses, carrying a slim laptop, metallic gold accent light, [表情], [风格后缀]
```
中文说明：开门属金、主开拓与决断，月白与鎏金。

#### 张博（`zhang_bo`）· 杜门 · 木 —— 关卡二 CTO

```
[前缀] man in his early 30s, brilliant but reclusive chief technology officer, dark green hoodie, over-ear headphones around neck, messy hair, faint glow of code reflected on face, [表情], [风格后缀]
```

#### 陈默（`chen_mo`）· 杜门 · 木 —— 关卡三 首席科学家/CTO

```
[前缀] man in his mid 30s, quiet chief scientist of an embodied AI company, thin face, black turtleneck under a deep green cardigan, holding a folded architecture diagram, guarded posture, [表情], [风格后缀]
```
中文说明：关卡三的关键人物（可能离职），`stressed` 与 `pleased` 的差异要明显。

#### 温润生（`wen_runsheng`）· 休门 · 水 —— 关卡三 COO

```
[前缀] woman in her early 40s, calm and empathetic chief operating officer, shoulder-length hair, deep indigo linen jacket, holding a small celadon teacup, gentle soft lighting, [表情], [风格后缀]
```
中文说明：休门属水、主调和，玄青色；"陪他喝了三次茶"的那个人。

#### 危机公关指挥室成员（关卡十）

| id | 角色 | 提示词要点 |
|---|---|---|
| `gu_jingran` | 景门 CEO | `woman in her late 30s, poised social commerce platform CEO, crimson accent scarf, standing at a press podium` |
| `qian_shouxin` | 生门 CFO | `man in his 50s, stern veteran CFO, ochre suit, holding a thick compliance report` |
| `wen_he` | 休门 COO | `man in his 40s, soft-spoken operations chief, navy cardigan, phone in hand coordinating` |

### 1.4 人才市场通用头像（八门 × 男女 = 16 张）

人才市场有 40 位候选人，用通用头像按门派显示即可。路径：`res://assets/portraits/talent_{门派id}_{m|f}.png`。

```
[前缀] [man|woman] in their 30s or 40s, generic professional executive, outfit accent color [五行主色], symbolic accessory [门派配饰], neutral expression, [风格后缀]
```

| 门派 | 配饰 | 气质 |
|---|---|---|
| 开门 `kai_men` | 鎏金钢笔 | 决断、领导 |
| 休门 `xiu_men` | 青瓷茶杯 | 温和、调和 |
| 生门 `sheng_men` | 算盘袖扣 | 精明、务实 |
| 伤门 `shang_men` | 卷起的衬衫袖 | 冲劲、攻击性 |
| 杜门 `du_men` | 头戴式耳机 | 内向、专注 |
| 景门 `jing_men` | 玉簪/口袋巾 | 审美、表现力 |
| 死门 `si_men` | 黑色皮质文件夹 | 冷峻、守成 |
| 惊门 `jing_alarm_men` | 银色徽章、法典 | 善辩、警觉 |

---

## 2. 场景与界面

### 2.1 标题画面（`scenes/title`）

```
a giant ancient bronze luopan compass floating above a misty ink-wash skyline of modern Chinese megacities, glass towers fading into mountains, faint golden grid of nine palaces overlaid in the sky, financial data lines flowing like qi currents around the compass, epic yet minimal composition, wide 16:9, [风格后缀]
```

### 2.2 主界面概念图（`scenes/ui_mockup`，给 UI 设计参考，不直接入游戏）

```
game UI concept, split screen: left half a dark financial terminal with amber and teal candlestick charts, monospace numbers and thin grid lines on near-black #0E1116; right half an ink-wash bronze qimen compass on rice paper with eight gates and five element symbols, the two halves blending through flowing ink, executive portrait cards along the bottom, clean modern layout, 16:9, [风格后缀]
```

### 2.3 九宫商业地图（`scenes/nine_palace_map`）

```
stylized top-down map of China rendered as a 3x3 Lo Shu magic square grid with north at the top, each of the nine cells tinted by its five-element color: top-left northwest metal silver white, top-center north water dark blue, top-right northeast earth ochre, middle-left west metal silver white, center earth ochre, middle-right east wood bamboo green, bottom-left southwest earth ochre, bottom-center south fire cinnabar, bottom-right southeast wood bamboo green, minimalist city landmark silhouettes as small icons, thin gold borders between palaces, ink texture, no text, 16:9, [风格后缀]
```
中文说明：宫位与城市对应见 `src/sandbox.py` 的 `PALACE_OPTIONS`。地图需要能叠加门店图标，中间区域留白要够。

### 2.4 企业总部办公室（等轴测，风水工位系统）

整体参考图（`scenes/office_overview`）：

```
isometric 2.5D modern Chinese minimalist office floor, 9x9 tile grid, main entrance door at the bottom (south) edge, large floor-to-ceiling window at the top (north) edge, one exposed concrete ceiling beam crossing the room horizontally a third of the way from the top, light oak floor, white walls, warm daylight, clean empty layout ready for furniture placement, 2:1 isometric projection, [风格后缀]
```

道具（每件单独出图，`office/{id}.png`，透明底，2:1 等轴测视角）：

| id | 物件 | 提示词要点 |
|---|---|---|
| `desk_president` | 总裁实木大案 | `large dark walnut executive desk with leather chair` |
| `desk_finance` | 财务保密专案桌 | `compact steel-and-wood desk with a small safe and ledger` |
| `desk_cto` | CTO研发台 | `standing desk with three monitors and a small server rack` |
| `desk_sales` | 销售战区工位 | `cluster of open desks with headsets and a whiteboard` |
| `screen` | 紫檀木玄关屏风 | `tall red sandalwood folding screen with carved cloud pattern` |
| `plant` | 高叶招财树 | `tall money tree plant in a celadon pot` |
| `pixiu` | 汉白玉貔貅 | `white jade pixiu guardian statue on a small pedestal` |
| `wenchang` | 九层紫铜文昌塔 | `nine-tier bronze wenchang pagoda ornament` |
| `fishtank` | 流动生态鱼缸 | `low aquascape fish tank with green plants and small fish` |

道具提示词后缀：`single isolated game prop, isometric 2:1 view, transparent background, soft shadow, [风格后缀]`

地块：`tile_floor`（浅橡木地板）、`tile_beam`（横梁投影行，地板上叠一条淡淡的阴影带）、`tile_door`、`tile_window`。

**风水特效参考**（给特效制作参考的概念图）：
- `vfx_draft_sha` 穿堂煞：`translucent grey wind streaks rushing in a straight line from the door to the window across an isometric office, scattered paper, cold tone`
- `vfx_draft_blocked` 化煞：`the same wind current curving gently around a carved wooden screen, turning into soft golden swirls`

### 2.5 门店与总部（事件插画背景，`scenes/{id}`）

| id | 场景 | 提示词 |
|---|---|---|
| `store_shanghai` | 上海直营老店 | `elegant modern Chinese bakery storefront on a tree-lined Shanghai street, glass display of mooncake-style pastries, warm evening light` |
| `store_chengdu` | 成都/西安国潮概念店 | `vibrant guochao concept bakery with lantern decor and intangible heritage craft display, crowds taking photos, warm red tones` |
| `store_hefei` | 合肥/郑州下沉店 | `simple affordable neighborhood bakery kiosk in a busy logistics hub city, practical signage without text, daytime` |
| `hq_zhongguancun` | 北京中关村AI研发总部 | `cramped AI startup office at night, whiteboards full of diagrams, server lights, takeout boxes, determined atmosphere` |
| `hq_nanshan` | 深圳南山总部 | `sleek embodied AI robotics lab in a glass tower, robot arms on workbenches, tense team meeting in background` |
| `war_room` | 24小时危机公关指挥室 | `dark crisis war room with wall of screens showing trending social media graphs in red, a countdown clock, executives around a long table, cinematic tension` |

### 2.6 月度决策卡插画（`events/{决策点id}.png`）

对应 `data/campaign_scenarios.json` 中的 `decision_points`。画面只表现情境，不画选项。

| 决策点 id | 情境 | 提示词 |
|---|---|---|
| `s1_summer` | 离火当令·夏季客流高峰 | `summer heat shimmer over a guochao bakery, limited edition pastry gift boxes with cinnabar ribbons, queue of customers, blazing sun motif in ink` |
| `s1_rival` | 白虎猖狂·外资连锁对门开店 | `a white tiger ink silhouette looming over a rival western bakery chain opening across the street, autumn leaves, cold metallic tones` |
| `s1_winter` | 水旺克火·入冬客流下滑 | `snowy evening street, a bakery's warm window light fading, dark water-ink waves creeping over red lanterns, melancholic` |
| `s2_terms` | 螣蛇暗流·对赌协议隐藏条款 | `a contract on a dark desk with a faint ink serpent coiling between the lines, magnifying glass, lawyer's hand pointing at a clause` |
| `s2_pandemic` | 天时骤变·在线教育井喷 | `empty city streets in winter seen through an apartment window, while inside a laptop glows with an online class full of student video tiles` |
| `s2_milestone_hard` | 对赌到期·回购条款触发 | `investor boardroom with a looming hourglass, red ink deadline stamp, tense founder facing a long table of shadowed investors` |
| `s2_milestone_soft` | 对赌复盘·增长曲线 | `bright quarterly review meeting, rising growth chart projected on wall, investors nodding, cautious optimism` |
| `s3_scientist` | 杜门闭塞·首席科学家辞呈 | `a resignation letter on a lab bench beside a robot arm, a lone scientist silhouetted against a window at dusk, closed door motif` |
| `s3_poach` | 伤门躁动·竞对挖角 | `a headhunter sliding a thick envelope across a cafe table to an ambitious salesman, rival company tower in the background` |
| `s3_launch` | 景门照耀·新品发布会 | `grand product launch stage with a humanoid robot under spotlights, audience silhouettes, cinnabar and gold light beams` |

决策卡后缀：`cinematic illustration for a strategy game event card, 16:9, [风格后缀]`

### 2.7 图标（`icons/`）

| 类别 | 数量 | 提示词 |
|---|---|---|
| 八门 `gate_{id}` | 8 | `minimal circular emblem for the "[门名] gate" of qimen dunjia, single bold Chinese-style symbol, [五行主色] on rice paper, ink brush outline, flat icon` |
| 八神 `god_{id}` | 8 | `minimal emblem of the mythical [值符=celestial jade seal / 螣蛇=coiling serpent / 太阴=crescent moon veil / 白虎=white tiger head / 六合=six interlocking rings / 九地=mountain and earth layers / 九天=soaring crane in clouds / 勾陈=coiled hook dragon], ink and gold, flat icon` |
| 五行 `element_{id}` | 5 | `minimal five-element symbol for [wood/fire/earth/metal/water], [五行主色], ink brush, flat icon` |
| 季节 `season_{id}` | 4 | `minimal seasonal emblem: spring bamboo sprout / summer blazing sun / autumn falling ginkgo leaf / winter snow over water, ink, flat icon` |

图标统一后缀：`centered, transparent background, consistent stroke weight, game UI icon set`

---

## 3. 音乐

**整体方向**：东方极简 + 现代电子底色。民族乐器（古琴、琵琶、箫、笛、编钟、太鼓）做旋律和质感，柔和的合成器铺底和轻电子节拍表现现代商业。**全部纯器乐、不要人声**。

**核心设计：季节 BGM 随天时切换。** 战役中每月按季节（对应五行）切换背景音乐，让玩家用耳朵感受"旺相休囚死"。四首季节曲用同一个主旋律动机，只换配器和情绪，切换时才不会突兀。

| 曲目 id | 用途 | 时长 | 提示词 |
|---|---|---|---|
| `theme_main` | 主菜单/标题 | 2:00 可循环 | `instrumental, modern Chinese minimalist, guqin melody over soft analog synth pads, slow ink-wash ambience, subtle electronic pulse, grand but restrained, memorable 4-note motif, 80 bpm, loopable, no vocals` |
| `season_spring_wood` | 春季（木旺） | 3:00 可循环 | `instrumental, bright bamboo dizi flute carrying the main motif, plucked guzheng arpeggios, light hand percussion, hopeful growth energy, gentle lo-fi beat, 95 bpm, loopable, no vocals` |
| `season_summer_fire` | 夏季（火旺） | 3:00 可循环 | `instrumental, energetic pipa lead playing the main motif, driving frame drums and modern trap-lite hi-hats, warm synth brass, confident competitive heat, 110 bpm, loopable, no vocals` |
| `season_autumn_metal` | 秋季（金旺） | 3:00 可循环 | `instrumental, sparse bianzhong bronze bells and erhu playing the main motif, crisp metallic plucks, cool restrained mood, minimal electronic clicks, sense of harvest and pruning, 88 bpm, loopable, no vocals` |
| `season_winter_water` | 冬季（水旺） | 3:00 可循环 | `instrumental, breathy xiao flute playing the main motif slowly, deep cello drones, distant water drips, dark ambient synth, patient and introspective, 70 bpm, loopable, no vocals` |
| `decision_tension` | 董事会紧急议题 | 1:30 可循环 | `instrumental, suspenseful loop, low taiko heartbeat, sustained guqin harmonics, ticking clock texture, rising synth tension without resolving, 90 bpm, no vocals` |
| `crisis_war_room` | 24小时危机公关 | 2:30 可循环 | `instrumental, urgent crisis thriller cue, pulsing synth bass, rapid erhu ostinato, war drums, news-room ticking, escalating intensity, 128 bpm, loopable, no vocals` |
| `fengshui_studio` | 风水工位系统 | 2:30 可循环 | `instrumental, calm zen interior design music, soft guqin, wind chimes, flowing water ambience, warm pads, focused and relaxing, 72 bpm, loopable, no vocals` |
| `sandbox_era` | 二十年沙盒 | 4:00 可循环 | `instrumental, long-form strategy game ambience, evolving modern Chinese orchestral textures, slow guzheng and synth layers, sense of decades passing, 85 bpm, loopable, no vocals` |
| `sting_victory` | 通关 | 0:08 | `instrumental short victory sting, bright gong hit followed by rising pipa flourish and golden bell shimmer, triumphant, no vocals` |
| `sting_defeat` | 未达标 | 0:06 | `instrumental short defeat sting, descending erhu phrase over a soft low drum, reflective not tragic, no vocals` |
| `sting_bankrupt` | 破产 | 0:07 | `instrumental short bankruptcy sting, cracked bronze bell, heavy low gong, abrupt silence, somber, no vocals` |

**循环制作要点**：在 Suno/Udio 生成后，在音频软件里截取首尾可以无缝衔接的段落，导出 OGG，在 Godot 中勾选 Loop。季节曲之间建议做 2 秒交叉淡入淡出。

---

## 4. 音效

**整体方向**：UI 音效用传统器物的声音（算盘、印章、铜磬、宣纸），系统事件用现代声音（终端提示音、数据滴答），两者混用，和"终端 + 罗盘"的两层视觉对应。

### 4.1 界面

| 音效 id | 时机 | 时长 | 提示词 |
|---|---|---|---|
| `ui_click` | 普通按钮 | 0.1s | `single crisp wooden abacus bead click, dry, close-mic` |
| `ui_hover` | 悬停 | 0.05s | `very soft paper rustle tick, subtle` |
| `ui_confirm` | 确认决策 | 0.4s | `firm red cinnabar seal stamp pressing onto rice paper, satisfying thud` |
| `ui_cancel` | 取消/返回 | 0.2s | `soft paper slide back, muted` |
| `ui_error` | 不可选选项 | 0.25s | `dull muted wooden knock, gentle rejection` |
| `ui_tab_switch` | 终端/罗盘视图切换 | 0.6s | `ink brush swoosh blending into a soft digital glitch` |
| `compass_rotate` | 罗盘转动 | 1.2s | `heavy bronze disc rotating with fine gear ticks, resonant` |

### 4.2 经营流程

| 音效 id | 时机 | 时长 | 提示词 |
|---|---|---|---|
| `month_advance` | 推进月份 | 1.5s | `single resonant bronze temple bowl strike with long decay, followed by faint clock tick` |
| `report_print` | 月度结账单弹出 | 0.8s | `old dot-matrix printer brief burst mixed with paper unfolding` |
| `cash_gain` | 净利润为正 | 0.5s | `cascade of small copper coins dropping into a porcelain bowl, pleasant` |
| `cash_loss` | 净利润为负 | 0.5s | `low muffled coin slip and a soft descending tone` |
| `season_change` | 季节切换 | 2.0s | `wind chime transition shimmer with a soft whoosh, airy` |
| `forecast_up` | 下月天时上升 | 0.4s | `rising gentle guzheng glissando, short` |
| `forecast_down` | 下月天时下降 | 0.4s | `falling gentle guzheng glissando, short` |

### 4.3 决策与事件

| 音效 id | 时机 | 时长 | 提示词 |
|---|---|---|---|
| `decision_open` | 董事会议题出现 | 1.0s | `scroll unrolling quickly on a wooden table, then a low taiko hit` |
| `event_opportunity` | 吉事（景门得使等） | 1.0s | `bright bronze wind bells ringing upward, auspicious` |
| `event_crisis` | 凶事（白虎猖狂等） | 1.0s | `ominous large gong hit with metallic shimmer, short tail` |
| `event_tengshe` | 螣蛇暗流 | 1.2s | `subtle hissing whisper over a low dark drone, creeping` |
| `exec_hire` | 招募高管 | 0.6s | `seal stamp followed by a firm handshake leather creak` |
| `exec_leave` | 高管离职 | 0.8s | `office door closing softly, footsteps fading` |
| `friction_clash` | 内耗冲突提示 | 0.6s | `two short clashing metal blade scrapes, tense` |

### 4.4 风水工位

| 音效 id | 时机 | 时长 | 提示词 |
|---|---|---|---|
| `place_furniture` | 摆放家具 | 0.4s | `heavy wooden furniture set down on stone floor, solid thunk` |
| `place_artifact` | 摆放法器 | 0.6s | `jade or bronze object placed on wood, followed by a soft bell ping` |
| `sha_detected` | 检测到穿堂煞 | 1.5s | `cold wind rushing through a long corridor, papers fluttering` |
| `sha_resolved` | 化煞成功 | 1.5s | `wind slowing and swirling into calm, ending with a gentle wind chime` |
| `fengshui_score_up` | 风水评分提升 | 0.6s | `ascending celesta and guqin harmonic sparkle` |

### 4.5 门店与结局

| 音效 id | 时机 | 时长 | 提示词 |
|---|---|---|---|
| `store_open` | 开店 | 1.0s | `distant small festive firecracker crackle and a ribbon snip` |
| `store_close` | 关店 | 0.9s | `metal roller shutter coming down, final clank` |
| `bankrupt` | 破产 | 2.0s | `abacus beads scattering across a floor, heavy door slam, silence` |
| `victory` | 通关 | 2.5s | `big ceremonial gong, followed by layered bronze bells and a rising shimmer` |

---

## 5. 生成与交付清单

**第一批（试玩后马上用得到，优先做）**
- [x] 常驻主角团立绘：苏清墨、沈务本、赵勇 × 4 表情（batch1 已交付，待返修：见下方"batch1 审核"）
- [x] 关卡一的 3 张决策卡（`s1_summer`、`s1_rival`、`s1_winter`）（batch1 已交付，通过）
- [x] 主题曲 `theme_main` + 四季 BGM（audio-batch1 已交付）
- [x] 界面音效 4.1 全部 + `month_advance`、`cash_gain`、`cash_loss`、`ui_confirm`（audio-batch1 已交付）

**batch1 审核（2026-11-19）**
- 决策卡 3 张：通过。无文字、无标志，季节与五行意象准确。
- 三人的 `pleased` 与 `neutral` 几乎一样，需要重做 `pleased`，笑容要明显（`warm open smile, eyes slightly crinkled`）。
- `shen_wuben_stressed`：构图更近、脸型和其他三张不一致，且缺少账本，需要用 neutral 作角色参考重做。
- `zhao_yong_stressed`：读起来像"愤怒/较劲"而不是"疲惫"，需要重做（`exhausted, dark circles under eyes, slumped shoulders, loosened collar`）。
- 同一角色不同表情的背景墨点不一致（有的有泼墨、有的没有），游戏内切换表情时背景会跳变。→ 已决定改透明底。
- 已用 `tools/remove_background.py --mode paper` 把 12 张抠成透明底作为过渡版本放入 `assets/portraits/`；原宣纸底版本保存在 `assets_src/paper-portraits/`。沈务本 neutral/pleased、赵勇 neutral/angry 边缘还残留少量墨点。
- 返修时按新规范在品红底上**重新生成全部 12 张**，保证背景和边缘一致，再用 `--mode chroma` 抠图。

**第二批（第三步做 Godot 样章时用）**
- [x] 标题画面、主界面概念图、九宫地图（batch2，九宫地图待返修）
- [x] 办公室地块与道具全套、风水特效概念图（batch2，4 块地砖待返修）
- [x] 其余角色立绘与人才市场通用头像（batch2）
- [x] 其余决策卡、场景背景、图标（batch2）

**batch2 审核（2026-11-19）**：117 张图，已处理后放入 `assets/`，原图保存在 `assets_src/batch2-original/`。
- 通过：主角团 12 张重绘（表情差异明显、形象统一）、决策卡 7 张、场景 11 张、办公室道具 9 张、八门/八神/五行/季节图标。
- 已处理：
  - 主角团 12 张边缘有品红色晕（苏清墨发际线最明显），已用 `--mode despill` 去除。
  - 另外 8 个角色 32 张和人才头像 16 张是白底而不是品红底，已用 `--mode paper` 抠成透明底。约三分之一边缘残留粘连的墨点（李道双肩、温润生左侧、顾景然西装边缘、部分人才头像），可用于原型。
  - 8 张图标半透明边缘有品红溢色，已用 `--mode despill --edges-only` 去除（太阴的紫纱设计未改动）。
  - 八神图标原名 `god_zhifu` 等与数据 id 不一致，已改为 `god_zhi_fu`、`god_teng_she` 等。
- **待返修**：
  - `zhang_bo` × 4：镜头太近，neutral/pleased/stressed 看不到连帽衫和耳机，只有 angry 有，服装像是换了；乱发间夹着白底，抠图后头发里有白斑。按品红底规范重绘，构图同其他角色（胸口以上）。
  - `tile_floor` / `tile_beam` / `tile_door` / `tile_window`：四块几乎一样，且边缘是模糊羽化的，平铺时会出现接缝；门、窗地块看不出门和窗，横梁地块阴影带不明显。要求边缘清晰的 2:1 菱形、无外发光。
  - `nine_palace_map`：西北（左上）应为金·月白、东南（右下）应为木·竹青，原规格写错了，已更正上方提示词。
  - `element_wood` 与 `season_spring` 都是竹笋，月度解读里"春季"和"木"并排出现时容易混淆，建议把 `season_spring` 改成春燕或桃花。
  - 可选：边缘残留墨点的角色和人才头像，以后按品红底规范重绘可彻底干净。

**batch2 返修审核（全部batch2，2026-11-19）**：与 batch2 逐文件比对，只有上述 10 个返修文件有改动，其余 107 个完全相同。返修原图保存在 `assets_src/batch2-rework/`。
- `nine_palace_map`：九宫五行配色全部正确。通过。
- `season_spring`：改为桃花环，与 `element_wood` 区分开了。边缘品红溢色已用 `--mode despill --edges-only` 去除。通过。
- `zhang_bo` × 4：四个表情都露出连帽衫和耳机，服装统一；头发不再夹白底。仍是白底，已用 `--mode paper` 抠图。通过。
- 地砖 4 块：四块已经能区分，但边缘仍是模糊羽化，拼起来每块之间有一道暗缝。已用 `--mode tile` 修成边缘清晰的标准菱形，拼接无缝。
- `tile_beam`：原图阴影沿错误的对角线分割，一排横梁砖拼起来是斑马条纹。已改为用 `--mode beam` 由地板砖生成：沿网格 x 方向（对应代码 `beam_rows`）压暗一条柔和阴影带，同一行首尾相接成连续阴影。原 AI 图保留在 `assets_src/batch2-rework/office/`。

**地砖处理流程**

```bash
python3 tools/remove_background.py --mode tile 新地砖/tile_*.png --out assets/office
# 横梁砖由处理后的地板砖生成（先复制一份命名为 tile_beam.png）
python3 tools/remove_background.py --mode beam 临时目录/tile_beam.png --out assets/office
```
- [x] 其余音乐与音效（audio-batch2 已交付：7 首音乐 + 20 个音效，见下方"audio-batch2 审核"）

**audio-batch2 审核（2026-11-19）**
- 交付：`decision_tension`、`crisis_war_room`、`fengshui_studio`、`sandbox_era`、三个结局短曲，以及 4.2–4.5 节的 20 个音效。命名、时长与规格一致，音效开头无延迟（≤13ms）。
- 已用 `tools/audio_master.py` 统一处理后放入 `assets/music/`、`assets/sfx/`，原始文件保存在 `assets_src/audio-original/`：
  - 音乐原为 192 kHz，统一转为 48 kHz；响度归一到 -14 LUFS，真峰值 ≤ -1.2 dBTP。
  - 音效响度原本相差 23 dB（`victory` 极响、`exec_leave` 极轻），已按"最响 200ms 窗口"对齐并限幅到 -2 dBFS。
  - 循环点：`crisis_war_room` 原本就能无缝循环；`decision_tension` 开头有 0.7 秒静音、`fengshui_studio` 首尾有淡入淡出、`sandbox_era` 有约 20 秒的渐弱尾声，循环时都会断一下或掉音量，已切掉静音/淡入淡出并做首尾交叉淡化。
- **需要人耳确认**：三首重做循环点的曲子（尤其 `sandbox_era` 的循环点仍比主体轻约 7–10 dB，持续约 1 秒，可能是乐句本身的呼吸）以及所有音效的内容是否符合提示词。
- 第一批音频已在 audio-batch1 补齐（见下方）。

**audio-batch1 审核（2026-11-19）**：主题曲 + 四季 BGM + 10 个音效，至此音乐 12 首、音效 30 个全部到齐。
- 音乐同样是 192 kHz，已转 48 kHz 并归一到 -14 LUFS。`season_autumn_metal` 原本真峰值 +0.3 dB（会爆音）且比其他季节轻 3–4 dB；四季曲在游戏中会交叉切换，现已统一响度。
- 循环点：秋季结尾淡出、冬季开头淡入，已切掉后做首尾交叉淡化；春、夏、主题曲首尾电平接近，只做了 2.5 秒交叉淡化。冬季原曲结尾有一个渐强，现在落在循环起点，循环处是"约 1 秒轻 → 渐强"，**需要人耳确认**。
- 音效：`cash_loss` 原本比 `cash_gain` 响约 10 dB（亏钱比赚钱吵得多），已对齐。`ui_hover`、`ui_click` 播放频繁，按 -20 dBFS 处理，比其他音效轻 6 dB；其余按 -14。
- **需要人耳确认**：四季曲是否共用同一个主旋律动机（提示词要求的设计，无法用测量判断）、冬季循环点、各音效内容是否符合提示词。

**音频交付后处理命令**

```bash
# 能直接循环的曲子 / 短曲
python3 tools/audio_master.py music 新曲/*.ogg --out assets/music
# 首尾有淡入淡出、需要做循环点的曲子
python3 tools/audio_master.py music 新曲/xxx.ogg --trim-fades --loop-xfade 3 --out assets/music
# 音效
python3 tools/audio_master.py sfx 新音效/*.ogg --out assets/sfx
# 只测量不修改
python3 tools/audio_master.py check assets/music assets/sfx
```

**一致性检查**
- 同一角色的 4 个表情要用同一个种子，或者用角色参考图功能（如 Midjourney `--cref`）生成，保证脸一致。
- 图标、道具成套生成，保持笔触粗细一致。
- 不要在画面里出现真实品牌、真实机构名称或标志（关卡文案中的真实机构名也会在发售前替换为虚构名称）。
