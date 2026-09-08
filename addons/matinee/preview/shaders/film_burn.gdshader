shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec2 burn_origin = vec2(0.35, 0.55);
uniform vec4 hot_color : source_color = vec4(1.0, 0.92, 0.62, 1.0);
uniform vec4 burn_color : source_color = vec4(0.95, 0.30, 0.035, 1.0);

float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 delta = uv - burn_origin;
	delta.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float noise = hash21(floor(uv * 180.0)) * 0.08;
	float distance_from_origin = length(delta) + noise;
	float threshold = mix(-0.08, 1.45, progress);
	float black_mask = 1.0 - smoothstep(threshold, threshold + 0.075, distance_from_origin);
	float edge = 1.0 - smoothstep(0.015, 0.09, abs(distance_from_origin - threshold));
	vec3 edge_color = mix(burn_color.rgb, hot_color.rgb, edge);
	float cover = smoothstep(0.94, 1.0, progress);
	vec3 final_color = mix(edge_color, vec3(0.0), max(black_mask, cover));
	COLOR = vec4(final_color, clamp(max(max(black_mask, edge), cover), 0.0, 1.0));
}
