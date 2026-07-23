@tool
extends MeshInstance3D

@export_group("Preview")
@export var quad_size: Vector2 = Vector2(0.9, 2.7):
	set(value):
		quad_size = Vector2(maxf(value.x, 0.05), maxf(value.y, 0.05))
		_queue_apply()
@export_range(1, 8, 1) var preview_stage: int = 8:
	set(value):
		preview_stage = clampi(value, 1, 8)
		_queue_apply()

@export_group("Colors")
@export var core_color: Color = Color(0.92, 0.97, 1.0, 1.0):
	set(value):
		core_color = value
		_queue_apply()
@export var glow_color: Color = Color(0.2, 0.62, 1.0, 1.0):
	set(value):
		glow_color = value
		_queue_apply()

@export_group("Shape")
@export_range(0.002, 0.2, 0.001) var core_width: float = 0.02:
	set(value):
		core_width = value
		_queue_apply()
@export_range(0.01, 0.6, 0.001) var glow_width: float = 0.15:
	set(value):
		glow_width = value
		_queue_apply()
@export_range(0.0, 0.5, 0.001) var jitter: float = 0.2:
	set(value):
		jitter = value
		_queue_apply()
@export_range(1.0, 50.0, 0.1) var detail_scale: float = 16.0:
	set(value):
		detail_scale = value
		_queue_apply()

@export_group("Motion")
@export_range(0.0, 20.0, 0.01) var bolt_speed: float = 7.5:
	set(value):
		bolt_speed = value
		_queue_apply()
@export_range(0.0, 80.0, 0.1) var flicker_speed: float = 42.0:
	set(value):
		flicker_speed = value
		_queue_apply()

@export_group("Flash")
@export_range(1.0, 80.0, 0.1) var flash_rate: float = 24.0:
	set(value):
		flash_rate = value
		_queue_apply()
@export_range(0.01, 0.5, 0.001) var flash_width: float = 0.1:
	set(value):
		flash_width = value
		_queue_apply()
@export_range(0.0, 1.0, 0.01) var flash_persistence: float = 0.88:
	set(value):
		flash_persistence = value
		_queue_apply()
@export_range(0.0, 1.0, 0.01) var idle_brightness: float = 0.2:
	set(value):
		idle_brightness = value
		_queue_apply()
@export_range(0.1, 8.0, 0.01) var flash_boost: float = 3.4:
	set(value):
		flash_boost = value
		_queue_apply()

@export_group("Branches")
@export_range(0.0, 2.0, 0.01) var branch_strength: float = 0.75:
	set(value):
		branch_strength = value
		_queue_apply()
@export_range(0.0, 2.0, 0.01) var branch_spread: float = 1.2:
	set(value):
		branch_spread = value
		_queue_apply()
@export_range(0.05, 1.0, 0.01) var branch_fade: float = 0.4:
	set(value):
		branch_fade = value
		_queue_apply()
@export_range(0.0, 0.2, 0.001) var branch_root_softness: float = 0.045:
	set(value):
		branch_root_softness = value
		_queue_apply()

@export_group("Energy")
@export_range(0.0, 60.0, 0.1) var core_energy: float = 18.0:
	set(value):
		core_energy = value
		_queue_apply()
@export_range(0.0, 40.0, 0.1) var glow_energy: float = 8.0:
	set(value):
		glow_energy = value
		_queue_apply()

@export_group("Alpha")
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0:
	set(value):
		opacity = value
		_queue_apply()
@export_range(0.0, 1.0, 0.01) var alpha_cutoff: float = 0.015:
	set(value):
		alpha_cutoff = value
		_queue_apply()

var _shader_material: ShaderMaterial
var _runtime_flash_multiplier: float = 1.0

func _ready() -> void:
	_apply_settings()

func _queue_apply() -> void:
	if not is_inside_tree():
		return
	call_deferred("_apply_settings")

func _apply_settings() -> void:
	_ensure_quad_mesh()
	_ensure_shader_material()

	if _shader_material == null:
		return

	_shader_material.set_shader_parameter("core_color", core_color)
	_shader_material.set_shader_parameter("glow_color", glow_color)
	_shader_material.set_shader_parameter("core_width", core_width)
	_shader_material.set_shader_parameter("glow_width", glow_width)
	_shader_material.set_shader_parameter("jitter", jitter)
	_shader_material.set_shader_parameter("detail_scale", detail_scale)
	_shader_material.set_shader_parameter("bolt_speed", bolt_speed)
	_shader_material.set_shader_parameter("flicker_speed", flicker_speed)
	_shader_material.set_shader_parameter("flash_rate", flash_rate)
	_shader_material.set_shader_parameter("flash_width", flash_width)
	_shader_material.set_shader_parameter("flash_persistence", flash_persistence)
	_shader_material.set_shader_parameter("idle_brightness", idle_brightness)
	_shader_material.set_shader_parameter("flash_boost", flash_boost)
	_shader_material.set_shader_parameter("branch_strength", branch_strength)
	_shader_material.set_shader_parameter("branch_spread", branch_spread)
	_shader_material.set_shader_parameter("branch_fade", branch_fade)
	_shader_material.set_shader_parameter("branch_root_softness", branch_root_softness)
	_shader_material.set_shader_parameter("core_energy", core_energy)
	_shader_material.set_shader_parameter("glow_energy", glow_energy)
	_shader_material.set_shader_parameter("opacity", opacity)
	_shader_material.set_shader_parameter("alpha_cutoff", alpha_cutoff)
	_shader_material.set_shader_parameter("runtime_flash_multiplier", _runtime_flash_multiplier)
	_shader_material.set_shader_parameter("preview_stage", preview_stage)

func set_runtime_flash_multiplier(value: float) -> void:
	_runtime_flash_multiplier = clampf(value, 0.0, 1.0)
	_ensure_shader_material()
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("runtime_flash_multiplier", _runtime_flash_multiplier)

func _ensure_quad_mesh() -> void:
	var quad := mesh as QuadMesh
	if quad == null:
		quad = QuadMesh.new()
		mesh = quad

	quad.size = quad_size

func _ensure_shader_material() -> void:
	var material := get_surface_override_material(0)
	if material == null:
		material = material_override

	if material is ShaderMaterial:
		_shader_material = material
	else:
		_shader_material = null
