@tool
extends Node3D

@export_range(-360.0, 360.0, 1.0, "or_greater", "or_less")
var rotation_speed_degrees := 36.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed_degrees) * delta)
