extends Control

signal plot_selected(plot_id: int)
signal worker_selected(worker_id: String)
signal object_selected(object_type: String, object_id: String)
signal ground_selected(cell: Vector2i)

const WORLD_SIZE := Vector2(720, 1280)
const LAND_ORIGIN := Vector2(24, 80)
const LAND_COLUMNS := 21
const LAND_ROWS := 35
const CELL := 32.0
const DRAG_THRESHOLD := 12.0

const WATER := preload("res://assets/terrain/water.png")
const GROUND := preload("res://assets/terrain/ground_flat.png")
const TREE := preload("res://assets/game/resources/tree.png")
const STONE_SMALL := preload("res://assets/game/resources/stone1.png")
const STONE_LARGE := preload("res://assets/game/resources/stone2.png")
const WORKER_IDLE := preload("res://assets/game/units/worker/blue_idle.png")
const WORKER_RUN := preload("res://assets/game/units/worker/blue_run.png")
const WORKER_RUN_AXE := preload("res://assets/game/units/worker/blue_run_axe.png")
const WORKER_RUN_PICKAXE := preload("res://assets/game/units/worker/blue_run_pickaxe.png")
const WORKER_RUN_KNIFE := preload("res://assets/game/units/worker/blue_run_knife.png")
const WORKER_AXE := preload("res://assets/game/units/worker/blue_axe.png")
const WORKER_PICKAXE := preload("res://assets/game/units/worker/blue_pickaxe.png")
const WORKER_FARM := preload("res://assets/game/units/worker/blue_knife.png")
const WORKER_CARRY_WOOD := preload("res://assets/game/units/worker/blue_carry_wood.png")
const WORKER_CARRY_GOLD := preload("res://assets/game/units/worker/blue_carry_gold.png")
const WORKER_CARRY_MEAT := preload("res://assets/game/units/worker/blue_carry_meat.png")
const WORKER_CARRY_STONE_SHADER := preload("res://assets/game/units/worker/carry_stone.gdshader")
const ISLAND_OBJECTS := preload("res://assets/island/island_initial_objects_v1.png")

var island_data: Dictionary = {}
var zoom := 1.0
var camera_center := WORLD_SIZE * 0.5
var dragging := false
var press_position := Vector2.ZERO
var last_pointer := Vector2.ZERO
var active_touches: Dictionary = {}
var pinch_distance := 0.0
var world_root: Node2D
var y_sort_world: Node2D
var interactions: Array[Dictionary] = []
var fog_by_plot: Dictionary = {}
var worker_sprites: Dictionary = {}
var worker_animation_state: Dictionary = {}
var island_astar: AStarGrid2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_world_root()


func _process(delta: float) -> void:
	_update_worker_animations(delta)


func configure(value: Dictionary) -> void:
	island_data = value.duplicate(true)
	zoom = 1.0
	camera_center = WORLD_SIZE * 0.5
	if not is_node_ready():
		await ready
	_rebuild_world()


func update_server_state(value: Dictionary) -> void:
	island_data = value.duplicate(true)
	if not is_node_ready():
		await ready
	_rebuild_world()


func reveal_plot(plot_id: int) -> void:
	var fog := fog_by_plot.get(plot_id) as Sprite2D
	if fog == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fog, "modulate:a", 0.0, 0.8)
	tween.tween_property(fog, "scale", fog.scale * 1.15, 0.8)
	tween.finished.connect(fog.queue_free)


func select_worker(worker_id: String) -> void:
	for id in worker_sprites:
		var sprite := worker_sprites[id] as Sprite2D
		if sprite != null:
			sprite.modulate = Color("fff2a3") if id == worker_id else Color.WHITE
			sprite.scale = Vector2.ONE * (0.47 if id == worker_id else 0.42)


func _build_world_root() -> void:
	world_root = Node2D.new()
	world_root.name = "IslandWorld"
	add_child(world_root)
	y_sort_world = Node2D.new()
	y_sort_world.name = "YSortWorld"
	y_sort_world.y_sort_enabled = true
	world_root.add_child(y_sort_world)
	_update_world_transform()


