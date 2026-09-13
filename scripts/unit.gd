extends Node2D

const CELL := 32.0
const ACTION_INTERVAL := 1.2
const DAMAGE_FLASH_DURATION := 0.16
const BRIDGE_LEFT_X := 328.0
const BRIDGE_RIGHT_X := 392.0
const MOVE_SPEEDS := {
	"monk": 72.0,
	"warrior": 68.0,
	"lancer": 64.0,
	"archer": 60.0,
	"worker": 56.0
}
const STATS := {
	"archer": {"hp": 80, "attack": 18, "range": 5, "heal": 0},
	"lancer": {"hp": 120, "attack": 22, "range": 3, "heal": 0},
	"worker": {"hp": 110, "attack": 6, "range": 1, "heal": 0},
	"monk": {"hp": 100, "attack": 8, "range": 6, "heal": 18},
	"warrior": {"hp": 160, "attack": 28, "range": 1, "heal": 0}
}

var world: Node
var team := "blue"
var unit_type := "archer"
var home_position := Vector2.ZERO
var hp := 1
var max_hp := 1
var attack_power := 1
var attack_range := CELL
var heal_power := 0
var move_speed := 56.0
var dead := false
var target: Node2D
var resource_target: Node2D
var carrying := ""
var state := "idle"
var state_time := 0.0
var action_cooldown := 0.0
var sprite: Sprite2D
var stone_carry: Sprite2D
var hp_fill: ColorRect
var hp_back: ColorRect
var frame_time := 0.0
var facing_left := false
var facing_direction := "front"
var attack_direction := "front"
var worker_combat_active := false
var target_locked := false
var monk_mode := ""
var damage_flash_time := 0.0
var gather_hit_applied := false
var pending_attack_target: Node2D
var attack_hit_applied := false
var pending_heal_target: Node2D
var heal_applied := false
var last_recorded_target_id := ""
var committed_bridge_x := 0.0
var bridge_crossing_direction := 0
var strategy_slot := 0
var strategy_under_attack_time := 0.0
var strategy_gather_counts: Dictionary = {"gold": 0, "stone": 0, "wood": 0, "meat": 0}
var replay_id := ""
var last_move_direction := Vector2.ZERO
var skill_configs: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var pending_skill: Dictionary = {}
var pending_skill_target: Node2D
var skill_effect_applied := false
var last_strategy_area_type := ""
var last_attack_target_position := Vector2.ZERO

func setup(controller: Node, owner_team: String, kind: String, spawn_position: Vector2) -> void:
	world = controller
	team = owner_team
	unit_type = kind
	home_position = spawn_position
	position = spawn_position
	var data: Dictionary = STATS[unit_type]
	max_hp = int(data["hp"])
	hp = max_hp
	attack_power = int(data["attack"])
	attack_range = float(data["range"]) * CELL
	heal_power = int(data["heal"])
	move_speed = float(MOVE_SPEEDS.get(unit_type, 56.0))
	build_visuals()
	play_state("idle")

func configure_skills(configs: Array) -> void:
	skill_configs.clear()
	skill_cooldowns.clear()
	for value in configs:
		if value is Dictionary:
			var config: Dictionary = value.duplicate(true)
			var skill_no := int(config.get("skillNo", 0))
			if skill_no > 0:
				skill_configs[skill_no] = config
				skill_cooldowns[skill_no] = 0.0

func build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	stone_carry = Sprite2D.new()
	stone_carry.texture = preload("res://assets/game/resources/stone1.png")
	stone_carry.scale = Vector2(0.42, 0.42)
	stone_carry.position = Vector2(0, -23)
	stone_carry.visible = false
	stone_carry.z_index = 2
	add_child(stone_carry)
	hp_back = ColorRect.new()
	hp_back.position = Vector2(-28, -53)
	hp_back.size = Vector2(56, 7)
	hp_back.color = Color(0.12, 0.09, 0.13, 0.92)
	add_child(hp_back)
	hp_fill = ColorRect.new()
	hp_fill.position = Vector2(-26, -51)
	hp_fill.size = Vector2(52, 3)
	hp_fill.color = Color("55cfe0") if team == "blue" else Color("ef6871")
	add_child(hp_fill)

