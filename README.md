# 《商道玄机：大亨罗盘》（Dynasty Tycoon: The Cosmic Board）
## 游戏设计全案与工程规划索引

本目录为 Steam 商业模拟策略游戏《商道玄机：大亨罗盘》的本地完整游戏设计文档（GDD）、数据配置与生产排期规划。

---

### 目录结构索引

```
dynasty_tycoon/
├── README.md                           # 本文件：项目总览与架构索引
├── play.py                             # 【核心入口】Milestone 0 交互式终端模拟器
├── src/                                # 核心游戏与数理仿真引擎代码库
│   ├── __init__.py                     # 模块导出定义
│   ├── models.py                       # 数据结构体 (Company, Store, Executive, etc.)
│   ├── cosmic_clock.py                 # 【天时】大运、四季、月令、日辰干支神煞
│   ├── nine_palaces.py                 # 【地利】九宫格拓扑、租金与空间亲和度 f(S)
│   ├── personnel.py                    # 【人和】八门高管适岗匹配与组织内耗算法 f(P)
│   ├── office_fengshui.py              # 【建造】企业总部风水工位DIY与穿堂煞射线检测 (WBS 4.0)
│   ├── simulation_engine.py            # f(T,S,P) 全月经营结算与现金流引擎
│   ├── campaign.py                     # 关卡战役脚本（已实装关卡1-3及10大图谱入库）
│   ├── event_system.py                 # 动态突发事件与商战公关机
│   └── save_manager.py                 # 进度快照保存与载入系统
├── tests/                              # 自动化单元测试与数理验证套件
│   ├── test_simulation.py              # 核心公式与关卡数值回测
│   ├── test_campaigns.py               # 关卡一/二/三与10大战役底表校验
│   └── test_fengshui.py                # 穿堂煞、横梁压顶与风水调理测试 (12/12通过)
├── docs/                               # 核心游戏策划设计文档 (GDD)
│   ├── 01_Core_Systems.md              # 核心玩法循环与时空人引擎架构
│   ├── 02_Nine_Palaces_Map.md          # 【地利】九宫商业地图与地块模拟设计
│   ├── 03_Time_Cosmic_Cycles.md        # 【天时】三元九运、四季月令与冲煞系统
│   ├── 04_Personnel_EightGates.md      # 【人和】八门八神角色命格与内耗算法
│   ├── 05_Office_FengShui_Building.md  # 【空间建造】企业总部风水工位DIY系统
│   ├── 06_Business_Battles_PR.md       # 【商战】资本博弈、价格战与24H公关战
│   ├── 07_Campaign_Ten_Scenarios.md    # 【战役】十大传奇商战案例关卡脚本
│   ├── 08_Playtest_Guide.md            # 终端版试玩指南与访谈问卷
│   └── 09_Art_Audio_Prompts.md         # 人物/场景/音乐/音效生成提示词
├── assets/                             # 游戏美术资源（路径与 Godot res://assets/ 一致）
│   ├── portraits/                      # 人物立绘（透明底 RGBA）
│   ├── events/                         # 月度决策卡插画
│   ├── music/                          # 背景音乐与结局短曲（48kHz OGG，-14 LUFS）
│   └── sfx/                            # 音效（48kHz OGG，响度对齐）
├── assets_src/                         # 美术/音频源文件（原始生成文件、宣纸底版本）
├── godot/                              # Godot 4.7 工程（引擎移植与正式客户端），见 godot/README.md
├── data/                               # 核心数据配置文件 (JSON)，Python 与 Godot 共用的唯一数据源
│   ├── nine_palaces.json               # 九宫特区属性与五行生克配置表
│   ├── eight_gates.json                # 八门高管属性与适岗匹配表
│   ├── eight_gods.json                 # 八神隐性力量 Buff/Debuff 表
│   ├── engine_tables.json              # 引擎数值表：大运、月令、神煞、九宫亲和、八门适岗
│   ├── campaign_scenarios.json         # 十大战役：开局配置、主决策、月度决策点、通关条件
│   └── random_events.json              # 随机突发事件池
├── tools/                              # 数值原型与模拟脚本 (Python)
│   ├── simulation_engine.py            # f(T,S,P) 早期概念沙盘验证脚本
│   ├── campaign_paths.py               # 战役决策路径穷举（平衡性检查）
│   ├── sandbox_balance.py              # 沙盒机器人玩家结局分布模拟
│   ├── remove_background.py            # 立绘去背景（品红底抠像 / 宣纸底应急抠图）
│   ├── audio_master.py                 # 音频母带：采样率/响度/峰值统一，循环点制作
│   ├── export_golden.py                # 导出 Python 引擎标准答案，供 Godot 对照
│   └── sync_godot_data.py              # 把 data/ 同步到 godot/data/
└── project_management/                 # 生产节奏与项目管理
    └── WBS_Workload_And_Schedule.md    # WBS工作量拆解、团队人月与排期甘特图
```

---

### 快速启动与实机推演指令

```bash
# 1. 启动交互式终端模拟器 (进入战役第一关实机操作)
python3 play.py

# 2. 运行自动化单元测试套件
python3 -m unittest discover -s tests

# 3. 无头批量回测 (关卡一/二/三 + 自由沙盒)
python3 play.py --headless

# 4. 直接进入指定战役 / 读取存档继续
python3 play.py --scenario 2
python3 play.py --load

# 5. 试玩模式（记录每局决策与结果到 saves/playtest_log.jsonl）
python3 play.py --playtest
```

---

### 核心设计哲学
将《奇门商用》的核心决策模型落地为现代商业模拟游戏机制：
* **核心公式**：$\text{商业产出} = \text{Base} \times f(\text{天时}) \times f(\text{地利}) \times f(\text{人和}) - \text{固定成本}$
* **双层交互体验**：现代彭博终端机（数据流、K线、报表）与动态奇门罗盘（气流、五行、八门、神煞）无缝联动切换。
