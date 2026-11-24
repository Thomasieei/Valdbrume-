// Vefects - SH_Vefects_URP_VFX_Opaque_Fr_01: opaque lit (alpha tested), back faces culled, regular meshes (MeshInstance3D).
// Specular highlights off, like every material of this shader (Unity _SPECULARHIGHLIGHTS_OFF); reflections stay.
shader_type spatial;
render_mode skip_vertex_transform, depth_draw_opaque, cull_back, specular_disabled;

#define VFX_LIT
#define VFX_NO_SCENE_DEPTH
#define VFX_STATIC_MESH
#include "res://Vefects/Stylized Fire/Shared/Shaders/SH_Vefects_URP_VFX_Opaque_Fr_01.gdshaderinc"
