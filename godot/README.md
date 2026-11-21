# 大亨罗盘 · Godot 工程

Godot 4.7，GDScript。

## 目录

```
godot/
├── project.godot
├── core/            # 纯逻辑引擎（不依赖场景节点），与 Python 版 src/ 一一对应
│   ├── data_tables.gd        # 读取 res://data/*.json
│   ├── py_fmt.gd             # 与 Python 一致的舍入/格式化
│   ├── executive.gd · store.gd · company.gd · financial_statement.gd   # 数据模型
│   ├── cosmic_clock.gd       # 天时
│   ├── nine_palaces.gd       # 地利
│   ├── personnel.gd          # 人和
│   ├── simulation_engine.gd  # 月度结算
│   ├── effects.gd            # 数据驱动的效果系统
│   ├── campaign_manager.gd   # 按数据搭建关卡
│   ├── campaign_runner.gd    # 战役状态机
│   ├── insight.gd            # 月度盈亏解读与下月预告
│   ├── event_system.gd       # 随机事件
│   ├── office_item.gd · office_layout.gd   # 风水工位网格与审计（与 src/office_fengshui.py 对照）
│   ├── sandbox_game.gd · talent_pool.gd   # 二十年自由沙盒与人才市场（与 src/sandbox.py、src/talent_pool.py 对照，数据在 sandbox.json）
│   ├── crisis_war_room.gd    # 24小时危机公关指挥室（与 src/crisis_war_room.py 对照，数据在 crisis_scenarios.json）
│   └── save_game.gd          # 存档（与 Python 存档格式相同，两端可互读）
├── ui/            # 界面（全部用代码搭建，入口场景 scenes/main.tscn）
│   ├── main.gd               # 标题 ↔ 战役画面切换
│   ├── title_screen.gd       # 标题画面
│   ├── campaign_screen.gd    # 战役主界面：终端（结账单/现金走势/盈亏解读）+ 罗盘（三才因子/下月预告/操作）+ 高管卡
│   ├── dialogs/              # 开局决断、董事会议题、终局复盘、系统菜单、存档列表、设置（宣纸卡片风格）
│   ├── widgets/              # 高管卡（按状态切换表情）、现金走势图、三才因子条、等轴测办公室视图（含穿堂气流特效）
│   ├── audio.gd              # 自动加载 Audio：四季音乐交叉淡入淡出、音效
│   ├── compass_3d.gd         # 3D 罗盘（移植自 Ninefold Gate，贴图在 assets/textures/）
│   ├── office_screen.gd      # 企业总部风水工位：草稿布局上购置/移动/移除，确认后扣款生效
│   ├── sandbox_setup.gd · sandbox_screen.gd   # 自由沙盒：开局（行业/商号/资本/总部宫位）与主界面（人才市场、九宫拓店、门店一览、风水工位、快进一年）
│   ├── crisis_screen.gd      # 危机公关指挥室：倒计时、三阶段时间轴、舆情播报、应对选项、怒火/信任指标、在场高管
│   ├── settings.gd           # 自动加载 Settings：音量、全屏、自动存档（user://settings.cfg）
│   └── theme_builder.gd · palette.gd · money.gd · role_names.gd
├── assets/          # 美术与音频（规格见 docs/09_Art_Audio_Prompts.md）
├── data/            # 由 tools/sync_godot_data.py 从仓库根目录 data/ 同步，不要直接改
└── tests/
    ├── run_tests.gd          # 对照测试入口
    ├── ui_shots.gd           # 界面自动截图（自动玩一局）
    ├── capture_shots.gd · capture_crisis.gd · capture_sandbox.gd   # 截图与冒烟测试（战役一、危机公关、沙盒），输出到 store/screenshots/
    ├── record_trailer.gd     # 宣传片素材录制（Movie Maker）
    └── golden/               # Python 引擎的标准答案（tools/export_golden.py 生成）
```

## 运行游戏

```bash
godot --path godot
```

或在 Godot 编辑器中打开 `godot/project.godot` 后按 F5。基准分辨率 1920×1080，窗口默认 1600×900，可自由缩放（canvas_items + expand）。

## 存档、设置与快捷键

- 存档在 `user://saves/`（macOS：`~/Library/Application Support/DynastyTycoon/saves/`；网页版存在浏览器本地存储）：自动存档 + 三个手动槽位。每月议题处理完、等待操作时自动存档；战役结束后自动存档会被删除。
- **存档格式与 Python 版 `src/save_manager.py` 完全相同**：Godot 能读 Python 存档继续玩（`tests/golden/saves.json`），Python 也能读 Godot 存档（`tests/test_godot_parity.py`），两边续玩结果一致。
- 快捷键：空格/回车 推进本月，F 风水工位，Esc 系统菜单；对话框里按选项字母（A/B/C）或数字直接选择。
- 危机公关指挥室（案例十）是一局 24 小时、三次决断的短战，不支持存档；按 1/2/3 下达决断。
- 自由沙盒：每月自动存档，可手动存三格（存档带 `"mode": "sandbox"`，只有 Godot 版能读）。人才市场每 3 个月刷新。快捷键：空格 推进本月，Y 快进一年，H 人才市场，N 九宫拓店，S 门店一览，F 风水工位。

