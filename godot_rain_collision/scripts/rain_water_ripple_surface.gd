@tool
extends MeshInstance3D

const MAX_RIPPLES := 24
const EXPIRED_TIME := -1000.0

@export_range(0.2, 1.5, 0.01) var ripple_lifetime: float = 0.80
@export_range(0.05, 1.0, 0.01) var ripple_speed: float = 0.30
@export_range(0.005, 0.08, 0.001) var ripple_band_width: float = 0.030

var _material: ShaderMaterial
var _events := PackedVector4Array()
var _next_event_index := 0
var _elapsed_time := 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()
	_events.resize(MAX_RIPPLES)
	for index in range(MAX_RIPPLES):
		_events[index] = Vector4(0.0, 0.0, EXPIRED_TIME, 0.0)
	_resolve_material()
	_push_settings()


func _process(delta: float) -> void:
	_elapsed_time += delta
	if _material == null:
		_resolve_material()
	if _material != null:
		_material.set_shader_parameter("ripple_time", _elapsed_time)


func emit_ripple_at(world_position: Vector3) -> void:
	if _material == null:
		_resolve_material()
	if _material == null:
		return

	_events[_next_event_index] = Vector4(
		world_position.x,
		world_position.z,
		_elapsed_time,
		_random.randf_range(0.82, 1.12)
	)
	_next_event_index = (_next_event_index + 1) % MAX_RIPPLES
	_material.set_shader_parameter("ripple_data", _events)


func clear_ripples() -> void:
	for index in range(MAX_RIPPLES):
		_events[index] = Vector4(0.0, 0.0, EXPIRED_TIME, 0.0)
	_next_event_index = 0
	if _material != null:
		_material.set_shader_parameter("ripple_data", _events)


func _resolve_material() -> void:
	_material = material_override as ShaderMaterial


func _push_settings() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("ripple_time", _elapsed_time)
	_material.set_shader_parameter("ripple_data", _events)
	_material.set_shader_parameter("ripple_lifetime", ripple_lifetime)
	_material.set_shader_parameter("ripple_speed", ripple_speed)
	_material.set_shader_parameter("ripple_band_width", ripple_band_width)
