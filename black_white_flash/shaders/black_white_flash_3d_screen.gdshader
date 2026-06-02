shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform sampler2D speed_line_noise : repeat_enable, filter_nearest;

uniform bool effect_enabled = true;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float impact_phase : hint_range(0.0, 1.0) = 0.32;
uniform vec2 flash_center = vec2(0.5, 0.54);
uniform vec4 effect_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float center_radius : hint_range(0.0, 1.5) = 0.035;
uniform float center_feather : hint_range(0.01, 2.0) = 0.2;

uniform float invert_effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float invert_amount : hint_range(0.0, 1.0) = 1.0;
uniform float filter_luma_start : hint_range(0.0, 1.0) = 0.5;
uniform float filter_luma_range : hint_range(0.001, 1.0) = 0.035;
uniform vec4 bright_flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dark_flash_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float flash_contrast : hint_range(0.0, 12.0) = 9.0;

uniform float speed_line_strength : hint_range(0.0, 3.0) = 2.25;
uniform float speed_line_displacement_px : hint_range(0.0, 260.0) = 118.0;
uniform float speed_line_density : hint_range(1.0, 180.0) = 96.0;
uniform float speed_line_y_stretch : hint_range(1.0, 160.0) = 132.0;
uniform float speed_line_width : hint_range(0.01, 0.9) = 0.42;
uniform float speed_line_speed : hint_range(-30.0, 30.0) = 11.0;
uniform float speed_line_warp : hint_range(0.0, 8.0) = 3.2;
uniform float speed_line_center_fade : hint_range(0.0, 1.5) = 0.035;
uniform float speed_line_edge_fade : hint_range(0.0, 2.0) = 1.32;

const float FULL_TURN = 6.28318530718;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec2 screen_size() {
	return vec2(textureSize(screen_texture, 0));
}

vec2 effect_screen_size() {
	return max(screen_size() * effect_uv_rect.zw, vec2(1.0));
}

vec2 effect_to_screen_uv(vec2 uv) {
	return effect_uv_rect.xy + uv * effect_uv_rect.zw;
}

vec2 screen_to_effect_uv(vec2 uv) {
	return (uv - effect_uv_rect.xy) / max(effect_uv_rect.zw, vec2(0.0001));
}

