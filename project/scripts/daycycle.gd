## Cycle jour / nuit suivant l'horloge de la ville : course du soleil, lumière
## dorée du matin et du soir, nuit bleutée sous la lune, fenêtres qui
## s'allument (paramètre global « nuit » lu par les façades).
extends Node

var life: Node
var env: Environment
var sun: DirectionalLight3D
var sky: ProceduralSkyMaterial
var _t := 99.0
var force_hour := -1.0          # pour les captures

const DAY_TOP := Color(0.27, 0.44, 0.72)
const DAY_HOR := Color(0.90, 0.80, 0.68)
const GOLD_HOR := Color(1.0, 0.62, 0.36)
const NIGHT_TOP := Color(0.015, 0.03, 0.075)
const NIGHT_HOR := Color(0.08, 0.10, 0.17)

func _process(dt: float) -> void:
	_t += dt
	if _t < 0.25: return
	_t = 0.0
	apply(force_hour if force_hour >= 0.0 else life.hour())

func apply(h: float) -> void:
	var f := (h - 6.5) / 14.0                         # 0 = lever, 1 = coucher
	var elev := sin(PI * clampf(f, 0.0, 1.0)) * 52.0 if f > 0.0 and f < 1.0 else -10.0
	var n := 1.0 - smoothstep(5.6, 7.2, h) if h < 12.0 else smoothstep(19.8, 21.6, h)
	var gold := clampf(1.0 - elev / 16.0, 0.0, 1.0) * (1.0 - n)   # lumière rasante dorée
	RenderingServer.global_shader_parameter_set("nuit", n)
	if n < 0.55:
		sun.rotation_degrees = Vector3(-max(elev, 4.0), -50.0 - 140.0 * clampf(f, 0.0, 1.0), 0.0)
		sun.light_color = Color(1.0, 0.86, 0.68).lerp(Color(1.0, 0.62, 0.36), gold * 0.8)
		sun.light_energy = 1.75 * (1.0 - n * 1.6) * (0.55 + 0.45 * smoothstep(0.0, 10.0, elev))
	else:
		# la lune : lumière froide et faible, ombres conservées
		sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
		sun.light_color = Color(0.55, 0.66, 1.0)
		sun.light_energy = 0.32 * n
	sky.sky_top_color = DAY_TOP.lerp(NIGHT_TOP, n)
	sky.sky_horizon_color = DAY_HOR.lerp(GOLD_HOR, gold * 0.75).lerp(NIGHT_HOR, n)
	sky.ground_horizon_color = Color(0.80, 0.76, 0.70).lerp(Color(0.06, 0.07, 0.11), n)
	sky.ground_bottom_color = Color(0.55, 0.53, 0.50).lerp(Color(0.03, 0.035, 0.05), n)
	env.ambient_light_energy = lerpf(0.7, 0.32, n)
	env.ambient_light_color = Color(0.66, 0.62, 0.58).lerp(Color(0.30, 0.36, 0.55), n)
	env.fog_light_color = Color(0.80, 0.76, 0.71).lerp(GOLD_HOR, gold * 0.35).lerp(Color(0.06, 0.07, 0.12), n)
	env.glow_intensity = lerpf(0.35, 0.8, n)
	env.glow_hdr_threshold = lerpf(1.1, 0.75, n)
