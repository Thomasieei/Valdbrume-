## Monstre sorti d'un portail : rugit à son arrivée, traque la cible la plus
## proche (héros ou chasseur allié), attaque au contact, recule sous les coups
## (éclair blanc), meurt en se dissolvant dans une flamme sombre.
class_name Monstre
extends CharacterBody3D

signal mort(m: Monstre)
const TYPES := {
	"rodeur": {"fichier": "res://assets/monsters/rodeur.glb", "pv": 60.0, "vitesse": 4.6, "degats": 8.0, "portee": 1.7, "rayon": 0.45, "hauteur": 1.7, "nom": "Rôdeur aveugle", "taille": 1.15},
	"brute": {"fichier": "res://assets/monsters/brute.glb", "pv": 320.0, "vitesse": 3.4, "degats": 18.0, "portee": 2.6, "rayon": 0.9, "hauteur": 2.6, "nom": "Brute de lave", "taille": 1.25},
}
var type := "rodeur"
var d: Dictionary
var pv := 60.0
var vivant := true
var rayon := 0.45
var hauteur := 1.7
var model: Node3D
var anim: AnimationPlayer
var state := "rugit"
var t := 0.0
var cd := 0.0
var cible = null
var frappe_faite := false
var flash := 0.0
var meshes: Array = []
var barre: Label3D
var recul := Vector3.ZERO
static var _overlay: ShaderMaterial

func setup(p_type: String) -> void:
	type = p_type; d = TYPES[type]
	pv = d.pv; rayon = d.rayon; hauteur = d.hauteur * d.taille
	add_to_group("ennemis")
	collision_layer = 4; collision_mask = 1 | 4
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = rayon * d.taille; cap.height = hauteur
	col.shape = cap; col.position.y = hauteur * 0.5
	add_child(col)
	model = (load(d.fichier) as PackedScene).instantiate()
	model.scale = Vector3.ONE * d.taille
	add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Idle", "Walk", "Run"]:
		if anim.has_animation(n): anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim.playback_default_blend_time = 0.15
	if _overlay == null:
		_overlay = ShaderMaterial.new(); _overlay.shader = load("res://shaders/hit_flash.gdshader")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _overlay
		meshes.append(mi)
	barre = Label3D.new()
	barre.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	barre.position.y = hauteur + 0.45
	barre.font_size = 40; barre.outline_size = 10; barre.pixel_size = 0.004
	barre.modulate = Color(1, 0.55, 0.45)
	add_child(barre)
	_barre()
	anim.play("Roar")
	floor_snap_length = 0.4

func _barre() -> void:
	var n := clampi(int(ceil(10.0 * pv / d.pv)), 0, 10)
	var s := ""
	for i in 10: s += "■" if i < n else "□"
	barre.text = "%s\n%s" % [d.nom, s]

func _cible() -> Node3D:
	var best: Node3D = null; var bd := 60.0
	for c in get_tree().get_nodes_in_group("combattants"):
		if c.get("vivant") == false or not c.visible: continue
		var dd: float = global_position.distance_to(c.global_position)
		if dd < bd: bd = dd; best = c
	return best

func touche(dmg: float, from: Vector3, _kind := "") -> void:
	if not vivant: return
	pv -= dmg
	flash = 1.0
	Sfx.joue("coup", global_position + Vector3(0, hauteur * 0.6, 0), -2.0)
	var away := global_position - from; away.y = 0
	recul = away.normalized() * (3.5 if type == "rodeur" else 1.2)
	_barre()
	if pv <= 0.0: _meurt()

func _meurt() -> void:
	vivant = false; state = "mort"; t = 0.0
	remove_from_group("ennemis")
	collision_layer = 0
	anim.play("Die", 0.1)
	Sfx.joue("chute", global_position, 2.0)
	barre.visible = false
	mort.emit(self)

func _physics_process(dt: float) -> void:
	t += dt; cd -= dt
	if flash > 0.0:
		flash = max(flash - dt * 6.0, 0.0)
		for mi in meshes: mi.set_instance_shader_parameter("flash", flash)
	if state == "mort":
		if t > 1.6 and t < 1.7:
			Fx.spawn(get_parent(), "Dark", "Radial_02", Transform3D(Basis(), global_position), 1.6 * d.taille, 2.0)
		if t > 2.0:
			var k := clampf((t - 2.0) / 0.8, 0.0, 1.0)
			for mi in meshes: mi.set_instance_shader_parameter("dissolve", k)
			model.position.y = -k * hauteur * 0.7
			if k >= 1.0: queue_free()
		return
	var v := Vector3.ZERO
	match state:
		"rugit":
			if t > anim.get_animation("Roar").length * 0.9: state = "chasse"
		"chasse":
			cible = _cible()
			if cible:
				var to: Vector3 = cible.global_position - global_position; to.y = 0
				var dist := to.length()
				_face(to, dt)
				if dist > d.portee:
					v = to.normalized() * d.vitesse
					anim.play("Run" if dist > 4.0 else "Walk")
					anim.speed_scale = 1.0
				elif cd <= 0.0:
					state = "attaque"; t = 0.0; frappe_faite = false
					anim.play("Attack", 0.1); anim.seek(0.0, true)
				else:
					anim.play("Idle")
			else:
				anim.play("Idle")
		"attaque":
			var L := anim.get_animation("Attack").length
			if cible and t < L * 0.3: _face(cible.global_position - global_position, dt)
			if not frappe_faite and t > L * 0.45:
				frappe_faite = true
				if cible and is_instance_valid(cible) and cible.global_position.distance_to(global_position) < d.portee + 0.8:
					var fwd := model.global_basis.z; fwd.y = 0
					var to2: Vector3 = cible.global_position - global_position; to2.y = 0
					if fwd.normalized().dot(to2.normalized()) > 0.3 and cible.has_method("blesse"):
						cible.blesse(d.degats, global_position)
			if t > L:
				state = "chasse"; cd = 0.6 if type == "rodeur" else 1.2
	recul = recul.move_toward(Vector3.ZERO, 14.0 * dt)
	v += recul
	velocity.x = v.x; velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * dt
	move_and_slide()

func _face(to: Vector3, dt: float) -> void:
	to.y = 0
	if to.length() < 0.01: return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), 1.0 - exp(-9.0 * dt))
