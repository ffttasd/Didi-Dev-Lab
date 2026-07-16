extends Node

const SCAN_ACTION: StringName = &"scan"
const SCAN_ANIMATION: StringName = &"scan_loop"
const SCAN_ORIGIN_PARAMETER: StringName = &"scan_origin"
const SCAN_RADIUS_PARAMETER: StringName = &"scan_radius"

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var scan_quad: MeshInstance3D = %ScanQuad
@onready var scan_origin: Node3D = get_node_or_null("../ScanOrigin") as Node3D
@onready var scan_material: ShaderMaterial = scan_quad.material_override as ShaderMaterial


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	if is_instance_valid(scan_origin):
		_sync_scan_origin()
	else:
		push_error("ScanInput requires a sibling Node3D named ScanOrigin.")
		set_process(false)
	_set_scan_radius(-1.0)


func _process(_delta: float) -> void:
	_sync_scan_origin()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(SCAN_ACTION):
		_play_scan()
		get_viewport().set_input_as_handled()


func _play_scan() -> void:
	animation_player.stop()
	animation_player.play(SCAN_ANIMATION)
	animation_player.seek(0.0, true)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == SCAN_ANIMATION:
		_set_scan_radius(-1.0)


func _set_scan_radius(radius: float) -> void:
	if scan_material:
		scan_material.set_shader_parameter(SCAN_RADIUS_PARAMETER, radius)


func _sync_scan_origin() -> void:
	if scan_material and is_instance_valid(scan_origin):
		scan_material.set_shader_parameter(SCAN_ORIGIN_PARAMETER, scan_origin.global_position)
