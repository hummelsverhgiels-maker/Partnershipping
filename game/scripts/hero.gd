extends CharacterBody2D
class_name Hero

signal hp_changed
signal leveled

var speed := 230.0
var max_hp := 120.0
var hp := 120.0
var damage := 12.0
var level := 1
var xp := 0
var move_input := Vector2.ZERO
var facing := Vector2.RIGHT
var swing := 0.0
var cd := {"attack": 0.0, "nova": 0.0, "dash": 0.0, "heal": 0.0}
const CD_MAX := {"attack": 0.35, "nova": 4.0, "dash": 3.0, "heal": 9.0}
var dash_t := 0.0

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14
	cs.shape = c
	add_child(cs)
	add_to_group("hero")

func _physics_process(delta: float) -> void:
	for k in cd:
		cd[k] = maxf(0.0, cd[k] - delta)
	swing = maxf(0.0, swing - delta)
	var v := move_input * speed
	if dash_t > 0.0:
		dash_t -= delta
		v = facing * speed * 3.2
	elif move_input.length() > 0.1:
		facing = move_input.normalized()
	velocity = v
	move_and_slide()
	queue_redraw()

func use_skill(name: String) -> void:
	if cd[name] > 0.0:
		return
	cd[name] = CD_MAX[name]
	match name:
		"attack":
			swing = 0.15
			for e in get_tree().get_nodes_in_group("enemies"):
				var to: Vector2 = e.global_position - global_position
				if to.length() < 80.0 and to.normalized().dot(facing) > 0.2:
					e.hurt(damage)
		"nova":
			swing = 0.3
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) < 150.0:
					e.hurt(damage * 2.2)
		"dash":
			dash_t = 0.18
		"heal":
			heal(max_hp * 0.4)

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	hp_changed.emit()

func hurt(amount: float) -> void:
	hp -= amount
	hp_changed.emit()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= level * 40:
		xp -= level * 40
		level += 1
		max_hp += 15.0
		hp = max_hp
		damage += 2.0
		leveled.emit()
	hp_changed.emit()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14, Color(0.75, 0.78, 0.85))
	draw_line(Vector2.ZERO, facing * 22, Color(0.9, 0.7, 0.3), 4)
	if swing > 0.0:
		draw_arc(Vector2.ZERO, 70, facing.angle() - 0.9, facing.angle() + 0.9, 16, Color(1, 1, 1, 0.8), 3)
