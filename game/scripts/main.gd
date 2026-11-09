extends Node2D

const RARITY := [
	["Обычный", Color(0.8, 0.8, 0.8), 1.0],
	["Магический", Color(0.3, 0.5, 1.0), 1.5],
	["Редкий", Color(1.0, 0.85, 0.2), 2.2],
	["Легендарный", Color(1.0, 0.45, 0.1), 3.5],
]

var hero: Hero
var hud: Hud
var loot: Array = []
var spawn_t := 0.0
var wave := 0

func _ready() -> void:
	randomize()
	hero = Hero.new()
	add_child(hero)
	var cam := Camera2D.new()
	hero.add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.hero = hero
	layer.add_child(hud)
	hero.leveled.connect(func(): hud.say("Новый уровень: %d" % hero.level))
	hero.hp_changed.connect(_check_death)
	hud.say("Ночь над Пепельной Долиной. Выживи.")

func _check_death() -> void:
	if hero.hp <= 0.0:
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	spawn_t -= delta
	if spawn_t <= 0.0 and get_tree().get_nodes_in_group("enemies").size() < 12 + hero.level * 2:
		spawn_t = 1.6
		wave += 1
		var e := Enemy.new()
		e.setup(hero, hero.level)
		var a := randf() * TAU
		e.global_position = hero.global_position + Vector2.from_angle(a) * 520.0
		add_child(e)
	for i in range(loot.size() - 1, -1, -1):
		var it = loot[i]
		if it.pos.distance_to(hero.global_position) < 34.0:
			var r = RARITY[it.rarity]
			hero.damage += 1.0 * r[2]
			hero.max_hp += 2.0 * r[2]
			hud.say("%s предмет: +урон" % r[0])
			loot.remove_at(i)
	queue_redraw()

func spawn_loot(pos: Vector2) -> void:
	if randf() > 0.45:
		return
	var roll := randf()
	var rarity := 0
	if roll > 0.97: rarity = 3
	elif roll > 0.85: rarity = 2
	elif roll > 0.55: rarity = 1
	loot.append({"pos": pos, "rarity": rarity})

func _draw() -> void:
	var c := hero.global_position if hero else Vector2.ZERO
	for x in range(-1000, 1001, 100):
		var gx := floorf((c.x + x) / 100.0) * 100.0
		draw_line(Vector2(gx, c.y - 1000), Vector2(gx, c.y + 1000), Color(0.15, 0.15, 0.18))
	for y in range(-1000, 1001, 100):
		var gy := floorf((c.y + y) / 100.0) * 100.0
		draw_line(Vector2(c.x - 1000, gy), Vector2(c.x + 1000, gy), Color(0.15, 0.15, 0.18))
	for it in loot:
		var col: Color = RARITY[it.rarity][1]
		draw_colored_polygon(PackedVector2Array([
			it.pos + Vector2(0, -10), it.pos + Vector2(8, 0),
			it.pos + Vector2(0, 10), it.pos + Vector2(-8, 0)]), col)
