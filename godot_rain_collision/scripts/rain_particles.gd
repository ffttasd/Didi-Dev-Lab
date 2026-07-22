@tool
extends GPUParticles3D

@export_group("Rain")
@export_range(20, 1000, 4) var amount_value: int = 2200:
	set(value):
		amount_value = value
		_apply_settings()
@export_range(0.5, 10.0, 0.1) var lifetime_value: float = 1.6:
	set(value):
		lifetime_value = value
		_apply_settings()
@export var area_extents: Vector3 = Vector3(9.0, 2.0, 14.0):
	set(value):
		area_extents = value
		_apply_settings()
@export var follow_offset: Vector3 = Vector3(0.0, 7.5, 0.0)
@export var rain_direction: Vector3 = Vector3(0.15, -1.0, 0.05):
	set(value):
		rain_direction = value
		_apply_settings()
@export_range(1.0, 60.0, 0.5) var speed_min: float = 20.0:
	set(value):
		speed_min = value
		_apply_settings()
@export_range(1.0, 80.0, 0.5) var speed_max: float = 28.0:
	set(value):
		speed_max = value
		_apply_settings()
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.38:
	set(value):
		opacity = value
		_apply_settings()
@export var manual_emission: bool = false:
	set(value):
		manual_emission = value
		_apply_settings()
@export_group("Trail")
@export_range(0.02, 1.0, 0.01) var trail_lifetime_value: float = 0.01:
	set(value):
		trail_lifetime_value = value
		_apply_settings()
@export_range(0.001, 0.2, 0.001) var trail_width: float = 0.004:
	set(value):
		trail_width = value
		_apply_settings()
@export_range(2, 32, 1) var trail_sections: int = 6:
	set(value):
		trail_sections = value
		_apply_settings()
@export_range(1, 8, 1) var trail_section_segments: int = 3:
	set(value):
		trail_section_segments = value
		_apply_settings()
@export var cross_section: bool = false:
	set(value):
		cross_section = value
		_apply_settings()

@export_group("Impact Sub-Emitter")
@export var impact_sub_emitter_path: NodePath:
	set(value):
		impact_sub_emitter_path = value
		_apply_settings()
@export_range(1, 4, 1) var splash_particles_per_hit: int = 1:
	set(value):
		splash_particles_per_hit = value
		_apply_settings()

@export_group("Follow")
@export var follow_camera: bool = true
@export var camera_path: NodePath

var _target_camera: Camera3D

func _ready() -> void:
	_target_camera = get_node_or_null(camera_path) as Camera3D
	if _target_camera == null:
		_target_camera = get_node_or_null("../Camera3D") as Camera3D
	_apply_settings()
	_update_follow()

func _process(_delta: float) -> void:
	if not follow_camera:
		return
	if Engine.is_editor_hint() and _target_camera == null:
		_target_camera = get_node_or_null(camera_path) as Camera3D
		if _target_camera == null:
			_target_camera = get_node_or_null("../Camera3D") as Camera3D
	_update_follow()

func _apply_settings() -> void:
	amount = amount_value
	lifetime = lifetime_value
	preprocess = 0.0 if manual_emission else lifetime_value
	fixed_fps = 60
	interpolate = true
	fract_delta = true
	local_coords = false
	emitting = not manual_emission
	draw_passes = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_enabled = true
	trail_lifetime = trail_lifetime_value
	sub_emitter = impact_sub_emitter_path
	visibility_aabb = _build_visibility_aabb()
	process_material = _build_process_material()
	draw_pass_1 = _build_ribbon_mesh()


func get_collision_drop_rate() -> float:
	return float(amount_value) / maxf(lifetime_value, 0.001)


func _build_visibility_aabb() -> AABB:
	var start_min: Vector3 = -area_extents
	var start_max: Vector3 = area_extents
	var direction: Vector3 = rain_direction.normalized()
	var travel: Vector3 = direction * max(speed_min, speed_max) * lifetime_value
	var end_min: Vector3 = start_min + travel
	var end_max: Vector3 = start_max + travel
	var padding: Vector3 = Vector3.ONE * 0.5
	var bounds_min: Vector3 = Vector3(
		minf(start_min.x, end_min.x),
		minf(start_min.y, end_min.y),
		minf(start_min.z, end_min.z)
	) - padding
	var bounds_max: Vector3 = Vector3(
		maxf(start_max.x, end_max.x),
		maxf(start_max.y, end_max.y),
		maxf(start_max.z, end_max.z)
	) + padding
	return AABB(bounds_min, bounds_max - bounds_min)

func _build_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = area_extents
	material.direction = rain_direction.normalized()
	material.spread = 0.0 if manual_emission else 4.0
	material.gravity = Vector3.ZERO
	material.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	if impact_sub_emitter_path != NodePath():
		material.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
		material.sub_emitter_amount_at_collision = splash_particles_per_hit
		material.sub_emitter_keep_velocity = false
	material.initial_velocity_min = 0.0 if manual_emission else min(speed_min, speed_max)
	material.initial_velocity_max = 0.0 if manual_emission else max(speed_min, speed_max)
	material.scale_min = 1.0
	material.scale_max = 1.0
	material.color = Color(0.82, 0.9, 1.0, opacity)
	return material

func _build_ribbon_mesh() -> RibbonTrailMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.82, 0.9, 1.0, opacity)
	material.vertex_color_use_as_albedo = true
	material.use_particle_trails = true

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.85, 0.45))
	curve.add_point(Vector2(1.0, 0.1))

	var mesh := RibbonTrailMesh.new()
	mesh.size = trail_width
	mesh.sections = trail_sections
	mesh.section_segments = trail_section_segments
	mesh.section_length = trail_lifetime_value * max(speed_min, speed_max) / max(float(trail_sections), 1.0)
	mesh.shape = RibbonTrailMesh.SHAPE_CROSS if cross_section else RibbonTrailMesh.SHAPE_FLAT
	mesh.curve = curve
	mesh.material = material
	return mesh

func _update_follow() -> void:
	if not follow_camera:
		return
	if _target_camera == null:
		return
	global_position = _target_camera.global_position + follow_offset
