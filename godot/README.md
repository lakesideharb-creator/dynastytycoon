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
├── data/            # 由 tools/sync_godot_data.py 从仓库根目录 data/ 同步，不要直接改
└── tests/
    ├── run_tests.gd          # 对照测试入口
    └── golden/               # Python 引擎的标准答案（tools/export_golden.py 生成）
```

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
