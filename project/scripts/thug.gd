## Ennemi humain (bande du Balafré) : tourne autour du héros, attaque à tour
## de rôle avec des enchaînements annoncés, pare, esquive. Chaque coup reçu le
## fait reculer (réaction selon le côté touché) ; au 3e coup d'affilée il est
## PROJETÉ : envol, chute, impact au sol (ou contre un mur), puis il se relève.
class_name Voyou
extends CharacterBody3D

signal ko(v: Voyou)
enum E { ATTENTE, TOURNE, APPROCHE, ARMEMENT, ATTAQUE, TOUCHE, GARDE, ESQUIVE, VOL, SOL, RELEVE, KO }

## attaques : [animation, instant du coup (fraction), dégâts, effet (0 recul, 1 gros recul, 2 projection), portée, vitesse]
const TYPES := {
	"rouquin": {"id": "voyou2", "nom": "Le Rouquin", "pv": 85.0, "vitesse": 3.6, "garde": 0.0, "esquive": 0.3, "poids": 1.0,
		"chaine": [["Punch_Jab", 0.34, 6.0, 0, 1.7, 1.15], ["Punch_Cross", 0.36, 8.0, 0, 1.8, 1.1], ["Kick", 0.42, 11.0, 1, 2.0, 1.0]]},
	"cogneur": {"id": "voyou3", "nom": "Le Cogneur", "pv": 150.0, "vitesse": 2.7, "garde": 0.35, "esquive": 0.0, "poids": 1.7,
		"chaine": [["Melee_Hook", 0.55, 11.0, 0, 1.9, 0.9], ["Melee_Knee", 0.42, 10.0, 1, 1.7, 0.95], ["Melee_Uppercut", 0.4, 15.0, 2, 2.0, 0.85]]},
	"balafre": {"id": "voyou1", "nom": "Le Balafré", "pv": 120.0, "vitesse": 3.9, "garde": 0.2, "esquive": 0.2, "poids": 1.15, "arme": "dague",
		"chaine": [["Sword_Light_A", 0.5, 8.0, 0, 1.9, 1.0], ["Sword_Light_B", 0.5, 9.0, 0, 1.9, 1.0], ["Sword_Dash", 0.3, 14.0, 1, 2.8, 1.05]]},
}
static var jeton: Voyou = null          # un seul ennemi attaque à la fois
static var _jeton_cd := 0.0
static var stats := {"projections": 0, "max_enchaine": 0, "touches": 0}
static var debug := false

var type := "rouquin"
var d: Dictionary
var vis: CharacterVisual
var pv := 100.0
var vivant := true
var rayon := 0.4
var hauteur := 1.8
var etat := E.ATTENTE
var t := 0.0
var duree := 0.0
var heros: Node3D
var chaine_i := 0
var coup_fait := false
var coups_recus := 0
var dernier_coup := -10.0
var orbite := 1.0                # sens de rotation autour du héros
var dist_voulue := 4.5
var recul := Vector3.ZERO
var barre: Label3D
var vol_t := 0.0
var invuln := 0.0
var _flash_t := 0.0
var horloge := 0.0               # temps de jeu (ralentis compris)

func setup(p_type: String, p_heros: Node3D) -> void:
	type = p_type; d = TYPES[type]; heros = p_heros
	pv = d.pv
	add_to_group("ennemis")
	collision_layer = 4; collision_mask = 1 | 4
	floor_snap_length = 0.3
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.34; cap.height = 1.8
	col.shape = cap; col.position.y = 0.9
	add_child(col)
	vis = CharacterVisual.new()
	add_child(vis)
	vis.setup(d.id)
	hauteur = 1.8 * float(vis.data.taille)
	if d.has("arme"): vis.set_weapon(d.arme)
	barre = Label3D.new()
	barre.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	barre.position.y = hauteur + 0.38
	barre.font_size = 34; barre.outline_size = 9; barre.pixel_size = 0.0042
	barre.modulate = Color(1.0, 0.62, 0.5)
	add_child(barre)
	_barre()
	orbite = 1.0 if randf() < 0.5 else -1.0
	dist_voulue = randf_range(3.8, 5.2)
	vis.play(["Idle_FoldArms_Loop", "Idle_No_Loop", "Idle_Loop"][randi() % 3], 0.0)

func _barre() -> void:
	var n := clampi(int(ceil(10.0 * pv / float(d.pv))), 0, 10)
	var s := ""
	for i in 10: s += "■" if i < n else "□"
	barre.text = "%s\n%s" % [d.nom, s]

func commence() -> void:
	if etat == E.ATTENTE: _passe(E.TOURNE)

func _passe(e: int, l := 0.0) -> void:
	if jeton == self and e not in [E.APPROCHE, E.ARMEMENT, E.ATTAQUE]:
		jeton = null; _jeton_cd = randf_range(0.5, 1.1)
	etat = e; t = 0.0; duree = l

