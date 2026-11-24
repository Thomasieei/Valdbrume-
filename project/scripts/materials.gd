## Matériaux partagés de la ville (créés une seule fois, réutilisés par toutes les zones).
class_name CityMaterials
extends RefCounted

const T := "res://assets/city/textures/"
const G := "res://assets/city/gen/"
var by_name := {}

func _tex(n: String) -> Texture2D:
	return load(T + n + ".png")

func _kit(base: String, ground := false, tint := Vector3.ONE, vertex_tint := 1.0, rough := 1.0, normal_tex := "", orm_tex := "") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/kit_ground.gdshader" if ground else "res://shaders/kit_surface.gdshader")
	var stem := base.replace("_BaseColor", "")
	if stem == "T_Concrete_Asphalt": stem = "T_Concrete"
	m.set_shader_parameter("albedo_tex", _tex(base))
	m.set_shader_parameter("orm_tex", _tex(orm_tex if orm_tex != "" else stem + "_ORM"))
	m.set_shader_parameter("normal_tex", _tex(normal_tex if normal_tex != "" else stem + "_Normal"))
	m.set_shader_parameter("base_tint", tint)
	m.set_shader_parameter("vertex_tint", vertex_tint)
	m.set_shader_parameter("roughness_mul", rough)
	return m

func _interior_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("room_lit_a", _tex("T_lit_interior_1"))
	m.set_shader_parameter("room_lit_b", _tex("T_lit_interior_2"))
	m.set_shader_parameter("room_dark", _tex("T_dark_interior"))
	m.set_shader_parameter("curtains", _tex("T_Curtains"))

func build(palette: Array) -> void:
	var brick := _kit("T_RedBrick_BaseColor")
	by_name["MI_RedBrick"] = brick
	by_name["MI_RedBrick_Pale"] = brick
	by_name["MI_InteriorWall"] = brick
	var trim := _kit("T_Trim_BaseColor")
	by_name["MI_Trim"] = trim
	by_name["MI_Trim_Dark"] = trim
	by_name["MI_Trim_Green"] = trim
	by_name["MI_Trim_MetalConcrete"] = _kit("T_MetalConcrete_BaseColor")
	by_name["MI_Ornaments"] = _kit("T_Ornaments_BaseColor")
	by_name["MI_Concrete"] = _kit("T_Concrete_BaseColor", true)
	by_name["MI_Dirt"] = _kit("T_Dirt_BaseColor")
	by_name["MI_Roof_Slate"] = _kit("T_RoofSlate_BaseColor")
	by_name["MI_InteriorFloor"] = _kit("T_MarbleFloor_BaseColor", true, Vector3(1.05, 1.03, 1.0), 1.0, 0.8)
	by_name["MI_BasinFloor"] = _kit("T_Concrete_BaseColor", true, Vector3(0.55, 0.6, 0.6))
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	by_name["MI_Water"] = water
	by_name["MI_InteriorRoof"] = _kit("T_Concrete_BaseColor")
	by_name["MI_Asphalt"] = _kit("T_Concrete_Asphalt_BaseColor", true, Vector3(0.92, 0.92, 0.95))
	by_name["MI_Roof"] = _kit("T_Concrete_Asphalt_BaseColor", false, Vector3(0.62, 0.6, 0.6))
	by_name["MI_Ground"] = _kit("T_Concrete_Asphalt_BaseColor", true, Vector3(0.5, 0.5, 0.5))
	var dec := ShaderMaterial.new()
	dec.shader = load("res://shaders/decal.gdshader")
	dec.set_shader_parameter("decal_tex", _tex("T_Street_Decals"))
	dec.render_priority = 1
	by_name["MI_StreetDecals"] = dec
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/interior_glass.gdshader")
	_interior_params(glass)
	by_name["MI_FakeInterior"] = glass
	var fac := ShaderMaterial.new()
	fac.shader = load("res://shaders/facade.gdshader")
	fac.set_shader_parameter("atlas_albedo", load(G + "facade_albedo.png"))
	fac.set_shader_parameter("atlas_nc", load(G + "facade_normal.png"))
	fac.set_shader_parameter("atlas_room", load(G + "facade_room.png"))
	var pal := PackedVector3Array()
	for c in palette: pal.append(Vector3(c[0], c[1], c[2]))
	while pal.size() < 16: pal.append(Vector3.ONE)
	fac.set_shader_parameter("palette", pal)
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(G + "facade_atlas.json"))
	fac.set_shader_parameter("relief_scale", Vector2(atlas.px_per_m / float(atlas.width), atlas.px_per_m / float(atlas.height)))
	_interior_params(fac)
	by_name["MI_Facade"] = fac
	var sky := ShaderMaterial.new()
	sky.shader = load("res://shaders/skyline.gdshader")
	by_name["MI_Skyline"] = sky

func apply(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null: return
	for i in mesh.get_surface_count():
		var src := mesh.surface_get_material(i)
		var n := src.resource_name if src else ""
		if by_name.has(n):
			mi.set_surface_override_material(i, by_name[n])
		else:
			push_warning("matériau inconnu : %s" % n)
