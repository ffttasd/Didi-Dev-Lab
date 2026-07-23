@tool
extends Node3D

const PREVIEW_NODE := ^"LightningPreview"
const FLASH_LIGHT_NODE := ^"FlashLight"

var _preview: Node
var _flash_light: OmniLight3D

@export_group("Preview")
@export_range(1, 8, 1) var preview_stage: int = 8:
	set(value):
		preview_stage = clampi(value, 1, 8)
		_apply_preview_property(&"preview_stage", preview_stage)
		_apply_light_properties()

@export var quad_size: Vector2 = Vector2(0.9, 2.7):
	set(value):
		quad_size = Vector2(maxf(value.x, 0.05), maxf(value.y, 0.05))
		_apply_preview_property(&"quad_size", quad_size)

@export_group("Colors")
@export var core_color: Color = Color(0.92, 0.97, 1.0, 1.0):
	set(value):
		core_color = value
		_apply_preview_property(&"core_color", core_color)
@export var glow_color: Color = Color(0.2, 0.62, 1.0, 1.0):
	set(value):
		glow_color = value
		_apply_preview_property(&"glow_color", glow_color)

@export_group("Shape")
@export_range(0.002, 0.2, 0.001) var core_width: float = 0.02:
	set(value):
		core_width = value
		_apply_preview_property(&"core_width", core_width)
@export_range(0.01, 0.6, 0.001) var glow_width: float = 0.15:
	set(value):
		glow_width = value
		_apply_preview_property(&"glow_width", glow_width)
@export_range(0.0, 0.5, 0.001) var jitter: float = 0.2:
	set(value):
		jitter = value
		_apply_preview_property(&"jitter", jitter)
@export_range(1.0, 50.0, 0.1) var detail_scale: float = 16.0:
	set(value):
		detail_scale = value
		_apply_preview_property(&"detail_scale", detail_scale)

@export_group("Motion")
@export_range(0.0, 20.0, 0.01) var bolt_speed: float = 7.5:
	set(value):
		bolt_speed = value
		_apply_preview_property(&"bolt_speed", bolt_speed)
@export_range(0.0, 80.0, 0.1) var flicker_speed: float = 42.0:
	set(value):
		flicker_speed = value
		_apply_preview_property(&"flicker_speed", flicker_speed)

@export_group("Flash")
@export_range(1.0, 80.0, 0.1) var flash_rate: float = 24.0:
	set(value):
		flash_rate = value
		_apply_preview_property(&"flash_rate", flash_rate)
@export_range(0.01, 0.5, 0.001) var flash_width: float = 0.1:
	set(value):
		flash_width = value
		_apply_preview_property(&"flash_width", flash_width)
@export_range(0.0, 1.0, 0.01) var flash_persistence: float = 0.88:
	set(value):
		flash_persistence = value
		_apply_preview_property(&"flash_persistence", flash_persistence)
@export_range(0.0, 1.0, 0.01) var idle_brightness: float = 0.2:
	set(value):
		idle_brightness = value
		_apply_preview_property(&"idle_brightness", idle_brightness)
@export_range(0.1, 8.0, 0.01) var flash_boost: float = 3.4:
	set(value):
		flash_boost = value
		_apply_preview_property(&"flash_boost", flash_boost)

@export_group("Branches")
@export_range(0.0, 2.0, 0.01) var branch_strength: float = 0.75:
	set(value):
		branch_strength = value
		_apply_preview_property(&"branch_strength", branch_strength)
@export_range(0.0, 2.0, 0.01) var branch_spread: float = 1.2:
	set(value):
		branch_spread = value
		_apply_preview_property(&"branch_spread", branch_spread)
@export_range(0.05, 1.0, 0.01) var branch_fade: float = 0.4:
	set(value):
		branch_fade = value
		_apply_preview_property(&"branch_fade", branch_fade)
@export_range(0.0, 0.2, 0.001) var branch_root_softness: float = 0.045:
	set(value):
		branch_root_softness = value
		_apply_preview_property(&"branch_root_softness", branch_root_softness)

@export_group("Energy")
@export_range(0.0, 60.0, 0.1) var core_energy: float = 18.0:
	set(value):
		core_energy = value
		_apply_preview_property(&"core_energy", core_energy)
@export_range(0.0, 40.0, 0.1) var glow_energy: float = 8.0:
	set(value):
		glow_energy = value
		_apply_preview_property(&"glow_energy", glow_energy)

@export_group("Alpha")
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0:
	set(value):
		opacity = value
		_apply_preview_property(&"opacity", opacity)
@export_range(0.0, 1.0, 0.01) var alpha_cutoff: float = 0.015:
	set(value):
		alpha_cutoff = value
		_apply_preview_property(&"alpha_cutoff", alpha_cutoff)

@export_group("Light")
@export var light_enabled: bool = true:
	set(value):
		light_enabled = value
		_apply_light_properties()
@export var light_use_preview_colors: bool = true:
	set(value):
		light_use_preview_colors = value
		_apply_light_properties()
