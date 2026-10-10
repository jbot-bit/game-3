shader_type spatial;
render_mode cull_disabled;

uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform vec4 crew_color : source_color = vec4(0.384, 0.725, 0.859, 1.0);
uniform vec4 outfit_color : source_color = vec4(0.384, 0.725, 0.859, 1.0);

void fragment() {
	vec3 original = texture(source_texture, UV).rgb;
	vec3 colour = original;
	// The publisher palette has separate emerald scarf and teal tunic ramps.
	// Preserve skin, eyes, hair, belt and boots; only replace those cloth ramps.
	if (original.g > original.r * 1.45 && original.g > original.b * 1.05) {
		vec3 dye = original.g > original.b * 2.2 ? crew_color.rgb : outfit_color.rgb;
		float shade = clamp(original.g / 0.25, 0.25, 1.15);
		colour = dye * shade;
	}
	ALBEDO = colour;
	ROUGHNESS = 0.86;
}
