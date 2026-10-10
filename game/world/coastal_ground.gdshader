shader_type spatial;
render_mode cull_disabled;
varying vec3 ground_position;
void vertex() { ground_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	// Large, quiet patches add depth without a noisy pixel texture underfoot.
	vec2 p=ground_position.xz;
	float meadow=step(COLOR.r,COLOR.g);
	float patch=sin(p.x*0.21+sin(p.y*0.15))*sin(p.y*0.24-p.x*0.07);
	float fine=sin(p.x*2.7+p.y*0.7)*sin(p.y*3.1-p.x*0.5);
	vec3 shade=COLOR.rgb*(1.0+patch*mix(0.035,0.10,meadow)+fine*0.008);
	// Wet sand darkens gently as it meets the water; no terrain displacement.
	float wet=1.0-smoothstep(0.05,0.85,ground_position.y);
	ALBEDO=mix(shade,shade*vec3(0.72,0.83,0.83),wet*(1.0-meadow));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
