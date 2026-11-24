// Vefects - SH_Vefects_URP_VFX_Opaque_Fr_01 (Unity URP Lit, Amplify Shader Editor), Forward pass.
// Opaque lit surface used by the metallic spheres of the demo layout. Two fresnel rims are combined into one mask:
// the first one as is, the second one broken up by a panning noise and faded towards the top and bottom of the UV
// (v * (1 - v) band, so on a sphere it fades at the poles). The mask blends the base color towards the fresnel base
// color and drives the emission: either a flat emissive color or, with use_lu_ts, a LUT gradient sampled by the
// mask, hue shifted and desaturated.
// Vertex streams: TEXCOORD0.xy = UV. Also reads the world normal and the world position (view direction).
// The Unity pass always compiles the alpha test (Alpha = 1 against cutoff). Render state is set by the variant
// .gdshader file that includes this one. Direct lighting is Godot's own; the reflections are URP's environment
// specular (EnvironmentBRDFSpecular) of a reflection panorama (reflection_texture, e.g. the demo HDRI), added to the
// emission, so the spheres reflect the same surroundings as in the original demo without a Godot reflection probe.

group_uniforms Surface;
uniform float metallic = 1.0;
uniform float smoothness = 0.0;
uniform float emissive = 1.0;
uniform vec4 color_fresnel_emissive : source_color = vec4(1.0, 0.5254902, 0.0, 1.0);
uniform vec4 color_fresnel_base : source_color = vec4(0.0, 0.0, 0.0, 0.0);
/** Alpha test threshold (the surface alpha is always 1, so only values above 1 clip anything). */
uniform float cutoff = 0.5;
/** Kept for material compatibility: the Unity pass compiles the alpha test unconditionally and never reads it. */
uniform float alpha_clip = 0.0;
group_uniforms;

group_uniforms Reflections;
/** Equirectangular panorama the surface reflects (black = no reflections). */
uniform sampler2D reflection_texture : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float reflection_intensity = 1.0;
/** Mip offset of the panorama (log2(panorama width / (4 * probe resolution))). */
uniform float reflection_lod_offset = 0.0;
group_uniforms;

group_uniforms Noise;
uniform sampler2D noises_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 noises_texture_sampling = ivec3(0, 0, 1);
uniform vec4 noises01_selector = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 noises01_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 noises01_speed = vec4(0.1, -1.0, 0.0, 0.0);
group_uniforms;

group_uniforms LUT;
uniform sampler2D lut : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 lut_sampling = ivec3(0, 0, 1);
uniform float lut_offset = 0.0;
uniform float lut_speed = 0.0;
uniform float lut_amplitude = 1.0;
/** Toggle (Unity keyword _USELUTS_ON): 1 = emission from the LUT, 0 = flat color_fresnel_emissive * emissive. */
uniform float use_lu_ts = 0.0;
uniform float hue_shift = 0.0;
uniform float desaturate = 0.0;
group_uniforms;

group_uniforms Fresnel;
uniform float fresnel_intensity = 0.05;
uniform float fresnel_bias = 0.0;
uniform float fresnel_scale = 1.0;
uniform float fresnel_power = 10.0;
group_uniforms;

group_uniforms Fresnel_02;
uniform float fresnel02_intensity = 0.05;
uniform float fresnel02_bias = 0.0;
uniform float fresnel02_scale = 1.0;
uniform float fresnel02_power = 10.0;
uniform float fresnel_emissive_multiply = 1.0;
group_uniforms;

#include "res://Vefects/Stylized Fire/Shared/Shaders/VFX_Unity_Common.gdshaderinc"

// Declared after the common include: its vertex() has a local variable named `color`.
group_uniforms Surface;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
group_uniforms;

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

