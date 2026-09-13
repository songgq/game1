extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var hero := {
		"heroId":"warrior", "name":"战士", "role":"前排", "level":1, "maxLevel":15,
		"cardCount":99, "battleStats":{"maxHp":100,"physicalAttack":20,"physicalDefense":10,"magicDefense":8,"skillPower":0},
		"nextUpgrade":{"heroCards":2,"coins":50,"playerXp":20}
	}
	game.player_gold = 1000
	game._render_hero_growth({"ok":true,"heroes":[hero]})
	await process_frame
	check(has_text(game, "战士  Lv1/15"), "hero screen must render the authoritative hero level")
	check(has_text(game, "英雄卡 99/2"), "hero screen must render cards and cost")

	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/island_plots.json"))
	for configured_plot in config["plots"]:
		for configured_content in configured_plot["contents"]:
			if str(configured_content["type"]) == "farm":
				var configured_size: Array = configured_content["sizeCells"]
				check(configured_size.size() == 2 and int(configured_size[0]) == 1 and int(configured_size[1]) == 1, "every farm must occupy exactly one 1x1 LandGrid cell")
	var crops_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/crops.json"))
	var plots: Array = []
	for raw in config["plots"]:
		var plot: Dictionary = raw.duplicate(true)
		plot["status"] = "UNLOCKED" if int(plot["plotId"]) <= 4 else "LOCKED"
		plot["costState"] = []
		plot["canUnlock"] = false
		plots.append(plot)
	var island := {"ok":true,"serverTime":1800000000000,"playerLevel":1,"map":config["map"],"plots":plots,
		"resourceNodes":[{"instanceId":"tree_2a","plotId":2,"resourceType":"normal_tree","localCell":[3,4],"charges":3}],
		"farmPlots":[{"farmPlotId":"farm_2a","plotId":2,"farmType":"normal_farm","localCell":[1,1],"cropId":null,"readyAt":null,"reservedByTaskId":null}],
		"buildings":[{"buildingId":"home","plotId":1,"buildingType":"home","localCell":[1,1],"state":"READY"},{"buildingId":"storage_chest","plotId":1,"buildingType":"storage_chest","localCell":[5,1],"state":"READY"}],
		"islandWorkers":[{"workerId":"island_worker_1","currentCell":[17,19],"state":"IDLE","activeTaskId":null,"activeTask":null,"queue":[{"groupId":"g1","taskIds":["t1"],"type":"GATHER_TREE","targetIds":["tree_2a"],"quantity":1,"state":"QUEUED","cancelRequested":false}]}],"inventory":[],"recipes":[],"crops":crops_config["crops"]}
	game._render_island(island)
	await process_frame
	var view: Control = game.get_node_or_null("IslandMapView")
	check(view != null, "island screen must include the interactive map")
	check(game.get_node_or_null("IslandUnlockButton") != null, "island screen must include unlock interaction")
	check(game.get_node_or_null("IslandOptionButton") != null, "island screen must include crop/recipe selection")
	check(game.get_node_or_null("IslandResourceStrip") != null, "island screen must show authoritative economy values")
	check(game.get_node_or_null("IslandWorkerDock") != null, "island screen must expose the worker icon and horizontal queue dock")
	check(game.selected_island_worker == "island_worker_1", "the first IslandWorker must be selected by default")
	if view != null:
		check(count_type(view,"TileMapLayer") >= 3, "island world must use TileMapLayer instead of debug rectangles")
		check(view.island_astar.region == Rect2i(0,0,21,35), "client island AStar must be the independent 21x35 LandGrid")
		check(not view.island_astar.is_point_solid(Vector2i(17,19)), "IslandWorker spawn marker must remain walkable in the client presentation grid")
		check(String(view._worker_state_visual({"state":"TRAVELING","activeTask":{"type":"GATHER_TREE"}})["texture"].resource_path).ends_with("blue_run_axe.png"), "tree travel must use the running axe frames")
		check(String(view._worker_state_visual({"state":"TRAVELING","activeTask":{"type":"GATHER_ORE"}})["texture"].resource_path).ends_with("blue_run_pickaxe.png"), "ore travel must use the running pickaxe frames")
		check(String(view._worker_state_visual({"state":"TRAVELING","activeTask":{"type":"HARVEST_CROP"}})["texture"].resource_path).ends_with("blue_run_knife.png"), "farm travel must use the running knife frames")
		check(String(view._worker_state_visual({"state":"RETURNING","activeTask":{"type":"GATHER_TREE"}})["texture"].resource_path).ends_with("blue_carry_wood.png"), "tree return must visibly carry wood")
		check(String(view._worker_state_visual({"state":"RETURNING","activeTask":{"type":"GATHER_MEAT"}})["texture"].resource_path).ends_with("blue_carry_meat.png"), "meat return must visibly carry meat")
		check(bool(view._worker_state_visual({"state":"RETURNING","activeTask":{"type":"GATHER_ORE"}}).get("stoneTint", false)), "ore return must use the distinct stone palette")
		check(String(view._worker_state_visual({"state":"RETURNING","activeTask":{"type":"GATHER_GOLD"}})["texture"].resource_path).ends_with("blue_carry_gold.png"), "gold return must visibly carry gold")
		var tree_frame_found := false
		for node in nodes_below(view):
			if node is Sprite2D and node.texture is AtlasTexture:
				var atlas := node.texture as AtlasTexture
				if atlas.atlas != null and String(atlas.atlas.resource_path).ends_with("tree.png"):
					tree_frame_found = true
					check(atlas.region.size == Vector2(192,192), "island tree must crop one complete frame without the next-row tree tip")
		check(tree_frame_found, "island must render its configured tree resource")
		check(view.world_root.get_node_or_null("QueuedTargetOutline_tree_2a") != null, "queued targets must have a pale-blue ownership outline")
		var worker_sprite := view.worker_sprites.get("island_worker_1") as Sprite2D
		if worker_sprite != null:
			worker_sprite.position.x -= 5.0
			view._update_worker_animations(0.2)
			check(worker_sprite.flip_h, "worker moving left must face left")
		view.zoom_at(Vector2(360, 640), 9.0)
		check(is_equal_approx(view.zoom, 2.5), "island zoom must clamp to 2.5")
		view.zoom_at(Vector2(360, 640), 0.1)
		check(is_equal_approx(view.zoom, 1.0), "island zoom must not show a map smaller than the viewport")
		view.zoom_at(Vector2(360,640),2.0)
		var preserved_center: Vector2 = view.camera_center
		view.update_server_state(island)
		check(is_equal_approx(view.zoom,2.0) and view.camera_center == preserved_center, "runtime refresh must preserve island camera and zoom")
	game._select_island_plot(5)
	check(has_text(game, "5号地 · 需Lv3"), "locked plot selection must explain its level requirement")
	game._select_island_worker("island_worker_1")
	check(has_text(game,"工人1已选中"),"island interaction must require and display the selected IslandWorker")
	game._select_island_object("farm", "farm_2a")
	check(has_text(game, "播种青芽草") or has_text(game, "购买青芽草种子"), "normal farm must default to the first compatible configured crop")
	game._island_option_action()
	check(has_text(game, "播种红根草") or has_text(game, "购买红根草种子"), "crop switch must use the next compatible configured crop")
	game.queue_free()
	if failures.is_empty():
		print("PHASE1_PHASE3_UI_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func has_text(parent: Node, fragment: String) -> bool:
	for node in nodes_below(parent):
		if (node is Label or node is Button) and fragment in String(node.text):
			return true
	return false

func nodes_below(parent: Node) -> Array:
	var result: Array = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(nodes_below(child))
	return result

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func count_type(parent: Node, class_name_value: String) -> int:
	var count := 0
	for node in nodes_below(parent):
		if node.get_class() == class_name_value: count += 1
	return count
