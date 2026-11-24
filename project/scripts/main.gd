## Scène principale : ciel, soleil de fin d'après-midi, brume, ville, joueur.
## Modes de test (arguments après "--") :
##   --capture   : photos de contrôle aux points de vue définis + mesures de rendu
##   --traverse  : traversée du boulevard d'ouest en est au sprint (temps mesuré)
extends Node3D

var city: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var stats: Label
var env: Environment
var sun: DirectionalLight3D
var life

func _ready() -> void:
	_environment()
	city = Node3D.new()
	city.name = "Ville"
	city.set_script(load("res://scripts/city.gd"))
	add_child(city)
	player = CharacterBody3D.new()
	player.name = "Joueur"
	player.set_script(load("res://scripts/player.gd"))
	var sp: Array = city.meta.spawn
	player.position = Vector3(sp[0], sp[1], sp[2])
	add_child(player)
	life = Node.new()
	life.name = "Vie"
	life.set_script(load("res://scripts/life.gd"))
	add_child(life)
	life.setup(city.meta, player)
	ui = CanvasLayer.new()
	add_child(ui)
	var tc := Control.new()
	tc.set_script(load("res://scripts/hud.gd"))
	tc.player = player
	tc.life = life
	ui.add_child(tc)
	stats = Label.new()
	stats.position = Vector2(16, 10)
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_outline_color", Color.BLACK)
	stats.add_theme_constant_override("outline_size", 4)
	ui.add_child(stats)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args: _capture.call_deferred()
	elif "--traverse" in args: _traverse.call_deferred()
	elif "--vie" in args: _simulate_life.call_deferred()
	elif "--diag-anim" in args: _diag_anim.call_deferred()

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.27, 0.44, 0.72)
	sm.sky_horizon_color = Color(0.90, 0.80, 0.68)
	sm.ground_horizon_color = Color(0.80, 0.76, 0.70)
	sm.ground_bottom_color = Color(0.55, 0.53, 0.50)
	sm.sun_angle_max = 25.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.66, 0.62, 0.58)
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.12
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.76, 0.71)
	env.fog_density = 0.0017
	env.fog_sky_affect = 0.18
	env.fog_aerial_perspective = 0.55
	env.fog_height = 40.0
	env.fog_height_density = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.08
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-27, -140, 0)     # soleil bas de fin d'après-midi (sud-ouest)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 75.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_blend_splits = false
	add_child(sun)

func _process(_dt: float) -> void:
	if stats.visible:
		stats.text = "%d i/s · %d appels · %.0fk tri" % [Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0]

# ------------------------------------------------------------------ tests
func _wait(frames: int) -> void:
	for i in frames: await get_tree().process_frame

