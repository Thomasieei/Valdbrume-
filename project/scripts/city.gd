## Ville de départ : zones fusionnées (LOD automatique), collisions simples,
## occulteurs (ce qui est caché derrière un immeuble n'est pas dessiné),
## silhouettes lointaines.
extends Node3D

const GEN := "res://assets/city/gen/"
var meta: Dictionary
var mats := CityMaterials.new()
var view_distance := 560.0

func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(GEN + "city.json"))
	mats.build(meta.palette)
	_load_chunks()
	_load_skyline()
	_build_collisions()
	_build_occluders()

func _load_chunks() -> void:
	var root := Node3D.new()
	root.name = "Zones"
	add_child(root)
	for ch in meta.chunks:
		var ps: PackedScene = load(GEN + "chunks/" + ch.name + ".glb")
		var inst := ps.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			mats.apply(mi)
			mi.visibility_range_end = view_distance
			mi.visibility_range_end_margin = 30.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(inst)

func _load_skyline() -> void:
	var ps: PackedScene = load(GEN + "skyline.glb")
	var inst := ps.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		mats.apply(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 0.0
	add_child(inst)

func _box(body: StaticBody3D, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation_degrees = rot
	body.add_child(cs)

func _build_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "Collisions"
	add_child(body)
	var ground := CollisionShape3D.new()
	var wb := WorldBoundaryShape3D.new()
	wb.plane = Plane(Vector3.UP, -0.15)
	ground.shape = wb
	body.add_child(ground)
	for b in meta.islands:
		_box(body, Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]))
	for b in meta.boxes:
		_box(body, Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]))
	for r in meta.ramps:
		_box(body, Vector3(r.pos[0], r.pos[1], r.pos[2]), Vector3(r.size[0], r.size[1], r.size[2]), Vector3(r.rot_x, r.rot_y, 0))
	# limites de la ville (au cas où) : murs invisibles au bout des rues
	var c: Array = meta.city
	_box(body, Vector3(c[0] - 1.0, 20, 0), Vector3(2, 40, c[3] - c[1] + 40))
	_box(body, Vector3(c[2] + 1.0, 20, 0), Vector3(2, 40, c[3] - c[1] + 40))
	_box(body, Vector3(0, 20, c[1] - 1.0), Vector3(c[2] - c[0] + 40, 40, 2))
	_box(body, Vector3(0, 20, c[3] + 1.0), Vector3(c[2] - c[0] + 40, 40, 2))

func _build_occluders() -> void:
	var root := Node3D.new()
	root.name = "Occulteurs"
	add_child(root)
	for o in meta.occluders:
		var oi := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new()
		bo.size = Vector3(max(o[3], 0.5), max(o[4], 0.5), max(o[5], 0.5))
		oi.occluder = bo
		oi.position = Vector3(o[0], o[1], o[2])
		root.add_child(oi)