func _rebuild_world() -> void:
	for child in world_root.get_children():
		world_root.remove_child(child)
		child.queue_free()
	interactions.clear()
	fog_by_plot.clear()
	worker_sprites.clear()
	worker_animation_state.clear()
	_build_water_layers()
	_build_land_layers()
	_build_client_astar()
	y_sort_world = Node2D.new()
	y_sort_world.name = "YSortWorld"
	y_sort_world.y_sort_enabled = true
	world_root.add_child(y_sort_world)
	_build_state_objects()
	_build_task_target_highlights()
	_build_workers()
	_build_locked_plots()
	_build_natural_details()
	_update_world_transform()


func _build_water_layers() -> void:
	var layer := TileMapLayer.new()
	layer.name = "WaterBaseLayer"
	layer.z_index = -50
	layer.tile_set = _single_texture_tileset(WATER)
	for row in range(20):
		for column in range(12):
			layer.set_cell(Vector2i(column, row), 0, Vector2i.ZERO)
	world_root.add_child(layer)


func _build_land_layers() -> void:
	var ground_set := TileSet.new()
	ground_set.tile_size = Vector2i(64, 64)
	var source := TileSetAtlasSource.new()
	source.texture = GROUND
	source.texture_region_size = Vector2i(64, 64)
	for y in range(4):
		for x in range(10):
			source.create_tile(Vector2i(x, y))
	ground_set.add_source(source, 0)

	var land := TileMapLayer.new()
	land.name = "LandBaseLayer"
	land.tile_set = ground_set
	land.position = LAND_ORIGIN
	land.scale = Vector2(0.5, 0.5)
	land.z_index = -30
	for row in range(LAND_ROWS):
		for column in range(LAND_COLUMNS):
			var atlas := Vector2i(1, 1)
			if row == 0:
				atlas.y = 0
			elif row == LAND_ROWS - 1:
				atlas.y = 2
			if column == 0:
				atlas.x = 0
			elif column == LAND_COLUMNS - 1:
				atlas.x = 2
			land.set_cell(Vector2i(column, row), 0, atlas)
	world_root.add_child(land)

	var paths := TileMapLayer.new()
	paths.name = "PathVisualLayer"
	paths.tile_set = ground_set
	paths.position = LAND_ORIGIN
	paths.scale = Vector2(0.5, 0.5)
	paths.z_index = -20
	var path_cells: Array[Vector2i] = []
	for x in range(8, 21):
		path_cells.append(Vector2i(x, 19))
	for y in range(8, 27):
		path_cells.append(Vector2i(13, y))
	for cell in path_cells:
		paths.set_cell(cell, 0, Vector2i(6, 1))
	world_root.add_child(paths)


func _build_state_objects() -> void:
	var content_by_id := _content_config_by_id()
	for building in island_data.get("buildings", []):
		var id := str(building["buildingId"])
		var content: Dictionary = content_by_id.get(id, {})
		var sprite: Sprite2D
		match str(building["buildingType"]):
			"home": sprite = _atlas_sprite(ISLAND_OBJECTS, Rect2(0, 40, 625, 750), 0.24)
			"storage_chest": sprite = _atlas_sprite(ISLAND_OBJECTS, Rect2(615, 60, 305, 350), 0.29)
			"workbench": sprite = _atlas_sprite(ISLAND_OBJECTS, Rect2(665, 405, 570, 410), 0.23)
			_: continue
		_place_state_sprite(sprite, content, str(building["buildingId"]), "building")
		if str(building.get("state", "READY")) != "READY":
			sprite.modulate = Color(0.68, 0.72, 0.70, 0.86)

	for farm in island_data.get("farmPlots", []):
		var content: Dictionary = content_by_id.get(str(farm["farmPlotId"]), {})
		# Farm plots are authoritative 1x1 LandGrid cells. Use the square soil
		# centre of the existing farm artwork instead of the 45-degree border.
		var sprite := _atlas_sprite(ISLAND_OBJECTS, Rect2(1035, 135, 145, 145), CELL / 145.0)
		_place_state_sprite(sprite, content, str(farm["farmPlotId"]), "farm")
		sprite.position.y -= CELL * 0.5
		_add_crop_visual(farm, content)

	for resource in island_data.get("resourceNodes", []):
		var id := str(resource["instanceId"])
		var content: Dictionary = content_by_id.get(id, {})
		var sprite: Sprite2D
		if "tree" in str(resource["resourceType"]):
			# tree.png is a 192x192 frame sheet. A 288px-high region also includes
			# the next animation row, which rendered as a second tree tip.
			sprite = _atlas_sprite(TREE, Rect2(0, 0, 192, 192), 0.38)
		else:
			sprite = Sprite2D.new()
			sprite.texture = STONE_LARGE if "rich" in str(resource["resourceType"]) else STONE_SMALL
			sprite.scale = Vector2.ONE * (1.1 if "rich" in str(resource["resourceType"]) else 0.9)
		_place_state_sprite(sprite, content, id, "resource")
		if int(resource.get("charges", 0)) - int(resource.get("reservedCharges", 0)) <= 0:
			sprite.modulate = Color(0.52, 0.58, 0.56, 0.72)


