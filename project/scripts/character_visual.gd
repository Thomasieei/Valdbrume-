## Apparence d'un personnage : corps, vêtements générés, coiffure, teintes,
## squelette animé par la banque partagée. Utilisé par le héros et les habitants.
class_name CharacterVisual
extends Node3D

const GEN := "res://assets/characters/gen/"
const BASE := "res://assets/characters/base/"
static var _cast := {}
static var _shaders := {}
var data: Dictionary
var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var current := ""
var weapon: Node3D

static func cast_data() -> Dictionary:
	if _cast.is_empty():
		for d in JSON.parse_string(FileAccess.get_file_as_string(GEN + "cast.json")):
			_cast[d.id] = d
	return _cast

static func _sh(n: String) -> Shader:
	if not _shaders.has(n): _shaders[n] = load("res://shaders/%s.gdshader" % n)
	return _shaders[n]

func setup(id: String) -> void:
	data = cast_data()[id]
	model = (load(GEN + data.fichier) as PackedScene).instantiate()
	add_child(model)
	scale = Vector3.ONE * float(data.taille)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		_materials(mi)
	_hair(data.cheveux, data.c_cheveux)
	if data.get("barbe", false): _hair("Hair_Beard", data.c_cheveux)
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.root_node = NodePath("..")
	AnimBank.attach(anim)
	anim.playback_default_blend_time = 0.18

func _col(a) -> Color: return Color(a[0], a[1], a[2])

func _materials(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	for i in mesh.get_surface_count():
		var src := mesh.surface_get_material(i)
		var n := src.resource_name if src else ""
		if n.begins_with("MI_Superhero"):
			var m := ShaderMaterial.new(); m.shader = _sh("skin")
			var s := src as BaseMaterial3D
			m.set_shader_parameter("albedo_tex", s.albedo_texture)
			m.set_shader_parameter("normal_tex", s.normal_texture)
			m.set_shader_parameter("rough_tex", s.roughness_texture)
			var t := float(data.peau)
			m.set_shader_parameter("tone", Vector3(t, pow(t, 1.08), pow(t, 1.18)))
			mi.set_surface_override_material(i, m)
		elif n.begins_with("MI_Hair"):     # sourcils
			var m2 := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			m2.albedo_color = _col(data.c_cheveux).lightened(0.05) * 1.6
			mi.set_surface_override_material(i, m2)
		elif n.begins_with("CL_"):
			var kind := n.substr(3)
			var spec: Dictionary = data.get(kind, {})
			var m3 := ShaderMaterial.new(); m3.shader = _sh("cloth")
			m3.set_shader_parameter("color", _col(spec.get("couleur", [0.5, 0.5, 0.5])))
			m3.set_shader_parameter("accent", _col(spec.get("col", [0.1, 0.1, 0.1])))
			m3.set_shader_parameter("fabric", {"coton": 0, "jean": 1, "cuir": 2, "laine": 3, "toile": 4, "nylon": 5}.get(spec.get("tissu", "coton"), 0))
			m3.set_shader_parameter("garment", {"haut": 0, "bas": 1, "pieds": 2, "extra": 3, "sous": 4}.get(kind, 0))
			m3.set_shader_parameter("style", {"veste": 1, "costume": 2, "blouse": 3, "chemise": 4, "pull": 5, "combinaison": 6, "bottes": 7}.get(spec.get("type", ""), 0))
			var c: Dictionary = data.decoupes.get(n, {})
			for k in ["xmax", "ymin", "ymax", "zmin", "open_w", "open_y", "belt"]:
				if c.has(k): m3.set_shader_parameter(k, float(c[k]))
			mi.set_surface_override_material(i, m3)

func _hair(style: String, col) -> void:
	var ps: PackedScene = load(BASE + style + ".gltf")
	if ps == null: return
	var h := ps.instantiate()
	var bi := skeleton.find_bone("Head")
	if bi < 0: return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skeleton.add_child(att)
	att.add_child(h)
	# la coiffure est modelée en pose de repos : on annule la transformation de la tête
	h.transform = skeleton.get_bone_global_rest(bi).affine_inverse()
	var tex_n := 2 if style in ["Hair_Buns", "Hair_Long"] else 1
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new(); m.shader = _sh("hair")
		m.set_shader_parameter("strands", load(BASE + "T_Hair_%d_BaseColor.png" % tex_n))
		m.set_shader_parameter("strands_n", load(BASE + "T_Hair_%d_Normal.png" % tex_n))
		m.set_shader_parameter("tint", Vector3(col[0], col[1], col[2]))
		mi.material_override = m

func play(n: String, blend := -1.0, speed := 1.0, restart := false) -> void:
	var p := AnimBank.path(n)
	if p == "": return
	anim.speed_scale = speed
	if current != n or restart:
		anim.play(p, blend)
		current = n
		if restart: anim.seek(0.0, true)

func length(n: String) -> float: return AnimBank.length(n)

func set_weapon(kind: String) -> void:
	if weapon: weapon.queue_free(); weapon = null
	if kind != "epee": return
	var ps: PackedScene = load("res://assets/characters/props/Human_Sword.fbx")
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skeleton.add_child(att)
	var w := ps.instantiate()
	att.add_child(w)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/human/HumanAnimations_ColorPalette.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.metallic = 0.6; mat.roughness = 0.35
	for m in w.find_children("*", "MeshInstance3D", true, false): m.material_override = mat
	w.rotation_degrees = Vector3(0, 0, -90)
	w.position = Vector3(0.0, 0.08, 0.02)
	weapon = att
