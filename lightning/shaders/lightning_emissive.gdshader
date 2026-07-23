shader_type spatial;

render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

group_uniforms Colors;
uniform vec4 core_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.62, 1.0, 1.0);
group_uniforms;

group_uniforms Shape;
uniform float core_width : hint_range(0.002, 0.2, 0.001) = 0.02;
uniform float glow_width : hint_range(0.01, 0.6, 0.001) = 0.15;
uniform float jitter : hint_range(0.0, 0.5, 0.001) = 0.2;
uniform float detail_scale : hint_range(1.0, 50.0, 0.1) = 16.0;
group_uniforms;

group_uniforms Motion;
uniform float bolt_speed : hint_range(0.0, 20.0, 0.01) = 7.5;
uniform float flicker_speed : hint_range(0.0, 80.0, 0.1) = 42.0;
group_uniforms;

group_uniforms Flash;
uniform float flash_rate : hint_range(1.0, 80.0, 0.1) = 24.0;
uniform float flash_width : hint_range(0.01, 0.5, 0.001) = 0.1;
uniform float flash_persistence : hint_range(0.0, 1.0, 0.01) = 0.88;
uniform float idle_brightness : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float flash_boost : hint_range(0.1, 8.0, 0.01) = 3.4;
group_uniforms;

group_uniforms Branches;
uniform float branch_strength : hint_range(0.0, 2.0, 0.01) = 0.75;
uniform float branch_spread : hint_range(0.0, 2.0, 0.01) = 1.2;
uniform float branch_fade : hint_range(0.05, 1.0, 0.01) = 0.4;
uniform float branch_root_softness : hint_range(0.0, 0.2, 0.001) = 0.045;
group_uniforms;

group_uniforms Energy;
uniform float core_energy : hint_range(0.0, 60.0, 0.1) = 18.0;
uniform float glow_energy : hint_range(0.0, 40.0, 0.1) = 8.0;
group_uniforms;

group_uniforms Alpha;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.015;
uniform float runtime_flash_multiplier : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform int preview_stage : hint_range(1, 8, 1) = 8;
group_uniforms;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u);
}

float fbm1(float x) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < 5; i++) {
		value += noise1(x * frequency) * amplitude;
		frequency *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}

float bolt_center(float y, float t, float seed) {
	float n = fbm1(y * detail_scale + t * 1.35 + seed * 13.7);
	float wobble = sin(y * 17.0 + t * 4.6 + seed * 6.1) * 0.5 + 0.5;
	return 0.5 + (n - 0.5) * jitter + (wobble - 0.5) * jitter * 0.55;
}

float branch_mask(vec2 uv, float root_y, float direction, float seed, float t, float root_center, float fade_enabled) {
	float rel_raw = uv.y - root_y;
	float rel = max(rel_raw, 0.0);
	float branch_length = max(branch_fade, 0.001);
	float along = clamp(rel / branch_length, 0.0, 1.0);
	float root_blend = smoothstep(-branch_root_softness, branch_root_softness + core_width * 1.8, rel_raw);
	float tip_fade = mix(1.0, 1.0 - smoothstep(0.7, 1.0, along), fade_enabled);
	float bend_gate = smoothstep(0.0, branch_root_softness * 2.0 + core_width * 2.5, rel);
	float bend = (fbm1(uv.y * detail_scale * 1.5 + t * 2.1 + seed * 9.2) - 0.5) * jitter * bend_gate;
	float branch_center = root_center + direction * rel * branch_spread + bend;
	float branch_dist = abs(uv.x - branch_center);
	float width_taper = mix(1.0, mix(1.15, 0.28, along), fade_enabled);
	float glow_taper = mix(1.0, mix(1.0, 0.38, along), fade_enabled);
	float core = smoothstep(core_width * 1.4 * width_taper + 0.0005, 0.0, branch_dist);
	float halo = smoothstep(glow_width * (0.75 * glow_taper + 0.2), 0.0, branch_dist);
	return max(core, halo * 0.5) * root_blend * tip_fade;
}

