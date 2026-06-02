@tool
extends Node3D

const SHADER_PATH := "res://shaders/black_white_flash_3d_screen.gdshader"
const DEFAULT_SPEED_NOISE := preload("res://sprite/FX/T_Noise56ko.png")
const EDITOR_CAMERA_PREVIEW_HEIGHT_RATIO := 0.5
const PROP_EFFECT_ENABLED := "效果启用"
const PROP_EDITOR_PREVIEW := "编辑器预览"
const PROP_AUTO_TRIGGER := "自动触发"
const PROP_TRIGGER_INTERVAL := "触发间隔"
const PROP_IMPACT_DURATION := "冲击帧时长"
const PROP_PREVIEW_PHASE := "冲击预览相位"
const PROP_EFFECT_STRENGTH := "效果强度"
const PROP_AUTO_CENTER_ON_ANCHOR := "自动跟随3D命中点"
const PROP_FLASH_CENTER := "屏幕中心"
const PROP_CENTER_RADIUS := "中心保留半径"
const PROP_CENTER_FEATHER := "中心冲击范围"
const PROP_INVERT_EFFECT_STRENGTH := "反转效果强度"
const PROP_INVERT_AMOUNT := "反转度"
const PROP_FILTER_LUMA_START := "过滤起始亮度"
const PROP_FILTER_LUMA_RANGE := "过滤范围"
const PROP_BRIGHT_FLASH_COLOR := "亮部闪颜色"
const PROP_DARK_FLASH_COLOR := "暗部闪颜色"
const PROP_FLASH_CONTRAST := "黑白硬度"
const PROP_SPEED_LINE_NOISE := "速度线噪波图"
const PROP_SPEED_LINE_STRENGTH := "速度线强度"
const PROP_SPEED_LINE_DISPLACEMENT := "速度线置换强度"
const PROP_SPEED_LINE_DENSITY := "速度线密度"
const PROP_SPEED_LINE_Y_STRETCH := "速度线Y拉伸"
const PROP_SPEED_LINE_WIDTH := "速度线宽度"
const PROP_SPEED_LINE_SPEED := "速度线速度"
const PROP_SPEED_LINE_WARP := "速度线噪波扰动"
const PROP_SPEED_LINE_CENTER_FADE := "速度线中心留白"
const PROP_SPEED_LINE_EDGE_FADE := "速度线边缘淡出"
const PROP_OVERLAY_PATH := "后处理覆盖层路径"
const PROP_CAMERA_PATH := "相机路径"
const PROP_IMPACT_ANCHOR_PATH := "命中点节点"
const PROP_TARGET_PIVOT_PATH := "目标节点"
const PROP_HIT_LIGHT_PATH := "冲击灯光"

var effect_enabled: bool = true
var editor_preview: bool = true
var auto_trigger: bool = true
var trigger_interval: float = 0.86
var impact_duration: float = 0.14
var preview_phase: float = 0.32
var effect_strength: float = 1.0
var auto_center_on_anchor: bool = true
var flash_center: Vector2 = Vector2(0.5, 0.54)
var center_radius: float = 0.035
var center_feather: float = 0.2
var invert_effect_strength: float = 1.0
var invert_amount: float = 1.0
var filter_luma_start: float = 0.5
var filter_luma_range: float = 0.035
var bright_flash_color: Color = Color.WHITE
var dark_flash_color: Color = Color.BLACK
var flash_contrast: float = 9.0
var speed_line_noise: Texture2D = DEFAULT_SPEED_NOISE
var speed_line_strength: float = 2.25
var speed_line_displacement_px: float = 118.0
var speed_line_density: float = 96.0
var speed_line_y_stretch: float = 132.0
var speed_line_width: float = 0.42
var speed_line_speed: float = 11.0
var speed_line_warp: float = 3.2
var speed_line_center_fade: float = 0.035
var speed_line_edge_fade: float = 1.32
var overlay_path: NodePath = NodePath("BlackWhiteFlashOverlay3D")
var camera_path: NodePath = NodePath("Camera3D")
var impact_anchor_path: NodePath = NodePath("TargetPivot/ImpactAnchor")
var target_pivot_path: NodePath = NodePath("TargetPivot")
var hit_light_path: NodePath = NodePath("HitLight")