func _place_state_sprite(sprite: Sprite2D, content: Dictionary, object_id: String, object_type: String) -> void:
	if content.is_empty():
		return
	var origin := Vector2(content["globalCell"][0], content["globalCell"][1]) * CELL + LAND_ORIGIN
	var size_cells := Vector2(content["sizeCells"][0], content["sizeCells"][1])
	sprite.position = origin + Vector2(size_cells.x * CELL * 0.5, size_cells.y * CELL)
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 0
	y_sort_world.add_child(sprite)
	interactions.append({"type":object_type, "id":object_id, "rect":Rect2(origin, size_cells * CELL), "priority":20})


func _add_crop_visual(farm: Dictionary, content: Dictionary) -> void:
	if farm.get("cropId") == null or content.is_empty(): return
	var planted := int(farm.get("plantedAt", island_data.get("serverTime",0)))
	var ready := int(farm.get("readyAt", planted+1))
	var now := int(island_data.get("serverTime",planted))
	var progress := clampf(float(now-planted)/float(maxi(1,ready-planted)),0.0,1.0)
	var crop := Sprite2D.new()
	crop.texture = load("res://assets/deco/10.png" if progress < 0.5 else "res://assets/deco/07.png")
	var origin := LAND_ORIGIN + Vector2(content["globalCell"][0],content["globalCell"][1])*CELL
	crop.position = origin + Vector2(CELL*0.5,CELL*0.72)
	crop.scale = Vector2.ONE * lerpf(0.34,0.48,progress)
	crop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_world.add_child(crop)


func _build_workers() -> void:
	for worker in island_data.get("islandWorkers", []):
		var visual := _worker_state_visual(worker)
		var sprite := _atlas_sprite(visual["texture"], Rect2(0, 0, 192, 192), 0.42)
		if bool(visual.get("stoneTint", false)):
			var stone_material := ShaderMaterial.new()
			stone_material.shader = WORKER_CARRY_STONE_SHADER
			sprite.material = stone_material
		var cell: Array = worker.get("currentCell", [17, 19])
		sprite.position = LAND_ORIGIN + Vector2(cell[0], cell[1]) * CELL + Vector2(CELL * 0.5, CELL)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 1
		y_sort_world.add_child(sprite)
		var worker_id := str(worker["workerId"])
		worker_sprites[worker_id] = sprite
		worker_animation_state[worker_id] = {
			"sprite": sprite,
			"elapsed": 0.0,
			"frameCount": int(visual["frameCount"]),
			"fps": float(visual["fps"]),
			"lastPosition": sprite.position,
			"visualKey": "%s:%s" % [worker.get("state", "IDLE"), _active_task_type(worker)],
			"worker": worker.duplicate(true),
			"serverTime": int(island_data.get("serverTime", Time.get_unix_time_from_system() * 1000.0)),
			"syncTicks": Time.get_ticks_msec(),
		}


func _active_task_type(worker: Dictionary) -> String:
	var active: Variant = worker.get("activeTask")
	return str(active.get("type", "")) if active is Dictionary else ""


func _build_task_target_highlights() -> void:
	var owner_by_target := target_owners()
	for item in interactions:
		var object_id := str(item.get("id", ""))
		if not owner_by_target.has(object_id):
			continue
		var rect: Rect2 = item["rect"]
		var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
		var glow := Line2D.new()
		glow.name = "QueuedTargetGlow_%s" % object_id
		glow.points = points
		glow.width = 8.0
		glow.default_color = Color(0.28, 0.78, 1.0, 0.20)
		glow.z_index = 38
		world_root.add_child(glow)
		var outline := Line2D.new()
		outline.name = "QueuedTargetOutline_%s" % object_id
		outline.points = points
		outline.width = 3.0
		outline.default_color = Color("79d8ff")
		outline.z_index = 39
		world_root.add_child(outline)


