shader_type spatial;

uniform float rot_x;
uniform bool rotated;
uniform bool axis_z;

uniform sampler2D skin_texture;
uniform vec2 skin_scale;
uniform vec2 skin_offset;

void vertex() {
	float rx_ = rot_x * (axis_z ? VERTEX.z : VERTEX.x);
	float scale = 1.0 + tan(rx_);

	float offset = rotated ? -0.5 : +0.5;
	VERTEX.y += offset;
	VERTEX.y *= scale;
	VERTEX.y -= offset;

	if (rotated) {
		vec2 rx = vec2(sin(rot_x), cos(rot_x));
		mat3 R = mat3(0);
		if (axis_z) {
			R = mat3(
				vec3(1, 0, 0),
				vec3(0, rx.y, -rx.x),
				vec3(0, rx.x, rx.y)
			);
		} else {
			R = mat3(
				vec3(rx.y, rx.x, 0),
				vec3(-rx.x, rx.y, 0),
				vec3(0, 0, 1)
			);
		}
		VERTEX = R * VERTEX;
		NORMAL = R * NORMAL;
	}
}

vec4 linearToSrgb(in vec4 color) {
    return vec4(pow(clamp(color.rgb, 0.0, 1.0), vec3(2.2)), color.a);
}

void fragment() {
	vec2 texcoord = clamp(UV, 0., 1.);
	texcoord = texcoord * skin_scale + skin_offset;
	vec4 texcolor = linearToSrgb(texture(skin_texture, texcoord));
	texcolor += COLOR * (1. - texcolor.a);
	if (texcolor.a <= 0.99) {
		discard;
	}
	ALBEDO = texcolor.rgb;
	METALLIC = 0.;
	ROUGHNESS = 1.;
}
