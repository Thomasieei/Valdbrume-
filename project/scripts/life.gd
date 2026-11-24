## La vie de la ville : horloge, emplois du temps des 10 habitants, rencontres,
## relations, mémoire de ce que le joueur a fait, événements qui changent leur
## destin (agression, amour, vocation de chasseur, demande d'aide).
extends Node

signal changed
const SAVE := "user://vie.json"
var minutes_per_second := 1.0          # 1 journée = 24 minutes réelles
var day := 1
var minute := 7 * 60 + 30
var astar := AStar3D.new()
var places := {}
var npcs := {}
var player: Node3D
var mem := {}                          # mémoire de chaque habitant
var log_lines: Array[String] = []
var thugs: Array = []
var agression := {}                    # état de l'événement du soir

# ------------------------------------------------------------ emplois du temps
# [heure de début, lieu, animation sur place, vitesse de marche]
const SCHED := {
	"lea": [[5.0, "boulangerie", "Counter_Idle_Loop", 1.3], [13.0, "fleuriste", "Idle_Talking_Loop", 1.25], [14.0, "banc_place_s", "Sitting_Idle_Loop", 1.25], [16.5, "dom_lea", "", 1.3]],
	"hugo": [[7.5, "boulangerie", "Idle_Talking_Loop", 3.6], [8.5, "pharmacie", "Interact", 3.6], [9.5, "garage", "Idle_Talking_Loop", 3.6], [10.5, "tour", "Interact", 3.6], [11.5, "redaction", "Interact", 3.6], [12.5, "cafe", "Idle_Loop", 3.6], [14.0, "gare", "Interact", 3.6], [15.5, "boulangerie", "Idle_Talking_Loop", 3.6], [17.5, "entrainement", "@entrainement", 3.6], [20.0, "dom_hugo", "", 3.0]],
	"ines": [[7.5, "pharmacie", "Counter_Idle_Loop", 1.35], [18.5, "banc_place_n", "Sitting_Idle02_Loop", 1.3], [20.0, "dom_ines", "", 1.35]],
	"marc": [[13.0, "cafe", "Idle_Tired_Loop", 1.05], [15.0, "banc_place_n", "Sitting_Nodding_Loop", 1.05], [20.5, "gare", "Idle_FoldArms_Loop", 1.1], [6.5, "dom_marc", "", 1.1]],
	"sofia": [[7.0, "fleuriste", "Counter_Idle_Loop", 1.3], [12.5, "cafe", "Idle_Talking_Loop", 1.3], [13.5, "fleuriste", "Counter_Idle_Loop", 1.3], [19.0, "banc_place_s", "Sitting_Talking_Loop", 1.2], [20.5, "dom_sofia", "", 1.3]],
	"karim": [[7.6, "fleuriste", "Idle_Talking_Loop", 1.4], [8.2, "garage", "Fixing_Kneeling", 1.4], [12.5, "cafe", "Idle_Loop", 1.4], [13.5, "garage", "Fixing_Kneeling", 1.4], [19.0, "banc_place_s", "Sitting_Talking_Loop", 1.3], [20.5, "dom_karim", "", 1.4]],
	"chloe": [[9.0, "redaction", "Idle_TalkingPhone_Loop", 1.5], [11.0, "commissariat", "Idle_Talking_Loop", 1.5], [12.5, "cafe", "Idle_Loop", 1.5], [14.0, "gare", "Idle_LookAround_Loop", 1.5], [16.0, "passage_lanternes", "Idle_LookAround_Loop", 1.5], [18.0, "redaction", "Idle_TalkingPhone_Loop", 1.5], [20.0, "dom_chloe", "", 1.5]],
	"theo": [[8.5, "cafe", "@service", 1.35], [21.0, "dom_theo", "", 1.35]],
	"nadia": [[8.0, "commissariat", "Idle_FoldArms_Loop", 1.4], [9.0, "@patrouille", "Idle_LookAround_Loop", 1.4], [17.0, "commissariat", "Idle_FoldArms_Loop", 1.4], [19.0, "dom_nadia", "", 1.4]],
	"victor": [[8.5, "tour", "Idle_TalkingPhone_Loop", 1.45], [12.5, "cafe", "Idle_Loop", 1.45], [14.0, "tour", "Idle_TalkingPhone_Loop", 1.45], [19.0, "dom_victor", "", 1.45]],
}
const PATROL := ["cafe", "fleuriste", "entrainement", "pharmacie", "commissariat", "banc_place_n"]
# relations : qui se connaît, et comment
const LIENS := {
	"lea-hugo": "amis", "lea-sofia": "amies", "karim-sofia": "attirance", "chloe-nadia": "source",
	"theo-victor": "client", "hugo-marc": "mentor", "ines-marc": "soins", "lea-theo": "voisins",
	"chloe-marc": "source", "ines-sofia": "amies", "hugo-karim": "amis", "nadia-victor": "méfiance",
}