@export var light_color: Color = Color(0.72, 0.86, 1.0, 1.0):
	set(value):
		light_color = value
		_apply_light_properties()
@export var light_offset: Vector3 = Vector3(0.0, 0.0, 0.0):
	set(value):
		light_offset = value
		_apply_light_properties()
@export_range(0.0, 32.0, 0.1) var light_base_energy: float = 0.25:
	set(value):
		light_base_energy = value
		_apply_light_properties()
@export_range(0.0, 128.0, 0.1) var light_flash_energy: float = 10.0:
	set(value):
		light_flash_energy = value
		_apply_light_properties()
@export_range(0.0, 32.0, 0.1) var light_range: float = 8.0:
	set(value):
		light_range = value
		_apply_light_properties()
@export_range(0.0, 4.0, 0.01) var light_attenuation: float = 1.0:
	set(value):
		light_attenuation = value
		_apply_light_properties()
@export_range(0.0, 8.0, 0.01) var light_size: float = 0.0:
	set(value):
		light_size = value
		_apply_light_properties()
@export var light_shadow_enabled: bool = false:
	set(value):
		light_shadow_enabled = value
		_apply_light_properties()
@export_range(0.0, 8.0, 0.01) var light_volumetric_fog_energy: float = 0.0:
	set(value):
		light_volumetric_fog_energy = value
		_apply_light_properties()
@export_range(0.05, 1.0, 0.01) var light_flash_rate_scale: float = 0.22:
	set(value):
		light_flash_rate_scale = value
		_apply_light_properties()
@export_range(0.05, 1.0, 0.01) var light_flash_width_scale: float = 0.18:
	set(value):
		light_flash_width_scale = value
		_apply_light_properties()
@export_range(0.0, 1.0, 0.01) var light_idle_scale: float = 0.08:
	set(value):
		light_idle_scale = value
		_apply_light_properties()
@export_range(0.0, 1.0, 0.01) var light_echo_strength: float = 0.45:
	set(value):
		light_echo_strength = value
		_apply_light_properties()
@export var light_drives_preview_flash: bool = true:
	set(value):
		light_drives_preview_flash = value
		_apply_preview_runtime_flash(_last_preview_flash_multiplier)
@export_range(0.0, 1.0, 0.01) var preview_flash_idle_floor: float = 0.06:
	set(value):
		preview_flash_idle_floor = value
		_apply_preview_runtime_flash(_last_preview_flash_multiplier)

var _last_preview_flash_multiplier: float = 1.0