float flash_shape(float phase, float width, float offset, float strength) {
	float pulse = smoothstep(width, 0.0, abs(phase - offset));
	return pulse * strength;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * bolt_speed;
	float noise_enabled = step(2.0, float(preview_stage));
	float glow_enabled = step(3.0, float(preview_stage));
	float branch_enabled = step(4.0, float(preview_stage));
	float branch_fade_enabled = step(5.0, float(preview_stage));
	float flicker_enabled = step(6.0, float(preview_stage));
	float pulse_enabled = step(7.0, float(preview_stage));

	float noisy_center = bolt_center(uv.y, t, 0.0);
	float center = mix(0.5, noisy_center, noise_enabled);
	float dist_to_main = abs(uv.x - center);

	float core = smoothstep(core_width, 0.0, dist_to_main);
	float glow = smoothstep(glow_width, 0.0, dist_to_main) * glow_enabled;

	float root_a = 0.18 + (hash11(floor(t * 0.33) + 2.3) - 0.5) * 0.16;
	float root_b = 0.42 + (hash11(floor(t * 0.41) + 4.7) - 0.5) * 0.14;
	float root_c = 0.68 + (hash11(floor(t * 0.37) + 8.9) - 0.5) * 0.18;

	float branch = 0.0;
	branch += branch_mask(uv, root_a, -1.0, 1.1, t, bolt_center(root_a, t, 1.0), branch_fade_enabled);
	branch += branch_mask(uv, root_b, 1.0, 2.7, t, bolt_center(root_b, t, 2.0), branch_fade_enabled);
	branch += branch_mask(uv, root_c, -1.0, 4.9, t, bolt_center(root_c, t, 3.0), branch_fade_enabled);
	branch *= branch_strength * branch_enabled;

	float strobe_time = TIME * flash_rate;
	float strobe_cycle = floor(strobe_time);
	float strobe_phase = fract(strobe_time);
	float cycle_seed = hash11(strobe_cycle + 17.0);
	float cycle_gain = mix(0.85, 1.4, hash11(strobe_cycle + 29.0));
	float cycle_on = step(1.0 - flash_persistence, cycle_seed);

	float main_burst = flash_shape(strobe_phase, flash_width, 0.06, 1.0);
	float burst_echo_a = flash_shape(strobe_phase, flash_width * 0.6, 0.22, 0.9);
	float burst_echo_b = flash_shape(strobe_phase, flash_width * 0.45, 0.36, 0.65);
	float burst_echo_c = flash_shape(strobe_phase, flash_width * 0.35, 0.52, 0.45);
	float burst_train = max(max(main_burst, burst_echo_a), max(burst_echo_b, burst_echo_c));

	float micro_cycle = TIME * (flicker_speed * 0.55);
	float micro_flash = 0.65 + 0.35 * sin(micro_cycle * 6.2831853 + fbm1(uv.y * 20.0 + TIME * 5.0) * 8.0);
	float scan_noise = 0.8 + 0.2 * sin(TIME * flicker_speed + uv.y * 70.0 + fbm1(TIME * 8.0) * 10.0);
	float chaotic_flicker = 0.75 + 0.25 * sin(TIME * (flicker_speed * 1.8) + uv.y * 90.0);

	float pulse = burst_train * cycle_on * pulse_enabled;
	float strobe = mix(1.0, mix(idle_brightness, 1.0, pulse), pulse_enabled);
	float flash_intensity = mix(1.0, mix(1.0, flash_boost * cycle_gain, pulse), pulse_enabled);

	float bolt = max(core, branch);
	float halo = max(glow, branch * 0.85);

	float alpha = (halo * 0.65 + bolt) * opacity;
	alpha *= mix(0.55, 1.0, strobe);
	alpha *= mix(1.0, micro_flash, flicker_enabled);
	alpha *= runtime_flash_multiplier;
	alpha = clamp(alpha, 0.0, 1.0);

	if (alpha < alpha_cutoff) {
		discard;
	}

	vec3 bolt_light = core_color.rgb * bolt;
	vec3 glow_light = glow_color.rgb * halo;
	vec3 emission = bolt_light * core_energy + glow_light * glow_energy;
	emission *= flash_intensity;
	emission *= mix(1.0, micro_flash * scan_noise * chaotic_flicker, flicker_enabled);
	emission *= runtime_flash_multiplier;

	ALBEDO = emission * 0.04;
	EMISSION = emission;
	ALPHA = alpha;
}
