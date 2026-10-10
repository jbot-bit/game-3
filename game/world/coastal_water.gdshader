shader_type spatial;
render_mode cull_disabled;
varying vec2 sea_position;
uniform vec3 deep_color : source_color = vec3(0.149,0.616,0.706);
uniform vec3 shallow_color : source_color = vec3(0.263,0.784,0.749);
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
	float wave=sin(sea_position.x*0.19+time*0.26)*sin(sea_position.y*0.26-time*0.18);
	float swell=sin(sea_position.y*0.80+sea_position.x*0.12+wave*1.8-time*0.34);
	float breaks=smoothstep(0.15,0.70,sin(sea_position.x*0.58+sin(sea_position.y*0.12)));
	float shimmer=smoothstep(0.965,0.997,swell)*breaks;
	shimmer*=mix(1.0,0.16,smoothstep(50.0,180.0,length(VERTEX)));
	float foam=(1.0-smoothstep(0.08,0.55,abs(abs(d)-0.30-wave*0.12)));
	foam*=0.62+0.15*sin(sea_position.x*1.4+sea_position.y*0.7+time*0.45);
	vec3 water=mix(shallow_color,deep_color,smoothstep(0.0,6.5,abs(d)));
	water*=1.0+wave*0.065;
	ALBEDO=mix(water,shallow_color*0.6+vec3(0.35,0.38,0.36),foam*0.45);
	ALBEDO+=vec3(0.14,0.18,0.17)*shimmer;
	NORMAL_MAP=vec3(0.5+cos(sea_position.x*0.19+time*0.26)*0.065,0.5+cos(sea_position.y*0.26-time*0.18)*0.06,1.0);
	NORMAL_MAP_DEPTH=0.4;
	ROUGHNESS=0.48;
	SPECULAR=0.28;
}
