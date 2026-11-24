## Traînée lumineuse d'une arme : on mémorise la garde et la pointe à chaque
## image pendant un coup, et on trace un ruban qui s'efface (coût : 1 appel).
class_name WeaponTrail
extends MeshInstance3D

var source: Node3D            # attache de l'arme (suit la main)
var base_off := Vector3.ZERO  # garde, dans le repère de l'arme
var tip_off := Vector3(0, 1, 0)
var samples: Array = []       # [garde, pointe, âge]
var active := false
var life := 0.16
var im := ImmediateMesh.new()

func setup(src: Node3D, p_base: Vector3, p_tip: Vector3, col: Color) -> void:
	source = src; base_off = p_base; tip_off = p_tip
	top_level = true
	mesh = im
	material_override = Fx.trail_material(col)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0

func _process(dt: float) -> void:
	if source == null or not is_instance_valid(source): return
	global_transform = Transform3D.IDENTITY
	for s in samples: s[2] += dt
	while samples.size() > 0 and samples[0][2] > life: samples.pop_front()
	if active:
		var x := source.global_transform
		samples.append([x * base_off, x * tip_off, 0.0])
		if samples.size() > 24: samples.pop_front()
	im.clear_surfaces()
	if samples.size() < 2: return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := samples.size()
	for i in range(n - 1, -1, -1):
		var s: Array = samples[i]
		var age := clampf(s[2] / life, 0.0, 1.0)
		im.surface_set_color(Color(1, 1, 1, 1.0 - age))
		im.surface_set_uv(Vector2(age, 0.0)); im.surface_add_vertex(s[0])
		im.surface_set_uv(Vector2(age, 1.0)); im.surface_add_vertex(s[1])
	im.surface_end()
