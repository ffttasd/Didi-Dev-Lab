@tool
extends Node3D

@export_group("References")
@export var rain_path: NodePath
@export var water_path: NodePath

@export_group("Physical Collision")
@export_flags_3d_physics var ground_collision_mask: int = 1
@export_range(0.0, 0.06, 0.001) var puddle_depth_threshold: float = 0.0
@export_range(0.0, 0.08, 0.001) var ripple_surface_offset: float = 0.026

const MAX_DROPS_PER_PHYSICS_FRAME := 48

var _rain: GPUParticles3D
var _water_level: MeshInstance3D
var _rain_drop_accumulator := 0.0
var _random := RandomNumberGenerator.new()
var _scheduled_ripples: Array[PendingRipple] = []


class PendingRipple:
	var world_position: Vector3
	var time_until_impact: float

	func _init(position: Vector3, delay: float) -> void:
		world_position = position
		time_until_impact = delay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rain = get_node_or_null(rain_path) as GPUParticles3D
	_water_level = get_node_or_null(water_path) as MeshInstance3D
	_random.randomize()


func _physics_process(delta: float) -> void:
	if _rain == null or _water_level == null:
		return

	_update_scheduled_ripples(delta)
	_rain_drop_accumulator += _get_collision_drop_rate() * delta
	var drop_count := mini(int(floorf(_rain_drop_accumulator)), MAX_DROPS_PER_PHYSICS_FRAME)
	_rain_drop_accumulator -= float(drop_count)
	for drop_index in range(drop_count):
		_emit_verified_rain_drop()


func _get_collision_drop_rate() -> float:
	if _rain != null and _rain.has_method("get_collision_drop_rate"):
		var rate_value: Variant = _rain.call("get_collision_drop_rate")
		if rate_value is float:
			return rate_value
	return 30.0


func _emit_verified_rain_drop() -> void:
	var rain_extent_value: Variant = _rain.get("area_extents")
	var rain_direction_value: Variant = _rain.get("rain_direction")
	var speed_min_value: Variant = _rain.get("speed_min")
	var speed_max_value: Variant = _rain.get("speed_max")
	if not (rain_extent_value is Vector3) \
		or not (rain_direction_value is Vector3) \
		or not (speed_min_value is float) \
		or not (speed_max_value is float):
		return

	var rain_extents: Vector3 = rain_extent_value
	var rain_direction: Vector3 = rain_direction_value
	var speed_minimum: float = speed_min_value
	var speed_maximum: float = speed_max_value
	rain_direction = rain_direction.normalized()
	var origin := _rain.global_position + Vector3(
		_random.randf_range(-rain_extents.x, rain_extents.x),
		rain_extents.y + 0.35,
		_random.randf_range(-rain_extents.z, rain_extents.z)
	)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + rain_direction * 24.0, ground_collision_mask)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var physical_hit: Vector3 = hit["position"]
	var speed := _random.randf_range(minf(speed_minimum, speed_maximum), maxf(speed_minimum, speed_maximum))
	var emission_transform := Transform3D(Basis.IDENTITY, origin)
	var emit_flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY
	_rain.emit_particle(
		emission_transform,
		rain_direction * speed,
		Color.WHITE,
		Color(0.0, 0.0, 0.0, 1.0),
		emit_flags
	)

	var water_y := _water_level.global_position.y
	if physical_hit.y > water_y - puddle_depth_threshold:
		return

	var ripple_position := Vector3(physical_hit.x, water_y + ripple_surface_offset, physical_hit.z)
	if not _water_level.has_method("emit_ripple_at"):
		return
	var flight_time := origin.distance_to(physical_hit) / maxf(speed, 0.001)
	_scheduled_ripples.append(PendingRipple.new(ripple_position, flight_time))


func _update_scheduled_ripples(delta: float) -> void:
	for index in range(_scheduled_ripples.size() - 1, -1, -1):
		var scheduled_ripple := _scheduled_ripples[index]
		scheduled_ripple.time_until_impact -= delta
		if scheduled_ripple.time_until_impact > 0.0:
			continue
		_water_level.call("emit_ripple_at", scheduled_ripple.world_position)
		_scheduled_ripples.remove_at(index)