func _process(delta: float) -> void:
	damage_flash_time = maxf(0.0, damage_flash_time - delta)
	strategy_under_attack_time = maxf(0.0, strategy_under_attack_time - delta)
	sprite.modulate = Color(1.0, 0.28, 0.28, 1.0) if damage_flash_time > 0.0 else Color.WHITE
	if dead:
		update_animation(delta)
		return
	if world != null and world.replay_mode:
		update_animation(delta)
		z_index = int(position.y / 10.0) + 50
		return
	state_time += delta
	action_cooldown = maxf(0.0, action_cooldown - delta)
	for skill_no in skill_cooldowns: skill_cooldowns[skill_no] = maxf(0.0, float(skill_cooldowns[skill_no]) - delta)
	if world != null and world.battle_started:
		if update_strategy_skill(delta):
			update_animation(delta)
			z_index = int(position.y / 10.0) + 50
			return
		match unit_type:
			"worker": update_worker(delta)
			"monk": update_monk(delta)
			_: update_combat(delta)
	else:
		play_state("idle")
	update_animation(delta)
	z_index = int(position.y / 10.0) + 50

func update_strategy_skill(_delta: float) -> bool:
	if team != "blue" or strategy_slot <= 0 or skill_configs.is_empty(): return false
	if not pending_skill.is_empty():
		var cast_time := float(pending_skill.get("castTime", 0.0))
		var recovery := float(pending_skill.get("recoveryTime", 0.0))
		if not skill_effect_applied and state_time >= cast_time:
			skill_effect_applied = true
			apply_skill_effect(pending_skill, pending_skill_target)
		if state_time < cast_time + recovery: return true
		world.emit_strategy_event("skill_completed", self, pending_skill_target, 21)
		pending_skill.clear()
		pending_skill_target = null
		play_state("idle")
	var action: Dictionary = world.get_strategy_skill_action(self)
	if action.is_empty(): return false
	var skill_no := int(action.get("skillNo", 0))
	if not skill_configs.has(skill_no) or float(skill_cooldowns.get(skill_no, 0.0)) > 0.0: return false
	var config: Dictionary = skill_configs[skill_no]
	var skill_target: Node2D = world.get_strategy_role_target(self, str(action.get("targetRef", "skill_target")))
	if config.get("targetType", "enemy") == "self": skill_target = self
	if not is_valid_unit(skill_target): return false
	if position.distance_to(skill_target.position) > float(config.get("castRange", attack_range)): return false
	pending_skill = config.duplicate(true)
	pending_skill_target = skill_target
	skill_effect_applied = false
	skill_cooldowns[skill_no] = float(config.get("cd", 8.0))
	face_position(skill_target.position)
	play_state("attack", true)
	world.record_strategy_skill_cast(self, skill_target, config)
	return true

func apply_skill_effect(config: Dictionary, skill_target: Node2D) -> void:
	if not is_valid_unit(skill_target): return
	var effect: Dictionary = config.get("effect", {})
	var amount := int(round(float(effect.get("value", 0.0))))
	if effect.get("type") == "heal":
		if skill_target.team == team: world.queue_heal(self, skill_target, amount)
	elif skill_target.team != team:
		if config.get("projectile") is Dictionary:
			world.spawn_skill_projectile(self, skill_target, amount, config["projectile"], str(config.get("skillId", "skill")))
		else: world.queue_damage(self, skill_target, amount)

