extends CharacterBody2D
class_name Enemy

var hp := 30.0
var speed := 90.0
var power := 6.0
var hit_cd := 0.0
var xp_value := 12
var hero: Hero
var hit_flash := 0.0

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12
	cs.shape = c
	add_child(cs)
	add_to_group("enemies")

func setup(h: Hero, tier: int) -> void:
	hero = h
	hp = 30.0 + tier * 12.0
	power = 6.0 + tier * 1.5
	speed = 85.0 + tier * 4.0
	xp_value = 12 + tier * 3

func _physics_process(delta: float) -> void:
	hit_cd = maxf(0.0, hit_cd - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	if not is_instance_valid(hero):
		return
	var to := hero.global_position - global_position
	if to.length() > 24.0:
		velocity = to.normalized() * speed
		move_and_slide()
	elif hit_cd <= 0.0:
		hit_cd = 0.8
		hero.hurt(power)
	queue_redraw()

func hurt(amount: float) -> void:
	hp -= amount
	hit_flash = 0.1
	if hp <= 0.0:
		hero.add_xp(xp_value)
		get_parent().spawn_loot(global_position)
		queue_free()

func _draw() -> void:
	var col := Color(0.8, 0.2, 0.2) if hit_flash <= 0.0 else Color.WHITE
	draw_circle(Vector2.ZERO, 12, col)
