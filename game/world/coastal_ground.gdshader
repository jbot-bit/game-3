shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
float patch(vec2 p) {
	vec2 cell=floor(p);
	vec2 f=fract(p);
	f=f*f*(3.0-2.0*f);
	float a=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	float b=fract(sin(dot(cell+vec2(1,0),vec2(127.1,311.7)))*43758.5453);
	float c=fract(sin(dot(cell+vec2(0,1),vec2(127.1,311.7)))*43758.5453);
	float d=fract(sin(dot(cell+vec2(1,1),vec2(127.1,311.7)))*43758.5453);
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float growth=patch(world_position.xz*0.18);
	ALBEDO=COLOR.rgb*mix(0.93,1.06,growth);
	ROUGHNESS=1.0;
}