func update_combat(delta: float) -> void:
	if state == "attack":
		if not attack_hit_applied and state_time >= attack_impact_time():
			attack_hit_applied = true
			apply_attack_impact()
		if state_time < attack_animation_duration():
			return
		world.emit_strategy_event("attack_completed", self, pending_attack_target, 20)
		play_state("idle")
	if apply_strategy_movement(delta):
		return
	if target_locked and (not is_valid_enemy(target) or position.distance_to(target.position) > attack_range):
		target_locked = false
		target = null
	if not target_locked:
		target = world.get_nearest_enemy(self)
		if is_valid_enemy(target):
			var selected_id := String(target.replay_id)
			if selected_id != last_recorded_target_id:
				last_recorded_target_id = selected_id
				world.record_strategy_target_selection(self, target)
	if not is_valid_enemy(target):
		target_locked = false
		play_state("idle")
		return
	face_position(target.position)
	var distance := position.distance_to(target.position)
	if distance > attack_range:
		if world.strategy_holds_position(self):
			target_locked = false
			target = null
			play_state("idle")
			return
		move_to(target.position, delta)
		return
	# Only lock after the selected enemy is actually inside attack range.
	target_locked = true
	if action_cooldown <= 0.0:
		action_cooldown = ACTION_INTERVAL
		pending_attack_target = target
		last_attack_target_position = target.position
		attack_hit_applied = false
		attack_direction = facing_direction
		play_state("attack", true)
	elif state_time > (0.75 if unit_type == "monk" else 0.55):
		play_state("idle")

func attack_impact_time() -> float:
	match unit_type:
		"lancer": return 0.125
		"worker": return 0.25
		"warrior": return 0.375
		"archer": return 0.375
		"monk": return 0.50
	return 0.25

func attack_animation_duration() -> float:
	match unit_type:
		"lancer": return 0.375
		"worker": return 0.50
	return 0.75

func apply_attack_impact() -> void:
	world.play_attack_sfx(unit_type)
	if not is_valid_enemy(pending_attack_target):
		return
	if position.distance_to(pending_attack_target.position) > attack_range:
		return
	if unit_type == "archer":
		world.spawn_arrow(self, pending_attack_target, attack_power)
	else:
		world.queue_damage(self, pending_attack_target, attack_power)

func update_monk(delta: float) -> void:
	if state == "heal":
		if not heal_applied and state_time >= 0.50:
			heal_applied = true
			if is_valid_unit(pending_heal_target) and pending_heal_target.team == team and pending_heal_target.hp < pending_heal_target.max_hp and position.distance_to(pending_heal_target.position) <= attack_range:
				world.queue_heal(self, pending_heal_target, heal_power)
		if state_time < 0.75:
			return
		pending_heal_target = null
		play_state("idle")
	if apply_strategy_movement(delta):
		return
	# An explicit combat order overrides the monk's default heal-first AI.
	# An explicit heal directive still wins over combat when both are present.
	var injured_ally: Node2D = null if world.strategy_forces_monk_combat(self) else world.get_nearest_injured_ally(self)
	if is_valid_unit(injured_ally):
		# Re-evaluate the support target before every cast. Keeping the target
		# merely because the monk was already in heal mode made lowest-HP orders
		# sticky and could leave a more injured ally untreated for many seconds.
		if monk_mode != "heal" or state != "heal":
			target_locked = false
			monk_mode = "heal"
			target = injured_ally
		elif not is_valid_unit(target):
			target = injured_ally
		face_position(target.position)
		if position.distance_to(target.position) > attack_range:
			if world.strategy_holds_position(self):
				play_state("idle")
				return
			move_to(target.position, delta)
		elif action_cooldown <= 0.0:
			action_cooldown = ACTION_INTERVAL
			pending_heal_target = target
			heal_applied = false
			world.record_strategy_heal_selection(self, target)
			play_state("heal", true)
		return
	if monk_mode != "attack":
		target = null
		target_locked = false
	monk_mode = "attack"
	update_combat(delta)

