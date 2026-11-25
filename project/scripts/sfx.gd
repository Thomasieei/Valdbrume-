## Bruitages : banque de sons (Kenney, CC0, et souffles synthétisés), joués en 3D
## avec une petite réserve de lecteurs réutilisés (pas d'allocation en jeu),
## variante et hauteur légèrement aléatoires pour éviter la répétition.
class_name Sfx
extends RefCounted

const DIR := "res://assets/audio/"
const BANQUE := {
	"pas": ["footstep_concrete_000", "footstep_concrete_001", "footstep_concrete_002", "footstep_concrete_003", "footstep_concrete_004"],
	"echelle": ["impact_metal_light_000", "impact_metal_light_001", "impact_metal_light_002", "impact_metal_light_003", "impact_metal_light_004"],
	"coup": ["impact_punch_medium_000", "impact_punch_medium_001", "impact_punch_medium_002", "impact_punch_medium_003", "impact_punch_medium_004"],
	"coup_fort": ["impact_punch_heavy_000", "impact_punch_heavy_001", "impact_punch_heavy_002", "impact_punch_heavy_003", "impact_punch_heavy_004"],
	"chute": ["impact_soft_heavy_000", "impact_soft_heavy_001", "impact_soft_heavy_002", "impact_soft_heavy_003", "impact_soft_heavy_004"],
	"reception": ["impact_soft_medium_000", "impact_soft_medium_001", "impact_soft_medium_002", "impact_soft_medium_003", "impact_soft_medium_004"],
	"bois": ["impact_plank_medium_000", "impact_plank_medium_001", "impact_plank_medium_002"],
	"fleche_plantee": ["impact_wood_light_000", "impact_wood_light_001", "impact_wood_light_002"],
	"parade": ["impact_plate_light_000", "impact_plate_light_001", "impact_plate_light_002"],
	"tissu": ["cloth_1", "cloth_2", "cloth_3", "cloth_4"],
	"lame": ["knife_slice", "knife_slice_2"],
	"degaine": ["draw_knife_1", "draw_knife_2", "draw_knife_3"],
	"sort": ["laser_small_000", "laser_small_001", "laser_small_002"],
	"explosion": ["explosion_crunch_000", "explosion_crunch_001", "explosion_crunch_002"],
	"grondement": ["low_frequency_explosion_000", "low_frequency_explosion_001"],
	"portail": ["force_field_000"],
	"souffle": ["souffle_0", "souffle_1", "souffle_2"],
	"souffle_lourd": ["souffle_lourd_0", "souffle_lourd_1"],
	"elan": ["elan"],
	"vent": ["vent_chute"],
	"corde": ["corde_arc"],
	"fleche": ["fleche_vol"],
}
static var _flux := {}
static var _lecteurs: Array = []
static var _i := 0
static var racine: Node = null

static func init(parent: Node) -> void:
	racine = Node.new(); racine.name = "Sons"
	parent.add_child(racine)
	for i in 18:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0; p.max_distance = 45.0
		p.attenuation_filter_cutoff_hz = 9000.0
		racine.add_child(p)
		_lecteurs.append(p)

static func _flux_de(nom: String) -> AudioStream:
	var l: Array = BANQUE[nom]
	var f: String = l[randi() % l.size()]
	if not _flux.has(f):
		var p: String = DIR + f + (".wav" if ResourceLoader.exists(DIR + f + ".wav") else ".ogg")
		_flux[f] = load(p)
	return _flux[f]

## joue un son à une position (volume en dB, variation de hauteur)
static func joue(nom: String, pos: Vector3, volume := 0.0, var_hauteur := 0.08) -> void:
	if racine == null or not BANQUE.has(nom): return
	var p: AudioStreamPlayer3D = _lecteurs[_i]
	_i = (_i + 1) % _lecteurs.size()
	p.stream = _flux_de(nom)
	p.volume_db = volume
	p.pitch_scale = 1.0 + randf_range(-var_hauteur, var_hauteur)
	p.global_position = pos
	p.play()

## précharge toute la banque (évite un à-coup au premier coup)
static func precharge() -> void:
	for nom in BANQUE:
		for f in BANQUE[nom]:
			if not _flux.has(f):
				var p: String = DIR + String(f) + (".wav" if ResourceLoader.exists(DIR + String(f) + ".wav") else ".ogg")
				_flux[f] = load(p)
