extends Control
class_name Hud

var hero: Hero
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var buttons := {}   # name -> [center, radius, label]
var log_text := ""
var log_t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var s := get_viewport_rect().size
	buttons = {
		"attack": [Vector2(s.x - 110, s.y - 110), 55.0, "Удар"],
		"nova": [Vector2(s.x - 250, s.y - 70), 40.0, "Вспышка"],
		"dash": [Vector2(s.x - 90, s.y - 250), 40.0, "Рывок"],
		"heal": [Vector2(s.x - 220, s.y - 190), 40.0, "Лечение"],
	}

func say(t: String) -> void:
	log_text = t
	log_t = 3.0

func _process(delta: float) -> void:
	log_t = maxf(0.0, log_t - delta)
	if hero and stick_id != -1:
		var d := stick_pos - stick_origin
		hero.move_input = (d / 70.0).limit_length(1.0)
	elif hero:
		hero.move_input = Vector2.ZERO
	queue_redraw()

func _input(event: InputEvent) -> void:
	var s := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			for n in buttons:
				if p.distance_to(buttons[n][0]) < buttons[n][1] + 12:
					hero.use_skill(n)
					return
			if p.x < s.x * 0.5 and stick_id == -1:
				stick_id = event.index
				stick_origin = p
				stick_pos = p
		elif event.index == stick_id:
			stick_id = -1
	elif event is InputEventScreenDrag and event.index == stick_id:
		stick_pos = event.position
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: hero.use_skill("attack")
			KEY_Q: hero.use_skill("nova")
			KEY_E: hero.use_skill("dash")
			KEY_R: hero.use_skill("heal")

func _draw() -> void:
	if hero == null:
		return
	var s := get_viewport_rect().size
	var f := ThemeDB.fallback_font
	# HP bar
	draw_rect(Rect2(20, 20, 260, 22), Color(0.2, 0, 0))
	draw_rect(Rect2(20, 20, 260.0 * hero.hp / hero.max_hp, 22), Color(0.8, 0.1, 0.1))
	draw_string(f, Vector2(24, 38), "HP %d/%d" % [hero.hp, hero.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(f, Vector2(20, 66), "Уровень %d   Урон %d" % [hero.level, hero.damage], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if log_t > 0.0:
		draw_string(f, Vector2(20, 96), log_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.85, 0.3))
	# Skill buttons
	for n in buttons:
		var b = buttons[n]
		var ready: bool = hero.cd[n] <= 0.0
		draw_circle(b[0], b[1], Color(0.1, 0.1, 0.1, 0.6) if ready else Color(0.3, 0.1, 0.1, 0.6))
		draw_arc(b[0], b[1], 0, TAU, 32, Color(0.9, 0.7, 0.3), 3)
		draw_string(f, b[0] + Vector2(-b[1] * 0.8, 6), b[2], HORIZONTAL_ALIGNMENT_CENTER, b[1] * 1.6, 14)
	# Joystick
	if stick_id != -1:
		draw_circle(stick_origin, 70, Color(1, 1, 1, 0.12))
		draw_circle(stick_origin + (stick_pos - stick_origin).limit_length(70), 28, Color(1, 1, 1, 0.35))