func update_worker(delta: float) -> void:
	if not world.has_living_non_worker_combatants(team):
		if not worker_combat_active:
			worker_combat_active = true
			carrying = ""
			resource_target = null
			target = null
			target_locked = false
			stone_carry.visible = false
			action_cooldown = 0.0
			play_state("idle", true)
			if world.test_mode:
				print("WORKER_COMBAT_ACTIVATED team=", team)
		if not apply_strategy_movement(delta):
			update_combat(delta)
		return
	if apply_strategy_movement(delta):
		return
	if carrying != "":
		face_position(home_position)
		if position.distance_to(home_position) > 24.0:
			play_state("carry_" + carrying)
			move_physical(home_position, delta, false)
		else:
			strategy_gather_counts[carrying] = int(strategy_gather_counts.get(carrying, 0)) + 1
			world.add_resource(team, carrying, 1)
			world.show_float_text(global_position - Vector2(0, 40), "+1", Color("f4d35e"))
			carrying = ""
			stone_carry.visible = false
			resource_target = null
			play_state("idle")
		return
	if not is_valid_resource(resource_target):
		var preferred_resource: String = world.get_strategy_resource_type(self)
		resource_target = null if preferred_resource == "__none__" else world.get_nearest_resource(self, preferred_resource)
	if not is_valid_resource(resource_target):
		play_state("idle")
		return
	face_position(resource_target.position)
	if position.distance_to(resource_target.position) > gather_distance(resource_target.resource_type):
		move_to(resource_target.position, delta)
	else:
		var gather_state := "knife" if resource_target.resource_type == "meat" else ("axe" if resource_target.resource_type == "wood" else "pickaxe")
		if action_cooldown <= 0.0:
			action_cooldown = ACTION_INTERVAL
			gather_hit_applied = false
			resource_target.begin_harvest()
			play_state(gather_state, true)
		elif state == gather_state:
			if not gather_hit_applied and state_time >= gather_impact_time(gather_state):
				gather_hit_applied = true
				var harvested_type: String = resource_target.resource_type
				if resource_target.hit_resource():
					carrying = harvested_type
					stone_carry.visible = carrying == "stone"
					resource_target = null
			if carrying == "" and state_time >= gather_animation_duration(gather_state):
				# The resource progress changes on the tool-impact frame, then the
				# one-shot animation finishes before the next cooldown cycle.
				play_state("idle")
		elif state != gather_state:
			play_state("idle")

func gather_impact_time(gather_state: String) -> float:
	return 0.25 if gather_state == "knife" else 0.375

func gather_animation_duration(gather_state: String) -> float:
	var frame_count := 4.0 if gather_state == "knife" else 6.0
	return frame_count / 8.0

func apply_strategy_movement(delta: float) -> bool:
	if team != "blue" or strategy_slot <= 0:
		return false
	var action: Dictionary = world.get_strategy_movement_action(self)
	if action.is_empty():
		return false
	var action_type := String(action.get("opcode", action.get("type", "")))
	var destination: Variant = world.get_strategy_movement_destination(self, action)
	if not destination is Vector2:
		return false
	var position_ref: Variant = action.get("positionRef")
	var is_line_block: bool = position_ref is Dictionary and position_ref.get("function") == "line_block_position"
	var stop_distance := 4.0 if is_line_block else (float(action.get("distance", 92.0)) if action_type in ["follow", "protect"] else 28.0)
	if position.distance_to(destination) > stop_distance:
		move_to(destination, delta)
		return true
	if action_type in ["hold", "hold_position", "stop"]:
		return false
	if action_type == "retreat":
		play_state("idle")
		return true
	return false

func gather_distance(kind: String) -> float:
	return 48.0 if kind in ["gold", "wood"] else 34.0

func move_to(destination: Vector2, delta: float) -> void:
	destination = world.constrain_strategy_destination(self, destination)
	if position.distance_to(destination) <= 1.0:
		play_state("idle")
		return
	play_state("run")
	update_bridge_commitment(destination)
	move_physical(world.get_next_waypoint(position, destination, committed_bridge_x), delta, true)
	update_bridge_completion()

