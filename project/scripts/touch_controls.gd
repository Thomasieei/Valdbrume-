## Commandes tactiles : joystick flottant (moitié gauche), glisser pour tourner
## la caméra (moitié droite), bouton de saut. Fonctionne aussi à la souris.
extends Control

var player: Node
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var look_id := -1
var look_last := Vector2.ZERO
const RADIUS := 110.0
var jump_rect := Rect2()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var w := get_viewport_rect().size
		jump_rect = Rect2(w.x - 230, w.y - 230, 170, 170)
		if e.pressed:
			if jump_rect.has_point(e.position):
				player.request_jump()
			elif e.position.x < w.x * 0.45 and stick_id == -1:
				stick_id = e.index; stick_origin = e.position; stick_pos = e.position
			elif look_id == -1:
				look_id = e.index; look_last = e.position
		else:
			if e.index == stick_id:
				stick_id = -1; player.move_input = Vector2.ZERO
			if e.index == look_id: look_id = -1
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == stick_id:
			stick_pos = e.position
			var v: Vector2 = (stick_pos - stick_origin) / RADIUS
			if v.length() > 1.0: v = v.normalized()
			player.move_input = v
			queue_redraw()
		elif e.index == look_id:
			player.look((e.position - look_last) * 1.25)
			look_last = e.position

func _draw() -> void:
	var w := get_viewport_rect().size
	jump_rect = Rect2(w.x - 230, w.y - 230, 170, 170)
	draw_circle(jump_rect.get_center(), 70, Color(1, 1, 1, 0.14))
	draw_arc(jump_rect.get_center(), 70, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
	draw_string(ThemeDB.fallback_font, jump_rect.get_center() + Vector2(-34, 9), "SAUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.85))
	if stick_id != -1:
		draw_circle(stick_origin, RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(stick_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
		var k := (stick_pos - stick_origin).limit_length(RADIUS)
		draw_circle(stick_origin + k, 46, Color(1, 1, 1, 0.5))
