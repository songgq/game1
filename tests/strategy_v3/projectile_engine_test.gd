extends SceneTree

const ENGINE := preload("res://scripts/projectile_engine.gd")

class MockUnit extends Node2D:
	var replay_id := ""
	var team := "blue"
	var dead := false
	var attack_range := 500.0

class MockWorld extends Node:
	var units: Array = []
	var replay_mode := false
	var battle_started := true
	var battle_finished := false
	var replay_elapsed := 0.0
	var damage_events: Array = []
	var projectile_events: Array = []
	func queue_damage(source: Node, target: Node, amount: int) -> void:
		damage_events.append({"source":source.replay_id,"target":target.replay_id,"amount":amount})
	func record_projectile_event(event: Dictionary) -> void:
		projectile_events.append(event.duplicate(true))

var failures: Array = []

func _initialize() -> void:
	test_enemy_intercepts_and_ally_does_not()
	test_obstacle_blocks()
	test_swept_collision_prevents_tunneling()
	test_moving_target_is_not_homing()
	test_ally_blocking_never_hits_source()
	if failures.is_empty():
		print("PROJECTILE_ENGINE_TEST_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func make_unit(world: MockWorld, id: String, team: String, position: Vector2) -> MockUnit:
	var unit := MockUnit.new()
	unit.replay_id = id; unit.team = team; unit.position = position
	world.add_child(unit); world.units.append(unit)
	return unit

func make_engine() -> Array:
	var world := MockWorld.new(); root.add_child(world)
	var engine := ENGINE.new(); world.add_child(engine); engine.setup(world)
	return [world, engine]

func test_enemy_intercepts_and_ally_does_not() -> void:
	var fixture := make_engine(); var world: MockWorld = fixture[0]; var engine: Node = fixture[1]
	var source := make_unit(world, "blue_archer", "blue", Vector2(0, 100))
	make_unit(world, "blue_ally", "blue", Vector2(100, 100))
	var blocker := make_unit(world, "red_blocker", "red", Vector2(200, 100))
	var intended := make_unit(world, "red_target", "red", Vector2(400, 100))
	engine.spawn_basic_attack(source, intended, 18)
	engine.advance(1.0)
	check(world.damage_events.size() == 1 and world.damage_events[0]["target"] == blocker.replay_id, "first enemy should intercept while ally is ignored")
	var hit: Dictionary = world.projectile_events[-1]
	check(hit["intendedTargetId"] == intended.replay_id and hit["actualHitTargetId"] == blocker.replay_id, "event must distinguish intended and actual target")
	world.free()

func test_obstacle_blocks() -> void:
	var fixture := make_engine(); var world: MockWorld = fixture[0]; var engine: Node = fixture[1]
	var source := make_unit(world, "source", "blue", Vector2(0, 0))
	var intended := make_unit(world, "target", "red", Vector2(400, 0))
	engine.obstacles.append({"id":"wall_1","shape":"rect","rect":Rect2(180,-30,20,60),"blocks_projectile":true})
	engine.spawn_basic_attack(source, intended, 18)
	engine.advance(1.0)
	check(world.damage_events.is_empty(), "blocking obstacle must prevent damage")
	check(world.projectile_events[-1]["type"] == "projectile_blocked", "obstacle block must be replayed")
	world.free()

func test_swept_collision_prevents_tunneling() -> void:
	var hit := ENGINE.segment_circle_hit(Vector2(0, 0), Vector2(1000, 0), Vector2(500, 0), 10.0)
	check(hit > 0.0 and hit < 1.0, "swept segment must hit a small object even at high speed")
	var miss := ENGINE.segment_circle_hit(Vector2(0, 0), Vector2(1000, 0), Vector2(500, 30), 10.0)
	check(miss < 0.0, "swept segment must not invent collisions")

func test_moving_target_is_not_homing() -> void:
	var fixture := make_engine(); var world: MockWorld = fixture[0]; var engine: Node = fixture[1]
	var source := make_unit(world, "moving_source", "blue", Vector2(0, 0))
	var intended := make_unit(world, "moving_target", "red", Vector2(400, 0))
	engine.spawn_configured(source, intended, 18, {"speed":100.0,"radius":4.0,"range":500.0,
		"blockedByObstacle":true,"blockedByEnemyUnit":true,"blockedByAllyUnit":false})
	engine.advance(1.0)
	intended.position = Vector2(400, 200)
	for _step in 4: engine.advance(1.0)
	check(world.damage_events.is_empty(), "projectile must keep its launch direction when the intended target moves")
	check(world.projectile_events[-1]["type"] == "projectile_expired", "missed moving target must expire rather than auto-hit")
	world.free()

func test_ally_blocking_never_hits_source() -> void:
	var fixture := make_engine(); var world: MockWorld = fixture[0]; var engine: Node = fixture[1]
	var source := make_unit(world, "skill_source", "blue", Vector2(0, 0))
	var ally := make_unit(world, "skill_ally", "blue", Vector2(150, 0))
	var intended := make_unit(world, "skill_target", "red", Vector2(300, 0))
	engine.spawn_configured(source, intended, 20, {"speed":500.0,"radius":4.0,"range":400.0,
		"blockedByObstacle":true,"blockedByEnemyUnit":true,"blockedByAllyUnit":true})
	engine.advance(1.0)
	check(world.damage_events.size() == 1 and world.damage_events[0]["target"] == ally.replay_id,
		"ally-blocking projectile must ignore its source and hit the first other ally")
	world.free()