func _face(p: Vector3, dt: float, k := 12.0) -> void:
	var to := p - global_position; to.y = 0
	if to.length() < 0.01: return
	vis.rotation.y = lerp_angle(vis.rotation.y, atan2(to.x, to.z), 1.0 - exp(-k * dt))

func _avant() -> Vector3:
	return Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1)

# ------------------------------------------------------------------ coups reçus
func touche(dmg: float, from: Vector3, kind := "") -> void:
	if not vivant or etat == E.KO or invuln > 0.0: return
	var away := global_position - from; away.y = 0
	away = away.normalized() if away.length() > 0.01 else -_avant()
	var face_attaquant := _avant().dot(-away) > 0.4
	# en l'air : on jongle (le coup le relance un peu)
	if etat == E.VOL:
		pv -= dmg * 0.8; _hit_fx(dmg * 0.8, from, false)
		velocity.y = max(velocity.y, 3.8); velocity += away * 1.5
		vis.play("LiftAir_Hit_L" if randf() < 0.5 else "LiftAir_Hit_R", 0.04, 1.2, true)
		vol_t = 0.0
		if pv <= 0.0: pv = 0.0; vivant = false
		_barre(); return
	if etat in [E.SOL, E.RELEVE]: return
	# parade : en garde, face à l'attaquant, sur un coup léger
	if etat in [E.TOURNE, E.ATTENTE] and face_attaquant and kind != "lourd" and randf() < float(d.garde):
		_passe(E.GARDE, 0.55)
		vis.play("Sword_Block", 0.05, 1.6, true)
		recul = away * 1.4
		Fx.choc(get_parent(), global_position + Vector3(0, 1.3, 0) - away * 0.4, 1.1, Color(0.6, 0.8, 1.0))
		if heros.has_method("recul"): heros.recul(global_position, 3.2)
		Fx.mot(get_parent(), global_position + Vector3(0, 2.1, 0), "PARÉ", Color(0.7, 0.85, 1.0))
		return
	# esquive (agile) : pas de côté avant d'être touché
	if etat == E.TOURNE and coups_recus == 0 and randf() < float(d.esquive):
		_passe(E.ESQUIVE, 0.75)
		var side := away.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		recul = side * 5.0 + away * 1.5
		vis.play("Dodge_Left" if side.dot(Basis(Vector3.UP, vis.rotation.y) * Vector3.RIGHT) < 0 else "Dodge_Right", 0.05, 1.3, true)
		return
	var now := horloge
	coups_recus = coups_recus + 1 if now - dernier_coup < 1.4 else 1
	dernier_coup = now
	stats.touches += 1
	stats.max_enchaine = max(int(stats.max_enchaine), coups_recus)
	if debug and int(stats.touches) <= 40: print("TOUCHE ", type, " enchaine=", coups_recus, " t=", snapped(now, 0.01), " etat=", etat, " kind=", kind)
	pv -= dmg
	_barre()
	if pv <= 0.0:
		pv = 0.0; vivant = false
		_projete(from, 1.25, dmg); return
	if coups_recus >= 3:
		_projete(from, 1.0, dmg); return
	_hit_fx(dmg, from, kind == "lourd")
	# le Cogneur encaisse sans broncher pendant qu'il frappe (super-armure)
	if type == "cogneur" and etat in [E.ARMEMENT, E.ATTAQUE]:
		recul = away * 1.2
		return
	# le Balafré, touché deux fois, se dégage d'un bond en arrière
	if type == "balafre" and coups_recus == 2 and randf() < 0.4:
		coups_recus = 0
		_passe(E.ESQUIVE, 0.6)
		recul = away * 8.0
		vis.play("Hit_Knockback", 0.05, 1.6, true)
		return
	# réaction : recule selon le côté touché, interrompt son attaque
	var cote := (Basis(Vector3.UP, vis.rotation.y) * Vector3.RIGHT).dot(-away)
	var anim := "Hit_Chest"
	if kind == "lourd": anim = "Hit_Stomach"
	elif coups_recus == 2: anim = "Hit_Head"
	elif cote > 0.45: anim = "Hit_Shoulder_R"
	elif cote < -0.45: anim = "Hit_Shoulder_L"
	recul = away * (7.5 if kind == "lourd" else 5.5) / sqrt(float(d.poids))
	_passe(E.TOUCHE, vis.length(anim) * 0.85 + 0.08)
	vis.play(anim, 0.04, 1.0, true)
	_face(from, 1.0, 60.0)