func _ready() -> void:
	_load()

func setup(city_meta: Dictionary, p_player: Node3D) -> void:
	player = p_player
	var nav: Dictionary = city_meta.nav
	for i in nav.nodes.size():
		var n: Array = nav.nodes[i]
		astar.add_point(i, Vector3(n[0], n[1], n[2]))
	for e in nav.edges: astar.connect_points(int(e[0]), int(e[1]))
	places = nav.places
	for id in SCHED.keys():
		var n := Npc.new()
		n.name = id
		get_parent().add_child(n)
		n.setup(id, self, _place_pos(_current_entry(id)[1]))
		npcs[id] = n
		if not mem.has(id): mem[id] = {"rencontre": false, "discussions": 0, "relation": 0, "souvenirs": []}
	warp()

# ------------------------------------------------------------ horloge
func hour() -> float: return float(minute) / 60.0

func clock_text() -> String:
	var jours := ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
	return "%s %02d:%02d" % [jours[(day - 1) % 7], minute / 60, minute % 60]

var _acc := 0.0
func _process(dt: float) -> void:
	_acc += dt * minutes_per_second
	while _acc >= 1.0:
		_acc -= 1.0
		minute += 1
		if minute >= 24 * 60: minute = 0; day += 1; _new_day()
		_tick_minute()
	_social(dt)
	_tick_agression(dt)

func _current_entry(id: String) -> Array:
	var s: Array = SCHED[id]
	var h := hour()
	var best: Array = s[s.size() - 1]
	var best_h := -1.0
	for e in s:
		var eh: float = e[0]
		if eh <= h and eh > best_h: best = e; best_h = eh
	if best_h < 0.0:   # avant la première entrée du jour : la dernière de la veille
		var mx := -1.0
		for e in s:
			if e[0] > mx: mx = e[0]; best = e
	return best

func _place_pos(p: String) -> Vector3:
	if p == "@patrouille": p = PATROL[(minute / 20) % PATROL.size()]
	var d: Dictionary = places[p]
	return Vector3(d.pos[0], d.pos[1], d.pos[2])

var _last_entry := {}
func _tick_minute() -> void:
	for id in npcs:
		var e := _current_entry(id)
		var key := str(e[0]) + str(e[1])
		if e[1] == "@patrouille": key += str((minute / 20) % PATROL.size())
		if _last_entry.get(id, "") != key:
			_last_entry[id] = key
			_send(id, e)
		var n: Npc = npcs[id]
		if n.activity.get("anim", "") == "@entrainement" and n.arrived() and n.busy_t <= 0.0 and minute % 2 == 0:
			n.react(["Punch_Jab", "Punch_Cross", "Kick", "Melee_Hook", "Melee_Uppercut"][randi() % 5], 1.2)
		if n.activity.get("anim", "") == "@service" and n.arrived() and n.busy_t <= 0.0 and minute % 3 == 0:
			n.react(["Interact", "Counter_Give", "Idle_Talking_Loop"][randi() % 3], 2.0)
	if minute % 60 == 0: _save()
	if minute == 21 * 60: _start_agression()
	changed.emit()

func _send(id: String, e: Array) -> void:
	var n: Npc = npcs[id]
	var dest: String = e[1]
	if dest == "@patrouille": dest = PATROL[(minute / 20) % PATROL.size()]
	var from := astar.get_closest_point(n.global_position)
	var to: int = places[dest].node
	var p := astar.get_point_path(from, to)
	p.append(_place_pos(dest))
	n.activity = {"anim": e[2], "lieu": dest}
	n.place = dest
	n.go_to(p, float(e[3]))

func npc_arrived(n: Npc) -> void:
	var at: Dictionary = places[n.place]
	var a := String(n.activity.get("anim", ""))
	var shown := a if not a.begins_with("@") else ("Idle_Loop" if a == "@service" else "Sword_Idle")
	n.do_activity({"anim": shown, "lieu": n.place}, at)
	if a == "": n.do_activity({"anim": ""}, at)

## place chaque habitant directement à l'endroit où il doit être à cette heure
func warp() -> void:
	for id in npcs:
		var e := _current_entry(id)
		var n: Npc = npcs[id]
		var dest: String = e[1]
		if dest == "@patrouille": dest = PATROL[(minute / 20) % PATROL.size()]
		n.place = dest
		n.path = PackedVector3Array(); n.path_i = 0
		n.activity = {"anim": e[2], "lieu": dest}
		npc_arrived(n)
		_last_entry[id] = str(e[0]) + str(e[1]) + (str((minute / 20) % PATROL.size()) if e[1] == "@patrouille" else "")

