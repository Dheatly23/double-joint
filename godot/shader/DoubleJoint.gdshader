shader_type spatial;

const float SQRT_1_2 = 0.7071067811865476;
const float SQRT_2 = 1.4142135623730951;

uniform float rot_x;
uniform float rot_y;
uniform bool rotated;

uniform sampler2D skin_texture;
uniform vec2 skin_scale;
uniform vec2 skin_offset;

void vertex() {
	float rot_y_ = rot_y * -.5;
	vec2 rx = vec2(sin(rot_x), cos(rot_x)).yx;
	vec2 ry = vec2(sin(rot_y_), cos(rot_y_));

	// [cry + srx**2*(1 - cry), -crx*sry, srx*crx*(1 - cry)]
	// [crx*sry, cry, -srx*sry]
	// [srx*crx*(1 - cry), srx*sry, cry + crx**2*(1 - cry)]
	mat3 R = mat3(
		vec3(ry.y + pow(rx.x, 2.) * (1. - ry.y), rx.y * ry.x, rx.x * rx.y * (1. - ry.y)),
		vec3(-rx.y * ry.x, ry.y, rx.x * ry.x),
		vec3(rx.x * rx.y * (1. - ry.y), -rx.x * ry.x, ry.y + pow(rx.y, 2.) * (1. - ry.y))
	);

	mat2 MI = inverse(transpose(mat2(R[0].xz, R[2].xz)));
	vec2 v0 = MI * -VERTEX.xz;
	float scale = dot(R[1].xz, v0);
	scale = max(scale * SQRT_2 + 1., 0);

	float offset = rotated ? -SQRT_1_2 : +SQRT_1_2;
	VERTEX.y += offset;
	VERTEX.y *= scale;
	VERTEX.y -= offset;

	if (rotated) {
		R *= R;
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
