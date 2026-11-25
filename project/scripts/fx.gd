## Effets visuels : flammes et explosions stylisées (pack Vefects), éclairs de
## lumière, projectiles (sorts, flèches), traînée d'épée. Tout est mis en cache
## et préchauffé au chargement pour éviter les à-coups à la première utilisation.
class_name Fx
extends RefCounted

const ROOT := "res://Vefects/Stylized Fire/VFX/%s/Particles/VFX_Stylized_Fire_%s_%s.tscn"
const FLAMES := "res://Vefects/Stylized Fire/VFX/Flames/Particles/VFX_Stylized_Fire_%s.tscn"
## couleurs de l'énergie de chaque usage
const TEINTE := {"Electric": Color(0.45, 0.75, 1.0), "Mystic": Color(0.62, 0.45, 1.0), "Dark": Color(0.55, 0.25, 0.95),
	"Pure": Color(0.9, 0.95, 1.0), "Flames": Color(1.0, 0.55, 0.2), "Poison": Color(0.5, 1.0, 0.35), "Water": Color(0.35, 0.7, 1.0)}
static var _scenes := {}
static var _trail_shader: Shader

static func scene(couleur: String, kind: String) -> PackedScene:
	var key := couleur + kind
	if not _scenes.has(key):
		var p := FLAMES % kind if couleur == "Flames" else ROOT % [couleur, kind, couleur]
		_scenes[key] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[key]

## kind : "01" (flamme), "02" (flamme fine), "Radial_01" / "Radial_02" (explosion au sol)
## duree < 0 : l'effet reste attaché (xf est alors local au parent)
static func spawn(parent: Node, couleur: String, kind: String, xf: Transform3D, taille := 1.0, duree := 2.5) -> Node3D:
	var ps := scene(couleur, kind)
	if ps == null: return null
	var n := ps.instantiate() as Node3D
	parent.add_child(n)
	if duree < 0.0: n.transform = xf.scaled_local(Vector3.ONE * taille)
	else: n.global_transform = xf.scaled_local(Vector3.ONE * taille)
	if duree > 0.0: n.get_tree().create_timer(duree).timeout.connect(n.queue_free)
	return n

## éclair de lumière bref (impact, lancement de sort)
static func flash(parent: Node, pos: Vector3, col: Color, energie := 3.0, portee := 6.0, duree := 0.35) -> void:
	var l := OmniLight3D.new()
	l.light_color = col; l.light_energy = energie; l.omni_range = portee
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duree).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)

## préchauffe : chaque effet utilisé est instancié une fois devant la caméra, en tout petit
static func prewarm(parent: Node, cam: Camera3D) -> void:
	for c in ["Electric", "Mystic", "Dark", "Pure"]:
		for k in ["01", "02", "Radial_01", "Radial_02"]:
			var xf := Transform3D(Basis(), cam.global_position - cam.global_basis.z * 3.0)
			spawn(parent, c, k, xf, 0.01, 0.4)

static func trail_material(col: Color) -> ShaderMaterial:
	if _trail_shader == null: _trail_shader = load("res://shaders/trail.gdshader")
	var m := ShaderMaterial.new(); m.shader = _trail_shader
	m.set_shader_parameter("color", col)
	return m

## chiffre de dégâts qui jaillit et s'efface (critique : plus gros, doré)
static func nombre(parent: Node, pos: Vector3, val: float, crit := false, col := Color(1, 1, 1)) -> void:
	mot(parent, pos, str(int(round(val))) + ("!" if crit else ""), Color(1.0, 0.82, 0.3) if crit else col, crit)

static func mot(parent: Node, pos: Vector3, texte: String, col := Color(1, 1, 1), gros := false) -> void:
	var l := Label3D.new()
	var crit := gros
	l.text = texte
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011 if crit else 0.0008
	l.font_size = 64
	l.outline_size = 14
	l.modulate = col
	l.render_priority = 10
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 0.9, 0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

## arrêt sur image puis ralenti : donne du poids aux coups (temps réel, pas le temps du jeu)
static var _hs_busy := false
static func impact(tree: SceneTree, arret := 0.05, ralenti := 1.0, duree_ralenti := 0.0) -> void:
	if _hs_busy: return
	_hs_busy = true
	Engine.time_scale = 0.04
	await tree.create_timer(arret, true, false, true).timeout
	if duree_ralenti > 0.0:
		Engine.time_scale = ralenti
		await tree.create_timer(duree_ralenti, true, false, true).timeout
	Engine.time_scale = 1.0
	_hs_busy = false


## choc d'impact (étoile + anneau, 0,2 s) ; « onde » : anneau qui court au sol
static var _impact_shader: Shader
static var _quad: QuadMesh
static func choc(parent: Node, pos: Vector3, taille := 1.0, col := Color(1.0, 0.9, 0.7), onde := false, duree := 0.22) -> void:
	if _impact_shader == null:
		_impact_shader = load("res://shaders/impact.gdshader"); _quad = QuadMesh.new()
	var m := ShaderMaterial.new(); m.shader = _impact_shader
	m.set_shader_parameter("color", col); m.set_shader_parameter("seed", randf() * 10.0)
	m.set_shader_parameter("flat_ring", onde)
	var mi := MeshInstance3D.new(); mi.mesh = _quad; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * taille
	if onde: mi.rotation.x = -PI / 2.0
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, duree)
	tw.tween_callback(mi.queue_free)
