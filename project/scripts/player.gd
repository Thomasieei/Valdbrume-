## Le héros (joueur) : 254 animations, déplacements fluides (marche, jogging,
## sprint, glissade, roulade, esquives, saut et double saut), quatre styles de
## combat avec enchaînements (mains nues, épée, magie, arc), émotes.
extends CharacterBody3D

signal action_text(t: String)
signal coup(style: String)          # chaque attaque lancée (entraînement, quêtes)
signal ko
@export var walk_speed := 1.6
@export var jog_speed := 4.2
@export var sprint_speed := 6.0
@export var jump_velocity := 5.6
var gravity := 18.0
var move_input := Vector2.ZERO
var sprint_held := false
var yaw := 0.0
var pitch := -0.18
var vis: CharacterVisual
var pivot := Node3D.new()
var arm := SpringArm3D.new()
var cam := Camera3D.new()

enum S { LOCO, AIR, ROLL, SLIDE, ATTACK, DODGE, EMOTE, LAND, HIT, DEAD, LAUNCH, SOL, GETUP, PARKOUR, WALLRUN, ECHELLE }
var state := S.LOCO
var state_t := 0.0
var state_len := 0.0
var air_jumps := 0
var styles := ["poings", "epee", "magie", "arc"]
var style_i := 0
var combo_i := 0
var queued := ""
var _jump_req := false
var facing := Vector3.FORWARD
var roll_dir := Vector3.ZERO
var emotes := ["Celebration", "Dance_Loop", "Yes", "Idle_FoldArms_Loop", "Surprise", "Idle_No_Loop", "Drink"]
var emote_i := 0
# combat
var pv := 120.0
var pv_max := 120.0
var vivant := true
var hauteur := 1.8
var rayon := 0.35
var hurt_t := 99.0
var hurt_flash := 0.0
var shake := 0.0
var hit_i := 0                 # prochain instant de frappe de l'attaque en cours
var attack_name := ""
var attack_heavy := false
var trail: WeaponTrail
var knock := Vector3.ZERO
var lunge := 2.2                # élan du coup (aimanté vers la cible)
var lunge_cible: Node3D = null
var encoche: MeshInstance3D       # flèche encochée sur l'arc
# parkour
var pk := {}                     # mouvement en cours : animation, départ, arrivée, durée…
var pk_cd := 0.0
var pk_tour := 0                 # alterne les styles de passage d'obstacle
var ninja := false               # saut en pleine course (réception stylée)
var chute_v := 0.0               # vitesse de chute maximale pendant le saut
var mur_n := Vector3.ZERO
var mur_dir := Vector3.ZERO
var mur_cote := "L"
signal parkour(nom: String)
signal pas(surface: String)          # bruit de pas, d'échelle…
var echelles: Array = []         # [x, z, bas, haut, direction du regard]
var echelle: Array = []
var _pas_d := 0.0
var combo_n := 0               # coups portés d'affilée (affiché à l'écran)
var combo_t := 0.0

## instants de frappe (fraction de l'animation) ; par défaut un seul coup à 42 %
const HIT_TIMES := {"Spell_Double_Shoot_Loop": [0.22, 0.58], "Bow_RapidShoot_Loop": [0.18, 0.5, 0.82],
	"Sword_Light_A": [0.36], "Sword_Light_B": [0.36], "Sword_Light_C": [0.38], "Sword_Light_D": [0.4],
	"Sword_Heavy_A": [0.48], "Sword_Heavy_B": [0.5], "Sword_Heavy_C": [0.5], "Sword_Heavy_D": [0.52],
	"Sword_Aerial_A": [0.4], "Sword_Aerial_B": [0.4], "Punch_Jab": [0.35], "Punch_Cross": [0.38], "Kick": [0.42],
	"Melee_Hook": [0.42], "Melee_Uppercut": [0.45], "Melee_Knee": [0.42], "Spell_Simple_Shoot": [0.38], "Bow_Shoot": [0.3]}
const DEGATS := {"poings": [9.0, 17.0], "epee": [15.0, 28.0], "magie": [18.0, 13.0], "arc": [14.0, 9.0]}

const COMBOS := {
	"poings": {"legere": ["Punch_Jab", "Punch_Cross", "Melee_Hook", "Kick"], "lourde": ["Melee_Uppercut", "Melee_Knee"]},
	"epee": {"legere": ["Sword_Light_A", "Sword_Light_B", "Sword_Light_C", "Sword_Light_D"], "lourde": ["Sword_Heavy_A", "Sword_Heavy_B", "Sword_Heavy_C", "Sword_Heavy_D"], "air": ["Sword_Aerial_A", "Sword_Aerial_B"]},
	"magie": {"legere": ["Spell_Simple_Shoot"], "lourde": ["Spell_Double_Shoot_Loop"]},
	"arc": {"legere": ["Bow_Shoot"], "lourde": ["Bow_RapidShoot_Loop"]},
}
const IDLE := {"poings": "Idle_Loop", "epee": "Sword_Idle", "magie": "Spell_Simple_Idle_Loop", "arc": "Bow_Aim_Neutral"}