func _ready() -> void:
	_cache_preview()
	_cache_light()
	_apply_all()
	_apply_light_properties()
	set_process(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	var stage := _stage_from_key(event)
	if stage == 0:
		return

	preview_stage = stage
	_apply_preview_property(&"preview_stage", preview_stage)
	_apply_light_properties()
	get_viewport().set_input_as_handled()

func _stage_from_key(event: InputEvent) -> int:
	if event is not InputEventKey:
		return 0

	var key_event := event as InputEventKey
	match key_event.physical_keycode:
		KEY_1, KEY_KP_1:
			return 1
		KEY_2, KEY_KP_2:
			return 2
		KEY_3, KEY_KP_3:
			return 3
		KEY_4, KEY_KP_4:
			return 4
		KEY_5, KEY_KP_5:
			return 5
		KEY_6, KEY_KP_6:
			return 6
		KEY_7, KEY_KP_7:
			return 7
		KEY_8, KEY_KP_8:
			return 8

	return 0

func _cache_preview() -> void:
	if _preview == null or not is_instance_valid(_preview):
		_preview = get_node_or_null(PREVIEW_NODE)

func _cache_light() -> void:
	if _flash_light == null or not is_instance_valid(_flash_light):
		_flash_light = get_node_or_null(FLASH_LIGHT_NODE) as OmniLight3D

func _apply_preview_property(property_name: StringName, value: Variant) -> void:
	_cache_preview()
	if _preview == null:
		return
	_preview.set(property_name, value)

func _apply_preview_runtime_flash(value: float) -> void:
	_last_preview_flash_multiplier = clampf(value, 0.0, 1.0)
	_cache_preview()
	if _preview == null:
		return
	if _preview.has_method("set_runtime_flash_multiplier"):
		var applied_value: float = _last_preview_flash_multiplier if light_drives_preview_flash else 1.0
		_preview.call("set_runtime_flash_multiplier", applied_value)

func _process(_delta: float) -> void:
	_update_flash_light(Time.get_ticks_msec() * 0.001)

func _apply_all() -> void:
	_apply_preview_property(&"preview_stage", preview_stage)
	_apply_preview_property(&"quad_size", quad_size)
	_apply_preview_property(&"core_color", core_color)
	_apply_preview_property(&"glow_color", glow_color)
	_apply_preview_property(&"core_width", core_width)
	_apply_preview_property(&"glow_width", glow_width)
	_apply_preview_property(&"jitter", jitter)
	_apply_preview_property(&"detail_scale", detail_scale)
	_apply_preview_property(&"bolt_speed", bolt_speed)
	_apply_preview_property(&"flicker_speed", flicker_speed)
	_apply_preview_property(&"flash_rate", flash_rate)
	_apply_preview_property(&"flash_width", flash_width)
	_apply_preview_property(&"flash_persistence", flash_persistence)
	_apply_preview_property(&"idle_brightness", idle_brightness)
	_apply_preview_property(&"flash_boost", flash_boost)
	_apply_preview_property(&"branch_strength", branch_strength)
	_apply_preview_property(&"branch_spread", branch_spread)
	_apply_preview_property(&"branch_fade", branch_fade)
	_apply_preview_property(&"branch_root_softness", branch_root_softness)
	_apply_preview_property(&"core_energy", core_energy)
	_apply_preview_property(&"glow_energy", glow_energy)
	_apply_preview_property(&"opacity", opacity)
	_apply_preview_property(&"alpha_cutoff", alpha_cutoff)
	_apply_preview_runtime_flash(_last_preview_flash_multiplier)
	_apply_light_properties()

func _apply_light_properties() -> void:
	_cache_light()
	if _flash_light == null:
		return

	var stage_light_enabled := light_enabled and preview_stage >= 8
	_flash_light.visible = stage_light_enabled
	_flash_light.position = light_offset
	_flash_light.omni_range = light_range
	_flash_light.omni_attenuation = light_attenuation
	_flash_light.light_size = light_size
	_flash_light.shadow_enabled = light_shadow_enabled
	_flash_light.light_volumetric_fog_energy = light_volumetric_fog_energy
	_flash_light.light_color = _get_light_color()

	if not stage_light_enabled:
		_flash_light.light_energy = 0.0
		_apply_preview_runtime_flash(1.0)
		return

	_update_flash_light(Time.get_ticks_msec() * 0.001)

func _update_flash_light(time_sec: float) -> void:
	_cache_light()
	if preview_stage < 8:
		_apply_preview_runtime_flash(1.0)
		if _flash_light != null:
			_flash_light.light_energy = 0.0
		return

	var light_flash_rate: float = maxf(0.25, flash_rate * light_flash_rate_scale)
	var strobe_time: float = time_sec * light_flash_rate
	var strobe_cycle: float = floor(strobe_time)
	var strobe_phase: float = strobe_time - strobe_cycle
	var cycle_seed: float = _hash11(strobe_cycle + 17.0)
	var cycle_gain: float = lerpf(0.85, 1.4, _hash11(strobe_cycle + 29.0))
	var cycle_threshold: float = clampf(1.0 - flash_persistence * 0.45, 0.45, 0.92)
	var cycle_on: float = 1.0 if cycle_seed >= cycle_threshold else 0.0

	var light_flash_width: float = maxf(0.012, flash_width * light_flash_width_scale)
	var main_burst: float = _flash_shape(strobe_phase, light_flash_width, 0.06, 1.0)
	var burst_echo_a: float = _flash_shape(strobe_phase, light_flash_width * 0.85, 0.15, light_echo_strength)
	var burst_echo_b: float = _flash_shape(strobe_phase, light_flash_width * 0.7, 0.26, light_echo_strength * 0.6)
	var burst_echo_c: float = _flash_shape(strobe_phase, light_flash_width * 0.5, 0.38, light_echo_strength * 0.35)
	var burst_train: float = maxf(maxf(main_burst, burst_echo_a), maxf(burst_echo_b, burst_echo_c))
	var pulse: float = burst_train * cycle_on

	var micro_flash: float = 0.8 + 0.2 * sin(time_sec * (flicker_speed * 0.18) * TAU)
	var chaotic_flicker: float = 0.88 + 0.12 * sin(time_sec * (flicker_speed * 0.45))
	var idle_factor: float = idle_brightness * light_idle_scale * (0.9 + 0.1 * micro_flash)
	var burst_factor: float = pulse * cycle_gain * micro_flash * chaotic_flicker
	var preview_flash_multiplier: float = clampf(preview_flash_idle_floor + burst_factor, 0.0, 1.0)

	_apply_preview_runtime_flash(preview_flash_multiplier)

	if _flash_light == null:
		return

	if not light_enabled:
		_flash_light.light_energy = 0.0
		return

	_flash_light.light_energy = light_base_energy * idle_factor + light_flash_energy * burst_factor
	_flash_light.light_color = _get_light_color().lerp(core_color, clamp(pulse * cycle_gain, 0.0, 1.0))

func _get_light_color() -> Color:
	if light_use_preview_colors:
		return glow_color.lerp(core_color, 0.58)
	return light_color

func _flash_shape(phase: float, width: float, offset: float, strength: float) -> float:
	var safe_width := maxf(width, 0.0001)
	return (1.0 - smoothstep(0.0, safe_width, absf(phase - offset))) * strength

func _hash11(value: float) -> float:
	return fposmod(sin(value * 127.1) * 43758.5453123, 1.0)
