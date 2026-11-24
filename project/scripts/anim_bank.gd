## Banque d'animations partagée (chargée une seule fois pour tous les personnages) :
## Universal Animation Library 1 et 2 (254 animations, même squelette que les
## personnages). On garde les rotations de tous les os et le déplacement du
## bassin seulement : les animations s'adaptent ainsi à chaque morphologie.
class_name AnimBank
extends RefCounted

const LIBS := {"ual1": "res://assets/characters/anims/UAL1.glb", "ual2": "res://assets/characters/anims/UAL2.glb"}
static var libs := {}            # nom -> AnimationLibrary nettoyée
static var index := {}           # nom d'animation -> "lib/nom"

static func ensure() -> void:
	if not libs.is_empty(): return
	for key in LIBS:
		var src: AnimationLibrary = load(LIBS[key])
		if src == null:
			push_error("bibliothèque d'animations introuvable : " + LIBS[key]); continue
		var lib := AnimationLibrary.new()
		for n in src.get_animation_list():
			var a: Animation = src.get_animation(n).duplicate(true)
			for t in range(a.get_track_count() - 1, -1, -1):
				var tt := a.track_get_type(t)
				var p := String(a.track_get_path(t))
				if tt == Animation.TYPE_SCALE_3D: a.remove_track(t)
				elif tt == Animation.TYPE_POSITION_3D and not (p.ends_with(":pelvis") or p.ends_with(":root")): a.remove_track(t)
			# l'import de Godot retire le suffixe « _Loop » (et règle la boucle) :
			# on accepte les deux noms
			if String(n) in ["Sword_Idle", "Fixing_Kneeling", "Counter_Idle", "Idle_Torch"]: a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(n, a)
			for alias in [String(n), String(n) + "_Loop"]:
				if not index.has(alias): index[alias] = key + "/" + String(n)
		libs[key] = lib

static func attach(ap: AnimationPlayer) -> void:
	ensure()
	for key in libs:
		if not ap.has_animation_library(key): ap.add_animation_library(key, libs[key])

static func path(n: String) -> String:
	ensure()
	return String(index.get(n, ""))

static func length(n: String) -> float:
	var p := path(n)
	if p == "": return 0.0
	var parts := p.split("/")
	return (libs[parts[0]] as AnimationLibrary).get_animation(parts[1]).length
