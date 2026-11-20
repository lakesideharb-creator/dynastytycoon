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
│   └── event_system.gd       # 随机事件
├── ui/            # 界面（全部用代码搭建，入口场景 scenes/main.tscn）
│   ├── main.gd               # 标题 ↔ 战役画面切换
│   ├── title_screen.gd       # 标题画面
│   ├── campaign_screen.gd    # 战役主界面：终端（结账单/现金走势/盈亏解读）+ 罗盘（三才因子/下月预告/操作）+ 高管卡
│   ├── dialogs/              # 开局决断、董事会议题、终局复盘（宣纸卡片风格）
│   ├── widgets/              # 高管卡（按状态切换表情）、现金走势图、三才因子条
│   ├── audio.gd              # 自动加载 Audio：四季音乐交叉淡入淡出、音效
│   ├── compass_3d.gd         # 3D 罗盘（移植自 Ninefold Gate，贴图在 assets/textures/）
│   └── theme_builder.gd · palette.gd · money.gd · role_names.gd
├── assets/          # 美术与音频（规格见 docs/09_Art_Audio_Prompts.md）
├── data/            # 由 tools/sync_godot_data.py 从仓库根目录 data/ 同步，不要直接改
└── tests/
    ├── run_tests.gd          # 对照测试入口
    ├── ui_shots.gd           # 界面自动截图（自动玩一局）
    └── golden/               # Python 引擎的标准答案（tools/export_golden.py 生成）
```

## 运行游戏

```bash
godot --path godot
```

或在 Godot 编辑器中打开 `godot/project.godot` 后按 F5。基准分辨率 1920×1080，窗口默认 1600×900，可自由缩放（canvas_items + expand）。

## 界面自动截图

自动玩完一局并在标题、开局决断、主界面、董事会议题、终局等画面截图（会打开一个窗口，结束后自动关闭）：

```bash
godot --path godot -s res://tests/ui_shots.gd -- <输出目录> [关卡编号] [开局选项]
```

## 字体（网页导出前必须处理）

目前用系统字体（`SystemFont`）：正文黑体 Hiragino Sans GB / STHeiti，标题与宣纸卡片宋体 Songti SC，数字 Menlo。只适用于 macOS 本机运行：

- macOS 上 "PingFang SC" 会解析成 PingFang HK，缺少部分简体字（如"杂"），因此没有用苹方。
- Songti SC 的 ¥ 字形为空白，含金额的文字一律用黑体。
- 网页版和其他平台没有这些系统字体，M5 导出前需要打包开源的 Noto Serif SC / Noto Sans SC（OFL 授权），可参考 Ninefold Gate 的 `tools/subset_font.py` 做子集化减小体积。

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

对照内容：天时/地利/人和因子表、三个战役全部 165 条决策路径的逐月结账单、现金、月度解读文字与下月预告（逐字一致）、终局胜负与高管状态。