# ------------------------------------------------------------ rencontres
var _social_t := 0.0
func _social(dt: float) -> void:
	_social_t += dt
	if _social_t < 0.5: return
	_social_t = 0.0
	var ids := npcs.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Npc = npcs[ids[i]]; var b: Npc = npcs[ids[j]]
			if a.hidden_inside or b.hidden_inside or a.busy_t > 0 or b.busy_t > 0: continue
			if a.talk_cd > 0 or b.talk_cd > 0: continue
			if a.arrived() and b.arrived(): continue
			var lien := _lien(ids[i], ids[j])
			if lien == "": continue
			if a.global_position.distance_to(b.global_position) < 2.2:
				a.react("Idle_Talking_Loop", 5.0, b.global_position); b.react("Idle_Talking_Loop", 5.0, a.global_position)
				a.talk_cd = 60.0; b.talk_cd = 60.0
				_note("%s et %s discutent (%s)." % [a.vis.data.nom, b.vis.data.nom, lien])

func _lien(a: String, b: String) -> String:
	return LIENS.get(a + "-" + b, LIENS.get(b + "-" + a, ""))

func _note(t: String) -> void:
	log_lines.append("[%s] %s" % [clock_text(), t])
	if log_lines.size() > 40: log_lines.pop_front()

# ------------------------------------------------------------ événements
func _new_day() -> void:
	# amour : chaque matin Karim passe voir Sofia ; au 3e jour, ils se donnent rendez-vous
	var m: Dictionary = mem.sofia
	if not "amoureuse de Karim" in m.souvenirs:
		m.relation_karim = int(m.get("relation_karim", 0)) + 1
		if m.relation_karim >= 3:
			m.souvenirs.append("amoureuse de Karim"); mem.karim.souvenirs.append("amoureux de Sofia")
			_note("Sofia et Karim sont ensemble.")
	# vocation : Hugo s'entraîne chaque soir ; au bout de 5 jours il passe l'examen de chasseur
	var h: Dictionary = mem.hugo
	h.entrainements = int(h.get("entrainements", 0)) + 1
	if h.entrainements >= 5 and not "chasseur novice" in h.souvenirs:
		h.souvenirs.append("chasseur novice"); _note("Hugo a réussi l'examen de chasseur (rang E).")
	_save()

func _start_agression() -> void:
	if agression.get("jour", -1) == day: return
	agression = {"jour": day, "etat": "attente", "t": 0.0}
	if thugs.is_empty():
		for tid in ["voyou1", "voyou2"]:
			var t := Node3D.new()
			var v := CharacterVisual.new(); t.add_child(v); v.setup(tid)
			get_parent().add_child(t)
			thugs.append(t)
	var base := _place_pos("passage_lanternes")
	for i in thugs.size():
		thugs[i].visible = true
		thugs[i].position = base + Vector3(-1.2 + 2.4 * i, 0, -3.0)
		thugs[i].get_child(0).play("Idle_FoldArms_Loop", 0.0)

func _tick_agression(dt: float) -> void:
	if agression.is_empty() or agression.etat == "fini": return
	agression.t += dt
	var theo: Npc = npcs.theo
	var spot := _place_pos("passage_lanternes")
	var near_player := player != null and player.global_position.distance_to(spot) < 30.0
	match agression.etat:
		"attente":
			if not theo.hidden_inside and theo.global_position.distance_to(spot) < 7.0:
				agression.etat = "menace"; agression.t = 0.0
				theo.path_i = theo.path.size()     # il s'arrête
				theo.react("Surprise", 3.0, thugs[0].global_position)
				for t in thugs: t.get_child(0).play("Idle_No_Loop", 0.2)
				_note("Deux voyous coincent Théo dans le Passage des Lanternes.")
			elif minute > 22 * 60: agression.etat = "fini"
		"menace":
			for t in thugs:
				var to: Vector3 = theo.global_position - t.global_position
				if to.length() > 1.4: t.position += Vector3(to.x, 0, to.z).normalized() * 1.2 * dt; t.get_child(0).play("Walk_Loop", 0.2)
				t.get_child(0).rotation.y = atan2(to.x, to.z)
			if near_player:
				agression.etat = "fuite"; agression.t = 0.0
				for t in thugs: t.get_child(0).play("Sprint_Loop", 0.15)
				theo.react("Idle_Tired_Loop", 4.0, player.global_position)
				_souvenir("theo", "sauvé par le joueur", 3)
				_note("Les voyous s'enfuient en vous voyant arriver. Théo est sauf.")
			elif agression.t > 4.0 and agression.t < 4.1:
				thugs[0].get_child(0).play("Punch_Cross", 0.1, 1.0, true)
				theo.react("Hit_Stomach", 1.5)
			elif agression.t > 9.0:
				agression.etat = "fuite"; agression.t = 0.0
				for t in thugs: t.get_child(0).play("Jog_Fwd_Loop", 0.2)
				theo.react("Crying", 6.0)
				_souvenir("theo", "agressé dans le passage", -1)
				mem.theo.souvenirs.append("veut apprendre à se défendre")
				_note("Théo a été agressé. Personne n'est venu l'aider.")
		"fuite":
			for t in thugs:
				t.position += Vector3(0, 0, -1) * 6.0 * dt
				t.get_child(0).rotation.y = PI
			if agression.t > 8.0:
				for t in thugs: t.visible = false
				agression.etat = "fini"
				var e := _current_entry("theo"); _send("theo", e)

