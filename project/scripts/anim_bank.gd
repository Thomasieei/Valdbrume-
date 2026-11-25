## Banque d'animations partagée (chargée une seule fois pour tous les personnages) :
## Universal Animation Library 1 et 2 (254 animations, même squelette que les
## personnages). On garde les rotations de tous les os et le déplacement du
## bassin seulement : les animations s'adaptent ainsi à chaque morphologie.
class_name AnimBank
extends RefCounted

const LIBS := {"ual1": "res://assets/characters/anims/UAL1.glb", "ual2": "res://assets/characters/anims/UAL2.glb",
	"pk1": "res://assets/characters/anims/PK_Vault.glb", "pk2": "res://assets/characters/anims/PK_Flip.glb", "pk3": "res://assets/characters/anims/PK_NinjaDouble.glb"}
## noms simples pour les animations de parkour fournies à part
const RENOMS := {"Move_-_vault": "PK_Vault", "Move_-_jog_into_a_flip": "PK_Flip", "Jump_-_ninja_double": "PK_NinjaDouble"}
static var libs := {}            # nom -> AnimationLibrary nettoyée
static var index := {}           # nom d'animation -> "lib/nom"
static var courbes := {}         # parkour : avance du corps (m) échantillonnée à 30 i/s

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
			# animations de parkour avec déplacement : on garde la hauteur du bassin
			# (le saut, la vrille) mais on retire l'avancée, rejouée par le corps
			if RENOMS.has(String(n)):
				for t in a.get_track_count():
					if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with(":pelvis"):
						var c := PackedFloat32Array()
						var p0: Vector3 = a.position_track_interpolate(t, 0.0)
						var s := 0.0
						while s <= a.length + 0.001:
							var pp: Vector3 = a.position_track_interpolate(t, s)
							c.append(-(pp.y - p0.y)); s += 1.0 / 30.0
						courbes[RENOMS[String(n)]] = c
						for k in a.track_get_key_count(t):
							var v: Vector3 = a.track_get_key_value(t, k)
							a.track_set_key_value(t, k, Vector3(p0.x, p0.y, v.z))
			# l'import de Godot retire le suffixe « _Loop » (et règle la boucle) :
			# on accepte les deux noms
			if String(n) in ["Sword_Idle", "Fixing_Kneeling", "Counter_Idle", "Idle_Torch"]: a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(n, a)
			for alias in [String(n), String(n) + "_Loop", String(RENOMS.get(String(n), String(n)))]:
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


## avance du corps (0 → 1) à l'instant t d'une animation de parkour ; lissée sinon
static func progression(n: String, t: float, duree: float) -> float:
	var k := clampf(t / maxf(duree, 0.01), 0.0, 1.0)
	if not courbes.has(n): return k * k * (3.0 - 2.0 * k)
	var c: PackedFloat32Array = courbes[n]
	var tot: float = c[c.size() - 1]
	if absf(tot) < 0.01: return k
	var f := k * (c.size() - 1)
	var i := int(floor(f)); var j := mini(i + 1, c.size() - 1)
	return clampf(lerpf(c[i], c[j], f - i) / tot, 0.0, 1.0)

static func avance_totale(n: String) -> float:
	if not courbes.has(n): return 0.0
	var c: PackedFloat32Array = courbes[n]
	return c[c.size() - 1]