func target_owners() -> Dictionary:
	var result := {}
	for worker in island_data.get("islandWorkers", []):
		for group in worker.get("queue", []):
			if str(group.get("state", "")) in ["COMPLETED", "SKIPPED", "CANCELLED"]:
				continue
			for target_id in group.get("targetIds", []):
				result[str(target_id)] = str(worker.get("workerId", ""))
	return result


func _worker_state_visual(worker: Dictionary) -> Dictionary:
	var state := str(worker.get("state", "IDLE"))
	var active: Dictionary = worker.get("activeTask", {}) if worker.get("activeTask") is Dictionary else {}
	var task_type := str(active.get("type", ""))
	if state == "TRAVELING":
		if task_type == "GATHER_TREE": return _worker_visual(WORKER_RUN_AXE, 6)
		if task_type in ["GATHER_ORE", "GATHER_STONE", "GATHER_GOLD"]: return _worker_visual(WORKER_RUN_PICKAXE, 6)
		if task_type in ["GATHER_MEAT", "PLANT_CROP", "HARVEST_CROP", "BATCH_PLANT", "BATCH_HARVEST"]: return _worker_visual(WORKER_RUN_KNIFE, 6)
		return _worker_visual(WORKER_RUN, 6)
	if state == "RETURNING":
		if task_type == "GATHER_TREE": return _worker_visual(WORKER_CARRY_WOOD, 6)
		if task_type == "GATHER_MEAT": return _worker_visual(WORKER_CARRY_MEAT, 6)
		if task_type in ["GATHER_ORE", "GATHER_STONE"]:
			var stone_visual := _worker_visual(WORKER_CARRY_GOLD, 6)
			stone_visual["stoneTint"] = true
			return stone_visual
		if task_type == "GATHER_GOLD": return _worker_visual(WORKER_CARRY_GOLD, 6)
		return _worker_visual(WORKER_RUN, 6)
	if state == "WORKING":
		if task_type == "GATHER_TREE": return _worker_visual(WORKER_AXE, 6)
		if task_type in ["GATHER_ORE", "GATHER_STONE", "GATHER_GOLD"]: return _worker_visual(WORKER_PICKAXE, 6)
		if task_type in ["GATHER_MEAT", "PLANT_CROP", "HARVEST_CROP", "BATCH_PLANT", "BATCH_HARVEST"]: return _worker_visual(WORKER_FARM, 4)
	return _worker_visual(WORKER_IDLE, 8, 6.0)


func _worker_visual(texture: Texture2D, frame_count: int, fps: float = 8.0) -> Dictionary:
	return {"texture": texture, "frameCount": frame_count, "fps": fps}


func _update_worker_animations(delta: float) -> void:
	for worker_id in worker_animation_state:
		var animation: Dictionary = worker_animation_state[worker_id]
		var sprite := animation.get("sprite") as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		_update_worker_plan_position(animation)
		animation["elapsed"] = float(animation["elapsed"]) + delta
		var frame_count := maxi(1, int(animation["frameCount"]))
		var frame := int(float(animation["elapsed"]) * float(animation["fps"])) % frame_count
		var atlas := sprite.texture as AtlasTexture
		if atlas != null:
			atlas.region = Rect2(frame * 192, 0, 192, 192)
		var last_position: Vector2 = animation["lastPosition"]
		var horizontal_delta := sprite.position.x - last_position.x
		if absf(horizontal_delta) > 0.05:
			# The blue worker source frames face right.
			sprite.flip_h = horizontal_delta < 0.0
		animation["lastPosition"] = sprite.position
		worker_animation_state[worker_id] = animation