var _elapsed: float = 0.0
var _shader_material: ShaderMaterial
var _overlay: GeometryInstance3D
var _camera: Camera3D
var _impact_anchor: Node3D
var _target_pivot: Node3D
var _hit_light: OmniLight3D
var _base_target_transform: Transform3D = Transform3D.IDENTITY
var _projected_flash_center: Vector2 = Vector2(0.5, 0.54)
var _has_projected_flash_center: bool = false
var _effect_uv_rect: Vector4 = Vector4(0.0, 0.0, 1.0, 1.0)
var _flash_active: bool = false


func _ready() -> void:
	_cache_nodes()
	if auto_trigger:
		_elapsed = impact_duration + 0.01
		_push_shader_params(0.0, preview_phase)
	else:
		_push_shader_params(effect_strength, preview_phase)
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	_update_projected_center()

	var runtime_strength := effect_strength
	var runtime_phase := preview_phase
	if Engine.is_editor_hint():
		if not editor_preview:
			runtime_strength = 0.0
	elif auto_trigger:
		if _flash_active:
			_elapsed += delta
			runtime_phase = clampf(_elapsed / maxf(impact_duration, 0.01), 0.0, 1.0)
			if _elapsed >= impact_duration:
				_flash_active = false
				runtime_strength = 0.0
		else:
			runtime_strength = 0.0

	_push_shader_params(runtime_strength, runtime_phase)
	_update_scene_reaction(runtime_strength, runtime_phase)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not auto_trigger:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_flash_active = true
	_elapsed = 0.0
	get_viewport().set_input_as_handled()


func _get_property_list() -> Array[Dictionary]:
	return [
		_prop(PROP_EFFECT_ENABLED, TYPE_BOOL),
		_prop(PROP_EDITOR_PREVIEW, TYPE_BOOL),
		_prop(PROP_AUTO_TRIGGER, TYPE_BOOL),
		_range_prop(PROP_TRIGGER_INTERVAL, 0.12, 4.0, 0.01),
		_range_prop(PROP_IMPACT_DURATION, 0.03, 0.5, 0.001),
		_range_prop(PROP_PREVIEW_PHASE, 0.0, 1.0, 0.01),
		_range_prop(PROP_EFFECT_STRENGTH, 0.0, 1.0, 0.01),
		_prop(PROP_AUTO_CENTER_ON_ANCHOR, TYPE_BOOL),
		_prop(PROP_FLASH_CENTER, TYPE_VECTOR2),
		_range_prop(PROP_CENTER_RADIUS, 0.0, 1.5, 0.01),
		_range_prop(PROP_CENTER_FEATHER, 0.01, 2.0, 0.01),
		_range_prop(PROP_INVERT_EFFECT_STRENGTH, 0.0, 1.0, 0.01),
		_range_prop(PROP_INVERT_AMOUNT, 0.0, 1.0, 0.01),
		_range_prop(PROP_FILTER_LUMA_START, 0.0, 1.0, 0.01),
		_range_prop(PROP_FILTER_LUMA_RANGE, 0.001, 1.0, 0.001),
		_prop(PROP_BRIGHT_FLASH_COLOR, TYPE_COLOR),
		_prop(PROP_DARK_FLASH_COLOR, TYPE_COLOR),
		_range_prop(PROP_FLASH_CONTRAST, 0.0, 12.0, 0.01),
		_resource_prop(PROP_SPEED_LINE_NOISE, "Texture2D"),
		_range_prop(PROP_SPEED_LINE_STRENGTH, 0.0, 3.0, 0.01),
		_range_prop(PROP_SPEED_LINE_DISPLACEMENT, 0.0, 260.0, 0.1),
		_range_prop(PROP_SPEED_LINE_DENSITY, 1.0, 180.0, 0.1),
		_range_prop(PROP_SPEED_LINE_Y_STRETCH, 1.0, 160.0, 0.1),
		_range_prop(PROP_SPEED_LINE_WIDTH, 0.01, 0.9, 0.01),
		_range_prop(PROP_SPEED_LINE_SPEED, -30.0, 30.0, 0.01),
		_range_prop(PROP_SPEED_LINE_WARP, 0.0, 8.0, 0.01),
		_range_prop(PROP_SPEED_LINE_CENTER_FADE, 0.0, 1.5, 0.01),
		_range_prop(PROP_SPEED_LINE_EDGE_FADE, 0.0, 2.0, 0.01),
		_prop(PROP_OVERLAY_PATH, TYPE_NODE_PATH),
		_prop(PROP_CAMERA_PATH, TYPE_NODE_PATH),
		_prop(PROP_IMPACT_ANCHOR_PATH, TYPE_NODE_PATH),
		_prop(PROP_TARGET_PIVOT_PATH, TYPE_NODE_PATH),
		_prop(PROP_HIT_LIGHT_PATH, TYPE_NODE_PATH),
	]


