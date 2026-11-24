## Diagnostic des effets Vefects (rendu réel, sans la ville)
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _shot(n: String) -> void:
	for i in 3: await process_frame
	var out := ProjectSettings.globalize_path("res://").path_join("../captures")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))
	print("FXDIAG capture ", n)

func _run() -> void:
	var w := Node3D.new(); root.add_child(w)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.25, 0.3, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.glow_enabled = true; env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env; w.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, -30, 0); w.add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); floor.mesh = pm; w.add_child(floor)
	var cam := Camera3D.new(); w.add_child(cam); cam.position = Vector3(0, 2.2, 9); cam.look_at(Vector3(0, 1.2, 0)); cam.current = true
	# particules Godot standard (contrôle)
	var gp := GPUParticles3D.new(); var ppm := ParticleProcessMaterial.new()
	ppm.direction = Vector3(0, 1, 0); ppm.initial_velocity_min = 1.0; ppm.initial_velocity_max = 2.0; ppm.gravity = Vector3.ZERO
	gp.process_material = ppm; var sm := SphereMesh.new(); sm.radius = 0.08; sm.height = 0.16; gp.draw_pass_1 = sm
	gp.amount = 30; w.add_child(gp); gp.position = Vector3(0, 3.2, 0)
	var list := [["Mystic", "01", Vector3(-4, 0, 0), 0.5], ["Electric", "Radial_01", Vector3(-1.3, 0, 0), 0.4], ["Dark", "02", Vector3(1.3, 0, 0), 0.5], ["Electric", "Radial_02", Vector3(4, 0, 0), 0.4]]
	for e in list:
		var n := Fx.spawn(w, e[0], e[1], Transform3D(Basis(), e[2]), e[3], -1.0)
		print("FXDIAG ", e[0], " ", e[1], " -> ", n, " enfants=", n.get_child_count() if n else -1)
		if n:
			for p in n.find_children("*", "GPUParticles3D", true, false):
				print("FXDIAG   ", p.name, " emitting=", p.emitting, " amount=", p.amount, " lifetime=", p.lifetime, " mat=", p.material_override, " proc=", p.process_material)
	await _shot("fxdiag_a_0s3")
	for i in 40: await process_frame
	await _shot("fxdiag_b_1s")
	for i in 80: await process_frame
	await _shot("fxdiag_c_2s")
	# portail
	var g := Portail.new(); w.add_child(g); g.position = Vector3(0, 0, -4)
	for i in 200: await process_frame
	await _shot("fxdiag_d_portail")
	g.queue_free()
	# monstres en plein jour (aucune lumière d'effet) et héros à l'arc / magie
	for e in w.get_children():
		if e.name.begins_with("VFX"): e.queue_free()
	var m1 := Monstre.new(); w.add_child(m1); m1.setup("rodeur"); m1.position = Vector3(-2.2, 0, 0); m1.model.rotation.y = 0.4
	var m2 := Monstre.new(); w.add_child(m2); m2.setup("brute"); m2.position = Vector3(2.4, 0, -0.5); m2.model.rotation.y = -0.4
	for i in 90: await process_frame
	await _shot("fxdiag_e_monstres")
	m1.queue_free(); m2.queue_free()
	var h := CharacterVisual.new(); w.add_child(h); h.setup("heros"); h.position = Vector3(-1.2, 0, 3.5); h.rotation.y = deg_to_rad(70)
	h.set_weapon("arc"); h.play("Bow_Aim_Neutral", 0.0)
	var h2 := CharacterVisual.new(); w.add_child(h2); h2.setup("heros"); h2.position = Vector3(1.4, 0, 3.5); h2.rotation.y = deg_to_rad(-30)
	h2.set_weapon("magie"); h2.play("Spell_Simple_Idle_Loop", 0.0)
	cam.position = Vector3(0, 1.5, 7.5); cam.look_at(Vector3(0, 1.1, 3.5))
	for i in 60: await process_frame
	await _shot("fxdiag_f_arc_magie")
	quit()
