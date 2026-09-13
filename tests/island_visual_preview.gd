extends SceneTree

const ISLAND_VIEW := preload("res://scripts/island/island_map_view.gd")
var preview_viewport: SubViewport


func _initialize() -> void:
	root.size = Vector2i(720, 1280)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(720, 1280)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(preview_viewport)
	var file := FileAccess.open("res://config/island_plots.json", FileAccess.READ)
	var config: Dictionary = JSON.parse_string(file.get_as_text())
	var payload := {
		"ok":true,
		"serverTime":1800000000000,
		"map":config["map"],
		"plots":[],
		"resourceNodes":[],
		"farmPlots":[],
		"buildings":[],
		"islandWorkers":[{"workerId":"island_worker_1","currentCell":[17,19],"state":"IDLE","activeTaskId":null,"queue":[]}],
	}
	for plot in config["plots"]:
		var rendered: Dictionary = plot.duplicate(true)
		rendered["status"] = "UNLOCKED" if int(plot["plotId"]) <= 4 else "LOCKED"
		payload["plots"].append(rendered)
		if int(plot["plotId"]) > 4: continue
		for content in plot["contents"]:
			var base := {"plotId":plot["plotId"],"localCell":content["localCell"]}
			match str(content["type"]):
				"resource":
					var value := base.duplicate(); value.merge({"instanceId":content["instanceKey"],"resourceType":content["contentId"],"charges":3}); payload["resourceNodes"].append(value)
				"farm":
					var value := base.duplicate(); value.merge({"farmPlotId":content["instanceKey"],"farmType":content["contentId"],"cropId":null,"readyAt":null}); payload["farmPlots"].append(value)
				"building":
					var value := base.duplicate(); value.merge({"buildingId":content["instanceKey"],"buildingType":content["contentId"],"state":content.get("state","READY")}); payload["buildings"].append(value)
	var view := ISLAND_VIEW.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_viewport.add_child(view)
	view.configure(payload)
	_capture.call_deferred()


func _capture() -> void:
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	var image := preview_viewport.get_texture().get_image()
	var result := image.save_png("res://island_tilemap_preview.png")
	print("ISLAND_TILEMAP_PREVIEW_RESULT:", result)
	quit()
