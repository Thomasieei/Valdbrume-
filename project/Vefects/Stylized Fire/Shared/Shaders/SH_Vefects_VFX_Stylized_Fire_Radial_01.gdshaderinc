// Vefects - SH_Vefects_VFX_Stylized_Fire_Radial_01 (Unity URP Unlit, Amplify Shader Editor), Forward pass.
// Radial stylized fire: the particle UV is turned into polar coordinates (radius, angle) around the quad centre,
// optionally twisted and panned. Two noise textures (picked by their channel selectors) are scrolled over those
// coordinates and bent by a third one; their sum distorts the polar UV that reads the green channel of the mask
// texture, inside a radial mask that keeps the centre undistorted. The mask, eroded by the particle, the scene depth
// fade and a fresnel term, picks a color in the LUT gradient (with hue shift / desaturation); the opacity is the
// same mask with its own erosion, times the particle alpha and a camera depth fade.
//
// The noise and mask textures are sampled with explicit gradients built from ddx(u) / ddy(v) of the particle UV,
// like the Unity graph: the polar UV jumps at the angle seam, and its own derivatives would pick the smallest mip
// along that line.
//
// Vertex streams (Unity custom vertex streams):
//   TEXCOORD0 (vfx_tc0): xy = UV, z = erosion, w = distortion intensity.
//   TEXCOORD1 (vfx_tc1): x = emissive, y = random offset, z = erosion smoothness, w = random rotation (radians).
//   COLOR: tint (rgb) and opacity (a). World normal / view direction: fresnel.
// Vertex offset: the vertex moves towards the camera by camera_offset percent of its distance to it.
// Render state (blend / cull) is set by the variant .gdshader files that include this one.

group_uniforms Clevender;
uniform float clevendercom_learn_vfx_now = 777.0;
group_uniforms;

group_uniforms General;
uniform float emissive = 1.0;
uniform float overall_uv_scale = 1.0;
uniform float overall_speed = 1.0;
uniform float noises_tile_vertical = 1.0;
uniform float noises_tile_horizontal = 1.0;
uniform float enable_random_rotation = 0.0;
uniform float erosion = 0.0;
uniform float erosion_smoothness = 1.0;
group_uniforms;

group_uniforms Noise;
uniform sampler2D noises_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 noises_texture_sampling = ivec3(0, 0, 1);
uniform vec4 noises01_selector = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 noises01_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 noises01_speed = vec4(-0.3, 0.01, 0.0, 0.0);
group_uniforms;

group_uniforms Noise_Secondary;
uniform sampler2D noises_texture_secondary : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 noises_texture_secondary_sampling = ivec3(0, 0, 1);
uniform vec4 noises02_selector = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 noises02_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 noises02_speed = vec4(-0.115, 0.01, 0.0, 0.0);
group_uniforms;

group_uniforms Noise_Tertiary;
uniform sampler2D noises_texture_tertiary : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 noises_texture_tertiary_sampling = ivec3(0, 0, 1);
uniform vec4 noises03_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 noises03_speed = vec4(-0.2, -0.01, 0.0, 0.0);
uniform float noises03_distort_intensity = 1.0;
group_uniforms;

group_uniforms Radial_Distort_Mask;
uniform float radial_distort_mask_size = 0.0;
uniform float radial_distort_mask_sharpness = 1.0;
uniform float radial_distortion_mask_ero = 0.0;
uniform float radial_distortion_mask_ero_smo = 0.5;
group_uniforms;

group_uniforms Twist;
uniform float twist_intensity = 0.0;
uniform float polar_coordinates_radial_scale = 0.5;
uniform float polar_coordinates_length_scale = 1.0;
uniform vec4 polar_coordinates_pan_speed = vec4(0.0, 0.0, 0.0, 0.0);
group_uniforms;

group_uniforms Masks;
uniform sampler2D masks_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 masks_texture_sampling = ivec3(0, 0, 1);
uniform float mask_erosion = 0.7;
uniform float mask_erosion_smoothness = 0.3;
group_uniforms;

group_uniforms Distortion;
uniform float distortion_intensity = 1.0;
uniform float distortion_inversion = -1.0;
group_uniforms;

