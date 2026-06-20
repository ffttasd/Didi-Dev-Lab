shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, shadows_disabled, specular_disabled;

uniform sampler2D flow_texture : filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(2.4, 1.25);
uniform vec2 uv_speed = vec2(0.22, -0.06);
uniform float density : hint_range(0.25, 4.0, 0.01) = 1.25;
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float white_threshold : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float top_dissolve_start : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float top_dissolve_span : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform vec2 top_noise_scale = vec2(6.2, 2.8);
uniform vec2 top_noise_speed = vec2(-0.18, 0.95);
uniform vec2 top_contour_break_scale = vec2(2.15, 0.34);
uniform float top_contour_break_strength : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform vec2 top_shape_noise_scale = vec2(1.65, 0.82);
uniform float top_height_variation : hint_range(0.0, 0.35, 0.01) = 0.14;
uniform float top_chunk_strength : hint_range(0.0, 0.5, 0.01) = 0.24;
uniform float top_fragment_bias : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float top_emission_fade : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform vec4 dark_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 8.0, 0.01) = 4.2;
uniform float glow_softness : hint_range(0.01, 0.5, 0.01) = 0.14;

void fragment() {
	vec2 flow_uv = UV * uv_scale + TIME * uv_speed;
	float noise = texture(flow_texture, flow_uv).r;
	float density_mask = pow(clamp(1.0 - noise, 0.0, 1.0), density);
	float body_visible = step(alpha_threshold, density_mask);
	float tone = step(white_threshold, density_mask);
	float glow_mask = smoothstep(
		white_threshold - glow_softness,
		white_threshold + glow_softness,
		density_mask
	) * body_visible;

	// Break the tip into uneven larger chunks first, then erode them with finer noise.
	float vertical_height = 1.0 - UV.y;
	vec2 top_shape_uv = UV * top_shape_noise_scale + TIME * top_noise_speed * 0.24;
	float top_shape_noise = texture(flow_texture, top_shape_uv).r;
	float local_top_start = top_dissolve_start + (top_shape_noise - 0.5) * top_height_variation;
	float top_zone_mask = smoothstep(
		top_dissolve_start - max(top_dissolve_span, 0.05),
		top_dissolve_start + 0.04,
		vertical_height
	);
	vec2 top_contour_break_uv = UV * top_contour_break_scale + TIME * top_noise_speed * 0.12;
	float top_contour_break_noise = texture(flow_texture, top_contour_break_uv).r;
	float top_contour_break = (top_contour_break_noise - 0.5) * top_contour_break_strength * top_zone_mask;
	float top_progress = clamp(
		(vertical_height - local_top_start + top_contour_break) / max(top_dissolve_span, 0.0001),
		0.0,
		1.0
	);
	vec2 top_chunk_uv = UV * (top_noise_scale * 0.48) + TIME * top_noise_speed * 0.38;
	top_chunk_uv.y += top_contour_break * 0.7;
	float top_chunk_noise = texture(flow_texture, top_chunk_uv).r;
	vec2 top_uv = UV * top_noise_scale + TIME * top_noise_speed;
	top_uv.y += top_contour_break;
	float top_noise = texture(flow_texture, top_uv).r;
	float top_fragment_pattern = clamp(1.0 - top_noise, 0.0, 1.0);
	float top_dissolve_threshold = clamp(
		top_progress * (1.0 + top_fragment_bias) + (top_chunk_noise - 0.5) * top_chunk_strength,
		0.0,
		0.98
	);
	float top_keep_mask = step(top_dissolve_threshold, top_fragment_pattern);
	float final_visible = body_visible * top_keep_mask;
	float emission_fade = 1.0 - top_progress * top_emission_fade;
	vec3 base_color = mix(dark_color.rgb, light_color.rgb, tone);

	ALBEDO = vec3(0.0);
	EMISSION = base_color * (1.0 + glow_strength * glow_mask) * final_visible * emission_fade;
	ROUGHNESS = 1.0;
	ALPHA = final_visible;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

void light() {
	DIFFUSE_LIGHT = vec3(0.0);
	SPECULAR_LIGHT = vec3(0.0);
}
