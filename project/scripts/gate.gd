## Portail (Gate) façon Solo Leveling : il apparaît en grandissant, palpite,
## devient instable, puis se brise en libérant ses monstres.
class_name Portail
extends Node3D

signal brise
var mat := ShaderMaterial.new()
var light := OmniLight3D.new()
var etat := "ouverture"     # ouverture, stable, instable, brise, ferme
var t := 0.0
var base_fx: Node3D

func _ready() -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(4.4, 6.2)
	q.mesh = qm
	mat.shader = load("res://shaders/gate.gdshader")
	mat.set_shader_parameter("open", 0.0)
	q.material_override = mat
	q.position.y = 3.3
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	light.light_color = Color(0.4, 0.65, 1.0); light.omni_range = 16.0; light.light_energy = 0.0
	light.position = Vector3(0, 2.5, 1.2)
	add_child(light)

func _process(dt: float) -> void:
	t += dt
	match etat:
		"ouverture":
			var k := clampf(t / 2.5, 0.0, 1.0)
			mat.set_shader_parameter("open", ease(k, 0.4))
			light.light_energy = 3.0 * k
			if k >= 1.0:
				etat = "stable"; t = 0.0
				Sfx.joue("portail", global_position + Vector3.UP * 2.0, 2.0, 0.0)
				base_fx = Fx.spawn(self, "Mystic", "Radial_02", Transform3D(Basis(), Vector3(0, 0.05, 0)), 3.2, -1.0)
		"stable":
			light.light_energy = 3.0 + 0.6 * sin(t * 2.3)
		"instable":
			mat.set_shader_parameter("instab", clampf(t / 3.0, 0.0, 1.0))
			light.light_energy = 3.5 + 1.8 * absf(sin(t * 9.0))
			if t > 3.2:
				etat = "brise"; t = 0.0
				Fx.spawn(get_parent(), "Mystic", "Radial_01", Transform3D(Basis(), global_position + Vector3(0, 0.1, 0)), 4.5, 2.5)
				Fx.flash(get_parent(), global_position + Vector3(0, 2.0, 0), Color(0.5, 0.75, 1.0), 10.0, 25.0, 0.9)
				Sfx.joue("grondement", global_position + Vector3.UP * 2.0, 6.0, 0.0)
				brise.emit()
		"brise":
			mat.set_shader_parameter("open", clampf(1.0 - t / 0.6, 0.0, 1.0) * 1.15)
			light.light_energy = max(0.0, 6.0 * (1.0 - t / 0.8))
			if t > 0.8:
				etat = "ferme"; visible = false
				if base_fx: base_fx.queue_free()

func destabilise() -> void:
	if etat in ["stable", "ouverture"]: etat = "instable"; t = 0.0
