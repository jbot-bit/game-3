shader_type spatial;
render_mode cull_disabled;
varying vec2 sea_position;
uniform vec3 deep_color : source_color = vec3(0.045,0.28,0.37);
uniform vec3 shallow_color : source_color = vec3(0.16,0.60,0.58);
uniform float motion = 1.0;
uniform float layout_scale = 1.0;
float shore_box(vec2 p, vec2 center, vec2 half_size) {
	vec2 q=abs(p-center)-half_size;
	return length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0);
}
void vertex() { sea_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 p=sea_position/layout_scale;
	float angle=atan(p.y,p.x);
	float tide_bay=max(0.0,1.0-abs(mod(angle-0.28+3.14159265,6.2831853)-3.14159265)/0.38);
	float variation=sin(angle*3.0+0.5)*2.7+sin(angle*7.0)*1.2-tide_bay*20.0;
	float outer=(length(p/vec2(106.0+variation,94.0+variation))-1.0)*94.0;
	vec2 q=abs(p)/vec2(54.0,47.5);
	float inner=(pow(pow(q.x,8.0)+pow(q.y,8.0),0.125)-1.0)*47.5;
	float d=max(outer,-inner);
	d=max(d,-shore_box(p,vec2(0,80),vec2(10,40)));
	d*=layout_scale;
	float time=TIME*motion;
	float wave=sin(sea_position.x*0.45+time*0.6)*sin(sea_position.y*0.34-time*0.4);
	float shimmer=smoothstep(0.88,1.0,sin(sea_position.x*0.9+sea_position.y*0.4+wave+time*0.45))*smoothstep(0.2,0.8,sin(sea_position.y*1.1-sea_position.x*0.35));
	float foam=(1.0-smoothstep(0.2,1.2,abs(d)))*(0.6+0.4*sin(d*3.0-time*1.2+wave));
	vec3 water=mix(shallow_color,deep_color,smoothstep(1.0,9.0,abs(d)));
	ALBEDO=water+vec3(0.015,0.045,0.055)*shimmer+vec3(0.25,0.3,0.26)*max(foam,0.0);
	ROUGHNESS=0.34;
	SPECULAR=0.45;
}