func update_bridge_commitment(destination: Vector2) -> void:
	const TOP_BANK := 574.0
	const BOTTOM_BANK := 706.0
	const RIVER_TOP := 592.0
	const RIVER_BOTTOM := 688.0
	if bridge_crossing_direction == 1 and position.y < RIVER_TOP and destination.y < RIVER_TOP:
		clear_bridge_commitment()
	elif bridge_crossing_direction == -1 and position.y > RIVER_BOTTOM and destination.y > RIVER_BOTTOM:
		clear_bridge_commitment()
	if bridge_crossing_direction != 0:
		return
	if position.y < TOP_BANK and destination.y > BOTTOM_BANK:
		bridge_crossing_direction = 1
	elif position.y > BOTTOM_BANK and destination.y < TOP_BANK:
		bridge_crossing_direction = -1
	else:
		return
	var left_cost := absf(position.x - BRIDGE_LEFT_X) + absf(destination.x - BRIDGE_LEFT_X)
	var right_cost := absf(position.x - BRIDGE_RIGHT_X) + absf(destination.x - BRIDGE_RIGHT_X)
	committed_bridge_x = BRIDGE_LEFT_X if left_cost <= right_cost else BRIDGE_RIGHT_X

func update_bridge_completion() -> void:
	const TOP_EXIT := 569.0
	const BOTTOM_EXIT := 711.0
	if bridge_crossing_direction == 1 and position.y >= BOTTOM_EXIT:
		clear_bridge_commitment()
	elif bridge_crossing_direction == -1 and position.y <= TOP_EXIT:
		clear_bridge_commitment()

func clear_bridge_commitment() -> void:
	committed_bridge_x = 0.0
	bridge_crossing_direction = 0

func move_physical(destination: Vector2, delta: float, update_facing: bool) -> void:
	var direction := position.direction_to(destination)
	last_move_direction = direction
	if update_facing and absf(direction.x) > 0.05:
		facing_left = direction.x < 0.0
		sprite.flip_h = facing_left
	var proposed_position := position + direction * move_speed * delta
	position = world.constrain_unit_position(position, proposed_position)

func face_position(destination: Vector2) -> void:
	var offset := destination - position
	if unit_type in ["archer", "lancer", "warrior"]:
		var horizontal_distance := absf(offset.x)
		var vertical_distance := absf(offset.y)
		if vertical_distance > horizontal_distance * 2.0:
			facing_direction = "down" if offset.y > 0.0 else "up"
		elif vertical_distance > horizontal_distance * 0.5:
			facing_direction = "down_diagonal" if offset.y > 0.0 else "up_diagonal"
		else:
			facing_direction = "front"
	if absf(offset.x) > 2.0:
		facing_left = offset.x < 0.0
		sprite.flip_h = facing_left

func resolve_combat(damage: int, healing: int) -> void:
	if dead:
		return
	var previous_hp := hp
	hp = clampi(hp + healing - damage, 0, max_hp)
	update_health_bar()
	if damage > 0:
		damage_flash_time = DAMAGE_FLASH_DURATION
		strategy_under_attack_time = 4.0
		world.play_damage_sfx()
		world.show_float_text(global_position - Vector2(0, 45), "-%d" % damage, Color("ff8b72"))
	if healing > 0 and previous_hp < max_hp:
		world.spawn_heal_effect(self)
		world.play_heal_sfx()
		world.show_float_text(global_position - Vector2(0, 70), "+%d" % healing, Color("7ee58b"))
	if hp <= 0:
		die()

func take_damage(amount: int) -> void:
	resolve_combat(amount, 0)

func receive_heal(amount: int) -> void:
	resolve_combat(0, amount)

func update_health_bar() -> void:
	hp_fill.size.x = 52.0 * float(hp) / float(max_hp)

func die() -> void:
	dead = true
	world.play_death_sfx()
	target = null
	target_locked = false
	pending_attack_target = null
	pending_heal_target = null
	clear_bridge_commitment()
	resource_target = null
	stone_carry.visible = false
	hp_back.visible = false
	hp_fill.visible = false
	play_state("dead", true)
	world.unit_died(self)

func play_state(next_state: String, force := false) -> void:
	if not force and state == next_state:
		return
	state = next_state
	state_time = 0.0
	frame_time = 0.0
	apply_animation_frame(0)

