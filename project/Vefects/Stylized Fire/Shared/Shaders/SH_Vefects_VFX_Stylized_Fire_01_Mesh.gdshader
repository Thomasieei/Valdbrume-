// Vefects - SH_Vefects_VFX_Stylized_Fire_01: alpha blended, back faces culled, regular meshes (MeshInstance3D).
shader_type spatial;
render_mode unshaded, skip_vertex_transform, depth_draw_never, blend_mix, cull_back;

#define VFX_STATIC_MESH
#include "res://Vefects/Stylized Fire/Shared/Shaders/SH_Vefects_VFX_Stylized_Fire_01.gdshaderinc"