func _ready() -> void:
	floor_max_angle = deg_to_rad(62.0)
	collision_mask = 1 | 4           # le décor et les monstres
	floor_snap_length = 0.35
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.32; cap.height = 1.8
	col.shape = cap; col.position.y = 0.9
	add_child(col)
	vis = CharacterVisual.new()
	add_child(vis)
	vis.setup("heros")
	pivot.position.y = 1.55
	add_child(pivot)
	arm.spring_length = 4.2; arm.margin = 0.25; arm.collision_mask = 1
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	arm.add_child(cam)
	cam.fov = 68.0; cam.near = 0.08; cam.far = 900.0; cam.current = true
	vis.play("Idle_Loop", 0.0)
	add_to_group("combattants")
	add_to_group("heros")
	trail = WeaponTrail.new()
	add_child(trail)
	# armes chargées d'avance : pas d'à-coup au premier changement d'arme
	for k in CharacterVisual.ARMES:
		load("res://assets/characters/props/%s.fbx" % CharacterVisual.ARMES[k].f)
	encoche = Fx.fleche_node()
	encoche.top_level = true
	encoche.visible = false
	add_child(encoche)

func style() -> String: return styles[style_i]

# ------------------------------------------------------------ commandes
func look(rel: Vector2) -> void:
	yaw -= rel.x * 0.006
	pitch = clamp(pitch - rel.y * 0.004, -1.1, 0.55)

func request_jump() -> void: _jump_req = true

func next_style() -> void:
	if state in [S.ATTACK, S.ROLL, S.SLIDE]: return
	style_i = (style_i + 1) % styles.size()
	vis.set_weapon(style())
	if vis.weapon_mesh and style() == "epee":
		var ax: Array = vis.weapon_axis()
		trail.setup(vis.weapon_mesh, ax[0], ax[1], Color(0.45, 0.72, 1.0))
	combo_i = 0
	action_text.emit({"poings": "Mains nues", "epee": "Épée", "magie": "Magie", "arc": "Arc"}[style()])

func attack(heavy := false) -> void:
	if not vivant or state in [S.HIT, S.LAUNCH, S.SOL, S.GETUP]: return
	var kind := "lourde" if heavy else "legere"
	if state == S.AIR and style() == "epee":
		_start_attack(COMBOS.epee.air[0]); return
	if state == S.ATTACK:
		queued = kind; return
	if state in [S.LOCO, S.EMOTE, S.LAND]:
		combo_i = 0
		_start_attack(COMBOS[style()][kind][0])

func _start_attack(n: String) -> void:
	state = S.ATTACK; state_t = 0.0
	state_len = max(vis.length(n) * 0.92, 0.25)
	vis.play(n, 0.08, 1.15, true)
	queued = ""
	attack_name = n; hit_i = 0
	attack_heavy = n in COMBOS[style()].get("lourde", []) or n.begins_with("Sword_Aerial")
	var bouche := global_position + Vector3(0, 1.3, 0)
	match style():
		"poings", "epee": Sfx.joue("souffle_lourd" if attack_heavy else "souffle", bouche, -4.0, 0.12)
		"magie": Sfx.joue("sort", bouche, -6.0)
	# visée assistée : on se tourne vers l'ennemi le plus proche devant soi
	var t := cible_visee()
	lunge = 2.2
	lunge_cible = null
	if t and t.global_position.distance_to(global_position) < 5.0: lunge_cible = t
	if t:
		var to := t.global_position - global_position
		vis.rotation.y = atan2(to.x, to.z)
		# l'élan rapproche juste ce qu'il faut pour rester au contact
		var gap: float = Vector2(to.x, to.z).length() - (1.0 + float(t.rayon))
		if gap < 3.5: lunge = clampf(gap / 0.18, 0.0, 11.0)
	coup.emit(style())

## ennemi visé : le plus proche dans un cône devant le héros (ou la caméra)
func cible_visee(portee := 24.0) -> Node3D:
	var fwd := Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1)
	var camf := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	var best: Node3D = null; var bs := -1e9
	for e in get_tree().get_nodes_in_group("ennemis"):
		var to: Vector3 = e.global_position - global_position; to.y = 0
		var d := to.length()
		if d > portee: continue
		var dir := to / maxf(d, 0.01)
		var score := maxf(dir.dot(fwd), dir.dot(camf)) * 10.0 - d
		if maxf(dir.dot(fwd), dir.dot(camf)) > 0.25 and score > bs: bs = score; best = e
	return best

func _bone_pos(b: String) -> Vector3:
	var sk := vis.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin

## le coup part : corps à corps, sort ou flèche
func _strike() -> void:
	var heavy := attack_heavy
	var dmg: float = DEGATS[style()][1 if heavy else 0]
	var fwd := Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1)
	match style():
		"poings", "epee":
			var reach := 2.5 if style() == "epee" else 2.0
			if heavy: reach += 0.4
			var touche := false
			for e in get_tree().get_nodes_in_group("ennemis"):
				var to: Vector3 = e.global_position - global_position; to.y = 0
				var dd := to.length()
				if dd < reach + float(e.rayon) and (dd < 0.6 or fwd.dot(to / dd) > 0.35):
					var crit := randf() < 0.12
					var val := dmg * (1.6 if crit else 1.0)
					e.touche(val, global_position, "lourd" if heavy else "")
					Sfx.joue("coup_fort" if heavy or crit else "coup", global_position + Vector3(0, 1.2, 0) + fwd)
					if style() == "epee": Sfx.joue("lame", global_position + Vector3(0, 1.2, 0) + fwd, -3.0)
					combo_n = combo_n + 1 if combo_t < 1.6 else 1
					combo_t = 0.0
					var p: Vector3 = e.global_position + Vector3(0, float(e.hauteur) * 0.55, 0) - to.normalized() * float(e.rayon)
					if not e is Voyou:        # les voyous gèrent eux-mêmes leur impact
						Fx.choc(get_parent(), p, 1.2 if not heavy else 1.7, Color(0.7, 0.85, 1.0) if style() == "epee" else Color(1.0, 0.9, 0.7))
						Fx.flash(get_parent(), p, Fx.TEINTE.Electric if style() == "epee" else Fx.TEINTE.Pure, 3.0, 5.0, 0.2)
						Fx.nombre(get_parent(), p + Vector3(0, 0.4, 0), val, crit)
					touche = true
			if touche:
				shake = 0.5 if heavy else 0.3
				Fx.impact(get_tree(), 0.075 if heavy else 0.045)
		"magie":
			var from := _bone_pos("hand_r") + fwd * 0.25
			var t := cible_visee()
			var pr := Projectile.new()
			pr.exclude = [get_rid()]; pr.kind = "sort"; pr.couleur = "Dark" if heavy else "Mystic"; pr.degats = dmg; pr.taille = 1.25 if heavy else 1.0
			get_parent().add_child(pr)
			var aim := (t.global_position + Vector3(0, 1.0, 0) - from).normalized() if t else fwd
			if heavy: aim = aim.rotated(Vector3.UP, 0.12 if hit_i == 1 else -0.12)
			pr.lance(from, aim, 22.0, t)
			Fx.flash(get_parent(), from, Fx.TEINTE.Dark if heavy else Fx.TEINTE.Mystic, 2.5, 4.0, 0.25)
		"arc":
			var from2 := _bone_pos("hand_l") + fwd * 0.15
			var t2 := cible_visee(32.0)
			var pr2 := Projectile.new()
			Sfx.joue("corde", from2, -2.0); Sfx.joue("fleche", from2, -6.0)
			pr2.exclude = [get_rid()]; pr2.kind = "fleche"; pr2.degats = dmg; pr2.vie = 1.4
			get_parent().add_child(pr2)
			pr2.lance(from2, (t2.global_position + Vector3(0, 1.0, 0) - from2).normalized() if t2 else fwd, 38.0, t2)

## la flèche encochée : de la main qui tend la corde vers la main qui tient l'arc
func _encoche() -> void:
	var montre := style() == "arc" and vivant and state not in [S.ROLL, S.SLIDE, S.LAUNCH, S.SOL, S.GETUP, S.HIT, S.DEAD]
	if montre and state == S.ATTACK:
		var hts: Array = HIT_TIMES.get(attack_name, [0.42])
		# disparaît au moment du tir, réapparaît pour la flèche suivante
		var rel := state_t / maxf(state_len, 0.01)
		montre = attack_name == "Bow_RapidShoot_Loop" or rel < float(hts[0]) / 0.92 or rel > 0.8
	encoche.visible = montre
	if not montre: return
	var nock := _bone_pos("hand_r")
	var grip := _bone_pos("hand_l")
	var d := grip - nock
	if d.length() < 0.05: encoche.visible = false; return
	encoche.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), nock)

func _hitstop(d: float) -> void:
	Engine.time_scale = 0.06
	await get_tree().create_timer(d, true, false, true).timeout
	Engine.time_scale = 1.0

## coup reçu (les roulades et glissades esquivent)
func blesse(dmg: float, from: Vector3, force := 4.0) -> void:
	if not vivant or state in [S.ROLL, S.SLIDE, S.DEAD, S.LAUNCH, S.SOL, S.GETUP, S.PARKOUR, S.WALLRUN, S.ECHELLE]: return
	pv -= dmg; hurt_t = 0.0; hurt_flash = 1.0; shake = 0.45 + force * 0.04
	Sfx.joue("coup", global_position + Vector3(0, 1.3, 0))
	combo_n = 0
	var away := global_position - from; away.y = 0
	knock = away.normalized() * force
	vis.rotation.y = atan2(-away.x, -away.z)        # il encaisse face à l'adversaire
	Fx.nombre(get_parent(), global_position + Vector3(0, 2.0, 0), dmg, false, Color(1.0, 0.35, 0.3))
	if pv <= 0.0:
		pv = 0.0; vivant = false; state = S.DEAD; state_t = 0.0
		vis.play("Death01", 0.1, 1.0, true)
		action_text.emit("Vous perdez connaissance…")
		return
	state = S.HIT; state_t = 0.0; state_len = 0.42
	vis.play(["Hit_Chest", "Hit_Head", "Hit_Shoulder_L", "Hit_Shoulder_R"][randi() % 4], 0.06, 1.2, true)

## projeté par un coup puissant : envol, chute sur le dos, relevé en kip-up
func projete(dmg: float, from: Vector3) -> void:
	if not vivant or state in [S.ROLL, S.SLIDE, S.DEAD, S.LAUNCH, S.SOL, S.GETUP, S.PARKOUR, S.WALLRUN, S.ECHELLE]: return
	pv -= dmg; hurt_t = 0.0; hurt_flash = 1.0; shake = 1.0; combo_n = 0
	Sfx.joue("coup_fort", global_position + Vector3(0, 1.3, 0), 2.0)
	var away := global_position - from; away.y = 0
	away = away.normalized()
	Fx.nombre(get_parent(), global_position + Vector3(0, 2.0, 0), dmg, true, Color(1.0, 0.35, 0.3))
	Fx.impact(get_tree(), 0.09, 0.4, 0.25)
	vis.rotation.y = atan2(-away.x, -away.z)
	if pv <= 0.0:
		pv = 0.0; vivant = false
	velocity = away * 8.5 + Vector3.UP * 5.8
	state = S.LAUNCH; state_t = 0.0
	vis.play("Hit_Knockback", 0.03, 1.1, true)

