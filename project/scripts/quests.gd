## Quêtes : nées des histoires des habitants (une agression, une vocation,
## un portail qui gronde sous la gare). Chaque quête avance selon ce que le
## joueur fait vraiment en ville ; l'état est mémorisé avec la vie de la ville.
extends Node

signal annonce(titre: String, texte: String)
var life: Node
var player: Node3D
var etat := {}                 # id -> {etape, compte, fini, echec}
var suivie := ""               # quête affichée à l'écran
var portail: Portail
var monstres: Array = []
var _t := 0.0
const GATE_POS := Vector3(-352.0, 0.0, 0.5)     # sur le parvis de la Gare de l'Ouest

const QUETES := {
	"lanternes": {"titre": "Le Passage des Lanternes", "etapes": [
		["Théo rentre par le Passage des Lanternes à 21 h. Rejoins-le avant.", "lieu", "passage_lanternes"],
		["Protège Théo des voyous.", "lieu", "passage_lanternes"],
		["Parle à Théo.", "pnj", "theo"]]},
	"hugo": {"titre": "La vocation de Hugo", "etapes": [
		["Rejoins Hugo au coin d'entraînement de la place (17 h 30 – 20 h).", "lieu", "entrainement"],
		["Entraîne-toi aux côtés de Hugo : %d / 12 coups.", "pnj", "hugo"],
		["Parle à Hugo.", "pnj", "hugo"]]},
	"gare": {"titre": "Ce qui vibre sous la gare", "etapes": [
		["Retrouve Marc devant la Gare de l'Ouest, à la nuit tombée (après 21 h).", "pos", GATE_POS],
		["Approche-toi du portail.", "pos", GATE_POS],
		["Le portail s'est brisé ! Élimine les monstres : %d / 3.", "monstres", null],
		["Abats la Brute de lave, maîtresse du portail.", "monstres", null],
		["Parle à Marc.", "pnj", "marc"]]},
}

func setup(p_life: Node, p_player: Node3D) -> void:
	life = p_life; player = p_player
	etat = life.mem.get("_quetes", {})
	life.mem["_quetes"] = etat
	life.parle.connect(_on_parle)
	player.coup.connect(_on_coup)
	for id in etat:
		if not etat[id].fini and not etat[id].get("echec", false): suivie = id
	# les destins déjà accomplis restent visibles
	if "chasseur novice" in life.mem.hugo.souvenirs: life.npcs.hugo.devient_chasseur()

func donne(id: String, message := "") -> void:
	if etat.has(id): return
	etat[id] = {"etape": 0, "compte": 0, "fini": false, "echec": false}
	suivie = id
	annonce.emit("Nouvelle quête : " + QUETES[id].titre, message if message != "" else texte(id))
	life._save()

func texte(id: String) -> String:
	var e: Dictionary = etat[id]
	if e.fini: return "Terminée."
	if e.get("echec", false): return "Échouée."
	var s: String = QUETES[id].etapes[int(e.etape)][0]
	return s % e.compte if "%d" in s else s

func avance(id: String, message := "") -> void:
	var e: Dictionary = etat[id]
	e.etape = int(e.etape) + 1; e.compte = 0
	if e.etape >= QUETES[id].etapes.size():
		e.fini = true
		annonce.emit("Quête terminée : " + QUETES[id].titre, message)
		suivie = ""
		for k in etat:
			if not etat[k].fini and not etat[k].get("echec", false): suivie = k
	else:
		suivie = id
		annonce.emit(QUETES[id].titre, message if message != "" else texte(id))
	life._save()

## position de l'objectif de la quête suivie (pour le marqueur et la flèche)
func objectif() -> Variant:
	if suivie == "" or not etat.has(suivie): return null
	var e: Dictionary = etat[suivie]
	if e.fini or e.get("echec", false): return null
	var st: Array = QUETES[suivie].etapes[int(e.etape)]
	match st[1]:
		"lieu": return life._place_pos(st[2])
		"pos": return st[2]
		"pnj":
			var n: Npc = life.npcs[st[2]]
			return null if n.hidden_inside else n.global_position
		"monstres":
			var best = null; var bd := 1e9
			for m in monstres:
				if is_instance_valid(m) and m.vivant:
					var d: float = m.global_position.distance_to(player.global_position)
					if d < bd: bd = d; best = m.global_position
			return best
	return null

