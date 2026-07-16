shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms Scan;
uniform vec3 scan_origin = vec3(0.0, 0.45, 0.0);
uniform float scan_radius : hint_range(-1.0, 28.0, 0.01) = -1.0;
uniform float ring_width : hint_range(0.05, 2.0, 0.01) = 0.52;
uniform float trail_width : hint_range(0.1, 6.0, 0.05) = 2.8;
uniform vec4 scan_color : source_color = vec4(0.0, 0.95, 1.3, 1.0);
uniform vec4 transition_color : source_color = vec4(0.16, 0.58, 0.68, 1.0);
uniform float transition_strength : hint_range(0.0, 1.5, 0.01) = 0.09;
uniform float transition_saturation : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float base_wash_strength : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 front_white_color : source_color = vec4(1.35, 1.35, 1.35, 1.0);
uniform float front_white_strength : hint_range(0.0, 1.5, 0.01) = 0.67;
uniform float ring_emission : hint_range(0.0, 12.0, 0.1) = 4.5;
uniform float trail_strength : hint_range(0.0, 1.0, 0.01) = 0.52;
group_uniforms;

group_uniforms Object_Highlight;
uniform float highlight_rise_distance : hint_range(0.05, 2.0, 0.05) = 0.55;
uniform float highlight_fade_distance : hint_range(0.5, 8.0, 0.1) = 4.8;
uniform float fresnel_power : hint_range(0.5, 8.0, 0.1) = 2.8;
uniform float fresnel_emission : hint_range(0.0, 12.0, 0.1) = 5.2;
uniform float outline_threshold : hint_range(0.001, 0.2, 0.001) = 0.018;
uniform float outline_emission : hint_range(0.0, 12.0, 0.1) = 6.8;
uniform float dark_band_rise_distance : hint_range(0.01, 1.0, 0.01) = 0.18;
uniform float dark_band_fade_distance : hint_range(0.5, 8.0, 0.1) = 4.8;
uniform float dark_band_strength : hint_range(0.0, 0.95, 0.01) = 0.72;
group_uniforms;

vec3 reconstruct_world_position(vec2 screen_uv, float sampled_depth, mat4 inv_projection, mat4 inv_view) {
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, sampled_depth);
	vec4 view_position = inv_projection * vec4(ndc, 1.0);
	view_position.xyz /= view_position.w;
	return (inv_view * vec4(view_position.xyz, 1.0)).xyz;
}