func _get(property: StringName) -> Variant:
	match String(property):
		PROP_EFFECT_ENABLED:
			return effect_enabled
		PROP_EDITOR_PREVIEW:
			return editor_preview
		PROP_AUTO_TRIGGER:
			return auto_trigger
		PROP_TRIGGER_INTERVAL:
			return trigger_interval
		PROP_IMPACT_DURATION:
			return impact_duration
		PROP_PREVIEW_PHASE:
			return preview_phase
		PROP_EFFECT_STRENGTH:
			return effect_strength
		PROP_AUTO_CENTER_ON_ANCHOR:
			return auto_center_on_anchor
		PROP_FLASH_CENTER:
			return flash_center
		PROP_CENTER_RADIUS:
			return center_radius
		PROP_CENTER_FEATHER:
			return center_feather
		PROP_INVERT_EFFECT_STRENGTH:
			return invert_effect_strength
		PROP_INVERT_AMOUNT:
			return invert_amount
		PROP_FILTER_LUMA_START:
			return filter_luma_start
		PROP_FILTER_LUMA_RANGE:
			return filter_luma_range
		PROP_BRIGHT_FLASH_COLOR:
			return bright_flash_color
		PROP_DARK_FLASH_COLOR:
			return dark_flash_color
		PROP_FLASH_CONTRAST:
			return flash_contrast
		PROP_SPEED_LINE_NOISE:
			return speed_line_noise
		PROP_SPEED_LINE_STRENGTH:
			return speed_line_strength
		PROP_SPEED_LINE_DISPLACEMENT:
			return speed_line_displacement_px
		PROP_SPEED_LINE_DENSITY:
			return speed_line_density
		PROP_SPEED_LINE_Y_STRETCH:
			return speed_line_y_stretch
		PROP_SPEED_LINE_WIDTH:
			return speed_line_width
		PROP_SPEED_LINE_SPEED:
			return speed_line_speed
		PROP_SPEED_LINE_WARP:
			return speed_line_warp
		PROP_SPEED_LINE_CENTER_FADE:
			return speed_line_center_fade
		PROP_SPEED_LINE_EDGE_FADE:
			return speed_line_edge_fade
		PROP_OVERLAY_PATH:
			return overlay_path
		PROP_CAMERA_PATH:
			return camera_path
		PROP_IMPACT_ANCHOR_PATH:
			return impact_anchor_path
		PROP_TARGET_PIVOT_PATH:
			return target_pivot_path
		PROP_HIT_LIGHT_PATH:
			return hit_light_path
	return null


