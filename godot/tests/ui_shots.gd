extends SceneTree
## 界面自动截图：自动玩一局并在关键画面截图（需要有窗口，不能 --headless）
## 运行：godot --path godot -s res://tests/ui_shots.gd -- <输出目录> [关卡编号] [开局选项]

const Driver := preload("res://tests/ui_shot_driver.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var d := Driver.new()
	d.out_dir = args[0] if args.size() > 0 else "user://shots"
	d.scenario_id = int(args[1]) if args.size() > 1 else 1
	d.main_choice = args[2] if args.size() > 2 else "B"
	root.add_child(d)