// URP GlossyEnvironmentReflection * EnvironmentBRDFSpecular (metallic workflow), reflection_texture as the probe.
vec3 environment_specular(vec3 base_color, float metal, float surface_smoothness, vec3 n_unity, vec3 v_unity) {
	float one_minus_reflectivity = 0.96 * (1.0 - metal);
	vec3 brdf_specular = mix(vec3(0.04), base_color, metal);
	float grazing = clamp(surface_smoothness + (1.0 - one_minus_reflectivity), 0.0, 1.0);
	float perceptual = 1.0 - surface_smoothness;
	float r = max(perceptual * perceptual, 0.0078125);
	float r2 = max(r * r, 6.103515625e-5);
	float no_v = clamp(dot(n_unity, v_unity), 0.0, 1.0);
	float fresnel = pow(1.0 - no_v, 4.0);
	// Unity axes -> Godot axes (z negated), then Godot's panorama convention.
	vec3 d = reflect(-v_unity, n_unity) * vec3(1.0, 1.0, -1.0);
	float u = atan(d.x, -d.z) / TAU;
	vec2 pano_uv = vec2(u < 0.0 ? u + 1.0 : u, acos(clamp(d.y, -1.0, 1.0)) / PI);
	float mip = perceptual * (1.7 - 0.7 * perceptual) * 6.0;
	vec3 env = textureLod(reflection_texture, pano_uv, mip + reflection_lod_offset).rgb * reflection_intensity;
	return env * (1.0 / (r2 + 1.0)) * mix(brdf_specular, vec3(grazing), fresnel);
}

void fragment() {
	// Amplify Fresnel nodes (renormalized world normal, normalized world view direction).
	vec3 camera_pos = vfx_to_unity(INV_VIEW_MATRIX[3].xyz);
	vec3 view_dir = normalize(camera_pos - vfx_world_pos);
	float n_dot_v = dot(normalize(vfx_world_normal), view_dir);
	float fresnel = fresnel_bias + fresnel_scale * pow(max(1.0 - n_dot_v, 0.0001), fresnel_power);
	float fresnel02 = fresnel02_bias + fresnel02_scale * pow(max(1.0 - n_dot_v, 0.0001), fresnel02_power);

	// Panning noise.
	vec2 noise_uv = TIME * noises01_speed.xy + vfx_tc0.xy * noises01_scale.xy;
	float noise = dot(vfx_sample(noises_texture, noise_uv, noises_texture_sampling), noises01_selector);

	// Band along v: 0 at both ends, 1 in the middle.
	float v = vfx_tc0.y;
	float band = smoothstep(0.5, 0.5 + 0.5, (v * (1.0 - v)) * 4.0);

	float rim01 = clamp(clamp(fresnel, 0.0, 1.0) * fresnel_intensity, 0.0, 1.0);
	float rim02 = clamp(clamp(fresnel02, 0.0, 1.0) * fresnel02_intensity, 0.0, 1.0);
	float noise_mask = clamp(clamp(noise, 0.0, 1.0) * clamp(band, 0.0, 1.0), 0.0, 1.0);
	float rim = clamp(rim01 + clamp(rim02 * noise_mask, 0.0, 1.0), 0.0, 1.0);

	vec3 base_color = mix(color.rgb, color_fresnel_base.rgb, rim);

	// Emission color: flat, or the LUT sampled by the rim mask (hue shift + desaturate).
	vec4 emission_color;
	if (use_lu_ts > 0.5) {
		vec2 lut_uv = TIME * vec2(lut_speed) + vec2(rim * lut_amplitude + lut_offset);
		vec3 hsv = rgb_to_hsv(vfx_sample(lut, lut_uv, lut_sampling).rgb);
		vec3 shifted = hsv_to_rgb(vec3(hsv.x + hue_shift, hsv.y, hsv.z));
		float luma = dot(shifted, vec3(0.299, 0.587, 0.114));
		emission_color = vec4(mix(shifted, vec3(luma), desaturate), 0.0);
	} else {
		emission_color = color_fresnel_emissive * emissive;
	}

	ALBEDO = base_color;
	METALLIC = clamp(metallic, 0.0, 1.0);
	ROUGHNESS = vfx_urp_roughness(smoothness);
	EMISSION = (emission_color * (rim * fresnel_emissive_multiply)).rgb
		+ environment_specular(base_color, METALLIC, clamp(smoothness, 0.0, 1.0), normalize(vfx_world_normal), view_dir);

	// URP alpha test (AlphaDiscard: clip(Alpha - cutoff)) with Alpha = 1. Written as a discard instead of ALPHA /
	// ALPHA_SCISSOR_THRESHOLD so the surface stays a plain opaque shadow caster.
	if (1.0 - cutoff < 0.0) {
		discard;
	}
}