func _set(property: StringName, value: Variant) -> bool:
	match String(property):
		PROP_EFFECT_ENABLED:
			effect_enabled = bool(value)
		PROP_EDITOR_PREVIEW:
			editor_preview = bool(value)
		PROP_AUTO_TRIGGER:
			auto_trigger = bool(value)
			if auto_trigger:
				_elapsed = impact_duration + 0.01
		PROP_TRIGGER_INTERVAL:
			trigger_interval = clampf(float(value), 0.12, 4.0)
		PROP_IMPACT_DURATION:
			impact_duration = clampf(float(value), 0.03, 0.5)
		PROP_PREVIEW_PHASE:
			preview_phase = clampf(float(value), 0.0, 1.0)
		PROP_EFFECT_STRENGTH:
			effect_strength = clampf(float(value), 0.0, 1.0)
		PROP_AUTO_CENTER_ON_ANCHOR:
			auto_center_on_anchor = bool(value)
		PROP_FLASH_CENTER:
			flash_center = value as Vector2
		PROP_CENTER_RADIUS:
			center_radius = clampf(float(value), 0.0, 1.5)
		PROP_CENTER_FEATHER:
			center_feather = clampf(float(value), 0.01, 2.0)
		PROP_INVERT_EFFECT_STRENGTH:
			invert_effect_strength = clampf(float(value), 0.0, 1.0)
		PROP_INVERT_AMOUNT:
			invert_amount = clampf(float(value), 0.0, 1.0)
		PROP_FILTER_LUMA_START:
			filter_luma_start = clampf(float(value), 0.0, 1.0)
		PROP_FILTER_LUMA_RANGE:
			filter_luma_range = clampf(float(value), 0.001, 1.0)
		PROP_BRIGHT_FLASH_COLOR:
			bright_flash_color = value as Color
		PROP_DARK_FLASH_COLOR:
			dark_flash_color = value as Color
		PROP_FLASH_CONTRAST:
			flash_contrast = clampf(float(value), 0.0, 12.0)
		PROP_SPEED_LINE_NOISE:
			speed_line_noise = value as Texture2D
			if speed_line_noise == null:
				speed_line_noise = DEFAULT_SPEED_NOISE
		PROP_SPEED_LINE_STRENGTH:
			speed_line_strength = clampf(float(value), 0.0, 3.0)
		PROP_SPEED_LINE_DISPLACEMENT:
			speed_line_displacement_px = clampf(float(value), 0.0, 260.0)
		PROP_SPEED_LINE_DENSITY:
			speed_line_density = clampf(float(value), 1.0, 180.0)
		PROP_SPEED_LINE_Y_STRETCH:
			speed_line_y_stretch = clampf(float(value), 1.0, 160.0)
		PROP_SPEED_LINE_WIDTH:
			speed_line_width = clampf(float(value), 0.01, 0.9)
		PROP_SPEED_LINE_SPEED:
			speed_line_speed = clampf(float(value), -30.0, 30.0)
		PROP_SPEED_LINE_WARP:
			speed_line_warp = clampf(float(value), 0.0, 8.0)
		PROP_SPEED_LINE_CENTER_FADE:
			speed_line_center_fade = clampf(float(value), 0.0, 1.5)
		PROP_SPEED_LINE_EDGE_FADE:
			speed_line_edge_fade = clampf(float(value), 0.0, 2.0)
		PROP_OVERLAY_PATH:
			overlay_path = value as NodePath
			_cache_nodes()
		PROP_CAMERA_PATH:
			camera_path = value as NodePath
			_cache_nodes()
		PROP_IMPACT_ANCHOR_PATH:
			impact_anchor_path = value as NodePath
			_cache_nodes()
		PROP_TARGET_PIVOT_PATH:
			target_pivot_path = value as NodePath
			_cache_nodes()
		PROP_HIT_LIGHT_PATH:
			hit_light_path = value as NodePath
			_cache_nodes()
		_:
			return false

	_update_projected_center()
	_push_shader_params(effect_strength, preview_phase)
	return true