func _souvenir(id: String, s: String, rel: int) -> void:
	var m: Dictionary = mem[id]
	if not s in m.souvenirs: m.souvenirs.append(s)
	m.relation = clamp(int(m.relation) + rel, -5, 5)
	_save()

# ------------------------------------------------------------ dialogues
func nearest_npc(pos: Vector3, max_d := 3.0) -> Npc:
	var best: Npc = null; var bd := max_d
	for id in npcs:
		var n: Npc = npcs[id]
		if n.hidden_inside: continue
		var d := n.global_position.distance_to(pos)
		if d < bd: bd = d; best = n
	return best

func talk(n: Npc) -> Dictionary:
	var m: Dictionary = mem[n.id]
	var first := not m.rencontre
	m.rencontre = true; m.discussions = int(m.discussions) + 1
	n.react("Idle_Talking_Loop", 6.0, player.global_position if player else Vector3.ZERO)
	var h := hour()
	var t := ""
	var s: Array = m.souvenirs
	match n.id:
		"lea":
			t = "Bonjour ! Un chasseur, ici ? Tenez, un croissant, c'est la maison qui offre." if first else ("Vous repassez ? Le pain de 16 h est le meilleur." if h < 16 else "Je ferme, revenez demain à l'aube !")
		"hugo":
			if "chasseur novice" in s: t = "J'ai réussi l'examen ! Rang E, comme toi. On fait équipe pour un portail ?"
			else: t = "Pas le temps, j'ai trois livraisons ! … Dis, c'est vrai que tu es chasseur ? Tu m'apprendrais ?" if first else "Ce soir je m'entraîne sur la place. Viens voir si je progresse !"
		"ines":
			t = "Pharmacie du Portail, je vous écoute. Vous êtes blessé ? Ça arrive souvent aux chasseurs." if first else "Marc boite de plus en plus. Il refuse de se faire soigner… vous pourriez lui parler ?"
		"marc":
			if h >= 20.5 or h < 6.5: t = "Tu entends ? Sous la gare, ça vibre la nuit. Un portail se forme. J'aurais besoin de toi, petit." ; _souvenir("marc", "a demandé de l'aide au joueur", 1)
			else: t = "J'étais rang B, autrefois. Maintenant je garde des quais vides. Reviens me voir cette nuit, à la gare."
		"sofia":
			t = ("Des fleurs pour quelqu'un ? … Karim ? Oh, ça se voit tant que ça ?" if "amoureuse de Karim" in s else "Bienvenue ! Les pivoines sont arrivées ce matin. Vous connaissez le mécanicien, Karim ?")
		"karim":
			t = ("Sofia et moi… c'est sérieux. Mais ces types de la bande me tournent autour. Je leur dois de l'argent." if "amoureux de Sofia" in s else "Le garage ouvre à 8 h. Si quelqu'un vous demande où je suis, vous ne m'avez pas vu, d'accord ?")
		"chloe":
			t = "Chloé Martin, journaliste. Les portails s'ouvrent toujours près de la Tour Valdbrume… et Lemaire en profite. Vous avez vu quelque chose ?"
		"theo":
			if "sauvé par le joueur" in s: t = "C'est vous… vous m'avez sauvé hier soir. Je ne l'oublierai jamais. Le café est pour moi, toujours."
			elif "agressé dans le passage" in s: t = "Je… je préfère ne pas en parler. Vous pourriez m'apprendre à me battre ?"
			else: t = "Bonjour ! Un café ? M. Lemaire est encore de mauvaise humeur aujourd'hui…"
		"nadia":
			t = "Lieutenante Kovač. Les chasseurs se croient au-dessus des lois. Pas dans ma ville." if first else "Si vous voyez la bande du Balafré dans le Vieux Quartier, appelez-moi."
		"victor":
			t = "Victor Lemaire, Valdbrume Gestion. Un chasseur de rang E ? Venez me voir quand vous serez quelqu'un."
	_save()
	return {"nom": n.vis.data.nom, "role": n.vis.data.role, "texte": t, "relation": m.relation}

# ------------------------------------------------------------ sauvegarde
func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"jour": day, "minute": minute, "memoire": mem}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if d is Dictionary:
		day = int(d.get("jour", 1)); minute = int(d.get("minute", minute)); mem = d.get("memoire", {})
