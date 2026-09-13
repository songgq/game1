class_name ProjectileEngine
extends Node2D

const DEFAULT_SPEED := 640.0
const DEFAULT_RADIUS := 6.0
const UNIT_RADIUS := 18.0
const MAX_LIFETIME_TICKS := 600
const ARROW := preload("res://assets/game/units/archer/arrow.png")

var world: Node
var next_serial := 0
var simulation_tick := 0
var projectiles: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []

func setup(controller: Node) -> void:
	world = controller
	process_physics_priority = 50

func _physics_process(delta: float) -> void:
	if world == null or world.replay_mode or not world.battle_started or world.battle_finished:
		return
	simulation_tick += 1
	advance(delta)

func spawn_basic_attack(source: Node2D, intended_target: Node2D, damage: int, speed := DEFAULT_SPEED, radius := DEFAULT_RADIUS) -> String:
	return spawn_configured(source, intended_target, damage, {"speed":speed,"radius":radius,"range":source.attack_range,
		"blockedByObstacle":true,"blockedByEnemyUnit":true,"blockedByAllyUnit":false,"pierceEnemyUnit":false,"maxPierceCount":0}, "basic_attack")

func spawn_configured(source: Node2D, intended_target: Node2D, damage: int, config: Dictionary, source_kind := "skill") -> String:
	if not is_instance_valid(source) or not is_instance_valid(intended_target) or intended_target.dead:
		return ""
	var direction := source.global_position.direction_to(intended_target.global_position)
	if direction.is_zero_approx():
		return ""
	next_serial += 1
	var projectile_id := "p_%s_%06d" % [str(source.replay_id), next_serial]
	var sprite := Sprite2D.new()
	sprite.texture = ARROW
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 64, 64)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.55, 0.55)
	sprite.global_position = source.global_position
	sprite.rotation = direction.angle()
	sprite.z_index = 100
	add_child(sprite)
	var item: Dictionary = {
		"id": projectile_id, "source": source, "sourceUnitId": str(source.replay_id), "team": str(source.team),
		"intendedTargetId": str(intended_target.replay_id), "actualHitTargetId": null,
		"position": source.global_position, "direction": direction, "speed": float(config.get("speed", DEFAULT_SPEED)), "radius": float(config.get("radius", DEFAULT_RADIUS)),
		"remainingRange": float(config.get("range", source.attack_range)), "damage": damage, "spawnTick": simulation_tick,
		"ageTicks": 0, "sprite": sprite, "sourceKind":source_kind,
		"blockedByObstacle":bool(config.get("blockedByObstacle", true)), "blockedByEnemyUnit":bool(config.get("blockedByEnemyUnit", true)),
		"blockedByAllyUnit":bool(config.get("blockedByAllyUnit", false)), "pierceEnemyUnit":bool(config.get("pierceEnemyUnit", false)),
		"maxPierceCount":int(config.get("maxPierceCount", 0)), "hitCount":0, "hitUnitIds":[],
	}
	projectiles.append(item)
	_record("projectile_spawned", item)
	return projectile_id

func advance(delta: float) -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		if not is_instance_valid(projectile.get("source")):
			_finish(projectile, "source_invalid", null, projectile["position"])
			continue
		var distance := minf(float(projectile["speed"]) * delta, float(projectile["remainingRange"]))
		var start: Vector2 = projectile["position"]
		var finish := start + Vector2(projectile["direction"]) * distance
		var collision := first_collision(projectile, start, finish)
		if not collision.is_empty():
			var hit_position := start.lerp(finish, float(collision["t"]))
			if str(collision["kind"]) == "unit" and bool(projectile.get("pierceEnemyUnit", false)) and int(projectile.get("maxPierceCount", 0)) > 0:
				var hit_unit: Node2D = collision["object"]
				projectile["actualHitTargetId"] = str(hit_unit.replay_id)
				projectile["hitCount"] = int(projectile.get("hitCount", 0)) + 1
				projectile["hitUnitIds"].append(str(hit_unit.replay_id))
				world.queue_damage(projectile.get("source"), hit_unit, int(projectile["damage"]))
				projectile["position"] = hit_position + Vector2(projectile["direction"]) * 0.1
				projectile["remainingRange"] = float(projectile["remainingRange"]) - start.distance_to(projectile["position"])
				_record("projectile_hit", projectile, {"firstHitObjectId":str(hit_unit.replay_id),"pierced":true,"hitCount":projectile["hitCount"]})
				if int(projectile["hitCount"]) >= int(projectile["maxPierceCount"]):
					var used_sprite: Sprite2D = projectile.get("sprite")
					if is_instance_valid(used_sprite): used_sprite.queue_free()
				else: survivors.append(projectile)
				continue
			_finish(projectile, str(collision["kind"]), collision.get("object"), hit_position)
			continue
		projectile["position"] = finish
		projectile["remainingRange"] = float(projectile["remainingRange"]) - distance
		projectile["ageTicks"] = int(projectile["ageTicks"]) + 1
		var sprite: Sprite2D = projectile["sprite"]
		if is_instance_valid(sprite): sprite.global_position = finish
		if float(projectile["remainingRange"]) <= 0.001 or int(projectile["ageTicks"]) >= MAX_LIFETIME_TICKS:
			_finish(projectile, "expired", null, finish)
		else:
			survivors.append(projectile)
	projectiles = survivors