## repoussé quand l'adversaire pare le coup
func recul(from: Vector3, force := 3.0) -> void:
	if state in [S.LAUNCH, S.SOL, S.GETUP, S.DEAD]: return
	var away := global_position - from; away.y = 0
	knock = away.normalized() * force
	state = S.HIT; state_t = 0.0; state_len = 0.38
	shake = 0.35; combo_n = 0
	vis.play("Hit_Shoulder_R", 0.05, 1.3, true)

func revive(at: Vector3) -> void:
	global_position = at; velocity = Vector3.ZERO
	pv = pv_max; vivant = true; state = S.LAND; state_t = 0.0
	vis.play("KipUp", 0.0, 1.0, true)

func dodge() -> void:
	if not vivant or state in [S.HIT, S.PARKOUR, S.WALLRUN, S.LAUNCH, S.SOL, S.GETUP]: return
	if not is_on_floor() or state in [S.ROLL, S.SLIDE]: return
	var hv := Vector3(velocity.x, 0, velocity.z)
	var mv := _move_dir()
	if hv.length() > sprint_speed * 0.85:
		state = S.SLIDE; state_t = 0.0; state_len = 0.9
		roll_dir = hv.normalized()
		vis.play("Slide_Start", 0.08, 1.0, true)
	else:
		state = S.ROLL; state_t = 0.0
		roll_dir = mv if mv.length() > 0.1 else -vis.global_transform.basis.z * -1.0
		if mv.length() < 0.1: roll_dir = Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1)
		state_len = vis.length("Roll") * 0.9
		vis.play("Roll", 0.06, 1.1, true)

func emote() -> void:
	if state != S.LOCO: return
	state = S.EMOTE; state_t = 0.0
	var n: String = emotes[emote_i]; emote_i = (emote_i + 1) % emotes.size()
	state_len = 6.0 if n.ends_with("_Loop") else vis.length(n)
	vis.play(n, 0.2, 1.0, true)

# ------------------------------------------------------------ parkour
func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)

## en pleine course face à un obstacle : on lit sa hauteur et son épaisseur, puis
## on choisit le mouvement (marche, saut de barrière, vrille, escalade)
func _parkour_check(hv: Vector3, lent := false, dir_force := Vector3.ZERO) -> bool:
	var fwd := hv.normalized() if dir_force == Vector3.ZERO else dir_force
	var pos := global_position
	var look := clampf(hv.length() * 0.3, 1.1, 2.0)
	var hit := {}
	for h in [0.4, 0.95, 1.5, 2.1]:
		var r := _ray(pos + Vector3.UP * h, pos + Vector3.UP * h + fwd * look)
		if not r.is_empty() and (r.normal as Vector3).dot(fwd) < -0.5 and absf(r.normal.y) < 0.4:
			hit = r; break
	if hit.is_empty(): return false
	var hp: Vector3 = hit.position
	var dist := Vector2(hp.x - pos.x, hp.z - pos.z).length()
	var probe := hp + fwd * 0.25
	var top := _ray(Vector3(probe.x, pos.y + 3.3, probe.z), Vector3(probe.x, pos.y - 0.2, probe.z))
	if top.is_empty(): return false
	var top_p: Vector3 = top.position
	var h2 := top_p.y - pos.y
	if h2 < 0.25 or h2 > 2.55: return false
	# épaisseur : tant que le dessus reste haut
	var depth := 0.25
	var land_y := pos.y
	var k := 0.35
	var deep := true
	while k <= 3.2:
		var q := hp + fwd * k
		var rr := _ray(Vector3(q.x, pos.y + 3.3, q.z), Vector3(q.x, pos.y - 1.5, q.z))
		if rr.is_empty() or (rr.position as Vector3).y < pos.y + 0.25:
			land_y = (rr.position as Vector3).y if not rr.is_empty() else pos.y
			deep = false
			break
		depth = k; k += 0.35
	# un mur juste derrière l'obstacle (benne contre une façade) : on grimpe dessus
	if not deep and not _ray(top_p + Vector3.UP * 0.35, top_p + Vector3.UP * 0.35 + fwd * (depth + 1.4)).is_empty():
		deep = true
	# assez de place au-dessus pour passer ou monter
	if not _ray(top_p + Vector3.UP * 0.05, top_p + Vector3.UP * 1.85).is_empty(): return false
	var sprint := hv.length() > 5.2
	var p_top := Vector3(hp.x, top_p.y, hp.z) + fwd * 0.55
	# au-dessus du vide (bord de toit) : seulement en sprint, et on s'élance
	var vide := not deep and land_y < pos.y - 1.2
	if lent or (vide and not sprint):
		# en marchant (ou bouton saut) : on ne fait qu'escalader
		if vide or h2 < 0.62 or not deep and h2 < 1.0: return false
		if h2 <= 1.45: return _pk_start("ClimbUp_1m", "grimpe", pos, p_top, top_p.y, 1.25, 0.0)
		return _pk_start("ClimbUp_2m", "grimpe", pos, p_top, top_p.y, 1.15, 0.0)
	if vide and h2 <= 1.4 and depth <= 1.5:
		var a0: String = ["PK_Flip", "PK_Vault"][pk_tour % 2]; pk_tour += 1
		var bout0 := pos + fwd * maxf(AnimBank.avance_totale(a0) * 0.9, dist + depth + 0.8)
		var ok := _pk_start(a0, "elan", pos, bout0, pos.y, 1.05, hv.length())
		return ok
	if h2 <= 0.62:
		if deep or depth > 1.0: return _pk_start("StepUp", "monte", pos, p_top, top_p.y, 1.5, hv.length())
		return _pk_start("PK_Vault", "passe", pos, hp + fwd * (depth + 0.55), land_y, 1.25, hv.length())
	if h2 <= 1.4 and not deep and depth <= 1.5:
		var styles := ["PK_Vault", "PK_Flip", "SafetyVault"] if sprint else ["SafetyVault", "PK_Vault"]
		var a: String = styles[pk_tour % styles.size()]; pk_tour += 1
		var bout := hp + fwd * (depth + 0.6)
		if a == "PK_Flip": bout = pos + fwd * maxf(AnimBank.avance_totale("PK_Flip") * 0.85, dist + depth + 0.9)
		return _pk_start(a, "passe", pos, bout, land_y, 1.05 if a == "PK_Flip" else 1.15, hv.length())
	if h2 <= 1.95 and not deep and depth <= 2.8 and sprint:
		var bout2 := pos + fwd * maxf(AnimBank.avance_totale("PK_Flip") * 0.9, dist + depth + 1.0)
		return _pk_start("PK_Flip", "passe", pos, bout2, land_y, 1.0, hv.length())
	if h2 <= 1.45: return _pk_start("ClimbUp_1m", "grimpe", pos, p_top, top_p.y, 1.25, 0.0)
	return _pk_start("ClimbUp_2m", "grimpe", pos, p_top, top_p.y, 1.15, 0.0)