func update_animation(delta: float) -> void:
	frame_time += delta
	var info := animation_info()
	var frame_count: int = int(info["count"])
	var fps: float = float(info["fps"])
	var frame_index := int(frame_time * fps)
	if state == "dead" and frame_index >= frame_count:
		if world != null and world.replay_mode:
			apply_animation_frame(frame_count - 1)
			return
		queue_free()
		return
	apply_animation_frame(frame_index % frame_count)

func apply_animation_frame(frame_index: int) -> void:
	var info := animation_info()
	var texture: Texture2D = load(String(info["path"]))
	sprite.texture = texture
	var frame_size: int = int(info["frame_size"])
	var row: int = int(info["row"])
	var column := frame_index
	if state == "dead":
		column = frame_index % 7
		row = frame_index / 7
	sprite.region_rect = Rect2(column * frame_size, row * frame_size, frame_size, frame_size)
	sprite.scale = Vector2.ONE * float(info["scale"])
	sprite.flip_h = facing_left

func animation_info() -> Dictionary:
	if state == "dead":
		return {"path": "res://assets/game/units/dead.png", "frame_size": 128, "row": 0, "count": 14, "fps": 10.0, "scale": 0.715}
	var side := team
	match unit_type:
		"archer":
			var archer_row := 0 if state == "idle" else 1
			if state == "attack":
				match attack_direction:
					"up": archer_row = 2
					"up_diagonal": archer_row = 3
					"down_diagonal": archer_row = 5
					"down": archer_row = 6
					_: archer_row = 4
			var archer_count := 8 if state == "attack" else 6
			return {"path": "res://assets/game/units/archer/%s.png" % side, "frame_size": 192, "row": archer_row, "count": archer_count, "fps": 8.0, "scale": 0.78}
		"warrior":
			var warrior_row := 0 if state == "idle" else 1
			if state == "attack":
				match attack_direction:
					"up", "up_diagonal": warrior_row = 6
					"down", "down_diagonal": warrior_row = 4
					_: warrior_row = 2
			return {"path": "res://assets/game/units/warrior/%s.png" % side, "frame_size": 192, "row": warrior_row, "count": 6, "fps": 8.0, "scale": 0.78}
		"lancer":
			var lancer_state := "idle" if state == "idle" else ("run" if state == "run" else "attack")
			var lancer_count := 12 if lancer_state == "idle" else (6 if lancer_state == "run" else 3)
			var lancer_path := "res://assets/game/units/lancer/%s_%s.png" % [side, lancer_state]
			if lancer_state == "attack" and attack_direction != "front":
				lancer_path = "res://assets/game/units/lancer/%s_attack_%s.png" % [side, attack_direction]
			return {"path": lancer_path, "frame_size": 320, "row": 0, "count": lancer_count, "fps": 8.0, "scale": 0.78}
		"monk":
			var monk_state := "heal" if state in ["heal", "attack"] else ("run" if state == "run" else "idle")
			var monk_count := 11 if monk_state == "heal" else (4 if monk_state == "run" else 6)
			return {"path": "res://assets/game/units/monk/%s_%s.png" % [side, monk_state], "frame_size": 192, "row": 0, "count": monk_count, "fps": 8.0, "scale": 0.78}
		"worker":
			var worker_state := state
			if worker_state == "attack":
				worker_state = "knife"
			if worker_state not in ["run", "pickaxe", "axe", "knife", "carry_gold", "carry_wood", "carry_meat"]:
				worker_state = "run" if worker_state == "carry_stone" else "idle"
			var worker_count := 8 if worker_state == "idle" else (4 if worker_state == "knife" else 6)
			return {"path": "res://assets/game/units/worker/%s_%s.png" % [side, worker_state], "frame_size": 192, "row": 0, "count": worker_count, "fps": 8.0, "scale": 0.78}
	return {"path": "res://assets/game/units/dead.png", "frame_size": 128, "row": 0, "count": 1, "fps": 1.0, "scale": 0.715}

func is_valid_unit(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and not node.dead

func is_valid_enemy(node: Variant) -> bool:
	return is_valid_unit(node) and node.team != team and (world == null or world.can_see_unit(self, node))

func is_valid_resource(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and not node.depleted and node.charges > 0
