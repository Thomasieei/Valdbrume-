## Ville de départ : zones fusionnées (LOD automatique), collisions simples,
## occulteurs (ce qui est caché derrière un immeuble n'est pas dessiné),
## silhouettes lointaines.
extends Node3D

const GEN := "res://assets/city/gen/"
var meta: Dictionary
var mats := CityMaterials.new()
var view_distance := 620.0
var near_distance := 105.0

func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(GEN + "city.json"))
	mats.build(meta.palette)
	_load_chunks()
	_load_skyline()
	_build_collisions()
	_build_occluders()
	_build_lamps()

func _load_chunks() -> void:
	var root := Node3D.new()
	root.name = "Zones"
	add_child(root)
	for ch in meta.chunks:
		var ps: PackedScene = load(GEN + "chunks/" + ch.name + ".glb")
		var inst := ps.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			mats.apply(mi)
			# version détaillée de près, version imprimée (très légère) de loin
			if mi.name.begins_with("loin"):
				mi.visibility_range_begin = near_distance
				mi.visibility_range_begin_margin = 6.0
				mi.visibility_range_end = view_distance
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mi.visibility_range_end = near_distance
				mi.visibility_range_end_margin = 6.0
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

# ------------------------------------------------------------ éclairage public
var lamps: Array = []           # positions des lanternes
var lights: Array = []          # quelques vraies lumières, données aux lanternes les plus proches
var _lt := 0.0
var nuit := 0.0                 # donné par le cycle jour / nuit

func _build_lamps() -> void:
	if not meta.has("lampes"): return
	var ps: PackedScene = load(GEN + "lampadaire.glb")
	var src := ps.instantiate()
	var parts := {}
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		parts[mi.name] = mi.mesh
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.07, 0.09, 0.085); metal.metallic = 0.7; metal.roughness = 0.42
	var glass := ShaderMaterial.new(); glass.shader = load("res://shaders/lantern.gdshader")
	# regroupement par carrés de 96 m : chaque groupe est masqué au-delà de 190 m
	var cells := {}
	for l in meta.lampes:
		var k := Vector2i(floori(float(l[0]) / 96.0), floori(float(l[1]) / 96.0))
		if not cells.has(k): cells[k] = []
		cells[k].append(l)
		lamps.append(Vector3(l[0], 4.12, l[1]))
	var root := Node3D.new(); root.name = "Lampadaires"; add_child(root)
	for k in cells:
		for part in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = parts[part]
			mm.instance_count = cells[k].size()
			for i in cells[k].size():
				var l: Array = cells[k][i]
				mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, deg_to_rad(float(l[2]))), Vector3(l[0], 0.0, l[1])))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = glass if String(part).contains("verre") else metal
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 190.0
			mmi.visibility_range_end_margin = 10.0
			root.add_child(mmi)
	src.free()
	for i in 8:
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.76, 0.48)
		ol.omni_range = 14.0
		ol.omni_attenuation = 1.1
		ol.light_energy = 0.0
		ol.shadow_enabled = false
		ol.distance_fade_enabled = true
		ol.distance_fade_begin = 55.0; ol.distance_fade_length = 15.0
		ol.visible = false
		add_child(ol)
		lights.append(ol)

func _process(dt: float) -> void:
	_lt += dt
	if _lt < 0.3 or lamps.is_empty(): return
	_lt = 0.0
	var n := nuit
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	if n < 0.05:
		for ol in lights: ol.visible = false
		return
	# les 8 lanternes les plus proches de la caméra reçoivent une vraie lumière
	var cp := cam.global_position
	var best: Array = []
	for p in lamps:
		var d: float = Vector2(p.x - cp.x, p.z - cp.z).length_squared()
		if d > 70.0 * 70.0: continue
		best.append([d, p])
	best.sort_custom(func(a, b): return a[0] < b[0])
	for i in lights.size():
		var ol: OmniLight3D = lights[i]
		if i < best.size():
			ol.visible = true
			ol.global_position = best[i][1]
			ol.light_energy = 2.4 * n
		else:
			ol.visible = false
