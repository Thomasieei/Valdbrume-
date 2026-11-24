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
	ui = CanvasLayer.new()
	add_child(ui)
	var tc := Control.new()
	tc.set_script(load("res://scripts/touch_controls.gd"))
	tc.player = player
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

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.47, 0.72)
	sm.sky_horizon_color = Color(0.80, 0.78, 0.74)
	sm.ground_horizon_color = Color(0.74, 0.76, 0.80)
	sm.ground_bottom_color = Color(0.55, 0.57, 0.60)
	sm.sun_angle_max = 25.0
	sm.sky_curve = 0.12
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.76, 0.80)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.18
	env.fog_aerial_perspective = 0.55
	env.fog_height = 40.0
	env.fog_height_density = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -128, 0)     # soleil bas, venant du sud-ouest
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.light_energy = 1.55
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
