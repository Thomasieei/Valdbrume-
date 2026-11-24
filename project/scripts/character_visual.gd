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
var weapon_mesh: Node3D        # le modèle de l'arme (pour la traînée)
var extras: Array = []         # carquois, arme dans le dos, aura…
var cloth_mats := {}           # vêtement -> matériau (pour changer de tenue)
static var _palette_mat: StandardMaterial3D

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
			cloth_mats[kind] = m3

func _hair(style: String, col) -> void:
	var ps: PackedScene = load(BASE + style + ".gltf")
	if ps == null: return
	var h := ps.instantiate() as Node3D
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

## armes : réglage de la prise en main (os, rotation, décalage) pour chaque modèle
const ARMES := {
	"epee": ["Human_Sword", "hand_r", Vector3(0, 0, -90), Vector3(0.0, 0.08, 0.02)],
	"epee_lourde": ["Human_Greatsword", "hand_r", Vector3(0, 0, -90), Vector3(0.0, 0.08, 0.02)],
	"dague": ["Human_Dagger", "hand_r", Vector3(0, 0, -90), Vector3(0.0, 0.08, 0.02)],
	"arc": ["HumanArcher_Bow", "hand_l", Vector3(90, 0, 0), Vector3(0.0, 0.08, -0.02)],
}
## dans le dos (rangée) : sur la colonne, en diagonale
const DOS := {
	"epee_lourde": [Vector3(0, 90, 145), Vector3(0.0, 0.05, -0.2)],
	"epee": [Vector3(0, 90, 145), Vector3(0.0, 0.05, -0.18)],
	"carquois": [Vector3(0, 90, 160), Vector3(0.05, 0.0, -0.17)],
}

static func palette_mat() -> StandardMaterial3D:
	if _palette_mat == null:
		_palette_mat = StandardMaterial3D.new()
		_palette_mat.albedo_texture = load("res://assets/human/HumanAnimations_ColorPalette.png")
		_palette_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_palette_mat.metallic = 0.6; _palette_mat.roughness = 0.35
	return _palette_mat

func _prop(fichier: String, bone: String, rot: Vector3, pos: Vector3) -> Node3D:
	var ps: PackedScene = load("res://assets/characters/props/%s.fbx" % fichier)
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skeleton.add_child(att)
	var w := ps.instantiate() as Node3D
	att.add_child(w)
	for m in w.find_children("*", "MeshInstance3D", true, false):
		m.material_override = palette_mat()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.rotation_degrees = rot
	w.position = pos
	return att

func set_weapon(kind: String) -> void:
	if weapon: weapon.queue_free(); weapon = null; weapon_mesh = null
	for e in extras:
		if is_instance_valid(e): e.queue_free()
	extras.clear()
	# comme les chasseurs de Solo Leveling, les armes sortent de l'inventaire : rien dans le dos
	if kind == "magie":
		# l'énergie du chasseur au creux de la main
		var att := BoneAttachment3D.new(); att.bone_name = "hand_r"; skeleton.add_child(att)
		var f := Fx.spawn(att, "Mystic", "01", Transform3D(Basis(), Vector3(0.0, 0.06, 0.0)), 0.32, -1.0)
		var l := OmniLight3D.new(); l.light_color = Fx.TEINTE.Mystic; l.light_energy = 0.9; l.omni_range = 2.2
		att.add_child(l); extras.append(att)
		return
	if not ARMES.has(kind): return
	var a: Array = ARMES[kind]
	weapon = _prop(a[0], a[1], a[2], a[3])
	weapon_mesh = weapon.get_child(0)

## arme rangée dans le dos (habitants devenus chasseurs)
func set_back_weapon(kind: String) -> void:
	var a: Array = ARMES[kind]
	extras.append(_prop(a[0], "spine_03", DOS[kind][0], DOS[kind][1]))

## garde et pointe de l'arme dans son propre repère (axe le plus long du modèle)
func weapon_axis() -> Array:
	var box := AABB()
	var first := true
	for m in weapon_mesh.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = weapon_mesh.global_transform.affine_inverse() * m.global_transform
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b); first = false
	var ax := box.get_longest_axis_index()
	var lo := box.position[ax]; var hi := box.end[ax]
	var tip := hi if absf(hi) > absf(lo) else lo
	var grip := lo if tip == hi else hi
	var a := box.get_center(); var b2 := box.get_center()
	a[ax] = lerpf(grip, tip, 0.28); b2[ax] = tip
	return [a, b2]

## tenue de chasseur : combinaison sombre à liserés lumineux, bottes de cuir
func hunter_look(accent: Color) -> void:
	var specs := {"haut": [Color(0.07, 0.08, 0.11), 5, 6], "bas": [Color(0.06, 0.06, 0.08), 2, 0], "pieds": [Color(0.05, 0.045, 0.04), 2, 7]}
	for k in specs:
		if cloth_mats.has(k):
			var m: ShaderMaterial = cloth_mats[k]
			m.set_shader_parameter("color", specs[k][0])
			m.set_shader_parameter("accent", accent)
			m.set_shader_parameter("fabric", specs[k][1])
			if specs[k][2] > 0: m.set_shader_parameter("style", specs[k][2])