func _pk_start(anim: String, kind: String, p0: Vector3, p1: Vector3, y1: float, vitesse: float, v_sortie: float) -> bool:
	var dur := vis.length(anim) / vitesse
	if dur <= 0.05: return false
	var fwd := Vector3(p1.x - p0.x, 0, p1.z - p0.z).normalized()
	pk = {"anim": anim, "kind": kind, "p0": p0, "p1": Vector3(p1.x, y1, p1.z), "dur": dur, "fwd": fwd, "v": v_sortie}
	state = S.PARKOUR; state_t = 0.0
	vis.rotation.y = atan2(fwd.x, fwd.z)
	vis.play(anim, 0.08, vitesse, true)
	velocity = Vector3.ZERO
	parkour.emit(anim)
	Sfx.joue("elan" if kind in ["passe", "elan"] else "tissu", global_position + Vector3.UP, -4.0, 0.1)
	if kind == "grimpe": Sfx.joue("tissu", global_position + Vector3.UP, -6.0)
	return true

func _pk_update(dt: float) -> void:
	var t := state_t
	var dur: float = pk.dur
	var p0: Vector3 = pk.p0; var p1: Vector3 = pk.p1
	var k := clampf(t / dur, 0.0, 1.0)
	var pos := global_position
	match String(pk.kind):
		"passe":
			var f := AnimBank.progression(String(pk.anim), t, dur)
			pos = p0.lerp(p1, f)
			pos.y = lerpf(p0.y, p1.y, smoothstep(0.55, 1.0, k))
		"elan":
			var f2 := AnimBank.progression(String(pk.anim), t, dur)
			pos = p0.lerp(p1, f2); pos.y = p0.y
		"monte", "grimpe":
			# on s'approche du mur, on se hisse, puis on avance sur le dessus
			var rise := smoothstep(0.08, 0.7 if pk.kind == "grimpe" else 0.5, k)
			var fw := smoothstep(0.45 if pk.kind == "grimpe" else 0.15, 1.0, k)
			pos = Vector3(lerpf(p0.x, p1.x, fw), lerpf(p0.y, p1.y, rise), lerpf(p0.z, p1.z, fw))
	global_position = pos
	if t >= dur and pk.kind == "elan":
		# on quitte le bord : chute libre en gardant l'élan (on peut se rattraper en face)
		state = S.AIR; state_t = 0.0; pk_cd = 0.2; ninja = true; air_jumps = 0
		velocity = (pk.fwd as Vector3) * maxf(float(pk.v), 6.5) + Vector3.UP * 1.2
		vis.play("NinjaJump_Idle_Loop", 0.15)
		return
	if t >= dur:
		state = S.LOCO; state_t = 0.0; pk_cd = 0.35
		velocity = (pk.fwd as Vector3) * float(pk.v)
		if float(pk.v) > 0.5 and pk.kind == "passe": vis.play("Sprint_Loop" if float(pk.v) > 5.0 else "Jog_Fwd_Loop", 0.12)

## rattrapage : en l'air, face à un rebord à portée de mains, on s'y hisse
func _rebord_check() -> bool:
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() < 1.0 or velocity.y > 2.5 or pk_cd > 0.0: return false
	var fwd := hv.normalized()
	var pos := global_position
	var r := _ray(pos + Vector3.UP * 1.3, pos + Vector3.UP * 1.3 + fwd * 0.9)
	if r.is_empty() or absf((r.normal as Vector3).y) > 0.4: return false
	var hp: Vector3 = r.position
	var probe := hp + fwd * 0.2
	var top := _ray(Vector3(probe.x, pos.y + 2.6, probe.z), Vector3(probe.x, pos.y - 0.2, probe.z))
	if top.is_empty(): return false
	var ty: float = (top.position as Vector3).y
	var h := ty - pos.y
	if h < 0.3 or h > 2.35: return false
	if not _ray(top.position + Vector3.UP * 0.05, top.position + Vector3.UP * 1.8).is_empty(): return false
	parkour.emit("Rattrapage")
	return _pk_start("ClimbUp_2m" if h > 1.2 else "ClimbUp_1m", "grimpe", pos, Vector3(hp.x, ty, hp.z) + fwd * 0.55, ty, 1.2, 0.0)