func _update_worker_plan_position(animation: Dictionary) -> void:
	var worker: Dictionary = animation.get("worker", {})
	var active: Variant = worker.get("activeTask")
	if not active is Dictionary or active.is_empty():
		return
	var plan: Dictionary = active.get("plan", {})
	var steps: Array = plan.get("steps", [])
	if steps.is_empty():
		return
	var effective_now := int(animation.get("serverTime", 0)) + Time.get_ticks_msec() - int(animation.get("syncTicks", 0))
	var remaining := maxi(0, effective_now - int(plan.get("activatedAt", effective_now)))
	var first_cells: Array = steps[0].get("pathCells", [])
	var current_position := _cell_world_position(first_cells[0] if not first_cells.is_empty() else worker.get("currentCell", [17, 19]))
	var local_state := str(active.get("state", "IDLE"))
	for step_value in steps:
		var step: Dictionary = step_value
		var duration := maxi(1, int(step.get("durationMs", 1)))
		var cells: Array = step.get("pathCells", [])
		if remaining < duration:
			local_state = str(step.get("phase", "IDLE"))
			if cells.size() >= 2:
				var path_progress := clampf(float(remaining) / float(duration), 0.0, 1.0) * float(cells.size() - 1)
				var segment := mini(int(floor(path_progress)), cells.size() - 2)
				current_position = _cell_world_position(cells[segment]).lerp(_cell_world_position(cells[segment + 1]), path_progress - float(segment))
			break
		remaining -= duration
		if not cells.is_empty():
			current_position = _cell_world_position(cells[-1])
	var sprite := animation.get("sprite") as Sprite2D
	if sprite == null:
		return
	sprite.position = current_position
	var visual_worker := worker.duplicate(false)
	visual_worker["state"] = local_state
	var visual := _worker_state_visual(visual_worker)
	var visual_key := "%s:%s" % [local_state, _active_task_type(worker)]
	if str(animation.get("visualKey", "")) != visual_key:
		var atlas := AtlasTexture.new()
		atlas.atlas = visual["texture"]
		atlas.region = Rect2(0, 0, 192, 192)
		sprite.texture = atlas
		sprite.material = null
		if bool(visual.get("stoneTint", false)):
			var material := ShaderMaterial.new()
			material.shader = WORKER_CARRY_STONE_SHADER
			sprite.material = material
		animation["frameCount"] = int(visual["frameCount"])
		animation["fps"] = float(visual["fps"])
		animation["visualKey"] = visual_key
		animation["elapsed"] = 0.0


func _cell_world_position(cell: Variant) -> Vector2:
	return LAND_ORIGIN + Vector2(cell[0], cell[1]) * CELL + Vector2(CELL * 0.5, CELL)


func _build_client_astar() -> void:
	island_astar = AStarGrid2D.new()
	island_astar.region = Rect2i(0, 0, LAND_COLUMNS, LAND_ROWS)
	island_astar.cell_size = Vector2(CELL, CELL)
	island_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	island_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	island_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	island_astar.update()
	for plot in island_data.get("plots", []):
		if str(plot.get("status", "LOCKED")) == "UNLOCKED": continue
		var origin := Vector2i(int(plot["originCell"][0]),int(plot["originCell"][1]))
		for y in range(7):
			for x in range(7): island_astar.set_point_solid(origin + Vector2i(x,y),true)
	for content in _content_config_by_id().values():
		if str(content.get("type", "")) == "marker": continue
		var origin := Vector2i(int(content["globalCell"][0]),int(content["globalCell"][1]))
		var footprint := Vector2i(int(content["sizeCells"][0]),int(content["sizeCells"][1]))
		for y in range(footprint.y):
			for x in range(footprint.x): island_astar.set_point_solid(origin + Vector2i(x,y),true)


func _build_locked_plots() -> void:
	for plot in island_data.get("plots", []):
		if str(plot.get("status", "LOCKED")) == "UNLOCKED":
			continue
		var origin := LAND_ORIGIN + Vector2(plot["originCell"][0], plot["originCell"][1]) * CELL
		var fog := _atlas_sprite(ISLAND_OBJECTS, Rect2(1240, 20, 633, 820), 0.34)
		fog.position = origin + Vector2(112, 120)
		fog.z_index = 50 + int(plot["plotId"])
		world_root.add_child(fog)
		fog_by_plot[int(plot["plotId"])] = fog
		interactions.append({"type":"plot", "id":str(plot["plotId"]), "plotId":int(plot["plotId"]), "rect":Rect2(origin, Vector2(224,224)), "priority":200})


func _build_natural_details() -> void:
	var details := [
		["res://assets/deco/01.png", Vector2(95, 245), 0.72],
		["res://assets/deco/07.png", Vector2(178, 1060), 0.78],
		["res://assets/deco/10.png", Vector2(640, 900), 0.75],
		["res://assets/deco/12.png", Vector2(78, 680), 0.72],
		["res://assets/deco/17.png", Vector2(630, 220), 0.62],
	]
	for item in details:
		var sprite := Sprite2D.new()
		sprite.texture = load(item[0])
		sprite.position = item[1]
		sprite.scale = Vector2.ONE * item[2]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 0
		y_sort_world.add_child(sprite)