func _cache_nodes() -> void:
	_overlay = get_node_or_null(overlay_path) as GeometryInstance3D
	_camera = get_node_or_null(camera_path) as Camera3D
	_impact_anchor = get_node_or_null(impact_anchor_path) as Node3D
	_target_pivot = get_node_or_null(target_pivot_path) as Node3D
	_hit_light = get_node_or_null(hit_light_path) as OmniLight3D

	if _target_pivot != null:
		_base_target_transform = _target_pivot.transform

	if _overlay == null:
		return

	_overlay.extra_cull_margin = 16384.0
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_shader_material = _overlay.material_override as ShaderMaterial
	if _shader_material != null:
		return

	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		push_warning("Black white flash 3D shader could not load %s." % SHADER_PATH)
		return

	_shader_material = ShaderMaterial.new()
	_shader_material.resource_local_to_scene = true
	_shader_material.shader = shader
	_overlay.material_override = _shader_material


func _update_projected_center() -> void:
	_has_projected_flash_center = false
	_effect_uv_rect = Vector4(0.0, 0.0, 1.0, 1.0)
	if Engine.is_editor_hint():
		return
	if not auto_center_on_anchor or _camera == null or _impact_anchor == null:
		return
	if _camera.is_position_behind(_impact_anchor.global_position):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var screen_position := _camera.unproject_position(_impact_anchor.global_position)
	var next_center := Vector2(
		clampf(screen_position.x / viewport_size.x, 0.0, 1.0),
		clampf(screen_position.y / viewport_size.y, 0.0, 1.0)
	)

	_projected_flash_center = next_center
	_has_projected_flash_center = true
	flash_center = next_center


func _project_world_to_camera_uv(world_position: Vector3, viewport_aspect: float) -> Variant:
	if _camera == null:
		return null

	if viewport_aspect <= 0.001:
		return null

	var camera_space: Vector3 = _camera.get_camera_transform().affine_inverse() * world_position
	var half_width := 1.0
	var half_height := 1.0

	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
			half_width = _camera.size * 0.5
			half_height = half_width / viewport_aspect
		else:
			half_height = _camera.size * 0.5
			half_width = half_height * viewport_aspect
	else:
		var depth := -camera_space.z
		if depth <= 0.001:
			return null
		var fov_radians := deg_to_rad(_camera.fov)
		if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
			half_width = tan(fov_radians * 0.5) * depth
			half_height = half_width / viewport_aspect
		else:
			half_height = tan(fov_radians * 0.5) * depth
			half_width = half_height * viewport_aspect

	if half_width <= 0.001 or half_height <= 0.001:
		return null

	return Vector2(
		clampf(0.5 + camera_space.x / (half_width * 2.0), 0.0, 1.0),
		clampf(0.5 - camera_space.y / (half_height * 2.0), 0.0, 1.0)
	)


func _get_project_viewport_aspect() -> float:
	var viewport_width := 1920.0
	var viewport_height := 1080.0
	if ProjectSettings.has_setting("display/window/size/viewport_width"):
		viewport_width = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if ProjectSettings.has_setting("display/window/size/viewport_height"):
		viewport_height = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	return viewport_width / maxf(viewport_height, 1.0)


func _get_editor_camera_preview_uv_rect() -> Vector4:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return Vector4(0.0, 0.0, 1.0, 1.0)

	var preview_aspect := _get_project_viewport_aspect()
	var preview_height := viewport_size.y * EDITOR_CAMERA_PREVIEW_HEIGHT_RATIO
	var preview_width := preview_height * preview_aspect
	if preview_width > viewport_size.x:
		preview_width = viewport_size.x
		preview_height = preview_width / maxf(preview_aspect, 0.001)

	var preview_position := Vector2(
		(viewport_size.x - preview_width) * 0.5,
		viewport_size.y - preview_height
	)
	return Vector4(
		preview_position.x / viewport_size.x,
		preview_position.y / viewport_size.y,
		preview_width / viewport_size.x,
		preview_height / viewport_size.y
	)


