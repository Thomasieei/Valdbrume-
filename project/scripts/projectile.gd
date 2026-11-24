## Projectile du héros : orbe de magie ou flèche. Vole droit (léger guidage
## vers la cible visée), touche les ennemis du groupe « ennemis », s'écrase
## contre les murs, et finit par une explosion stylisée.
class_name Projectile
extends Node3D

var vel := Vector3.ZERO
var degats := 10.0
var couleur := "Mystic"
var kind := "sort"          # "sort" ou "fleche"
var cible: Node3D = null
var vie := 1.6
var taille := 1.0
var _last := Vector3.ZERO
var exclude: Array[RID] = []
static var _arrow: PackedScene
static var _orb_mat: StandardMaterial3D

func lance(from: Vector3, dir: Vector3, vitesse: float, p_cible: Node3D) -> void:
	global_position = from
	_last = from
	vel = dir.normalized() * vitesse
	cible = p_cible
	look_at(from + dir, Vector3.UP)
	if kind == "fleche":
		if _arrow == null: _arrow = load("res://assets/characters/props/HumanArcher_Arrow.fbx")
		var a := _arrow.instantiate() as Node3D
		add_child(a)
		a.rotation_degrees = Vector3(-90, 0, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/human/HumanAnimations_ColorPalette.png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		for m in a.find_children("*", "MeshInstance3D", true, false): m.material_override = mat
		Fx.spawn(self, "Electric", "02", Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, 0.35)), 0.3 * taille, -1.0)
	else:
		if _orb_mat == null:
			_orb_mat = StandardMaterial3D.new()
			_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_orb_mat.albedo_color = Color(1, 1, 1)
			_orb_mat.emission_enabled = true
		var core := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.11 * taille; sm.height = 0.22 * taille; sm.radial_segments = 12; sm.rings = 6
		core.mesh = sm; core.material_override = _orb_mat
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(core)
		# la flamme stylisée couchée dans le sens du vol forme la traîne de l'orbe
		Fx.spawn(self, couleur, "01", Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), 0.75 * taille, -1.0)
		var l := OmniLight3D.new(); l.light_color = Fx.TEINTE[couleur]; l.light_energy = 2.2; l.omni_range = 4.5
		add_child(l)

func _physics_process(dt: float) -> void:
	vie -= dt
	if cible and is_instance_valid(cible) and cible.get("vivant") != false:
		var to: Vector3 = (cible.global_position + Vector3(0, 1.0, 0)) - global_position
		vel = vel.slerp(to.normalized() * vel.length(), clampf(3.5 * dt, 0.0, 1.0))
	var next := global_position + vel * dt
	# ennemis touchés sur le segment parcouru
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e.get("vivant") == false: continue
		var c: Vector3 = e.global_position + Vector3(0, e.get("hauteur") * 0.5, 0)
		var seg := Geometry3D.get_closest_point_to_segment(c, global_position, next)
		if seg.distance_to(c) < float(e.get("rayon")) + 0.15:
			e.touche(degats, global_position, kind)
			_boum(seg)
			return
	var q := PhysicsRayQueryParameters3D.create(global_position, next, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		_boum(hit.position + hit.normal * 0.1); return
	global_position = next
	if vel.length() > 0.1: look_at(global_position + vel, Vector3.UP)
	if vie <= 0.0: _boum(global_position)

func _boum(p: Vector3) -> void:
	var parent := get_parent()
	var k := "Radial_01" if kind == "sort" else "Radial_02"
	var col := couleur if kind == "sort" else "Electric"
	Fx.spawn(parent, col, k, Transform3D(Basis(), p - Vector3(0, 0.1, 0)), (1.0 if kind == "sort" else 0.7) * taille, 1.6)
	Fx.flash(parent, p, Fx.TEINTE[col], 4.0 * taille, 7.0)
	queue_free()
