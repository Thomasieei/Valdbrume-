## Le héros (joueur) : 254 animations, déplacements fluides (marche, jogging,
## sprint, glissade, roulade, esquives, saut et double saut), quatre styles de
## combat avec enchaînements (mains nues, épée, magie, arc), émotes.
extends CharacterBody3D

signal action_text(t: String)
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

enum S { LOCO, AIR, ROLL, SLIDE, ATTACK, DODGE, EMOTE, LAND }
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

const COMBOS := {
	"poings": {"legere": ["Punch_Jab", "Punch_Cross", "Melee_Hook", "Kick"], "lourde": ["Melee_Uppercut", "Melee_Knee"]},
	"epee": {"legere": ["Sword_Light_A", "Sword_Light_B", "Sword_Light_C", "Sword_Light_D"], "lourde": ["Sword_Heavy_A", "Sword_Heavy_B", "Sword_Heavy_C", "Sword_Heavy_D"], "air": ["Sword_Aerial_A", "Sword_Aerial_B"]},
	"magie": {"legere": ["Spell_Simple_Shoot"], "lourde": ["Spell_Double_Shoot_Loop"]},
	"arc": {"legere": ["Bow_Shoot"], "lourde": ["Bow_RapidShoot_Loop"]},
}
const IDLE := {"poings": "Idle_Loop", "epee": "Sword_Idle", "magie": "Spell_Simple_Idle_Loop", "arc": "Bow_Aim_Neutral"}

func _ready() -> void:
	floor_max_angle = deg_to_rad(62.0)
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
	combo_i = 0
	action_text.emit({"poings": "Mains nues", "epee": "Épée", "magie": "Magie", "arc": "Arc"}[style()])

func attack(heavy := false) -> void:
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

func dodge() -> void:
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
			target = hv.move_toward(Vector3.ZERO, 30.0 * dt) if is_on_floor() else hv
			# petite avancée au moment du coup
			if state_t < 0.18 and is_on_floor(): target += Basis(Vector3.UP, vis.rotation.y) * Vector3(0, 0, 1) * 2.2
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
		S.AIR:
			target = hv.lerp(mv.normalized() * max(hv.length(), jog_speed) if amount > 0.05 else hv, 2.5 * dt)
	var accel := 24.0 if is_on_floor() else 8.0
	if state in [S.ROLL, S.SLIDE, S.ATTACK]: hv = target
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
	if face.length() > 0.0 and state != S.ROLL:
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