func first_collision(projectile: Dictionary, start: Vector2, finish: Vector2) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for unit in world.units:
		if not is_instance_valid(unit) or unit.dead:
			continue
		# A projectile begins inside its source collider. The source can never
		# intercept its own shot, even when a skill collides with allied units.
		if str(unit.replay_id) == str(projectile.get("sourceUnitId", "")): continue
		if unit.team == projectile["team"] and not bool(projectile.get("blockedByAllyUnit", false)): continue
		if unit.team != projectile["team"] and not bool(projectile.get("blockedByEnemyUnit", true)): continue
		if str(unit.replay_id) in projectile.get("hitUnitIds", []): continue
		var hit_t := segment_circle_hit(start, finish, unit.global_position, UNIT_RADIUS + float(projectile["radius"]))
		if hit_t >= 0.0:
			candidates.append({"t": hit_t, "typeOrder": 1, "entityId": str(unit.replay_id), "kind": "unit", "object": unit})
	for obstacle in obstacles:
		if not bool(projectile.get("blockedByObstacle", true)) or not bool(obstacle.get("blocks_projectile", false)):
			continue
		var hit_t := segment_obstacle_hit(start, finish, obstacle, float(projectile["radius"]))
		if hit_t >= 0.0:
			candidates.append({"t": hit_t, "typeOrder": 0, "entityId": str(obstacle.get("id", "")), "kind": "obstacle", "object": obstacle})
	if candidates.is_empty(): return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["t"]), float(b["t"])): return float(a["t"]) < float(b["t"])
		if int(a["typeOrder"]) != int(b["typeOrder"]): return int(a["typeOrder"]) < int(b["typeOrder"])
		return str(a["entityId"]) < str(b["entityId"])
	)
	return candidates[0]

static func segment_circle_hit(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
	var movement := finish - start
	var offset := start - center
	var c := offset.dot(offset) - radius * radius
	if c <= 0.0: return 0.0
	var a := movement.dot(movement)
	if a <= 0.000001: return -1.0
	var b := 2.0 * offset.dot(movement)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0: return -1.0
	var root := sqrt(discriminant)
	var first := (-b - root) / (2.0 * a)
	var second := (-b + root) / (2.0 * a)
	if first >= 0.0 and first <= 1.0: return first
	if second >= 0.0 and second <= 1.0: return second
	return -1.0

static func segment_obstacle_hit(start: Vector2, finish: Vector2, obstacle: Dictionary, radius: float) -> float:
	if obstacle.get("shape") == "circle":
		return segment_circle_hit(start, finish, Vector2(obstacle.get("center", Vector2.ZERO)), float(obstacle.get("radius", 0.0)) + radius)
	if obstacle.get("shape") != "rect": return -1.0
	var rect: Rect2 = obstacle.get("rect", Rect2())
	rect = rect.grow(radius)
	var delta := finish - start
	var near := 0.0
	var far := 1.0
	for axis in 2:
		var origin := start[axis]
		var direction := delta[axis]
		var low := rect.position[axis]
		var high := rect.end[axis]
		if absf(direction) <= 0.000001:
			if origin < low or origin > high: return -1.0
			continue
		var first := (low - origin) / direction
		var second := (high - origin) / direction
		if first > second:
			var swap := first; first = second; second = swap
		near = maxf(near, first)
		far = minf(far, second)
		if near > far: return -1.0
	return near if near >= 0.0 and near <= 1.0 else -1.0

func _finish(projectile: Dictionary, reason: String, hit_object: Variant, position: Vector2) -> void:
	projectile["position"] = position
	if reason == "unit" and is_instance_valid(hit_object):
		projectile["actualHitTargetId"] = str(hit_object.replay_id)
		world.queue_damage(projectile.get("source"), hit_object, int(projectile["damage"]))
		_record("projectile_hit", projectile, {"firstHitObjectId": str(hit_object.replay_id)})
	elif reason == "obstacle":
		_record("projectile_blocked", projectile, {"firstHitObjectId": str(hit_object.get("id", "")), "blockedByObstacle": true})
	else:
		_record("projectile_expired", projectile, {"reason": reason})
	var sprite: Sprite2D = projectile.get("sprite")
	if is_instance_valid(sprite): sprite.queue_free()

func _record(event_type: String, projectile: Dictionary, extra := {}) -> void:
	if world == null: return
	var event := {"type": event_type, "tick": simulation_tick, "time": snappedf(float(world.replay_elapsed), 0.001),
		"projectileId": str(projectile["id"]), "sourceUnitId": str(projectile["sourceUnitId"]),
		"sourceKind":str(projectile.get("sourceKind", "basic_attack")),
		"intendedTargetId": str(projectile["intendedTargetId"]), "actualHitTargetId": projectile.get("actualHitTargetId"),
		"position": [snappedf(Vector2(projectile["position"]).x, 0.01), snappedf(Vector2(projectile["position"]).y, 0.01)]}
	for key in extra: event[key] = extra[key]
	world.record_projectile_event(event)

func snapshot() -> Array:
	var result: Array = []
	for projectile in projectiles:
		result.append({"id":str(projectile["id"]), "position":[snappedf(Vector2(projectile["position"]).x,0.1),snappedf(Vector2(projectile["position"]).y,0.1)],
			"rotation":Vector2(projectile["direction"]).angle(), "team":str(projectile["team"]),
			"sourceUnitId":str(projectile["sourceUnitId"]), "intendedTargetId":str(projectile["intendedTargetId"])})
	return result
