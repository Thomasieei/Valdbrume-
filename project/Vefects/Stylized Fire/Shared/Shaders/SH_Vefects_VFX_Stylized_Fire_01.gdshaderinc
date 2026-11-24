// Vefects - SH_Vefects_VFX_Stylized_Fire_01 (Unity URP Unlit, Amplify Shader Editor), Forward pass.
// Stylized flame drawn on vertical billboards: two panning noises (the first one with a random offset and an
// optional random rotation, both warped by a third panning noise) distort the green channel of the masks
// texture, which is eroded twice by a smoothstep: once to pick the colour in a LUT gradient (with hue shift and
// desaturation) and once for the opacity. The erosion is pushed by the scene depth fade and a fresnel term, so the
// flame thins out where it meets geometry and towards its silhouette. Faded near the camera, and the vertices can
// be pulled towards / pushed away from the camera (camera offset).
//
// Vertex streams: TEXCOORD0.xy = UV, TEXCOORD0.z = erosion, TEXCOORD0.w = distortion multiplier,
// TEXCOORD1.x = emission multiplier, TEXCOORD1.y = random offset, TEXCOORD1.z = erosion smoothness multiplier,
// TEXCOORD1.w = random rotation (radians), COLOR = tint (rgb) and opacity (a). Also reads the world normal
// (fresnel) and the scene depth (depth fade).
// Render state (blend / cull) is set by the variant .gdshader files that include this one.

group_uniforms Clevender;
uniform float clevendercom_learn_vfx_now = 777.0;
group_uniforms;

group_uniforms General;
uniform float emissive = 1.0;
uniform float overall_scale = 1.0;
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
/** Channel weights of the noise (dot product with the texture rgba). */
uniform vec4 noises01_selector = vec4(0.0, 1.0, 0.0, 0.0);
/** UV scale (xy). */
uniform vec4 noises01_scale = vec4(1.0, 1.0, 0.0, 0.0);
/** Pan speed (xy, per second). */
uniform vec4 noises01_speed = vec4(0.1, -1.0, 0.0, 0.0);
group_uniforms;

group_uniforms Noise_Secondary;
uniform sampler2D noises_texture_secondary : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 noises_texture_secondary_sampling = ivec3(0, 0, 1);
uniform vec4 noises02_selector = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 noises02_scale = vec4(0.555, 0.555, 0.0, 0.0);
uniform vec4 noises02_speed = vec4(-0.01, -0.2, 0.0, 0.0);
group_uniforms;

group_uniforms Noise_Tertiary;
uniform sampler2D noises_texture_tertiary : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 noises_texture_tertiary_sampling = ivec3(0, 0, 1);
uniform vec4 noises03_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 noises03_speed = vec4(0.05, -0.5, 0.0, 0.0);
group_uniforms;

group_uniforms Masks;
uniform sampler2D masks_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 masks_texture_sampling = ivec3(0, 0, 1);
uniform vec4 masks_texture_st = vec4(1.0, 1.0, 0.0, 0.0);
group_uniforms;

group_uniforms Distortion;
uniform float distortion_intensity = 1.0;
uniform float distortion_vertical = -1.0;
uniform float distortion_horizontal = 0.1;
uniform float distortion_mask_ero = 0.0;
uniform float distortion_mask_ero_smoothness = 0.3;
uniform float noises_tertiary_distortion_intensity = 1.0;
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
/** Moves the vertices along the camera ray by this percentage of their distance to the camera
 *  (negative = towards the camera). */
uniform float camera_offset = 0.0;
group_uniforms;

/** Linear part of the object -> world matrix the camera offset goes through (Godot axes): the mesh transform for
 *  regular meshes, identity for particles (their vertices are already in world space). */
#ifdef VFX_STATIC_MESH
#define STYLIZED_FIRE_OBJECT_BASIS(model) mat3(model)
#else
#define STYLIZED_FIRE_OBJECT_BASIS(model) mat3(1.0)
#endif

/** Amplify vertex offset: (world position - camera position) * camera_offset * 0.01, added to the object space
 *  position. Takes and returns Unity axes. */
vec3 stylized_fire_camera_offset(vec3 object_pos, mat4 model, mat4 inv_view) {
	vec3 local = vec3(object_pos.x, object_pos.y, -object_pos.z);
#ifdef VFX_STATIC_MESH
	vec3 world = (model * vec4(local, 1.0)).xyz;
#else
	vec3 world = local;
#endif
	vec3 to_vertex = world - inv_view[3].xyz;
	return vec3(to_vertex.x, to_vertex.y, -to_vertex.z) * (camera_offset * 0.01);
}

// The offset needs the camera and model matrices: the macro expands inside the common vertex().
#define VFX_VERTEX_OFFSET
#define vfx_vertex_offset(object_pos, object_normal, tc0, tc1, tc2, color) stylized_fire_camera_offset(object_pos, MODEL_MATRIX, INV_VIEW_MATRIX)

#include "res://Vefects/Stylized Fire/Shared/Shaders/VFX_Unity_Common.gdshaderinc"

/** Camera near plane distance (Unity _ProjectionParams.y). */
float camera_near(mat4 inv_proj) {
	vec4 p = inv_proj * vec4(0.0, 0.0, 1.0, 1.0);
	return -p.z / p.w;
}

/** Amplify HSV to RGB. */
vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

/** Amplify RGB to HSV. */
vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

/** HLSL mul(v, float2x2(c, -s, s, c)) (Amplify Rotator around the origin). */
vec2 rotate_uv(vec2 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(v.x * c + v.y * s, -v.x * s + v.y * c);
}

