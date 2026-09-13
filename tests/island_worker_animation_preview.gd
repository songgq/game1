extends SceneTree

const ISLAND_VIEW := preload("res://scripts/island/island_map_view.gd")
var preview_viewport: SubViewport


func _initialize() -> void:
	root.size = Vector2i(720, 720)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(720, 720)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(preview_viewport)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/island_plots.json"))
	var workers := [
		_worker("tree_travel", [9, 17], "TRAVELING", "GATHER_TREE"),
		_worker("tree_work", [11, 17], "WORKING", "GATHER_TREE"),
		_worker("tree_return", [13, 17], "RETURNING", "GATHER_TREE"),
		_worker("ore_travel", [9, 19], "TRAVELING", "GATHER_ORE"),
		_worker("ore_work", [11, 19], "WORKING", "GATHER_ORE"),
		_worker("ore_return", [13, 19], "RETURNING", "GATHER_ORE"),
		_worker("meat_travel", [9, 21], "TRAVELING", "GATHER_MEAT"),
		_worker("meat_work", [11, 21], "WORKING", "GATHER_MEAT"),
		_worker("meat_return", [13, 21], "RETURNING", "GATHER_MEAT"),
		_worker("gold_travel", [9, 23], "TRAVELING", "GATHER_GOLD"),
		_worker("gold_work", [11, 23], "WORKING", "GATHER_GOLD"),
		_worker("gold_return", [13, 23], "RETURNING", "GATHER_GOLD"),
	]
	var payload := {"ok":true, "serverTime":1800000000000, "map":config["map"], "plots":[], "resourceNodes":[], "farmPlots":[], "buildings":[], "islandWorkers":workers}
	for plot in config["plots"]:
		var rendered: Dictionary = plot.duplicate(true)
		rendered["status"] = "UNLOCKED"
		payload["plots"].append(rendered)
	var view := ISLAND_VIEW.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_viewport.add_child(view)
	view.configure(payload)
	view.zoom = 2.5
	view.camera_center = Vector2(384, 720)
	view._update_world_transform()
	_capture.call_deferred()


func _worker(worker_id: String, cell: Array, state: String, task_type: String) -> Dictionary:
	return {"workerId":worker_id, "currentCell":cell, "state":state, "activeTaskId":worker_id + "_task", "activeTask":{"type":task_type, "state":state, "plan":{}}, "queue":[]}


func _capture() -> void:
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var image := preview_viewport.get_texture().get_image()
	var result := image.save_png("res://island_worker_animation_preview.png")
	print("ISLAND_WORKER_ANIMATION_PREVIEW_RESULT:", result)
	quit(0 if result == OK else 1)