## échelles de secours : on s'y accroche en poussant vers le mur
func _echelle_check(mv: Vector3) -> bool:
	if mv.length() < 0.3: return false
	for e in echelles:
		var f := Basis(Vector3.UP, deg_to_rad(float(e[4]))) * Vector3(0, 0, 1)
		var d := Vector2(global_position.x - float(e[0]), global_position.z - float(e[1])).length()
		if d < 0.9 and global_position.y > float(e[2]) - 0.5 and global_position.y < float(e[3]) - 1.0 and mv.normalized().dot(f) > 0.5:
			echelle = e
			state = S.ECHELLE; state_t = 0.0
			global_position = Vector3(float(e[0]), maxf(global_position.y, float(e[2])), float(e[1]))
			velocity = Vector3.ZERO
			vis.rotation.y = atan2(f.x, f.z)
			vis.play("Climb_Enter", 0.1, 1.4, true)
			parkour.emit("Echelle")
			return true
	return false

func _echelle_update(dt: float, mv: Vector3) -> void:
	var e := echelle
	var f := Basis(Vector3.UP, deg_to_rad(float(e[4]))) * Vector3(0, 0, 1)
	var monte := mv.normalized().dot(f) if mv.length() > 0.2 else 0.0
	var want := Input.is_action_just_pressed("ui_accept") or _jump_req
	_jump_req = false
	if want:
		# saut arrière depuis l'échelle
		state = S.AIR; state_t = 0.0; echelle = []
		velocity = -f * 4.0 + Vector3.UP * 4.5
		vis.rotation.y = atan2(-f.x, -f.z)
		vis.play("Jump_Start", 0.08, 1.2, true)
		return
	if state_t < 0.45: return              # le temps de s'agripper
	var vy := 0.0
	if monte > 0.3:
		vy = 2.1; vis.play("Climb_Up_Loop", 0.15, 1.35)
	elif monte < -0.3:
		vy = -2.6; vis.play("Climb_Down_Loop", 0.15, 1.4)
	else:
		vis.play("Climb_Idle_Loop", 0.2)
	global_position.y += vy * dt
	_pas_d += absf(vy) * dt
	if _pas_d > 0.32: _pas_d = 0.0; pas.emit("echelle")
	if global_position.y <= float(e[2]) and vy < 0.0:
		global_position.y = float(e[2]); state = S.LOCO; echelle = []
	elif global_position.y >= float(e[3]) - 1.25:
		# en haut : on passe par-dessus le parapet et on prend pied sur le toit
		echelle = []
		var p1 := Vector3(float(e[0]), float(e[3]), float(e[1])) + f * 1.3
		_pk_start("Climb_Exit", "grimpe", global_position, p1, float(e[3]), 1.3, 0.0)

## course sur un mur : sprint + saut le long d'une façade
func _wallrun_check(hv: Vector3) -> bool:
	if hv.length() < 5.0: return false
	var fwd := hv.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	for side in [-1.0, 1.0]:
		var r := _ray(global_position + Vector3.UP, global_position + Vector3.UP + right * side * 1.3)
		if r.is_empty(): continue
		var n: Vector3 = r.normal
		if absf(n.y) > 0.3 or absf(n.dot(fwd)) > 0.45: continue
		mur_n = Vector3(n.x, 0, n.z).normalized()
		mur_dir = (fwd - mur_n * fwd.dot(mur_n)).normalized()
		mur_cote = "R" if side > 0.0 else "L"
		state = S.WALLRUN; state_t = 0.0
		velocity = mur_dir * maxf(hv.length(), 6.5) + Vector3.UP * 3.2
		vis.rotation.y = atan2(mur_dir.x, mur_dir.z)
		vis.play("WallRun_%s_Loop" % mur_cote, 0.1, 1.15, true)
		parkour.emit("WallRun")
		return true
	return false

func _wallrun_end(saute: bool) -> void:
	state = S.AIR; state_t = 0.0; ninja = saute
	if saute:
		velocity = mur_dir * 6.2 + mur_n * 4.2 + Vector3.UP * 6.0
		vis.play("WallRun_Jump_%s" % mur_cote, 0.06, 1.1, true)
	else:
		velocity = mur_dir * 5.0 + mur_n * 1.5

# ------------------------------------------------------------ boucle
func _move_dir() -> Vector3:
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var mv := move_input if move_input.length() > 0.05 else kb
	var d := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
	return d if d.length() <= 1.0 else d.normalized()

