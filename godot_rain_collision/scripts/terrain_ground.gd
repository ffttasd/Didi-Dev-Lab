@tool
extends MeshInstance3D

@export_group("Terrain Shape")
@export var terrain_size: Vector2 = Vector2(16.0, 14.0):
	set(value):
		terrain_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_request_rebuild()
@export_range(8, 160, 1) var subdivisions_x: int = 80:
	set(value):
		subdivisions_x = maxi(value, 8)
		_request_rebuild()
@export_range(8, 160, 1) var subdivisions_z: int = 70:
	set(value):
		subdivisions_z = maxi(value, 8)
		_request_rebuild()
@export_range(0.0, 0.3, 0.001) var broad_land_height: float = 0.115:
	set(value):
		broad_land_height = maxf(value, 0.0)
		_request_rebuild()
@export_range(0.0, 0.1, 0.001) var fine_land_height: float = 0.024:
	set(value):
		fine_land_height = maxf(value, 0.0)
		_request_rebuild()
@export_range(0.05, 3.0, 0.01) var broad_noise_scale: float = 0.38:
	set(value):
		broad_noise_scale = maxf(value, 0.01)
		_request_rebuild()
@export_range(0.1, 8.0, 0.01) var fine_noise_scale: float = 2.15:
	set(value):
		fine_noise_scale = maxf(value, 0.01)
		_request_rebuild()

@export_group("Resources")
@export var terrain_material: Material
@export var collision_shape_path: NodePath

var _is_rebuilding := false


func _ready() -> void:
	_rebuild()


func _request_rebuild() -> void:
	if is_inside_tree():
		call_deferred("_rebuild")


func _rebuild() -> void:
	if _is_rebuilding:
		return
	_is_rebuilding = true

	var vertex_columns := subdivisions_x + 1
	var vertex_rows := subdivisions_z + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(vertex_columns * vertex_rows)
	normals.resize(vertex_columns * vertex_rows)
	uvs.resize(vertex_columns * vertex_rows)

	for z in range(vertex_rows):
		var v := float(z) / float(subdivisions_z)
		var local_z := lerpf(-terrain_size.y * 0.5, terrain_size.y * 0.5, v)
		for x in range(vertex_columns):
			var u := float(x) / float(subdivisions_x)
			var local_x := lerpf(-terrain_size.x * 0.5, terrain_size.x * 0.5, u)
			var index := z * vertex_columns + x
			var sample_position := Vector2(local_x, local_z)
			vertices[index] = Vector3(local_x, _height_at(sample_position), local_z)
			normals[index] = _normal_at(sample_position)
			uvs[index] = Vector2(u, v)

	var indices := PackedInt32Array()
	indices.resize(subdivisions_x * subdivisions_z * 6)
	var write_index := 0
	for z in range(subdivisions_z):
		for x in range(subdivisions_x):
			var bottom_left := z * vertex_columns + x
			var bottom_right := bottom_left + 1
			var top_left := bottom_left + vertex_columns
			var top_right := top_left + 1
			indices[write_index] = bottom_left
			indices[write_index + 1] = top_left
			indices[write_index + 2] = bottom_right
			indices[write_index + 3] = bottom_right
			indices[write_index + 4] = top_left
			indices[write_index + 5] = top_right
			write_index += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var generated_mesh := ArrayMesh.new()
	generated_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	generated_mesh.surface_set_material(0, terrain_material)
	mesh = generated_mesh
	_update_static_collision(vertices, indices)
	_is_rebuilding = false


func _update_static_collision(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var collision_shape := get_node_or_null(collision_shape_path) as CollisionShape3D
	if collision_shape == null:
		return

	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index in range(indices.size()):
		faces[index] = vertices[indices[index]]

	var terrain_collision := ConcavePolygonShape3D.new()
	terrain_collision.set_faces(faces)
	terrain_collision.backface_collision = true
	collision_shape.shape = terrain_collision


func _height_at(point: Vector2) -> float:
	var broad := _value_noise(point * broad_noise_scale) * 2.0 - 1.0
	var fine := _value_noise(point * fine_noise_scale + Vector2(18.2, 7.4)) * 2.0 - 1.0
	return broad * broad_land_height + fine * fine_land_height


func _normal_at(point: Vector2) -> Vector3:
	var sample_offset := 0.03
	var left_height := _height_at(point - Vector2(sample_offset, 0.0))
	var right_height := _height_at(point + Vector2(sample_offset, 0.0))
	var back_height := _height_at(point - Vector2(0.0, sample_offset))
	var forward_height := _height_at(point + Vector2(0.0, sample_offset))
	return Vector3(
		left_height - right_height,
		sample_offset * 2.0,
		back_height - forward_height
	).normalized()


func _value_noise(point: Vector2) -> float:
	var cell := Vector2(floorf(point.x), floorf(point.y))
	var local := point - cell
	local = local * local * (Vector2.ONE * 3.0 - local * 2.0)
	var bottom := lerpf(_hash(cell), _hash(cell + Vector2.RIGHT), local.x)
	var top := lerpf(_hash(cell + Vector2.DOWN), _hash(cell + Vector2.ONE), local.x)
	return lerpf(bottom, top, local.y)


func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(127.1, 311.7))) * 43758.5453123, 1.0)