func _capture() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join("../captures")
	DirAccess.make_dir_recursive_absolute(out)
	ui.visible = false
	var cam := Camera3D.new()
	cam.fov = 68.0
	cam.near = 0.08
	cam.far = 900.0
	add_child(cam)
	var report := []
	await _wait(30)
	for v in city.meta.views:
		var eye := Vector3(v.eye[0], v.eye[1], v.eye[2])
		var at := Vector3(v.at[0], v.at[1], v.at[2])
		cam.global_position = eye
		cam.look_at(at, Vector3.UP)
		cam.current = true
		player.position = eye + (at - eye).normalized() * 6.0 * Vector3(1, 0, 1) + Vector3(0, 0.2, 0) if v.name.begins_with("12") else Vector3(0, -50, 0)
		await _wait(24)
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join(v.name + ".png"))
		report.append({"vue": v.name,
			"appels": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"objets": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			"triangles": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
		print("capture ", v.name, " ", report[-1])
	await _capture_characters(cam, out, report)
	await _capture_life(cam, out, report)
	# vue avec le joueur (3e personne) sur le boulevard
	player.position = Vector3(-80, 0.2, 3)
	player.yaw = -PI / 2.0 - 0.35
	player.pitch = -0.12
	player.cam.current = true
	await _wait(40)
	get_viewport().get_texture().get_image().save_png(out.path_join("17_joueur_boulevard.png"))
	report.append({"vue": "17_joueur_boulevard",
		"appels": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"triangles": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	var f := FileAccess.open(out.path_join("rapport_rendu.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	get_tree().quit()

func _shot(out: String, name: String, report: Array) -> void:
	await _wait(20)
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	report.append({"vue": name,
		"appels": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"triangles": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	print("capture ", name, " ", report[-1])

## galerie : les 11 personnages alignés sur l'anneau de marbre de la place, puis le héros en action
func _capture_characters(cam: Camera3D, out: String, report: Array) -> void:
	var ids := ["heros", "lea", "hugo", "ines", "marc", "sofia", "karim", "chloe", "theo", "nadia", "victor"]
	var shown: Array = []
	life.process_mode = Node.PROCESS_MODE_DISABLED
	for n in life.npcs.values(): n.visible = false
	for i in ids.size():
		var v := CharacterVisual.new()
		add_child(v); v.setup(ids[i])
		v.position = Vector3(-10.0 + i * 2.0, 0.0, 24.5)
		v.rotation.y = 0.0
		v.play(["Idle_Loop", "Idle_Talking_Loop", "Idle_LookAround_Loop", "Idle_Loop", "Idle_FoldArms_Loop", "Idle_Loop", "Idle_Loop", "Idle_TalkingPhone_Loop", "Idle_Loop", "Idle_FoldArms_Loop", "Idle_Loop"][i], 0.0)
		shown.append(v)
	player.position = Vector3(0, -50, 0)
	cam.current = true
	cam.global_position = Vector3(0, 1.4, 35.0); cam.look_at(Vector3(0, 1.0, 24.5))
	await _shot(out, "30_les_onze", report)
	for i in [0, 1, 4, 7, 10]:
		var p: Vector3 = shown[i].position
		cam.global_position = p + Vector3(0.35, 1.62, 1.6); cam.look_at(p + Vector3(0, 1.45, 0))
		await _shot(out, "31_portrait_" + ids[i], report)
	for v in shown: v.queue_free()
	# le héros en action (pose figée au milieu de l'animation)
	var hero := CharacterVisual.new(); add_child(hero); hero.setup("heros")
	hero.position = Vector3(-22, 0, 36); hero.rotation.y = deg_to_rad(60)
	var poses := [["Sprint_Loop", 0.3, ""], ["Sword_Heavy_B", 0.45, "epee"], ["Sword_Aerial_A", 0.4, "epee"], ["Spell_Double_Shoot_Loop", 0.5, ""], ["Roll", 0.4, ""], ["Melee_Uppercut", 0.5, ""], ["Bow_Shoot", 0.3, ""], ["Slide_Loop", 0.4, ""], ["NinjaJump_Double", 0.4, ""], ["WallRun_L_Loop", 0.4, ""]]
	for po in poses:
		hero.set_weapon(po[2])
		hero.play(po[0], 0.0, 1.0, true)
		hero.anim.seek(hero.length(po[0]) * po[1], true)
		hero.anim.pause()
		cam.global_position = hero.position + Vector3(2.4, 1.3, 2.2); cam.look_at(hero.position + Vector3(0, 0.95, 0))
		await _shot(out, "32_heros_" + po[0].to_lower(), report)
	hero.queue_free()
	for n in life.npcs.values(): n.visible = true
	life.process_mode = Node.PROCESS_MODE_INHERIT

## la vie en ville à différentes heures
func _capture_life(cam: Camera3D, out: String, report: Array) -> void:
	var shots := [
		[7 * 60 + 40, "fleuriste", Vector3(6, 1.6, 7), "40_matin_fleuriste_sofia_karim"],
		[8 * 60 + 30, "boulangerie", Vector3(-6, 1.6, 2), "41_matin_boulangerie_lea"],
		[12 * 60 + 50, "cafe", Vector3(7, 1.7, 6), "42_midi_cafe"],
		[9 * 60 + 30, "garage", Vector3(-6, 1.6, 4), "43_garage_karim"],
		[19 * 60 + 20, "banc_place_s", Vector3(3, 1.6, 6), "44_soir_banc_sofia_karim"],
		[21 * 60 + 30, "gare", Vector3(6, 1.7, 4), "45_nuit_gare_marc"],
	]
	for s in shots:
		life.minute = s[0]
		life.warp()
		await _wait(5)
		var p: Dictionary = life.places[s[1]]
		var at := Vector3(p.pos[0], p.pos[1], p.pos[2])
		cam.current = true
		cam.global_position = at + s[2]; cam.look_at(at + Vector3(0, 1.1, 0))
		await _shot(out, s[3], report)

## simulation d'une journée complète (sans rendu) : chacun atteint-il ses lieux ?
func _simulate_life() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join("../captures")
	DirAccess.make_dir_recursive_absolute(out)
	life.minute = 5 * 60
	life.warp()
	life.minutes_per_second = 20.0           # 1 minute de jeu = 3 images à 60 i/s
	var res := {"etapes": [], "bloques": []}
	var last := {}
	var still := {}
	var t := 0.0
	while not (life.day == 2 and life.minute >= 5 * 60) and t < 240.0:
		await get_tree().process_frame
		t += 1.0 / 60.0
		if life.minute % 60 == 0 and int(t * 60) % 3 == 0:
			var row := {"heure": life.clock_text()}
			for id in life.npcs:
				var n: Npc = life.npcs[id]
				row[id] = "%s%s" % [n.place, "" if n.arrived() else " (en route)"]
				var pp: Vector3 = n.global_position
				if not n.arrived() and last.has(id) and pp.distance_to(last[id]) < 0.05:
					still[id] = still.get(id, 0) + 1
					if still[id] == 20: res.bloques.append("%s bloqué près de %s à %s" % [id, str(pp), life.clock_text()])
				else: still[id] = 0
				last[id] = pp
			if res.etapes.is_empty() or res.etapes[-1].heure != row.heure: res.etapes.append(row)
	res["journal"] = life.log_lines
	res["memoire"] = life.mem
	var f := FileAccess.open(out.path_join("vie_journee.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  ")); f.close()
	print("VIE bloques=", res.bloques.size(), " evenements=", life.log_lines.size())
	get_tree().quit()

func _diag_anim() -> void:
	await _wait(3)
	var v := CharacterVisual.new(); add_child(v); v.setup("lea")
	v.play("Idle_Loop", 0.0)
	await _wait(10)
	var sk := v.skeleton
	var pi := sk.find_bone("upperarm_l")
	print("DIAG lea joue=", v.anim.is_playing(), " anim=", v.anim.current_animation, " pos=", v.anim.current_animation_position, " bras=", sk.get_bone_pose_rotation(pi), " repos=", sk.get_bone_rest(pi).basis.get_rotation_quaternion())
	print("DIAG racine=", v.anim.root_node, " -> ", v.anim.get_node_or_null(v.anim.root_node), " squelette=", sk.get_path(), " modele=", v.model.get_path())
	var a: Animation = AnimBank.libs.ual1.get_animation("Idle_Loop")
	for t in min(4, a.get_track_count()): print("DIAG piste ", a.track_get_path(t), " type ", a.track_get_type(t))
	var psk: Skeleton3D = player.vis.skeleton
	print("DIAG joueur joue=", player.vis.anim.is_playing(), " anim=", player.vis.anim.current_animation, " bras=", psk.get_bone_pose_rotation(psk.find_bone("upperarm_l")), " chemin=", psk.get_path())
	for n in life.npcs.values():
		print("DIAG pnj ", n.id, " joue=", n.vis.anim.is_playing(), " anim=", n.vis.anim.current_animation, " mode=", n.vis.anim.callback_mode_process, " bras=", n.vis.skeleton.get_bone_pose_rotation(n.vis.skeleton.find_bone("upperarm_l")))
		break
	get_tree().quit()

func _traverse() -> void:
	# sprint en ligne droite d'ouest en est le long du Grand Boulevard
	var out := ProjectSettings.globalize_path("res://").path_join("../captures")
	DirAccess.make_dir_recursive_absolute(out)
	player.position = Vector3(-370, 0.3, 2.5)
	player.yaw = -PI / 2.0
	await _wait(5)
	var t := 0.0
	var last_x := player.position.x
	var stuck := 0.0
	var journal := []
	var max_y := 0.0
	while player.position.x < 370.0 and t < 400.0:
		player.move_input = Vector2(0, -1)
		player.sprint_held = true
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		max_y = max(max_y, player.position.y)
		if int(t * 60) % 600 == 0: journal.append([snapped(t, 0.1), snapped(player.position.x, 0.1), snapped(player.position.y, 0.01)])
		if abs(player.position.x - last_x) < 0.01: stuck += 1.0 / 60.0
		else: stuck = 0.0
		last_x = player.position.x
		if stuck > 3.0: break
	var res := {"duree_s": snapped(t, 0.1), "x_final": snapped(player.position.x, 0.1), "bloque": stuck > 3.0, "y_max": max_y, "journal": journal}
	print("TRAVERSEE ", JSON.stringify(res))
	var f := FileAccess.open(out.path_join("traversee.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	get_tree().quit()
