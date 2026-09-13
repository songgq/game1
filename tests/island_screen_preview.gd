extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720,1280)
	var game = load("res://main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/island_plots.json"))
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/recipes.json"))
	var crops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/crops.json"))
	var active_plan := {"activatedAt":1799999998000,"stepIndex":0,"steps":[{"phase":"TRAVELING","durationMs":8000,"pathCells":[[17,19],[16,19],[15,19],[14,19],[13,19]],"targetId":"tree_2a"},{"phase":"WORKING","durationMs":5000,"action":"GATHER","targetId":"tree_2a"},{"phase":"RETURNING","durationMs":8000,"pathCells":[[13,19],[14,19],[15,19],[16,19],[17,19]],"targetId":"storage_chest"},{"phase":"DEPOSITING","durationMs":800,"action":"DEPOSIT"}]}
	var active_task := {"taskId":"preview_task_1","type":"GATHER_TREE","state":"TRAVELING","phaseStartedAt":1799999998000,"phaseEndsAt":1800000006000,"plan":active_plan}
	var queue := [{"groupId":"preview_group","taskIds":["preview_task_1","preview_task_2"],"type":"GATHER_TREE","targetIds":["tree_2a"],"quantity":2,"state":"IN_PROGRESS","cancelRequested":false},{"groupId":null,"taskIds":["preview_move"],"type":"MOVE_TO_CELL","targetIds":[],"targetCell":[12,19],"quantity":1,"state":"QUEUED","cancelRequested":false}]
	var payload := {"ok":true,"serverTime":1800000000000,"playerLevel":1,"map":config["map"],"plots":[],"resourceNodes":[],"farmPlots":[],"buildings":[],"islandWorkers":[{"workerId":"island_worker_1","currentCell":[17,19],"state":"TRAVELING","activeTaskId":"preview_task_1","activeTask":active_task,"queue":queue}],"inventory":[],"recipes":recipes["recipes"],"crops":crops["crops"]}
	for plot in config["plots"]:
		var rendered: Dictionary = plot.duplicate(true)
		rendered["status"] = "UNLOCKED" if int(plot["plotId"]) <= 4 else "LOCKED"
		rendered["costState"] = []
		rendered["canUnlock"] = false
		payload["plots"].append(rendered)
		if int(plot["plotId"]) > 4: continue
		for content in plot["contents"]:
			var base := {"plotId":plot["plotId"],"localCell":content["localCell"]}
			var value := base.duplicate()
			match str(content["type"]):
				"resource": value.merge({"instanceId":content["instanceKey"],"resourceType":content["contentId"],"charges":3}); payload["resourceNodes"].append(value)
				"farm": value.merge({"farmPlotId":content["instanceKey"],"farmType":content["contentId"],"cropId":null,"readyAt":null,"reservedByTaskId":null}); payload["farmPlots"].append(value)
				"building": value.merge({"buildingId":content["instanceKey"],"buildingType":content["contentId"],"state":content.get("state","READY")}); payload["buildings"].append(value)
	game._render_island(payload)
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	var image := root.get_texture().get_image()
	var result := image.save_png("res://island_full_screen_preview.png")
	print("ISLAND_FULL_SCREEN_PREVIEW_RESULT:",result)
	game.queue_free()
	quit(0 if result == OK else 1)
