## Interface tactile : joystick (gauche), caméra (glisser à droite), boutons
## d'action, horloge, bouton « Parler » près d'un habitant, fenêtre de dialogue.
extends Control

var player: Node
var life: Node
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var look_id := -1
var look_last := Vector2.ZERO
const RADIUS := 110.0
var buttons := {}            # nom -> [centre, rayon, texte]
var clock: Label
var toast: Label
var toast_t := 0.0
var dialog: PanelContainer
var dialog_text: Label
var talk_target = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock = Label.new(); add_child(clock)
	clock.add_theme_font_size_override("font_size", 26)
	clock.add_theme_color_override("font_outline_color", Color.BLACK); clock.add_theme_constant_override("outline_size", 6)
	toast = Label.new(); add_child(toast)
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_outline_color", Color.BLACK); toast.add_theme_constant_override("outline_size", 6)
	dialog = PanelContainer.new(); add_child(dialog); dialog.visible = false
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.06, 0.08, 0.86); sb.set_corner_radius_all(14)
	sb.content_margin_left = 22; sb.content_margin_right = 22; sb.content_margin_top = 16; sb.content_margin_bottom = 16
	sb.border_color = Color(0.85, 0.7, 0.4, 0.8); sb.set_border_width_all(2)
	dialog.add_theme_stylebox_override("panel", sb)
	dialog_text = Label.new(); dialog.add_child(dialog_text)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.add_theme_font_size_override("font_size", 24)
	player.action_text.connect(func(t): show_toast(t))

func show_toast(t: String) -> void:
	toast.text = t; toast_t = 2.5

func _layout() -> void:
	var w := get_viewport_rect().size
	buttons = {
		"attaque": [Vector2(w.x - 150, w.y - 150), 78, "ATTAQUE"],
		"lourd": [Vector2(w.x - 300, w.y - 110), 56, "LOURD"],
		"saut": [Vector2(w.x - 130, w.y - 330), 60, "SAUT"],
		"esquive": [Vector2(w.x - 280, w.y - 250), 56, "ESQUIVE"],
		"arme": [Vector2(w.x - 70, w.y - 470), 44, "ARME"],
		"emote": [Vector2(w.x - 180, w.y - 470), 44, "ÉMOTE"],
	}
	if talk_target != null: buttons["parler"] = [Vector2(w.x * 0.5, w.y - 120), 64, "PARLER"]
	clock.position = Vector2(w.x - 240, 14)
	toast.position = Vector2(w.x * 0.5 - 120, 70)
	dialog.position = Vector2(w.x * 0.18, w.y * 0.58)
	dialog.size = Vector2(w.x * 0.64, 0)
	dialog_text.custom_minimum_size = Vector2(w.x * 0.6, 0)

func _process(dt: float) -> void:
	clock.text = life.clock_text()
	toast_t -= dt; toast.visible = toast_t > 0.0
	var n = life.nearest_npc(player.global_position, 3.2)
	if n != talk_target:
		talk_target = n
		if n == null: dialog.visible = false
	_layout()
	queue_redraw()

func _press(name: String) -> void:
	match name:
		"attaque": player.attack(false)
		"lourd": player.attack(true)
		"saut": player.request_jump()
		"esquive": player.dodge()
		"arme": player.next_style()
		"emote": player.emote()
		"parler":
			if talk_target != null:
				var r: Dictionary = life.talk(talk_target)
				dialog_text.text = "%s — %s\n\n« %s »" % [r.nom, r.role, r.texte]
				dialog.visible = true

func _hit(p: Vector2) -> String:
	for k in buttons:
		if p.distance_to(buttons[k][0]) < buttons[k][1] + 10: return k
	return ""

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var w := get_viewport_rect().size
		if e.pressed:
			var b := _hit(e.position)
			if b != "": _press(b); return
			if dialog.visible and Rect2(dialog.position, dialog.size).has_point(e.position): dialog.visible = false; return
			if e.position.x < w.x * 0.45 and stick_id == -1:
				stick_id = e.index; stick_origin = e.position; stick_pos = e.position
			elif look_id == -1:
				look_id = e.index; look_last = e.position
		else:
			if e.index == stick_id: stick_id = -1; player.move_input = Vector2.ZERO
			if e.index == look_id: look_id = -1
	elif e is InputEventScreenDrag:
		if e.index == stick_id:
			stick_pos = e.position
			var v: Vector2 = (stick_pos - stick_origin) / RADIUS
			if v.length() > 1.0: v = v.normalized()
			player.move_input = v
		elif e.index == look_id:
			player.look((e.position - look_last) * 1.25)
			look_last = e.position
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_F: _press("attaque")
			KEY_G: _press("lourd")
			KEY_C: _press("esquive")
			KEY_TAB: _press("arme")
			KEY_E: _press("parler")
			KEY_B: _press("emote")

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for k in buttons:
		var c: Vector2 = buttons[k][0]; var r: float = buttons[k][1]
		draw_circle(c, r, Color(0.05, 0.05, 0.07, 0.35) if k != "parler" else Color(0.75, 0.55, 0.2, 0.55))
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
		var txt: String = buttons[k][2]
		var fs := 22 if r > 50 else 17
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
	if stick_id != -1:
		draw_circle(stick_origin, RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(stick_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
		draw_circle(stick_origin + (stick_pos - stick_origin).limit_length(RADIUS), 46, Color(1, 1, 1, 0.5))