func _content_config_by_id() -> Dictionary:
	var result := {}
	for plot in island_data.get("plots", []):
		var plot_origin := Vector2i(int(plot["originCell"][0]), int(plot["originCell"][1]))
		for content in plot.get("contents", []):
			var local := Vector2i(int(content["localCell"][0]), int(content["localCell"][1]))
			result[str(content["instanceKey"])] = {
				"globalCell":[plot_origin.x + local.x, plot_origin.y + local.y],
				"sizeCells":content["sizeCells"],
				"type":content["type"],
			}
	return result


func _single_texture_tileset(texture: Texture2D) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(64, 64)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	return tile_set


func _atlas_sprite(texture: Texture2D, region: Rect2, sprite_scale: float) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.scale = Vector2.ONE * sprite_scale
	return sprite


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(event.position, zoom * 1.16)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(event.position, zoom / 1.16)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				press_position = event.position
				last_pointer = event.position
			else:
				if dragging and event.position.distance_to(press_position) <= DRAG_THRESHOLD:
					select_at(event.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		camera_center -= (event.position - last_pointer) / zoom
		camera_center = _clamped_center(camera_center)
		last_pointer = event.position
		_update_world_transform()
	elif event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
			if active_touches.size() == 1:
				press_position = event.position
				last_pointer = event.position
			elif active_touches.size() == 2:
				pinch_distance = _touch_distance()
		else:
			if active_touches.size() == 1 and event.position.distance_to(press_position) <= DRAG_THRESHOLD:
				select_at(event.position)
			active_touches.erase(event.index)
			pinch_distance = _touch_distance() if active_touches.size() == 2 else 0.0
	elif event is InputEventScreenDrag:
		if not active_touches.has(event.index):
			return
		active_touches[event.index] = event.position
		if active_touches.size() == 1:
			camera_center -= event.relative / zoom
			camera_center = _clamped_center(camera_center)
			_update_world_transform()
		elif active_touches.size() == 2:
			var distance := _touch_distance()
			if pinch_distance > 0.0:
				zoom_at(_touch_center(), zoom * distance / pinch_distance)
			pinch_distance = distance


func select_at(screen_point: Vector2) -> void:
	var world := _screen_to_world(screen_point)
	var sorted := interactions.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) > int(b["priority"]))
	for item in sorted:
		if not (item["rect"] as Rect2).has_point(world):
			continue
		match str(item["type"]):
			"worker": worker_selected.emit(str(item["id"]))
			"plot": plot_selected.emit(int(item["plotId"]))
			_: object_selected.emit(str(item["type"]), str(item["id"]))
		return
	for plot in island_data.get("plots", []):
		var origin := LAND_ORIGIN + Vector2(plot["originCell"][0], plot["originCell"][1]) * CELL
		if Rect2(origin, Vector2(224,224)).has_point(world):
			if str(plot.get("status", "LOCKED")) == "UNLOCKED":
				var cell := Vector2i(floori((world.x - LAND_ORIGIN.x) / CELL), floori((world.y - LAND_ORIGIN.y) / CELL))
				if island_astar != null and island_astar.is_in_boundsv(cell) and not island_astar.is_point_solid(cell):
					ground_selected.emit(cell)
			else:
				plot_selected.emit(int(plot["plotId"]))
			return


func zoom_at(screen_point: Vector2, requested: float) -> void:
	var old_world := _screen_to_world(screen_point)
	zoom = clampf(requested, 1.0, 2.5)
	camera_center = old_world - (screen_point - size * 0.5) / zoom
	camera_center = _clamped_center(camera_center)
	_update_world_transform()


func _update_world_transform() -> void:
	if world_root == null:
		return
	world_root.scale = Vector2.ONE * zoom
	world_root.position = size * 0.5 - camera_center * zoom


func _clamped_center(value: Vector2) -> Vector2:
	var half := size * 0.5 / zoom
	return Vector2(clampf(value.x, half.x, WORLD_SIZE.x - half.x), clampf(value.y, half.y, WORLD_SIZE.y - half.y))


func _screen_to_world(point: Vector2) -> Vector2:
	return camera_center + (point - size * 0.5) / zoom


func _touch_distance() -> float:
	var points := active_touches.values()
	return points[0].distance_to(points[1]) if points.size() == 2 else 0.0


func _touch_center() -> Vector2:
	var points := active_touches.values()
	return (points[0] + points[1]) * 0.5