void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 scene_color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;

	ALBEDO = scene_color;
	EMISSION = vec3(0.0);
	ALPHA = 1.0;

	if (depth > 0.00001 && scan_radius >= 0.0) {
		vec3 world_position = reconstruct_world_position(SCREEN_UV, depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

		float surface_distance = distance(world_position, scan_origin);
		float distance_to_front = abs(surface_distance - scan_radius);
		float transition_luminance = dot(transition_color.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 muted_transition_color = mix(vec3(transition_luminance), transition_color.rgb, transition_saturation);

		float behind_front = scan_radius - surface_distance;
		float inside_front = step(0.0, behind_front);
		float trail_rise = smoothstep(0.0, ring_width * 0.34, behind_front);
		float trail_falloff = 1.0 - smoothstep(ring_width * 0.18, trail_width, behind_front);
		float trail = inside_front * trail_rise * trail_falloff;
		float ripple_pattern = smoothstep(0.68, 0.96, 0.5 + 0.5 * sin(surface_distance * 15.0 - TIME * 7.0));
		float ripple_layer = inside_front * trail_falloff * ripple_pattern;
		float blue_band_rise = smoothstep(ring_width * 0.055, ring_width * 0.11, behind_front);
		float blue_band_fade = 1.0 - smoothstep(ring_width * 0.11, ring_width * 1.70, behind_front);
		float bright_blue_band = inside_front * blue_band_rise * blue_band_fade;

		vec2 texel_size = 1.0 / vec2(textureSize(depth_texture, 0));
		float depth_left = textureLod(depth_texture, SCREEN_UV - vec2(texel_size.x, 0.0), 0.0).r;
		float depth_right = textureLod(depth_texture, SCREEN_UV + vec2(texel_size.x, 0.0), 0.0).r;
		float depth_down = textureLod(depth_texture, SCREEN_UV - vec2(0.0, texel_size.y), 0.0).r;
		float depth_up = textureLod(depth_texture, SCREEN_UV + vec2(0.0, texel_size.y), 0.0).r;

		vec3 view_normal = normalize(textureLod(normal_roughness_texture, SCREEN_UV, 0.0).xyz * 2.0 - 1.0);
		vec3 normal_left = normalize(textureLod(normal_roughness_texture, SCREEN_UV - vec2(texel_size.x, 0.0), 0.0).xyz * 2.0 - 1.0);
		vec3 normal_right = normalize(textureLod(normal_roughness_texture, SCREEN_UV + vec2(texel_size.x, 0.0), 0.0).xyz * 2.0 - 1.0);
		vec3 normal_down = normalize(textureLod(normal_roughness_texture, SCREEN_UV - vec2(0.0, texel_size.y), 0.0).xyz * 2.0 - 1.0);
		vec3 normal_up = normalize(textureLod(normal_roughness_texture, SCREEN_UV + vec2(0.0, texel_size.y), 0.0).xyz * 2.0 - 1.0);

		vec4 view_position_h = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		vec3 view_position = view_position_h.xyz / view_position_h.w;
		vec3 view_direction = normalize(-view_position);
		float fresnel = pow(1.0 - clamp(abs(dot(view_normal, view_direction)), 0.0, 1.0), fresnel_power);
		fresnel = smoothstep(0.025, 0.72, fresnel);
		vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz);
		float fresnel_surface_mask = 1.0 - smoothstep(0.72, 0.92, abs(world_normal.y));

		float max_depth_delta = max(max(abs(depth - depth_left), abs(depth - depth_right)), max(abs(depth - depth_down), abs(depth - depth_up)));
		float relative_depth_delta = max_depth_delta / max(depth, 0.0001);
		float depth_outline = smoothstep(outline_threshold, outline_threshold * 4.0, relative_depth_delta);
		float max_normal_delta = max(max(1.0 - dot(view_normal, normal_left), 1.0 - dot(view_normal, normal_right)), max(1.0 - dot(view_normal, normal_down), 1.0 - dot(view_normal, normal_up)));
		float normal_outline = smoothstep(0.035, 0.28, max_normal_delta);
		float pipeline_outline = max(depth_outline, normal_outline);

		float highlight_age = max(behind_front, 0.0);
		float highlight_rise = smoothstep(0.0, highlight_rise_distance, highlight_age);
		float highlight_fade = 1.0 - smoothstep(highlight_rise_distance, highlight_fade_distance, highlight_age);
		float highlight_envelope = inside_front * highlight_rise * highlight_fade;
		float object_highlight = highlight_envelope * (fresnel * fresnel_emission * fresnel_surface_mask + pipeline_outline * outline_emission);

		float dark_band_rise = smoothstep(ring_width * 0.12, dark_band_rise_distance, highlight_age);
		float dark_band_fade = 1.0 - smoothstep(0.55, dark_band_fade_distance, highlight_age);
		float dark_band = inside_front * dark_band_rise * dark_band_fade;
		vec3 darkened_scene = scene_color * (1.0 - dark_band * dark_band_strength);

		float tint_amount = clamp(trail * trail_strength * base_wash_strength + highlight_envelope * base_wash_strength * 0.3, 0.0, base_wash_strength);
		float surface_luminance = dot(darkened_scene, vec3(0.2126, 0.7152, 0.0722));
		vec3 luminance_matched_blue = muted_transition_color * (surface_luminance / max(transition_luminance, 0.001));
		ALBEDO = mix(darkened_scene, luminance_matched_blue, tint_amount);
		float white_core = 1.0 - smoothstep(ring_width * 0.018, ring_width * 0.09, distance_to_front);
		vec3 detail_light = muted_transition_color * (trail * 0.35 + ripple_layer * 0.90) * transition_strength;
		vec3 wave_blue = mix(muted_transition_color, scan_color.rgb, 0.35);
		detail_light += wave_blue * bright_blue_band * 0.48;
		detail_light += scan_color.rgb * object_highlight;

		ALBEDO += detail_light * 0.18;
		EMISSION = detail_light * 0.4;
		float white_mask = clamp(white_core * front_white_strength * (ring_emission / 4.5), 0.0, 1.0);
		ALBEDO = mix(ALBEDO, min(front_white_color.rgb, vec3(1.0)), white_mask);
	}
}