func _physics_process(dt: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0)
	state_t += dt
	hurt_t += dt
	hurt_flash = max(hurt_flash - dt * 2.5, 0.0)
	if hurt_t > 6.0 and vivant: pv = min(pv_max, pv + 8.0 * dt)
	shake = max(shake - dt * 2.2, 0.0)
	combo_t += dt
	if combo_t > 1.6: combo_n = 0
	cam.h_offset = randf_range(-1.0, 1.0) * shake * 0.09
	cam.v_offset = randf_range(-1.0, 1.0) * shake * 0.07
	trail.active = state == S.ATTACK and style() == "epee" and state_t < state_len * 0.8
	_encoche()
	if state == S.ATTACK:
		var hts: Array = HIT_TIMES.get(attack_name, [0.42])
		if hit_i < hts.size() and state_t >= state_len * float(hts[hit_i]) / 0.92:
			_strike(); hit_i += 1
	var mv := _move_dir()
	var amount := mv.length()
	var hv := Vector3(velocity.x, 0, velocity.z)
	var target := Vector3.ZERO
	var sprint := sprint_held or Input.is_key_pressed(KEY_SHIFT) or amount > 0.92
	pk_cd -= dt
	if state == S.ECHELLE:
		_echelle_update(dt, mv)
		return
	if state == S.LOCO and is_on_floor() and not echelles.is_empty() and _echelle_check(mv): return
	if state == S.AIR and state_t > 0.12 and _rebord_check(): return
	if state == S.PARKOUR:
		_pk_update(dt)
		_animate(0.0)
		return
	if state == S.WALLRUN:
		# collé au mur, on court dessus ; saut = rebond, fin du mur = chute
		velocity.y -= gravity * 0.32 * dt
		var wr := _ray(global_position + Vector3.UP, global_position + Vector3.UP - mur_n * 1.3)
		var saute := Input.is_action_just_pressed("ui_accept") or _jump_req
		_jump_req = false
		if wr.is_empty() or state_t > 1.15 or saute or (is_on_floor() and state_t > 0.3):
			_wallrun_end(saute)
		else:
			var wp: Vector3 = wr.position
			var cible_p := wp + mur_n * 0.42
			var sp := maxf(Vector2(velocity.x, velocity.z).length(), 6.5)
			velocity.x = mur_dir.x * sp + (cible_p.x - global_position.x) * 8.0
			velocity.z = mur_dir.z * sp + (cible_p.z - global_position.z) * 8.0
			move_and_slide()
			return
	# parkour automatique : en courant vers un obstacle
	if state == S.LOCO and is_on_floor() and pk_cd <= 0.0 and amount > 0.5:
		var hv0 := Vector3(velocity.x, 0, velocity.z)
		if hv0.length() > 3.6 and hv0.normalized().dot(mv.normalized()) > 0.7:
			if _parkour_check(hv0): return
		elif hv0.length() > 1.0 and hv0.normalized().dot(mv.normalized()) > 0.7:
			if _parkour_check(hv0, true): return
	match state:
		S.LOCO, S.EMOTE, S.LAND:
			if amount > 0.05:
				var sp := sprint_speed if sprint else (jog_speed if amount > 0.45 else walk_speed)
				target = mv.normalized() * sp
				if state == S.EMOTE: state = S.LOCO
			if state == S.LAND and state_t > 0.25: state = S.LOCO
			if state == S.EMOTE and state_t > state_len: state = S.LOCO
		S.ATTACK:
			# petite avancée au moment du coup (vitesse fixe, jamais cumulée), puis arrêt net
			if state_t < 0.2 and is_on_floor() and lunge_cible and is_instance_valid(lunge_cible) and lunge_cible.get("vivant") != false:
				# suit la cible pendant l'élan : le coup arrive au contact même si elle recule
				var tl := lunge_cible.global_position - global_position; tl.y = 0
				var gap2: float = tl.length() - (0.95 + float(lunge_cible.get("rayon")))
				target = tl.normalized() * clampf(gap2 / maxf(0.2 - state_t, 0.05), 0.0, 12.0)
				vis.rotation.y = atan2(tl.x, tl.z)
			elif state_t < 0.18 and is_on_floor(): target = Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1) * lunge
			else: target = hv.move_toward(Vector3.ZERO, 30.0 * dt) if is_on_floor() else hv
			if state_t > state_len * 0.55 and queued != "":
				var list: Array = COMBOS[style()][queued]
				combo_i = (combo_i + 1) % list.size()
				_start_attack(list[combo_i])
			elif state_t > state_len:
				state = S.LOCO if is_on_floor() else S.AIR
		S.ROLL:
			target = roll_dir * 6.5 * (1.0 - clamp(state_t / state_len, 0.0, 1.0) * 0.6)
			if state_t > state_len: state = S.LOCO
		S.SLIDE:
			target = roll_dir * lerp(sprint_speed * 1.15, 2.0, clamp(state_t / state_len, 0.0, 1.0))
			if state_t > 0.25 and vis.current == "Slide_Start": vis.play("Slide_Loop", 0.1)
			if state_t > state_len:
				vis.play("Slide_Exit", 0.1, 1.0, true); state = S.LAND; state_t = 0.0
		S.HIT:
			target = knock
			if state_t > state_len: state = S.LOCO
		S.DEAD:
			target = Vector3.ZERO
			if state_t > 3.5: ko.emit()
		S.LAUNCH:
			target = hv
			if vis.current == "Hit_Knockback" and state_t > 0.3: vis.play("LiftAir_Fall_Air_Loop", 0.15)
			vis.rotation.x = lerpf(vis.rotation.x, clampf(-velocity.y * 0.06, -0.5, 0.5), 1.0 - exp(-8.0 * dt))
			if is_on_floor() and state_t > 0.15:
				state = S.SOL; state_t = 0.0; vis.rotation.x = 0.0
				vis.play("LiftAir_Fall_Impact", 0.06, 1.0, true)
				Fx.choc(get_parent(), global_position + Vector3(0, 0.06, 0), 3.0, Color(0.75, 0.7, 0.62), true, 0.5)
				Sfx.joue("chute", global_position, 0.0)
				shake = 0.6
		S.SOL:
			target = hv.move_toward(Vector3.ZERO, 14.0 * dt)
			if state_t > 0.9:
				if not vivant:
					state = S.DEAD; state_t = 0.0
					action_text.emit("Vous perdez connaissance…")
				else:
					state = S.GETUP; state_t = 0.0; state_len = vis.length("KipUp") * 0.9
					vis.play("KipUp", 0.1, 1.0, true)
		S.GETUP:
			target = Vector3.ZERO
			if state_t > state_len: state = S.LOCO
		S.AIR:
			target = hv.lerp(mv.normalized() * max(hv.length(), jog_speed) if amount > 0.05 else hv, 2.5 * dt)
	var accel := 24.0 if is_on_floor() else 8.0
	knock = knock.move_toward(Vector3.ZERO, 12.0 * dt)
	if state in [S.ROLL, S.SLIDE, S.ATTACK, S.HIT, S.DEAD, S.LAUNCH, S.SOL, S.GETUP]: hv = target
	else: hv = hv.move_toward(target, accel * dt)
	velocity.x = hv.x; velocity.z = hv.z
	# saut / double saut
	var want_jump := Input.is_action_just_pressed("ui_accept") or _jump_req
	_jump_req = false
	if is_on_floor():
		air_jumps = 0
		if want_jump and state in [S.LOCO, S.EMOTE, S.LAND, S.SLIDE]:
			var hvj := Vector3(velocity.x, 0, velocity.z)
			if state == S.LOCO and _wallrun_check(hvj): return
			# saut face à un rebord : on l'escalade
			var face_dir := Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1)
			if state == S.LOCO and _parkour_check(face_dir * 2.0, true, face_dir): return
			if hvj.length() > 5.0:
				# saut de ninja en pleine course : plus haut, plus loin
				velocity.y = jump_velocity * 1.1
				velocity.x *= 1.15; velocity.z *= 1.15
				state = S.AIR; state_t = 0.0; ninja = true
				vis.play("NinjaJump_Start", 0.05, 1.4, true)
				parkour.emit("NinjaJump")
			else:
				velocity.y = jump_velocity; state = S.AIR; state_t = 0.0; ninja = false
				vis.play("Jump_Start", 0.06, 1.2, true)
	else:
		velocity.y -= gravity * dt
		if want_jump and air_jumps == 0 and state in [S.AIR, S.LOCO]:
			air_jumps = 1; velocity.y = jump_velocity * (1.15 if ninja else 0.95); state = S.AIR; state_t = 0.0
			vis.play("PK_NinjaDouble" if ninja else "DoubleJump", 0.06, 1.1, true)
		if state == S.LOCO and velocity.y < -2.0: state = S.AIR; state_t = 0.0
	# bruits de pas (au rythme de la foulée)
	if is_on_floor() and state in [S.LOCO, S.LAND]:
		var vh := Vector2(velocity.x, velocity.z).length()
		if vh > 0.6:
			_pas_d += vh * dt
			if _pas_d > (0.8 if vh > 5.0 else 0.68 if vh > 3.0 else 0.55):
				_pas_d = 0.0; pas.emit("course" if vh > 5.0 else "pas")
	var was_air := state == S.AIR
	if was_air: chute_v = minf(chute_v, velocity.y)
	move_and_slide()
	if was_air and is_on_floor() and state_t > 0.1:
		var hv_l := Vector3(velocity.x, 0, velocity.z)
		if chute_v < -6.0 and hv_l.length() > 2.0:
			# grande chute en mouvement : roulade de réception
			state = S.ROLL; state_t = 0.0; roll_dir = hv_l.normalized()
			state_len = vis.length("Roll") * 0.85
			vis.play("Roll", 0.05, 1.2, true)
			parkour.emit("Roll")
			Sfx.joue("chute", global_position, -4.0); Sfx.joue("tissu", global_position, -6.0)
		elif ninja:
			state = S.LAND; state_t = 0.0
			vis.play("NinjaJump_Land", 0.05, 1.8, true)
			Sfx.joue("reception", global_position, -3.0)
		else:
			state = S.LAND; state_t = 0.0
			vis.play("Jump_Land", 0.05, 1.3, true)
			Sfx.joue("reception", global_position, -6.0)
		chute_v = 0.0; ninja = false
	# orientation du corps
	var face := hv if hv.length() > 0.4 else Vector3.ZERO
	if state == S.ATTACK and mv.length() > 0.1 and state_t < 0.1: face = mv
	if face.length() > 0.0 and state not in [S.ROLL, S.HIT, S.LAUNCH, S.SOL, S.GETUP, S.DEAD]:
		vis.rotation.y = lerp_angle(vis.rotation.y, atan2(face.x, face.z), 1.0 - exp(-14.0 * dt))
	elif state == S.ROLL:
		vis.rotation.y = atan2(roll_dir.x, roll_dir.z)
	_animate(hv.length())

func _animate(s: float) -> void:
	match state:
		S.LOCO:
			if s < 0.3: vis.play(IDLE[style()] if style() != "poings" else "Idle_Loop", 0.25)
			elif s < 2.4: vis.play("Walk_Loop", 0.22, s / 1.5)
			elif s < 5.2: vis.play("Jog_Fwd_Loop", 0.22, s / 4.0)
			else: vis.play("Sprint_Loop", 0.22, s / 6.0)
		S.AIR:
			if state_t > 0.35 and vis.current in ["Jump_Start", "DoubleJump"]: vis.play("Jump_Loop", 0.2)
			if state_t > 0.3 and vis.current in ["NinjaJump_Start", "WallRun_Jump_L", "WallRun_Jump_R"]: vis.play("NinjaJump_Idle_Loop", 0.2)