func _push_shader_params(runtime_strength: float, runtime_phase: float) -> void:
	if _shader_material == null:
		_cache_nodes()
	if _shader_material == null:
		return

	if _overlay != null:
		_overlay.visible = effect_enabled

	var shader_flash_center := flash_center
	if auto_center_on_anchor and _has_projected_flash_center:
		shader_flash_center = _projected_flash_center

	_shader_material.set_shader_parameter(&"effect_enabled", effect_enabled)
	_shader_material.set_shader_parameter(&"effect_strength", clampf(runtime_strength if effect_enabled else 0.0, 0.0, 1.0))
	_shader_material.set_shader_parameter(&"impact_phase", clampf(runtime_phase, 0.0, 1.0))
	_shader_material.set_shader_parameter(&"flash_center", shader_flash_center)
	_shader_material.set_shader_parameter(&"effect_uv_rect", _effect_uv_rect)
	_shader_material.set_shader_parameter(&"center_radius", center_radius)
	_shader_material.set_shader_parameter(&"center_feather", center_feather)
	_shader_material.set_shader_parameter(&"invert_effect_strength", invert_effect_strength)
	_shader_material.set_shader_parameter(&"invert_amount", invert_amount)
	_shader_material.set_shader_parameter(&"filter_luma_start", filter_luma_start)
	_shader_material.set_shader_parameter(&"filter_luma_range", filter_luma_range)
	_shader_material.set_shader_parameter(&"bright_flash_color", bright_flash_color)
	_shader_material.set_shader_parameter(&"dark_flash_color", dark_flash_color)
	_shader_material.set_shader_parameter(&"flash_contrast", flash_contrast)
	_shader_material.set_shader_parameter(&"speed_line_noise", speed_line_noise if speed_line_noise != null else DEFAULT_SPEED_NOISE)
	_shader_material.set_shader_parameter(&"speed_line_strength", speed_line_strength)
	_shader_material.set_shader_parameter(&"speed_line_displacement_px", speed_line_displacement_px)
	_shader_material.set_shader_parameter(&"speed_line_density", speed_line_density)
	_shader_material.set_shader_parameter(&"speed_line_y_stretch", speed_line_y_stretch)
	_shader_material.set_shader_parameter(&"speed_line_width", speed_line_width)
	_shader_material.set_shader_parameter(&"speed_line_speed", speed_line_speed)
	_shader_material.set_shader_parameter(&"speed_line_warp", speed_line_warp)
	_shader_material.set_shader_parameter(&"speed_line_center_fade", speed_line_center_fade)
	_shader_material.set_shader_parameter(&"speed_line_edge_fade", speed_line_edge_fade)


func _update_scene_reaction(runtime_strength: float, runtime_phase: float) -> void:
	var hit := clampf(runtime_strength * (1.0 - smoothstep(0.58, 1.0, runtime_phase)), 0.0, 1.0)

	if _target_pivot != null:
		_target_pivot.transform = _base_target_transform
		if hit > 0.001 and not Engine.is_editor_hint():
			var shake := 0.055 * hit
			_target_pivot.position += Vector3(
				sin(Time.get_ticks_msec() * 0.073) * shake,
				sin(Time.get_ticks_msec() * 0.109) * shake * 0.5,
				sin(Time.get_ticks_msec() * 0.061) * shake
			)
			_target_pivot.rotation.y += sin(Time.get_ticks_msec() * 0.041) * hit * 0.05

	if _hit_light != null:
		_hit_light.light_energy = 0.15 + hit * 10.0
		_hit_light.omni_range = 2.0 + hit * 3.4


func _prop(property_name: String, property_type: int) -> Dictionary:
	return {
		"name": property_name,
		"type": property_type,
		"usage": PROPERTY_USAGE_DEFAULT,
	}


func _range_prop(property_name: String, min_value: float, max_value: float, step: float) -> Dictionary:
	return {
		"name": property_name,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%s,%s,%s" % [min_value, max_value, step],
		"usage": PROPERTY_USAGE_DEFAULT,
	}


func _resource_prop(property_name: String, resource_type: String) -> Dictionary:
	return {
		"name": property_name,
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": resource_type,
		"usage": PROPERTY_USAGE_DEFAULT,
	}
