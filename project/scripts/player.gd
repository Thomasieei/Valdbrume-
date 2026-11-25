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

enum S { LOCO, AIR, ROLL, SLIDE, ATTACK, DODGE, EMOTE, LAND, HIT, DEAD, LAUNCH, SOL, GETUP }
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
	# visée assistée : on se tourne vers l'ennemi le plus proche devant soi
	var t := cible_visee()
	lunge = 2.2
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
			var reach := 2.4 if style() == "epee" else 1.7
			if heavy: reach += 0.4
			var touche := false
			for e in get_tree().get_nodes_in_group("ennemis"):
				var to: Vector3 = e.global_position - global_position; to.y = 0
				var dd := to.length()
				if dd < reach + float(e.rayon) and (dd < 0.6 or fwd.dot(to / dd) > 0.35):
					var crit := randf() < 0.12
					var val := dmg * (1.6 if crit else 1.0)
					e.touche(val, global_position, "lourd" if heavy else "")
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
			var from2 := _bone_pos("hand_l") + Vector3(0, 0.05, 0) + fwd * 0.3
			var t2 := cible_visee(32.0)
			var pr2 := Projectile.new()
			pr2.exclude = [get_rid()]; pr2.kind = "fleche"; pr2.degats = dmg; pr2.vie = 1.4
			get_parent().add_child(pr2)
			pr2.lance(from2, (t2.global_position + Vector3(0, 1.0, 0) - from2).normalized() if t2 else fwd, 38.0, t2)

func _hitstop(d: float) -> void:
	Engine.time_scale = 0.06
	await get_tree().create_timer(d, true, false, true).timeout
	Engine.time_scale = 1.0

## coup reçu (les roulades et glissades esquivent)
func blesse(dmg: float, from: Vector3, force := 4.0) -> void:
	if not vivant or state in [S.ROLL, S.SLIDE, S.DEAD, S.LAUNCH, S.SOL, S.GETUP]: return
	pv -= dmg; hurt_t = 0.0; hurt_flash = 1.0; shake = 0.45 + force * 0.04
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
	if not vivant or state in [S.ROLL, S.SLIDE, S.DEAD, S.LAUNCH, S.SOL, S.GETUP]: return
	pv -= dmg; hurt_t = 0.0; hurt_flash = 1.0; shake = 1.0; combo_n = 0
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
	if not vivant or state == S.HIT: return
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
	if state == S.ATTACK:
		var hts: Array = HIT_TIMES.get(attack_name, [0.42])
		if hit_i < hts.size() and state_t >= state_len * float(hts[hit_i]) / 0.92:
			_strike(); hit_i += 1
	var mv := _move_dir()
	var amount := mv.length()
	var hv := Vector3(velocity.x, 0, velocity.z)
	var target := Vector3.ZERO
	var sprint := sprint_held or Input.is_key_pressed(KEY_SHIFT) or amount > 0.92
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
			if state_t < 0.18 and is_on_floor(): target = Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1) * lunge
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
			velocity.y = jump_velocity; state = S.AIR; state_t = 0.0
			vis.play("Jump_Start", 0.06, 1.2, true)
	else:
		velocity.y -= gravity * dt
		if want_jump and air_jumps == 0 and state in [S.AIR, S.LOCO]:
			air_jumps = 1; velocity.y = jump_velocity * 0.95; state = S.AIR; state_t = 0.0
			vis.play("DoubleJump", 0.06, 1.1, true)
		if state == S.LOCO and velocity.y < -2.0: state = S.AIR; state_t = 0.0
	var was_air := state == S.AIR
	move_and_slide()
	if was_air and is_on_floor() and state_t > 0.1:
		state = S.LAND; state_t = 0.0
		vis.play("Jump_Land", 0.05, 1.3, true)
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
