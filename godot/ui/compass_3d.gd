class_name Compass3D extends Sprite2D

## 2.5D 罗盘：在 SubViewport 中实时渲染一个倾斜的 3D 青铜罗盘，贴回 2D 场景。
## 移植自 Ninefold Gate（scripts/Compass3D.gd），改动：缩放改为可配置的 base_scale。
## 盘面、外环、指针分层旋转；起局时调用 spin()。

const VIEW_SIZE := Vector2i(900, 900)
const DIAL_TEX: Texture2D = preload("res://assets/textures/compass_dial.png")
const OUTER_TEX: Texture2D = preload("res://assets/textures/compass_outer.png")

var _viewport: SubViewport
var _dial: Node3D        # 盘面（内盘，随推演转动）
var _outer: Node3D       # 外环（缓慢反向旋转）
var _needle: Node3D      # 指南针
var _idle_speed := 0.05  # 弧度/秒
var _needle_wobble := 0.0
var _time := 0.0

## 罗盘显示缩放（3D 视口为 900×900 像素）
@export var base_scale := 0.68

func _ready() -> void:
	material = null
	modulate = Color(0.78, 0.74, 0.7)
	_build()
	texture = _viewport.get_texture()
	scale = Vector2.ONE * base_scale

func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.48)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 4.3, 2.35)
	_viewport.add_child(cam)
	cam.look_at(Vector3(0, 0, 0.05), Vector3.UP)

	# 主光：左上暖光；补光：右侧冷光，让金属有明暗
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.82, 0.58)
	key.light_energy = 0.75
	key.rotation_degrees = Vector3(-55, -35, 0)
	_viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.45, 0.55, 1.0)
	rim.light_energy = 1.1
	rim.omni_range = 6.0
	rim.position = Vector3(2.2, 1.0, -1.2)
	_viewport.add_child(rim)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.3)
	glow.light_energy = 0.35
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.9, 0)
	_viewport.add_child(glow)

	var root := Node3D.new()
	_viewport.add_child(root)

	# 青铜底盘：厚圆盘 + 外缘金属环
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.08
	cyl.bottom_radius = 1.14
	cyl.height = 0.16
	cyl.radial_segments = 96
	base.mesh = cyl
	base.material_override = _bronze(Color(0.12, 0.09, 0.07), 0.8, 0.5)
	base.position.y = -0.09
	root.add_child(base)

	var rim_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.03
	torus.outer_radius = 1.13
	torus.rings = 96
	torus.ring_segments = 16
	rim_ring.mesh = torus
	rim_ring.material_override = _bronze(Color(0.42, 0.31, 0.16), 0.95, 0.3)
	rim_ring.position.y = 0.0
	root.add_child(rim_ring)

	# 外环（二十四山）与内盘贴图分层，略微抬高形成层次
	_outer = Node3D.new()
	root.add_child(_outer)
	_outer.add_child(_disc(OUTER_TEX, 2.06, 0.012))

	_dial = Node3D.new()
	root.add_child(_dial)
	_dial.add_child(_disc(DIAL_TEX, 1.86, 0.03))
	var inner_ring := MeshInstance3D.new()
	var t2 := TorusMesh.new()
	t2.inner_radius = 0.9
	t2.outer_radius = 0.94
	t2.rings = 96
	t2.ring_segments = 8
	inner_ring.mesh = t2
	inner_ring.material_override = _bronze(Color(0.7, 0.52, 0.25), 0.95, 0.3)
	inner_ring.position.y = 0.035
	_dial.add_child(inner_ring)

	# 天池中心与指南针
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.13
	hub_mesh.bottom_radius = 0.15
	hub_mesh.height = 0.08
	hub.mesh = hub_mesh
	hub.material_override = _bronze(Color(0.55, 0.4, 0.2), 0.9, 0.3)
	hub.position.y = 0.07
	root.add_child(hub)

	_needle = Node3D.new()
	_needle.position.y = 0.13
	root.add_child(_needle)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.75, 0.08, 0.05)
	red.emission_enabled = true
	red.emission = Color(0.9, 0.15, 0.05)
	red.emission_energy_multiplier = 0.6
	red.roughness = 0.4
	for dir: float in [1.0, -1.0]:
		var half := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.07, 0.42, 0.02)
		half.mesh = prism
		half.material_override = red if dir > 0 else _bronze(Color(0.75, 0.6, 0.3), 0.9, 0.25)
		half.rotation_degrees = Vector3(-90, 0, 0) if dir > 0 else Vector3(90, 0, 0)
		half.position.z = -0.21 * dir
		_needle.add_child(half)

func _disc(tex: Texture2D, size: float, y: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	m.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.2
	mat.metallic = 0.55
	mat.roughness = 0.45
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.material_override = mat
	m.position.y = y
	return m

func _bronze(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.metallic = metallic
	mat.roughness = rough
	return mat

func _process(delta: float) -> void:
	_time += delta
	_dial.rotation.y += _idle_speed * delta
	_outer.rotation.y -= _idle_speed * 0.4 * delta
	# 指针轻微摆动，像真的磁针
	_needle.rotation.y = _needle_wobble + sin(_time * 1.3) * 0.05

## 起局：内盘转 degrees 度，外环反转，指针快速旋转后定住
func spin(degrees: float = 120.0, duration: float = 0.7) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dial, "rotation:y", _dial.rotation.y + deg_to_rad(degrees), duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_outer, "rotation:y", _outer.rotation.y - deg_to_rad(degrees * 0.35), duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_needle_wobble", _needle_wobble + TAU * 2.0 + randf_range(-0.6, 0.6), duration * 1.4) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var bump := create_tween()
	bump.tween_property(self, "scale", Vector2.ONE * base_scale * 1.045, duration * 0.25)
	bump.tween_property(self, "scale", Vector2.ONE * base_scale, duration * 0.75).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