## répliques spéciales des habitants selon l'avancée des quêtes
func replique(id: String) -> String:
	match id:
		"marc":
			if etat.has("gare") and etat.gare.fini: return "Un rang E qui se bat comme un rang B… Je n'avais pas vu ça depuis vingt ans. Ton aura a changé, petit. Fais attention à qui la remarque."
		"hugo":
			if etat.has("hugo") and etat.hugo.etape == 1: return "Allez, frappe avec moi ! Encore ! Je sens quelque chose… comme un courant sous la peau."
		"theo":
			if etat.has("lanternes") and etat.lanternes.get("echec", false): return "Ne me regardez pas comme ça. Vous n'étiez pas là, c'est tout. Personne n'est jamais là."
	return ""

func _on_parle(id: String) -> void:
	match id:
		"hugo":
			if not etat.has("hugo") and not life.npcs.hugo.chasseur:
				donne("hugo", "Hugo rêve de devenir chasseur. Entraîne-toi avec lui ce soir sur la place.")
			elif etat.has("hugo") and etat.hugo.etape == 2: avance("hugo", "Hugo s'est éveillé. Il combattra désormais à tes côtés quand un portail se brisera.")
		"marc":
			if not etat.has("gare"): donne("gare", "Marc, ancien chasseur de rang B, sent un portail se former sous la gare. Rejoins-le cette nuit.")
			elif etat.gare.etape == 4: avance("gare", "Niveau supérieur ! Points de vie max +20.")
		"theo":
			if etat.has("lanternes") and etat.lanternes.etape == 2: avance("lanternes", "Théo te doit la vie. Son café sera toujours offert.")
		"nadia", "chloe":
			if not etat.has("lanternes") and life.hour() >= 15.0: donne("lanternes")

func _on_coup(_style: String) -> void:
	if etat.has("hugo") and etat.hugo.etape == 1 and not etat.hugo.fini:
		var h: Npc = life.npcs.hugo
		if h.place == "entrainement" and h.global_position.distance_to(player.global_position) < 7.0:
			etat.hugo.compte += 1
			if etat.hugo.compte >= 12: _eveil_hugo()

func _eveil_hugo() -> void:
	var h: Npc = life.npcs.hugo
	h.react("Celebration", 3.0, player.global_position)
	Fx.spawn(get_parent(), "Electric", "Radial_02", Transform3D(Basis(), h.global_position), 0.5, 3.0)
	Fx.flash(get_parent(), h.global_position + Vector3(0, 1.2, 0), Color(0.45, 0.7, 1.0), 8.0, 12.0, 1.2)
	h.devient_chasseur()
	if not "chasseur novice" in life.mem.hugo.souvenirs: life.mem.hugo.souvenirs.append("chasseur novice")
	life._note("Hugo s'est éveillé pendant l'entraînement : chasseur de rang E.")
	avance("hugo", "Une lumière bleue enveloppe Hugo… Il vient de s'éveiller !")

func _process(dt: float) -> void:
	_t += dt
	if _t < 0.2: return
	var step := _t; _t = 0.0
	var h: float = life.hour()
	var pp := player.global_position
	# la rumeur du soir : Chloé prévient le joueur
	if not etat.has("lanternes") and h >= 19.5 and h < 20.9:
		donne("lanternes", "Message de Chloé : « La bande du Balafré traîne dans le Passage des Lanternes. Théo rentre par là à 21 h… »")
	for id in etat.keys():
		var e: Dictionary = etat[id]
		if e.fini or e.get("echec", false): continue
		match id:
			"lanternes": _lanternes(e)
			"hugo":
				if e.etape == 0:
					var hu: Npc = life.npcs.hugo
					if hu.place == "entrainement" and hu.arrived() and hu.global_position.distance_to(pp) < 7.0:
						avance("hugo", "Frappe aux côtés de Hugo pour l'entraîner (attaque près de lui).")
			"gare": _gare(e, h, pp, step)