group_uniforms Camera_Depth_Fade;
uniform float camera_depth_fade_length = 0.333;
uniform float camera_depth_fade_offset = 0.0;
group_uniforms;

group_uniforms LUT;
uniform sampler2D lut : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 lut_sampling = ivec3(0, 0, 1);
uniform float lut_offset = 0.0;
uniform float lut_speed = 0.0;
uniform float lut_amplitude = 1.0;
uniform float lut_erosion = 0.0;
uniform float lut_erosion_smoothness = 1.0;
uniform float hue_shift = 0.0;
uniform float desaturate = 0.0;
group_uniforms;

group_uniforms Depth_Fade;
uniform float depth_fade = 0.1;
group_uniforms;

group_uniforms Fresnel;
uniform float fresnel_intensity = 1.0;
uniform float fresnel_bias = 0.0;
uniform float fresnel_scale = 1.0;
uniform float fresnel_power = 5.0;
group_uniforms;

group_uniforms Camera_Offset;
uniform float camera_offset = 0.0;
group_uniforms;

/** Camera offset (Amplify vertex offset): (world position - camera position) * camera_offset %, added to the
 *  object space position like Unity does. object_pos is in Unity axes; the matrices are Godot's. For particles the
 *  object space is the world space; meshes are moved to world space first. */
vec3 camera_offset_vertex(vec3 object_pos, mat4 model_matrix, mat4 inv_view) {
	vec3 flip = vec3(1.0, 1.0, -1.0);
#ifdef VFX_STATIC_MESH
	vec3 world_pos = (model_matrix * vec4(object_pos * flip, 1.0)).xyz * flip;
#else
	vec3 world_pos = object_pos;
#endif
	vec3 camera_pos = inv_view[3].xyz * flip;
	return (world_pos - camera_pos) * (camera_offset * 0.01);
}

#define VFX_VERTEX_OFFSET
#define vfx_vertex_offset(object_pos, object_normal, tc0, tc1, tc2, color) camera_offset_vertex(object_pos, MODEL_MATRIX, INV_VIEW_MATRIX)

#include "res://Vefects/Stylized Fire/Shared/Shaders/VFX_Unity_Common.gdshaderinc"

