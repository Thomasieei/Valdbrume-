## Défi chronométré « Les toits des Lanternes » : passer dans chaque anneau,
## du pied de l'échelle jusqu'au saut final dans les sacs. Le record est gardé.
extends Node

signal fini(temps: float, record: bool)
var life: Node
var player: Node3D
var anneaux: Array = []          # positions
var noeuds: Array = []           # anneaux visibles
var actif := false
var suivant := 0
var temps := 0.0
var lab: Label
var mat_off := StandardMaterial3D.new()
var mat_on := StandardMaterial3D.new()
var mat_fait := StandardMaterial3D.new()

func setup(p_life: Node, p_player: Node3D, pts: Array) -> void:
	life = p_life; player = p_player
	for m in [mat_off, mat_on, mat_fait]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_off.albedo_color = Color(1.0, 0.75, 0.3, 0.35)
	mat_on.albedo_color = Color(0.4, 0.85, 1.0, 0.85)
	mat_fait.albedo_color = Color(0.4, 1.0, 0.5, 0.0)
	var tm := TorusMesh.new(); tm.inner_radius = 0.95; tm.outer_radius = 1.12; tm.rings = 24; tm.ring_segments = 8
	for p in pts:
		var a := Vector3(p[0], p[1], p[2])
		anneaux.append(a)
		var n := MeshInstance3D.new(); n.mesh = tm; n.material_override = mat_off
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.rotation.x = PI / 2.0
		get_parent().add_child.call_deferred(n)
		n.position = a
		noeuds.append(n)
	var cl := CanvasLayer.new(); add_child(cl)
	lab = Label.new(); cl.add_child(lab)
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	lab.add_theme_color_override("font_outline_color", Color.BLACK); lab.add_theme_constant_override("outline_size", 8)
	lab.position = Vector2(560, 64)
	lab.visible = false
	_reset()

func record() -> float:
	return float(life.mem.get("_defis", {}).get("toits", 0.0))

func _reset() -> void:
	actif = false; suivant = 0; temps = 0.0
	for i in noeuds.size():
		noeuds[i].material_override = mat_on if i == 0 else mat_off
		noeuds[i].visible = true

func _process(dt: float) -> void:
	if noeuds.is_empty(): return
	var t := Time.get_ticks_msec() / 1000.0
	for i in noeuds.size():
		var n: MeshInstance3D = noeuds[i]
		n.rotation.z = t * 0.8 + i
		n.scale = Vector3.ONE * (1.0 + (0.08 * sin(t * 5.0) if i == suivant else 0.0))
	var pp := player.global_position + Vector3(0, 1.0, 0)
	if not actif:
		lab.visible = false
		if pp.distance_to(anneaux[0]) < 1.6:
			actif = true; suivant = 1; temps = 0.0
			noeuds[0].material_override = mat_fait
			noeuds[1].material_override = mat_on
			Sfx.joue("degaine", player.global_position, 0.0, 0.0)
		return
	temps += dt
	var r := record()
	lab.visible = true
	lab.text = "Défi des toits   %s   (%d / %d)%s" % [_fmt(temps), suivant, anneaux.size() - 1, "   record %s" % _fmt(r) if r > 0.0 else ""]
	if pp.distance_to(anneaux[suivant]) < 1.9:
		noeuds[suivant].material_override = mat_fait
		Sfx.joue("parade", anneaux[suivant], 0.0, 0.0)
		suivant += 1
		if suivant >= anneaux.size():
			var nouveau := r <= 0.0 or temps < r
			if nouveau:
				if not life.mem.has("_defis"): life.mem["_defis"] = {}
				life.mem["_defis"]["toits"] = temps
				life._save()
			fini.emit(temps, nouveau)
			_reset()
		else:
			noeuds[suivant].material_override = mat_on
	# abandon : retombé au sol loin de l'arrivée, ou trop long
	if temps > 180.0 or (suivant >= 2 and suivant < anneaux.size() - 1 and player.global_position.y < 2.0 and player.is_on_floor()):
		_reset()

func _fmt(s: float) -> String:
	return "%d:%05.2f" % [int(s) / 60, fmod(s, 60.0)]
