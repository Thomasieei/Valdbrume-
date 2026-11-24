## Un habitant : marche sur les trottoirs (graphe de déplacement), suit son
## emploi du temps, s'arrête pour parler aux gens qu'il connaît, réagit au joueur.
class_name Npc
extends Node3D

var id := ""
var life: Node
var vis: CharacterVisual
var label: Label3D
var path: PackedVector3Array = PackedVector3Array()
var path_i := 0
var speed := 1.35
var activity: Dictionary = {}
var place := ""
var busy_t := 0.0          # conversation / réaction en cours
var busy_anim := ""
var talk_cd := 0.0
var face_target := Vector3.ZERO
var hidden_inside := false
var lod_t := 0.0

func setup(p_id: String, p_life: Node, start: Vector3) -> void:
	id = p_id; life = p_life
	vis = CharacterVisual.new()
	add_child(vis)
	vis.setup(id)
	position = start
	label = Label3D.new()
	label.text = "%s\n%s" % [vis.data.nom, vis.data.role]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.15
	label.font_size = 42
	label.outline_size = 10
	label.pixel_size = 0.004
	label.modulate = Color(1, 0.97, 0.9)
	label.no_depth_test = false
	label.visible = false
	add_child(label)
	vis.play("Idle_Loop", 0.0)

func go_to(world_path: PackedVector3Array, p_speed := 1.35) -> void:
	path = world_path; path_i = 0; speed = p_speed
	_set_inside(false)

func arrived() -> bool: return path_i >= path.size()

func _set_inside(v: bool) -> void:
	hidden_inside = v
	visible = not v

func do_activity(a: Dictionary, at: Dictionary) -> void:
	activity = a
	if at.get("interieur", false) and a.get("anim", "") == "":
		_set_inside(true)
		return
	_set_inside(false)
	position = Vector3(at.pos[0], at.pos[1], at.pos[2])
	vis.rotation.y = deg_to_rad(float(at.rot))
	vis.play(a.get("anim", "Idle_Loop"), 0.3)

func react(anim_name: String, duration: float, look_at_pos := Vector3.ZERO) -> void:
	busy_t = duration; busy_anim = anim_name
	if look_at_pos != Vector3.ZERO: face_target = look_at_pos
	vis.play(anim_name, 0.2, 1.0, true)

func _process(dt: float) -> void:
	if hidden_inside: return
	talk_cd = max(talk_cd - dt, 0.0)
	# économie : animations moins fréquentes quand le personnage est loin
	var cam := get_viewport().get_camera_3d()
	var d := cam.global_position.distance_to(global_position) if cam else 0.0
	vis.visible = d < 160.0
	vis.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if d < 45.0 else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if d >= 45.0 and vis.visible:
		lod_t += dt
		if lod_t > (0.066 if d < 90.0 else 0.15):
			vis.anim.advance(lod_t); lod_t = 0.0
	label.visible = d < 9.0
	if busy_t > 0.0:
		busy_t -= dt
		if face_target != Vector3.ZERO:
			var to := face_target - global_position
			vis.rotation.y = lerp_angle(vis.rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * dt))
		if busy_t <= 0.0:
			face_target = Vector3.ZERO
			if path_i < path.size(): vis.play("Walk_Loop", 0.25, speed / 1.35)
			elif activity.has("anim"): vis.play(activity.anim, 0.3)
		return
	if path_i < path.size():
		var tgt := path[path_i]
		var to := tgt - position
		var flat := Vector3(to.x, 0, to.z)
		# hors de vue du joueur : on accélère (le trajet reste cohérent avec l'horloge)
		var step: float = speed * dt * (life.offscreen_factor() if d > 90.0 or cam == null else 1.0)
		if flat.length() <= step:
			position = tgt; path_i += 1
			if path_i >= path.size(): life.npc_arrived(self)
		else:
			var dir := flat.normalized()
			position += dir * step
			position.y = lerp(position.y, tgt.y, clamp(step / max(flat.length(), 0.01), 0.0, 1.0))
			vis.rotation.y = lerp_angle(vis.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-10.0 * dt))
		vis.play("Jog_Fwd_Loop" if speed > 2.5 else ("Walk_Formal_Loop" if vis.data.role == "homme d'affaires" else "Walk_Loop"), 0.25, speed / (3.8 if speed > 2.5 else 1.35))