func _lanternes(e: Dictionary) -> void:
	var s: Array = life.mem.theo.souvenirs
	if e.etape <= 1 and "sauvé par le joueur" in s:
		e.etape = 1; avance("lanternes", "Les voyous ont fui. Va voir si Théo va bien.")
	elif e.etape <= 1 and "agressé dans le passage" in s:
		e.echec = true; suivie = ""
		annonce.emit("Quête échouée : " + QUETES.lanternes.titre, "Théo a été agressé. Tu n'étais pas là.")
		life._save()
	elif e.etape == 0 and not life.agression.is_empty() and life.agression.get("etat", "") in ["attente", "menace"] \
			and player.global_position.distance_to(life._place_pos("passage_lanternes")) < 40.0:
		avance("lanternes")

func _gare(e: Dictionary, h: float, pp: Vector3, _dt: float) -> void:
	var nuit := h >= 21.0 or h < 4.5
	match int(e.etape):
		0:
			if nuit and pp.distance_to(GATE_POS) < 26.0:
				_ouvre_portail(); avance("gare", "Un portail de rang E s'ouvre devant la gare !")
		1:
			if portail == null: _ouvre_portail()
			if pp.distance_to(GATE_POS) < 9.0 and portail.etat == "stable":
				portail.destabilise()
				annonce.emit(QUETES.gare.titre, "Le portail devient instable… il va se briser !")
		2:
			var morts := 0
			for m in monstres:
				if not is_instance_valid(m) or not m.vivant: morts += 1
			if monstres.size() >= 3: e.compte = morts
			if monstres.size() >= 3 and morts >= 3:
				avance("gare", "Le sol tremble… la maîtresse du portail sort à son tour !")
				_spawn("brute", GATE_POS + Vector3(0, 0, 0), 0.0)
		3:
			var reste := false
			for m in monstres:
				if is_instance_valid(m) and m.vivant: reste = true
			if not reste and monstres.size() >= 4:
				for n in life.npcs.values():
					if n.combat: n.entre_en_combat(false)
				player.pv_max += 20.0; player.pv = player.pv_max
				avance("gare", "Le portail est vaincu. Marc t'attend.")

func _ouvre_portail() -> void:
	if portail: return
	portail = Portail.new()
	get_parent().add_child(portail)
	portail.global_position = GATE_POS
	portail.rotation.y = PI / 2.0
	portail.brise.connect(_brise)
	var marc: Npc = life.npcs.marc
	if not marc.hidden_inside: marc.react("Surprise", 3.0, GATE_POS)

func _brise() -> void:
	avance("gare")
	for i in 3:
		_spawn("rodeur", GATE_POS + Vector3(2.5, 0, -2.5 + 2.5 * i), 0.35 * i)
	# Hugo, s'il s'est éveillé, accourt
	var hu: Npc = life.npcs.hugo
	if hu.chasseur:
		hu.path = PackedVector3Array(); hu.path_i = 0
		hu.hidden_inside = false; hu.visible = true
		hu.global_position = player.global_position + Vector3(10, 0, 6)
		hu.entre_en_combat(true)
		annonce.emit("Hugo", "« J'ai vu la lumière depuis la place ! Je suis avec toi ! »")

func _spawn(type: String, pos: Vector3, delai: float) -> void:
	if delai > 0.0: await get_tree().create_timer(delai).timeout
	var m := Monstre.new()
	get_parent().add_child(m)
	m.setup(type)
	m.global_position = pos
	m.model.rotation.y = PI / 2.0
	monstres.append(m)
	Fx.spawn(get_parent(), "Dark", "Radial_01", Transform3D(Basis(), pos), 0.35, 2.0)