bool is_inside_effect_rect(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

vec3 sample_raw_screen_rgb(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

vec3 sample_screen_rgb(vec2 uv) {
	return sample_raw_screen_rgb(effect_to_screen_uv(clamp(uv, vec2(0.001), vec2(0.999))));
}

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec2 pixel_delta_from_center(vec2 uv) {
	return (uv - flash_center) * effect_screen_size();
}

float radial_distance(vec2 uv) {
	vec2 size = effect_screen_size();
	float aspect = size.x / max(size.y, 1.0);
	return length((uv - flash_center) * vec2(aspect, 1.0));
}

float radial_center_mask(vec2 uv) {
	float d = radial_distance(uv);
	return 1.0 - smoothstep(center_radius, center_radius + center_feather, d);
}

vec2 radial_dir_uv(vec2 uv) {
	vec2 delta_px = pixel_delta_from_center(uv);
	if (length(delta_px) <= 0.0001) {
		return vec2(0.0);
	}
	return normalize(delta_px) / effect_screen_size();
}

float line_pattern(vec2 uv) {
	vec2 delta_px = pixel_delta_from_center(uv);
	float r_px = length(delta_px);
	if (r_px <= 0.001 || speed_line_strength <= 0.001) {
		return 0.0;
	}

	float angle01 = fract(atan(delta_px.y, delta_px.x) / FULL_TURN + 0.5);
	float r_norm = radial_distance(uv);
	float phase_pull = impact_phase * speed_line_speed;
	vec2 noise_uv = vec2(
		angle01 * speed_line_density * 0.19 + phase_pull * 0.11,
		r_norm / max(speed_line_y_stretch, 1.0) - phase_pull * 0.025
	);
	float radial_noise = texture(speed_line_noise, noise_uv).r;
	float break_noise = texture(speed_line_noise, noise_uv * vec2(0.37, 11.0) + vec2(0.23, impact_phase * 4.7)).r;
	float stripe_phase = angle01 * speed_line_density + (radial_noise - 0.5) * speed_line_warp + phase_pull;
	float stripe = 1.0 - abs(fract(stripe_phase) - 0.5) * 2.0;
	float hard_line = smoothstep(1.0 - speed_line_width, 1.0, stripe);
	float texture_line = smoothstep(0.56, 0.88, radial_noise);
	float line_shape = max(hard_line, texture_line * 0.92);
	float broken_line = line_shape * (0.58 + break_noise * 0.42);
	float center_fade = smoothstep(speed_line_center_fade, speed_line_center_fade + 0.1, r_norm);
	float edge_fade = 1.0 - smoothstep(speed_line_edge_fade, speed_line_edge_fade + 0.25, r_norm);
	return clamp(hard_line * broken_line * center_fade * edge_fade, 0.0, 1.0);
}

float depth_edge(vec2 uv) {
	vec2 px = 1.0 / effect_screen_size();
	float d = texture(depth_texture, effect_to_screen_uv(uv)).r;
	float dx = abs(texture(depth_texture, effect_to_screen_uv(uv + vec2(px.x, 0.0))).r - d);
	float dy = abs(texture(depth_texture, effect_to_screen_uv(uv + vec2(0.0, px.y))).r - d);
	return clamp((dx + dy) * 180.0, 0.0, 1.0);
}

float normal_separation(vec2 uv) {
	vec3 n = texture(normal_roughness_texture, effect_to_screen_uv(uv)).xyz * 2.0 - 1.0;
	float normal_value = n.y * 0.48 + n.z * 0.32 + n.x * 0.2;
	return clamp(normal_value * 0.5 + 0.5, 0.0, 1.0);
}

vec3 radial_distorted_scene(vec2 uv, float line_mask) {
	vec2 dir = radial_dir_uv(uv);
	float amount = speed_line_displacement_px * effect_strength * (0.18 + line_mask * speed_line_strength);
	vec3 color = sample_screen_rgb(uv - dir * amount * 0.18) * 0.25;
	color += sample_screen_rgb(uv - dir * amount * 0.46) * 0.22;
	color += sample_screen_rgb(uv - dir * amount * 0.72) * 0.2;
	color += sample_screen_rgb(uv - dir * amount) * 0.17;
	color += sample_screen_rgb(uv + dir * amount * 0.22) * 0.16;
	return color;
}

float binary_black_white(float value) {
	float soft = smoothstep(filter_luma_start - filter_luma_range, filter_luma_start + filter_luma_range, value);
	float hard = step(filter_luma_start, value);
	return mix(soft, hard, clamp(flash_contrast / 12.0, 0.0, 1.0));
}

float strobe_polarity() {
	float frame = floor(impact_phase * 6.0);
	return mod(frame, 2.0);
}

void fragment() {
	vec2 uv = screen_to_effect_uv(SCREEN_UV);
	vec3 original = sample_raw_screen_rgb(SCREEN_UV);
	vec3 output_color = original;

	if (effect_enabled && effect_strength > 0.001 && is_inside_effect_rect(uv)) {
		float line_mask = line_pattern(uv);
		vec2 dir = radial_dir_uv(uv);
		vec2 warped_uv = uv - dir * speed_line_displacement_px * line_mask * effect_strength;
		vec3 streaked_scene = radial_distorted_scene(warped_uv, line_mask);

		float scene_luma = luminance(streaked_scene);
		float normal_luma = normal_separation(warped_uv);
		float edge = depth_edge(warped_uv);
		float center_flash = radial_center_mask(uv);

		float composed = scene_luma;
		composed = mix(composed, normal_luma, 0.55);
		composed = mix(composed, 1.0 - composed, line_mask * clamp(speed_line_strength, 0.0, 1.0));
		composed = max(composed, center_flash * 0.82);
		composed = mix(composed, 0.0, edge * 0.72);

		float bw = binary_black_white(composed);
		float inverted_bw = 1.0 - bw;
		bw = mix(bw, inverted_bw, invert_amount * invert_effect_strength);
		bw = mix(bw, 1.0 - bw, strobe_polarity());

		float end_gate = 1.0 - smoothstep(0.9, 1.0, impact_phase);
		if (end_gate > 0.001) {
			vec3 flash_color = mix(dark_flash_color.rgb, bright_flash_color.rgb, bw);
			output_color = mix(original, flash_color, end_gate);
		}
	}

	ALBEDO = output_color;
	EMISSION = output_color;
	ALPHA = 1.0;
}
