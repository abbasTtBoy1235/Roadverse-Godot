shader_type sky;

// Procedural sky for Roadverse: a DayCycle-driven gradient with a sun disc,
// a pale moon disc and hash-star sparkle that fades in with the night.
// All colours arrive as uniforms from TimeOfDay, so the pure DayCycle model
// (and its tests) decide how the sky looks at every hour.

uniform vec4 top_color : source_color = vec4(0.004, 0.008, 0.025, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.03, 0.05, 0.10, 1.0);
uniform vec4 ground_color : source_color = vec4(0.01, 0.012, 0.02, 1.0);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;

	vec3 col = h >= 0.0
		? mix(horizon_color.rgb, top_color.rgb, pow(clamp(h, 0.0, 1.0), 0.55))
		: mix(horizon_color.rgb, ground_color.rgb, pow(clamp(-h, 0.0, 1.0), 0.65));

	float sun_d = max(dot(dir, sun_direction), 0.0);
	col += sun_color.rgb * (pow(sun_d, 600.0) * 1.6 + pow(sun_d, 10.0) * 0.22);

	float moon_d = max(dot(dir, moon_direction), 0.0);
	col += vec3(0.75, 0.82, 0.95) * (pow(moon_d, 900.0) * 0.9 + pow(moon_d, 40.0) * 0.05) * star_amount;

	if (star_amount > 0.001 && h > 0.0) {
		vec3 cell = floor(dir * 260.0);
		float star = step(0.9975, hash13(cell));
		col += vec3(0.9, 0.93, 1.0) * star * star_amount * smoothstep(0.01, 0.25, h);
	}

	COLOR = col;
}
