shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	bool mineral_yellow = color.r > 0.72 && color.g > 0.42 && color.b < 0.34 && color.r - color.b > 0.42;
	if (mineral_yellow) {
		float lightness = clamp((color.r + color.g) * 0.55, 0.0, 1.0);
		color.rgb = mix(vec3(0.22, 0.35, 0.39), vec3(0.74, 0.84, 0.86), lightness);
	}
	COLOR = color;
}
