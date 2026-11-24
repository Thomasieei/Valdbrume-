## Personnage de test pour parcourir la ville : course, sprint, saut,
## caméra à la 3e personne qui évite les murs. Commandes tactiles + clavier.
extends CharacterBody3D

const ANIM_DIR := "res://assets/human/anims/"
@export var walk_speed := 1.7
@export var run_speed := 4.6
@export var sprint_speed := 6.0
@export var jump_velocity := 5.2
var gravity := 18.0
var move_input := Vector2.ZERO          # fourni par les commandes tactiles / clavier
var sprint_held := false
var yaw := 0.0
var pitch := -0.18
var model: Node3D
var anim: AnimationPlayer
var cur_anim := ""
var anims := {}
@onready var pivot := Node3D.new()
@onready var arm := SpringArm3D.new()
@onready var cam := Camera3D.new()

func _ready() -> void:
	floor_max_angle = deg_to_rad(62.0)       # monte les bordures de trottoir (15 cm)
	floor_snap_length = 0.35
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	model = (load("res://assets/human/HumanM_Model.fbx") as PackedScene).instantiate()
	add_child(model)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/human/HumanAnimations_ColorPalette.png")
	mat.roughness = 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	anim = AnimationPlayer.new()
	model.add_child(anim)
	for key in ["Idle01", "Walk01_Forward", "Run01_Forward", "Sprint01_Forward", "Jump01_Begin", "Fall01", "Jump01_Land"]:
		var lib: AnimationLibrary = load(ANIM_DIR + key + ".fbx")
		if lib == null or lib.get_animation_list().is_empty():
			push_warning("animation absente : " + key)
			continue
		var a: Animation = lib.get_animation(lib.get_animation_list()[0]).duplicate()
		a.loop_mode = Animation.LOOP_NONE if key.begins_with("Jump") else Animation.LOOP_LINEAR
		var l := AnimationLibrary.new()
		l.add_animation(key, a)
		anim.add_animation_library(key, l)
		anims[key] = key + "/" + key
	pivot.position.y = 1.55
	add_child(pivot)
	arm.spring_length = 4.3
	arm.margin = 0.25
	arm.collision_mask = 1
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	arm.add_child(cam)
	cam.fov = 68.0
	cam.near = 0.08
	cam.far = 900.0
	cam.current = true
	_play("Idle01")

func _play(key: String, blend := 0.18, spd := 1.0) -> void:
	if not anims.has(key): return
	anim.speed_scale = spd
	if cur_anim != key:
		anim.play(anims[key], blend)
		cur_anim = key

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look(e.relative)

func look(rel: Vector2) -> void:
	yaw -= rel.x * 0.006
	pitch = clamp(pitch - rel.y * 0.004, -1.1, 0.55)

func _physics_process(dt: float) -> void:
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var mv := move_input if move_input.length() > 0.05 else kb
	var sprint := sprint_held or Input.is_key_pressed(KEY_SHIFT) or mv.length() > 0.92
	pivot.rotation = Vector3(pitch, yaw, 0)
	var basis_y := Basis(Vector3.UP, yaw)
	var dir := basis_y * Vector3(mv.x, 0, mv.y)
	var amount: float = clamp(mv.length(), 0.0, 1.0)
	var target_speed := 0.0
	if amount > 0.05:
		target_speed = sprint_speed if sprint else (run_speed if amount > 0.45 else walk_speed)
		dir = dir.normalized()
	var hv := Vector3(velocity.x, 0, velocity.z)
	var want := dir * target_speed
	var accel := 22.0 if is_on_floor() else 6.0
	hv = hv.move_toward(want, accel * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * dt
	elif Input.is_action_just_pressed("ui_accept") or _jump_req:
		velocity.y = jump_velocity
		_play("Jump01_Begin", 0.08)
	_jump_req = false
	move_and_slide()
	if hv.length() > 0.3:
		var target_yaw := atan2(hv.x, hv.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-12.0 * dt))
	# animations
	var s := hv.length()
	if not is_on_floor():
		if velocity.y < -1.0: _play("Fall01", 0.2)
	elif s < 0.3: _play("Idle01", 0.25)
	elif s < 2.6: _play("Walk01_Forward", 0.2, s / 1.6)
	elif s < 5.6: _play("Run01_Forward", 0.2, s / 4.4)
	else: _play("Sprint01_Forward", 0.2, s / 6.2)

var _jump_req := false
func request_jump() -> void:
	_jump_req = true