## 界面自动截图

自动玩完一局并在标题、开局决断、主界面、董事会议题、终局等画面截图（会打开一个窗口，结束后自动关闭）：

```bash
godot --path godot -s res://tests/ui_shots.gd -- <输出目录> [关卡编号] [开局选项] [play|systems]
```

`systems` 模式截取系统菜单、存档列表、设置、标题「继续游戏」与读档后的画面。截图脚本使用独立的 `user://shot_saves/`，不会覆盖玩家存档。

## 字体

所有平台（含网页版）都使用打包的开源字体，保证显示一致：

- `assets/fonts/NotoSerifSC-subset.ttf`（宋体，2.8 MB）、`NotoSansSC-subset.ttf`（黑体，2.0 MB），均为 SIL OFL 1.1 授权，授权文本在同目录。
- 由 `tools/subset_fonts.py` 从 Noto Serif SC / Noto Sans SC 可变字体裁剪：收入游戏数据与脚本中出现的全部字符 + GB2312 一级汉字 + 常用符号，保留字重轴（一个文件覆盖所有字重，界面用 `FontVariation` 选字重）。
- **新增文案出现生僻字时需要重新裁剪**：`python3 tools/subset_fonts.py <NotoSerifSC[wght].ttf> <NotoSansSC[wght].ttf>`（需要 `pip install fonttools`）。字体缺字时宋体会回落到黑体。
- 数字用黑体的等宽数字特性（tnum），不依赖系统等宽字体。

## 网页版与试玩发布

```bash
tools/publish_web.sh                                   # 只导出到 godot/export/web/
ITCH_GAME=用户名/游戏网址名 tools/publish_web.sh --push   # 导出并用 butler 推送到 itch.io（html5 频道）
```

- 导出预设 `export_presets.cfg` 的「Web」：单线程（无需特殊响应头，itch.io 可直接运行），网页版自动使用 Compatibility 渲染器。
- 包体约 40 MB（gzip 后）：引擎 wasm 约 10 MB，数据包约 30 MB（其中音乐约 20 MB）。大图（立绘、决策卡、场景、图标）导入为有损 WebP（质量 0.85），办公室地砖与道具保持无损。
- 门店与总部场景插画（`hq_*`、`store_*`）、风水特效草图等暂未用到的图在导出时排除；以后用到时从 `exclude_filter` 中删掉对应条目。
- 网页音频：所有播放器在网页上改用 Stream 播放，避免 Chrome 因总线回路把声音静音（沿用 Ninefold Gate 的修复）。
- 存档与试玩记录在网页版保存在浏览器本地存储（同一浏览器、同一网址下刷新后仍在）。

## 试玩记录

- 每局战役结束（通关/失败/破产）或中途离开时，在本机追加一行记录（`user://playtest_log.jsonl`）：开局决断、各议题选择、期末现金、末月利润、内耗、风水修正与办公室评分。字段与终端版 `play.py --playtest` 一致。
- 自由沙盒每局记一行：`"mode": "sandbox"`，含行业、结局评级、经营月数、净资产、门店数、高管岗位与门派、风水；提前封盘记为 `sealed`，中途离开记为 `quit`。
- 危机公关每局也记一行：`"mode": "crisis"`，含每步选择、终局类型（verdict）、终值怒火/信任、应急投入与商誉。
- 设置里可以关闭；「导出试玩记录」在设置和结局复盘界面：网页版直接下载文件，桌面版保存到用户目录并复制到剪贴板。

## 数据与一致性

- **数据只在仓库根目录 `data/` 里改。** 改完运行 `python3 tools/sync_godot_data.py` 同步到 `godot/data/`。
- **Python 版是标准答案。** 改了 Python 引擎逻辑或数值后，运行 `python3 tools/export_golden.py` 重新生成 `tests/golden/`，再跑 Godot 测试，确认两边一致。
- `python3 -m unittest discover -s tests` 会同时检查：数据已同步、golden 已更新、Godot 端对照测试通过（本机找不到 Godot 时跳过这一项，可用环境变量 `GODOT_BIN` 指定路径）。

## 运行测试

```bash
# 首次运行或新增 class_name 脚本后，先导入一次以生成全局类缓存
godot --headless --path godot --import
godot --headless --path godot -s res://tests/run_tests.gd
```

对照内容：天时/地利/人和因子表、跨引擎存档（读 Python 存档续玩）、风水审计（两个预设 + 300 个随机布局的评分与全部文字）、三个战役全部 165 条决策路径的逐月结账单、现金、月度解读文字与下月预告（逐字一致）、终局胜负与高管状态。

## 风水工位与平衡

- 网格、宫位、开局布局、物件目录与价格在 `data/office_items.json`。
- 改造只把**审计修正值变化的 30%**（`modifier_weight`）计入公司风水修正：总部改造影响全部门店营收，按全额计入时关卡一里错误的开局主决策也能靠一次改造通关，月度决策也失去意义。
- 关卡一（空间算法）的目标相应提高到年末现金 1.35 亿：不改造时约四分之一的正确路径能通关，完成改造后正确主决策都能通关，错误主决策即使满配改造加随机事件好运也不能通关（`tests/test_balance.py` 锁定）。