func _hit_fx(dmg: float, from: Vector3, fort: bool) -> void:
	var p := global_position + Vector3(0, hauteur * 0.62, 0) + (from - global_position).normalized() * 0.3
	Fx.choc(get_parent(), p, 1.2 if not fort else 1.7)
	Fx.flash(get_parent(), p, Color(1.0, 0.92, 0.8), 2.5, 4.5, 0.15)
	Fx.nombre(get_parent(), p + Vector3(0, 0.45, 0), dmg, fort)
	_flash_t = 0.12

## projection : il s'envole, retombe, glisse, puis se relève (ou reste K.-O.)
func _projete(from: Vector3, force: float, dmg: float) -> void:
	stats.projections += 1
	coups_recus = 0
	var away := global_position - from; away.y = 0
	away = away.normalized() if away.length() > 0.01 else -_avant()
	vis.rotation.y = atan2(-away.x, -away.z)          # il regarde celui qui l'a frappé
	var p := global_position + Vector3(0, hauteur * 0.6, 0) - away * 0.3
	Fx.choc(get_parent(), p, 1.9 * force, Color(1.0, 0.85, 0.55), false, 0.3)
	Fx.choc(get_parent(), global_position + Vector3(0, 0.06, 0), 4.0, Color(1.0, 0.8, 0.5), true, 0.45)
	Fx.spawn(get_parent(), "Electric", "Radial_01", Transform3D(Basis(), p), 0.35 * force, 1.0)
	Fx.flash(get_parent(), p, Color(1.0, 0.9, 0.7), 6.0, 9.0, 0.3)
	Fx.nombre(get_parent(), p + Vector3(0, 0.6, 0), dmg, true)
	Fx.mot(get_parent(), p + Vector3(0, 1.1, 0), "PROJECTION !" if vivant else "K.-O. !", Color(1.0, 0.55, 0.3), true)
	Fx.impact(get_tree(), 0.1, 0.3, 0.32)
	if heros.get("shake") != null: heros.shake = 0.9
	velocity = away * 10.5 * force / sqrt(float(d.poids)) + Vector3.UP * 6.2 * force
	vis.play("Hit_Knockback", 0.03, 1.15, true)
	_passe(E.VOL)
	vol_t = 0.0

