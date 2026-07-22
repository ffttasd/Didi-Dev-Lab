shader_type spatial;

const int MAX_RIPPLES = 24;

uniform sampler2D source_water_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 water_albedo : source_color = vec4(0.82, 0.88, 0.94, 1.0);
uniform float water_metallic : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float water_roughness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float micro_normal_scale_a : hint_range(0.05, 2.0, 0.01) = 0.46;
uniform float micro_normal_scale_b : hint_range(0.05, 2.0, 0.01) = 0.73;
uniform vec2 micro_normal_direction_a = vec2(0.82, 0.36);
uniform vec2 micro_normal_direction_b = vec2(-0.31, 0.95);
uniform float micro_normal_world_speed_a : hint_range(0.0, 0.60, 0.005) = 0.18;
uniform float micro_normal_world_speed_b : hint_range(0.0, 0.60, 0.005) = 0.21;
uniform float micro_normal_strength : hint_range(0.0, 0.20, 0.001) = 0.045;
uniform float micro_roughness_boost : hint_range(0.0, 0.10, 0.001) = 0.010;
uniform float ripple_normal_strength : hint_range(0.0001, 0.01, 0.0001) = 0.0020;
uniform float ripple_roughness_boost : hint_range(0.0, 0.2, 0.005) = 0.035;
uniform float ripple_lifetime : hint_range(0.2, 1.5, 0.01) = 0.80;
uniform float ripple_speed : hint_range(0.05, 1.0, 0.01) = 0.30;
uniform float ripple_band_width : hint_range(0.005, 0.08, 0.001) = 0.030;
uniform float ripple_edge_breakup : hint_range(0.0, 0.5, 0.01) = 0.18;
uniform vec4 ripple_data[MAX_RIPPLES];
uniform float ripple_time = 0.0;

varying vec3 ripple_world_position;


void vertex() {
	ripple_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 ripple_gradient = vec2(0.0);
	float ripple_energy = 0.0;
	vec2 world_uv = ripple_world_position.xz;

	vec2 micro_direction_a = normalize(micro_normal_direction_a);
	vec2 micro_direction_b = normalize(micro_normal_direction_b);
	vec2 micro_normal_a = texture(
		source_water_normal,
		world_uv * micro_normal_scale_a
			+ micro_direction_a * (TIME * micro_normal_scale_a * micro_normal_world_speed_a)
	).rg * 2.0 - 1.0;
	vec2 micro_normal_b = texture(
		source_water_normal,
		world_uv * micro_normal_scale_b
			+ micro_direction_b * (TIME * micro_normal_scale_b * micro_normal_world_speed_b)
	).rg * 2.0 - 1.0;
	vec2 micro_slope = (micro_normal_a + micro_normal_b) * (0.5 * micro_normal_strength);

	for (int index = 0; index < MAX_RIPPLES; index++) {
		vec4 ripple = ripple_data[index];
		float age = ripple_time - ripple.z;
		if (age <= 0.0 || age >= ripple_lifetime) {
			continue;
		}

		float lifetime_ratio = age / ripple_lifetime;
		vec2 to_fragment = ripple_world_position.xz - ripple.xy;
		float distance_to_center = length(to_fragment);
		if (distance_to_center <= 0.0001) {
			continue;
		}

		float radius = 0.025 + ripple_speed * age;
		vec2 breakup_uv = ripple_world_position.xz * 0.38 + ripple.xy * 0.11;
		float edge_breakup = texture(source_water_normal, breakup_uv).r * 2.0 - 1.0;
		float ring_offset = (distance_to_center - radius) / ripple_band_width + edge_breakup * ripple_edge_breakup;
		float envelope = exp(-ring_offset * ring_offset * 2.4);
		float fade = pow(1.0 - lifetime_ratio, 1.65) * ripple.w;

		float radial_slope = envelope * (-4.8 * ring_offset / ripple_band_width) * fade;
		ripple_gradient += (to_fragment / distance_to_center) * radial_slope;
		ripple_energy += envelope * fade;
	}

	vec2 ripple_slope = ripple_gradient * ripple_normal_strength;
	vec2 combined_slope = clamp(micro_slope + ripple_slope, vec2(-0.65), vec2(0.65));
	NORMAL_MAP = vec3(combined_slope * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;

	ALBEDO = water_albedo.rgb;
	METALLIC = water_metallic;
	float micro_roughness = clamp(length(micro_slope) * 18.0, 0.0, 1.0) * micro_roughness_boost;
	ROUGHNESS = clamp(
		water_roughness + micro_roughness + min(ripple_energy, 1.0) * ripple_roughness_boost,
		0.0,
		1.0
	);
}