void fragment() {
	vec2 uv = vfx_tc0.xy;
	float vtc_erosion = vfx_tc0.z;
	float vtc_distortion = vfx_tc0.w;
	float vtc_emission = vfx_tc1.x;
	float vtc_random_offset = vfx_tc1.y;
	float vtc_erosion_smoothness = vfx_tc1.z;
	float vtc_random_rotation = vfx_tc1.w * enable_random_rotation;

	// Erosion push: scene depth fade (inverted) plus fresnel.
	vec3 camera_pos = vfx_to_unity(INV_VIEW_MATRIX[3].xyz);
	vec3 view_dir = normalize(camera_pos - vfx_world_pos);
	vec3 normal_ws = normalize(vfx_world_normal);
	float scene_fade = vfx_depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade);
	float n_dot_v = dot(normal_ws, view_dir);
	float fresnel = fresnel_bias + fresnel_scale * pow(max(1.0 - n_dot_v, 0.0001), fresnel_power);
	float edge = clamp((1.0 - clamp(scene_fade, 0.0, 1.0)) + clamp(clamp(fresnel, 0.0, 1.0) * fresnel_intensity, 0.0, 1.0), 0.0, 1.0);

	// Noises.
	vec2 noise_uv = (uv * overall_scale) * vec2(noises_tile_vertical, noises_tile_horizontal);
	vec2 pan01 = TIME * (noises01_speed.xy * overall_speed) + noise_uv * noises01_scale.xy;
	vec2 pan02 = TIME * (noises02_speed.xy * overall_speed) + noise_uv * noises02_scale.xy;
	vec2 pan03 = TIME * (noises03_speed.xy * overall_speed) + noise_uv * noises03_scale.xy;
	vec3 tertiary = vfx_sample(noises_texture_tertiary, pan03 + vtc_random_offset * 1.777, noises_texture_tertiary_sampling).rgb;
	vec2 tertiary_distortion = ((tertiary.xy + -0.5) * 2.0) * (noises_tertiary_distortion_intensity * 0.1);
	vec2 noise01_uv = rotate_uv((pan01 + vtc_random_offset * clevendercom_learn_vfx_now) + tertiary_distortion, vtc_random_rotation);
	float noise01 = dot(vfx_sample(noises_texture, noise01_uv, noises_texture_sampling), noises01_selector);
	vec2 noise02_uv = (pan02 + vtc_random_offset * 1.333) + tertiary_distortion;
	float noise02 = dot(vfx_sample(noises_texture_secondary, noise02_uv, noises_texture_secondary_sampling), noises02_selector);
	float noises = clamp(noise01, 0.0, 1.0) + clamp(noise02, 0.0, 1.0);

	// Distortion of the mask UV, masked by the red channel and growing with the height.
	vec2 masks_uv = uv * masks_texture_st.xy + masks_texture_st.zw;
	float distortion_mask = smoothstep(distortion_mask_ero, distortion_mask_ero + distortion_mask_ero_smoothness, vfx_sample(masks_texture, masks_uv, masks_texture_sampling).r);
	float distortion = clamp(uv.y, 0.0, 1.0) * (clamp(noises * clamp(distortion_mask, 0.0, 1.0), 0.0, 1.0) * (distortion_intensity * vtc_distortion));
	vec2 distorted_uv = vec2(uv.x + distortion * distortion_horizontal, uv.y + distortion * distortion_vertical);
	float shape = vfx_sample(masks_texture, distorted_uv, masks_texture_sampling).g;

	// Colour: LUT by the eroded shape, hue shift, desaturation, particle tint and emission.
	float lut_ero = lut_erosion + (vtc_erosion + edge);
	float lut_shape = smoothstep(lut_ero, lut_ero + lut_erosion_smoothness * vtc_erosion_smoothness, shape);
	float lut_coord = clamp(lut_shape, 0.0, 1.0) * lut_amplitude + lut_offset;
	vec2 lut_uv = TIME * vec2(lut_speed) + vec2(lut_coord);
	vec3 hsv = rgb_to_hsv(vfx_sample(lut, lut_uv, lut_sampling).rgb);
	vec3 shifted = hsv_to_rgb(vec3(hsv.x + hue_shift, hsv.y, hsv.z));
	vec3 desaturated = mix(shifted, vec3(dot(shifted, vec3(0.299, 0.587, 0.114))), desaturate);
	vec3 color = (desaturated * vfx_color.rgb) * (emissive * vtc_emission);

	// Opacity: eroded shape, particle opacity, camera depth fade.
	float ero = erosion + (vtc_erosion + edge);
	float opacity_shape = smoothstep(ero, ero + erosion_smoothness * vtc_erosion_smoothness, shape);
	// Unity measures the camera fade with the eye depth of the vertex before the camera offset. The offset moves
	// the world position w to c + (I + k * A) (w - c) (c = camera, A = object basis, k = camera_offset * 0.01):
	// undo it to recover that depth.
	vec3 offset_from_camera = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - INV_VIEW_MATRIX[3].xyz;
	mat3 offset_basis = mat3(1.0) + (camera_offset * 0.01) * STYLIZED_FIRE_OBJECT_BASIS(MODEL_MATRIX);
	vec3 from_camera = inverse(offset_basis) * offset_from_camera;
	float eye_depth = -(mat3(VIEW_MATRIX) * from_camera).z;
	float camera_fade = (eye_depth - camera_near(INV_PROJECTION_MATRIX) - camera_depth_fade_offset) / camera_depth_fade_length;
	float alpha = clamp(clamp(clamp(opacity_shape, 0.0, 1.0) * vfx_color.a, 0.0, 1.0) * clamp(camera_fade, 0.0, 1.0), 0.0, 1.0);

	VFX_OUTPUT(color, alpha);
}