# ------------------------------------------------------------------ boucle
func _physics_process(dt: float) -> void:
	t += dt; horloge += dt; invuln = max(invuln - dt, 0.0)
	if jeton == null: _jeton_cd -= dt * 0.33       # partagé : avancé un peu par chacun
	if _flash_t > 0.0:
		_flash_t -= dt
	var v := Vector3.ZERO
	var hp := heros.global_position if heros else global_position
	var to := hp - global_position; to.y = 0
	var dist := to.length()
	var heros_dispo: bool = heros.get("vivant") != false and not (heros.get("state") in [10, 11, 12])
	match etat:
		E.ATTENTE:
			_face(hp, dt, 4.0)
		E.TOURNE:
			_face(hp, dt)
			# garde ses distances en tournant autour du héros
			var radial := to.normalized() * clampf(dist - dist_voulue, -1.0, 1.0) * float(d.vitesse)
			var tang := to.normalized().cross(Vector3.UP) * orbite * 1.3
			v = radial + tang
			if t > 2.5 and randf() < dt * 0.4: orbite = -orbite
			var vloc := Basis(Vector3.UP, -vis.rotation.y) * v
			if v.length() < 0.4: vis.play("Idle_Loop" if type != "balafre" else "Sword_Idle", 0.3)
			elif absf(vloc.x) > absf(vloc.z): vis.play("Walk_L_Loop" if vloc.x > 0 else "Walk_R_Loop", 0.25)
			else: vis.play("Walk_Fwd_Loop" if vloc.z > 0 else "Walk_Bwd_Loop", 0.25)
			if jeton == null and _jeton_cd <= 0.0 and heros_dispo and t > 0.8:
				jeton = self; chaine_i = 0
				_passe(E.APPROCHE)
		E.APPROCHE:
			_face(hp, dt)
			var portee: float = d.chaine[0][4]
			if not heros_dispo: _passe(E.TOURNE)
			elif dist > portee - 0.2:
				v = to.normalized() * float(d.vitesse) * 1.35
				vis.play("Jog_Fwd_Loop", 0.2)
				if t > 4.0: _passe(E.TOURNE)
			else:
				_arme()
		E.ARMEMENT:
			# annonce du coup : léger recul du corps, éclat rouge
			_face(hp, dt, 8.0)
			if t > duree: _frappe()
		E.ATTAQUE:
			var a: Array = d.chaine[chaine_i]
			if t < duree * 0.3: _face(hp, dt, 10.0)
			if t < duree * float(a[1]) and dist > 1.1: v = _avant() * (4.5 if a[0] == "Sword_Dash" else 1.6)
			if not coup_fait and t >= duree * float(a[1]):
				coup_fait = true
				var reach: float = a[4]
				var ang := _avant().dot(to.normalized()) if dist > 0.01 else 1.0
				if dist < reach + 0.35 and ang > 0.25 and heros_dispo:
					var fx_p := hp + Vector3(0, 1.25, 0) - to.normalized() * 0.3
					Fx.choc(get_parent(), fx_p, 1.3, Color(1.0, 0.45, 0.35))
					if int(a[3]) == 2 and heros.has_method("projete"): heros.projete(float(a[2]), global_position)
					elif heros.has_method("blesse"): heros.blesse(float(a[2]), global_position, 7.0 if int(a[3]) == 1 else 2.4)
					recul = -_avant() * 0.8         # il recule aussi un peu sous le choc
			if t > duree:
				chaine_i += 1
				if chaine_i < d.chaine.size() and heros_dispo and dist < float(d.chaine[chaine_i][4]) + 1.2:
					_frappe()
				else:
					_passe(E.TOURNE)
		E.TOUCHE, E.GARDE, E.ESQUIVE:
			if t > duree: _passe(E.TOURNE)
		E.VOL:
			vol_t += dt
			if vis.current == "Hit_Knockback" and vol_t > 0.3: vis.play("LiftAir_Fall_Air_Loop", 0.15)
			# inclinaison du corps dans la trajectoire
			vis.rotation.x = lerpf(vis.rotation.x, clampf(-velocity.y * 0.06, -0.5, 0.5), 1.0 - exp(-8.0 * dt))
			# choc contre un mur
			for i in get_slide_collision_count():
				var c := get_slide_collision(i)
				var n := c.get_normal()
				if absf(n.y) < 0.5 and Vector2(velocity.x, velocity.z).length() > 3.0:
					Fx.choc(get_parent(), c.get_position(), 2.2, Color(1.0, 0.9, 0.7), false, 0.28)
					Fx.flash(get_parent(), c.get_position(), Color(1, 0.9, 0.8), 3.0, 6.0, 0.2)
					if heros.get("shake") != null: heros.shake = 0.7
					var hv := Vector3(velocity.x, 0, velocity.z)
					hv = hv.bounce(n) * 0.3
					velocity.x = hv.x; velocity.z = hv.z
					pv -= 6.0; _barre()
					if pv <= 0.0: pv = 0.0; vivant = false
			if is_on_floor() and vol_t > 0.15:
				_passe(E.SOL)
				vis.rotation.x = 0.0
				vis.play("LiftAir_Fall_Impact", 0.06, 1.0, true)
				Fx.choc(get_parent(), global_position + Vector3(0, 0.06, 0), 3.2, Color(0.75, 0.7, 0.62), true, 0.5)
				if heros.get("shake") != null: heros.shake = max(heros.shake, 0.45)
			velocity.y -= 20.0 * dt
			move_and_slide()
			_anim_lod(); return
		E.SOL:
			# glisse sur le sol, puis se relève (ou reste à terre)
			var hv2 := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 14.0 * dt)
			velocity.x = hv2.x; velocity.z = hv2.z
			if not vivant:
				if etat != E.KO and t > 0.5:
					etat = E.KO; barre.text = "%s\nK.-O." % d.nom
					remove_from_group("ennemis"); collision_layer = 0
					ko.emit(self)
			elif t > 1.3:
				_passe(E.RELEVE, vis.length("LayToIdle") * 0.95)
				vis.play("LayToIdle", 0.12, 1.15, true)
				invuln = duree
		E.RELEVE:
			if t > duree:
				_passe(E.TOURNE); invuln = 0.3
		E.KO:
			var hv3 := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 14.0 * dt)
			velocity.x = hv3.x; velocity.z = hv3.z
	recul = recul.move_toward(Vector3.ZERO, 11.0 * dt)
	if etat not in [E.SOL, E.KO]:
		velocity.x = v.x + recul.x; velocity.z = v.z + recul.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * dt
	move_and_slide()

func _anim_lod() -> void:
	pass

func _arme() -> void:
	var a: Array = d.chaine[chaine_i]
	_passe(E.ARMEMENT, 0.32 if chaine_i == 0 else 0.0)
	if chaine_i == 0:
		# éclat rouge : le joueur voit venir le coup et peut esquiver
		var p := global_position + Vector3(0, hauteur * 0.9, 0) + _avant() * 0.25
		Fx.flash(get_parent(), p, Color(1.0, 0.25, 0.2), 3.0, 3.0, 0.3)
		Fx.spawn(get_parent(), "Flames", "02", Transform3D(Basis(), p), 0.25, 0.5)
		vis.play(a[0], 0.08, 0.25, true)       # début de l'élan, au ralenti

func _frappe() -> void:
	var a: Array = d.chaine[chaine_i]
	coup_fait = false
	_passe(E.ATTAQUE, vis.length(a[0]) / float(a[5]))
	if jeton == null: jeton = self
	vis.play(a[0], 0.06, float(a[5]), true)
