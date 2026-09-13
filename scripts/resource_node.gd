extends Node2D

const MAX_CHARGES := 4
const TREE_TEXTURE := preload("res://assets/game/resources/tree.png")
const SHEEP_MOVE_TEXTURE := preload("res://assets/game/resources/sheep_move.png")
const SHEEP_IDLE_TEXTURE := preload("res://assets/game/resources/sheep_idle.png")
const GOLD_TEXTURE := preload("res://assets/game/resources/gold_mine.png")
const GOLD_DESTROYED := preload("res://assets/game/resources/gold_mine_destroyed.png")
const STONE_1 := preload("res://assets/game/resources/stone1.png")
const STONE_2 := preload("res://assets/game/resources/stone2.png")
const SHEEP_MOVE_SPEED := 26.0
const SHEEP_HIT_FLASH_DURATION := 0.22

var world: Node
var team := "blue"
var resource_type := "gold"
var charges := MAX_CHARGES
var sprite: Sprite2D
var pips: Array[ColorRect] = []
var animation_time := 0.0
var move_target := Vector2.ZERO
var move_wait := 0.0
var rng := RandomNumberGenerator.new()
var depleted := false
var sheep_under_attack := false
var hit_flash_time := 0.0
var replay_id := ""
var resource_variant := 0

func setup(controller: Node, owner_team: String, kind: String, spawn_position: Vector2, variant: int = 0) -> void:
	world = controller
	team = owner_team
	resource_type = kind
	resource_variant = variant
	position = spawn_position
	z_index = int(position.y / 10.0) + 10
	rng.seed = int(position.x * 37.0 + position.y * 19.0 + variant * 101)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	match resource_type:
		"gold":
			sprite.texture = GOLD_TEXTURE
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 128, 128)
			sprite.scale = Vector2(0.55, 0.55)
		"stone":
			sprite.texture = STONE_1 if variant % 2 == 0 else STONE_2
			sprite.scale = Vector2(0.82, 0.82)
		"wood":
			sprite.texture = TREE_TEXTURE
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 192, 192)
			sprite.scale = Vector2(0.42, 0.42)
		"meat":
			sprite.texture = SHEEP_IDLE_TEXTURE
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 128, 128)
			sprite.scale = Vector2(0.88, 0.88)
			move_target = position
	build_charge_pips()

func build_charge_pips() -> void:
	var holder := Control.new()
	holder.position = Vector2(-25, -47 if resource_type != "wood" else -70)
	holder.size = Vector2(50, 7)
	add_child(holder)
	for index in MAX_CHARGES:
		var pip := ColorRect.new()
		pip.position = Vector2(index * 13, 0)
		pip.size = Vector2(10, 6)
		pip.color = Color("f4d35e")
		holder.add_child(pip)
		pips.append(pip)

func _process(delta: float) -> void:
	if depleted:
		return
	animation_time += delta
	if resource_type == "meat":
		hit_flash_time = maxf(0.0, hit_flash_time - delta)
		sprite.modulate = Color(1.0, 0.28, 0.28, 1.0) if hit_flash_time > 0.0 else Color.WHITE
	if resource_type == "gold":
		var gold_frame := int(animation_time * 7.0) % 6
		sprite.region_rect = Rect2(gold_frame * 128, 0, 128, 128)
	elif resource_type == "wood":
		var tree_frame := int(animation_time * 5.0) % 6
		var tree_col := tree_frame if tree_frame < 4 else tree_frame - 4
		var tree_row := 0 if tree_frame < 4 else 1
		sprite.region_rect = Rect2(tree_col * 192, tree_row * 192, 192, 192)
	elif resource_type == "meat":
		var sheep_is_moving: bool = world != null and world.battle_started and not world.replay_mode and not sheep_under_attack
		sprite.texture = SHEEP_MOVE_TEXTURE if sheep_is_moving else SHEEP_IDLE_TEXTURE
		var sheep_frame_count := 4 if sheep_is_moving else 6
		var sheep_frame := int(animation_time * (8.0 if sheep_is_moving else 6.0)) % sheep_frame_count
		sprite.region_rect = Rect2(sheep_frame * 128, 0, 128, 128)
		if sheep_is_moving:
			update_sheep(delta)

func update_sheep(delta: float) -> void:
	move_wait -= delta
	if move_wait <= 0.0 or position.distance_to(move_target) < 5.0:
		move_wait = rng.randf_range(2.0, 5.0)
		var candidate := position + Vector2(rng.randf_range(-75.0, 75.0), rng.randf_range(-55.0, 55.0))
		candidate.x = clampf(candidate.x, 40.0, 680.0)
		if team == "red":
			candidate.y = clampf(candidate.y, 190.0, 545.0)
		else:
			candidate.y = clampf(candidate.y, 735.0, 1090.0)
		move_target = candidate
	var direction := position.direction_to(move_target)
	position += direction * SHEEP_MOVE_SPEED * delta
	if absf(direction.x) > 0.05:
		sprite.flip_h = direction.x < 0.0
	z_index = int(position.y / 10.0) + 10

func begin_harvest() -> void:
	# Freeze a sheep when the worker starts the knife wind-up, not only on
	# the later impact frame. This prevents attack/chase threshold jitter.
	if resource_type == "meat":
		sheep_under_attack = true
		move_target = position

func hit_resource() -> bool:
	if depleted or charges <= 0:
		return false
	if resource_type == "meat":
		sheep_under_attack = true
		move_target = position
		hit_flash_time = SHEEP_HIT_FLASH_DURATION
	if world != null:
		world.play_resource_hit_sfx(resource_type)
	charges -= 1
	if world != null and world.test_mode:
		print("RESOURCE_HIT team=", team, " kind=", resource_type, " remaining=", charges)
	for index in pips.size():
		pips[index].visible = index < charges
	if charges <= 0:
		deplete()
		return true
	return false

func deplete() -> void:
	depleted = true
	if world != null and world.test_mode:
		print("RESOURCE_DESTROYED team=", team, " kind=", resource_type)
	if resource_type == "gold":
		sprite.texture = GOLD_DESTROYED
		sprite.region_enabled = false
	elif resource_type == "wood":
		sprite.region_rect = Rect2(0, 384, 192, 192)
	else:
		sprite.modulate = Color(1, 1, 1, 0.45)
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