/** HLSL smoothstep: equal edges give a step instead of an undefined result. */
float vfx_smoothstep(float edge0, float edge1, float x) {
	float t = edge1 == edge0 ? (x > edge0 ? 1.0 : 0.0) : clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

/** vfx_sample with explicit gradients (HLSL tex2D(s, uv, ddx, ddy)); the gradients are Unity ones (UV v up,
 *  screen y up) and are converted to the flipped Godot UV and screen. Clamped axes keep the uv half a texel of the
 *  mip level the gradients select (plus the next one, trilinear) away from the border: the sampler repeats, and the
 *  polar mask UV goes far below 0 in the middle of the radial flames, where Unity's clamp sampler reads the edge. */
vec4 vfx_sample_grad(sampler2D tex, vec2 uv_unity, vec2 grad_x, vec2 grad_y, ivec3 s) {
	vec2 uv = uv_unity;
	if (s.x != 0 || s.y != 0) {
		vec2 size = vec2(textureSize(tex, 0));
		float rho = max(length(grad_x * size), length(grad_y * size));
		float lod = max(ceil(log2(max(rho, 1e-6))), 0.0);
		vec2 h = min(0.5 * exp2(lod + 1.0) / size, vec2(0.5));
		if (s.x != 0) {
			uv.x = clamp(uv.x, h.x, 1.0 - h.x);
		}
		if (s.y != 0) {
			uv.y = clamp(uv.y, h.y, 1.0 - h.y);
		}
	}
	vec4 c = textureGrad(tex, vec2(uv.x, 1.0 - uv.y), vec2(grad_x.x, -grad_x.y), vec2(-grad_y.x, grad_y.y));
	if (s.z != 0) {
		c.rgb = vfx_srgb_to_linear(c.rgb);
	}
	return c;
}

/** Camera near plane distance (Unity _ProjectionParams.y), whatever the depth convention of the projection. */
float vfx_camera_near(mat4 inv_proj) {
	vec4 a = inv_proj * vec4(0.0, 0.0, 0.0, 1.0);
	vec4 b = inv_proj * vec4(0.0, 0.0, 1.0, 1.0);
	return min(-a.z / a.w, -b.z / b.w);
}

/** Amplify "Polar Coordinates" around (0.5, 0.5): (radius * 2 * radial scale, angle / 2pi * length scale). */
vec2 polar_coordinates(vec2 uv, float radial_scale, float length_scale) {
	vec2 d = uv - vec2(0.5);
	return vec2(radial_scale * (length(d) * 2.0), (atan(d.x, d.y) * (1.0 / TAU)) * length_scale);
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

/** Two noise layers scrolled independently on x and y: uv * scale + (speed.x * t, speed.y * t). */
vec2 scrolled_uv(vec2 uv, vec4 scale, vec4 speed, float time) {
	return vec2(scale.x * uv.x, uv.y * scale.y) + vec2(speed.x * time, time * speed.y);
}

void fragment() {
	vec2 uv = vfx_tc0.xy;
	float vtc_erosion = vfx_tc0.z;
	float vtc_distortion = vfx_tc0.w;
	float vtc_emissive = vfx_tc1.x;
	float vtc_random_offset = vfx_tc1.y;
	float vtc_erosion_smoothness = vfx_tc1.z;
	float vtc_random_rotation = vfx_tc1.w * enable_random_rotation;

	// Gradients of every noise / mask sample: (ddx(u), ddx(u)) and (ddy(v), ddy(v)), Unity screen axes.
	float ddx_u = dFdx(uv.x);
	float ddy_v = -dFdy(uv.y);
	vec2 grad_x = vec2(ddx_u);
	vec2 grad_y = vec2(ddy_v);

	// Erosion from the scene depth fade and the fresnel term.
	float scene_fade = vfx_depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade);
	vec3 camera_pos = vfx_to_unity(INV_VIEW_MATRIX[3].xyz);
	vec3 view_dir = normalize(camera_pos - vfx_world_pos);
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		// Orthographic camera: Unity uses the camera direction.
		view_dir = normalize(vfx_to_unity(INV_VIEW_MATRIX[2].xyz));
	}
	float n_dot_v = dot(normalize(vfx_world_normal), view_dir);
	float fresnel = fresnel_bias + fresnel_scale * pow(max(1.0 - n_dot_v, 0.0001), fresnel_power);
	float edge_erosion = clamp((1.0 - clamp(scene_fade, 0.0, 1.0)) + clamp(clamp(fresnel, 0.0, 1.0) * fresnel_intensity, 0.0, 1.0), 0.0, 1.0);

	// Polar UV of the mask (unit scales) and twisted, panned polar UV of the noises.
	vec2 mask_polar = polar_coordinates(uv, 1.0, 1.0);
	vec2 polar = polar_coordinates(uv, polar_coordinates_radial_scale, polar_coordinates_length_scale);
	vec2 polar_pan = TIME * polar_coordinates_pan_speed.xy;
	vec2 twisted_uv = (((polar + polar_pan) + polar.x * twist_intensity) * overall_uv_scale) * vec2(noises_tile_vertical, noises_tile_horizontal);
	float time = TIME * overall_speed;

	// Tertiary noise: distorts the two other noises.
	vec2 noise03_uv = scrolled_uv(twisted_uv, noises03_scale, noises03_speed, time) + vtc_random_offset * 1.777;
	vec2 noise03_distortion = ((vfx_sample_grad(noises_texture_tertiary, noise03_uv, grad_x, grad_y, noises_texture_tertiary_sampling).rgb.xy - 0.5) * 2.0) * (noises03_distort_intensity * 0.1);

	// Noise 01, randomly offset and rotated per particle.
	vec2 noise01_uv = (scrolled_uv(twisted_uv, noises01_scale, noises01_speed, time) + noise03_distortion) + vtc_random_offset * clevendercom_learn_vfx_now;
	float rot_cos = cos(vtc_random_rotation);
	float rot_sin = sin(vtc_random_rotation);
	noise01_uv = vec2(noise01_uv.x * rot_cos + noise01_uv.y * rot_sin, -noise01_uv.x * rot_sin + noise01_uv.y * rot_cos);
	float noise01 = dot(vfx_sample_grad(noises_texture, noise01_uv, grad_x, grad_y, noises_texture_sampling), noises01_selector);

	// Noise 02.
	vec2 noise02_uv = (scrolled_uv(twisted_uv, noises02_scale, noises02_speed, time) + noise03_distortion) + vtc_random_offset * 1.333;
	float noise02 = dot(vfx_sample_grad(noises_texture_secondary, noise02_uv, grad_x, grad_y, noises_texture_secondary_sampling), noises02_selector);

	float uv_distortion = clamp(clamp(noise01, 0.0, 1.0) + clamp(noise02, 0.0, 1.0), 0.0, 1.0) * distortion_inversion;

	// Radial mask: no distortion in the centre of the quad.
	float radial = clamp((length(uv * 2.0 - 1.0) - radial_distort_mask_size) * radial_distort_mask_sharpness, 0.0, 1.0);
	float radial_mask = clamp(vfx_smoothstep(radial_distortion_mask_ero, radial_distortion_mask_ero + radial_distortion_mask_ero_smo, clamp(1.0 - radial, 0.0, 1.0)), 0.0, 1.0);
	float final_distortion = (uv_distortion * radial_mask) * (distortion_intensity * vtc_distortion);

	// Fire mask (green channel) on the distorted polar UV.
	float mask_sample = vfx_sample_grad(masks_texture, mask_polar + final_distortion, grad_x, grad_y, masks_texture_sampling).g;
	float mask = clamp(vfx_smoothstep(mask_erosion, mask_erosion + mask_erosion_smoothness, mask_sample), 0.0, 1.0);

	// Color: the eroded mask picks a color in the (panning) LUT, then hue shift, desaturation, tint and emission.
	float lut_threshold = lut_erosion + (vtc_erosion + edge_erosion);
	float lut_mask = vfx_smoothstep(lut_threshold, lut_threshold + lut_erosion_smoothness * vtc_erosion_smoothness, mask);
	vec2 lut_uv = vec2((clamp(lut_mask, 0.0, 1.0) * lut_amplitude) + lut_offset) + TIME * vec2(lut_speed);
	vec3 hsv = rgb_to_hsv(vfx_sample(lut, lut_uv, lut_sampling).rgb);
	vec3 shifted = hsv_to_rgb(vec3(hsv.x + hue_shift, hsv.y, hsv.z));
	vec3 desaturated = mix(shifted, vec3(dot(shifted, vec3(0.299, 0.587, 0.114))), desaturate);
	vec3 color = (desaturated * vfx_color.rgb) * (emissive * vtc_emissive);

	// Opacity: eroded mask * particle alpha * camera depth fade. The camera depth fade uses the eye depth of the
	// vertex before the camera offset: undo the offset (linear in the position relative to the camera).
	float threshold = erosion + (vtc_erosion + edge_erosion);
	float opacity_mask = vfx_smoothstep(threshold, threshold + erosion_smoothness * vtc_erosion_smoothness, mask);
	vec3 to_vertex = mat3(INV_VIEW_MATRIX) * VERTEX;
#ifdef VFX_STATIC_MESH
	mat3 offset_matrix = mat3(1.0) + mat3(MODEL_MATRIX) * (camera_offset * 0.01);
#else
	mat3 offset_matrix = mat3(1.0) * (1.0 + camera_offset * 0.01);
#endif
	float eye_depth = -(mat3(VIEW_MATRIX) * (inverse(offset_matrix) * to_vertex)).z;
	float camera_fade = (eye_depth - vfx_camera_near(INV_PROJECTION_MATRIX) - camera_depth_fade_offset) / camera_depth_fade_length;
	float alpha = clamp(clamp(clamp(opacity_mask, 0.0, 1.0) * vfx_color.a, 0.0, 1.0) * clamp(camera_fade, 0.0, 1.0), 0.0, 1.0);

	VFX_OUTPUT(color, alpha);
}
