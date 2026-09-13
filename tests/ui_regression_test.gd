extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.test_mode = true
	await capture_screen(game, "main", Callable(game, "show_main_menu"))
	await capture_screen(game, "settings", Callable(game, "show_settings"))
	await capture_screen(game, "lineup", Callable(game, "show_lineup_screen"))
	game.battle_history = [{
		"id": "test", "outcome": "victory", "duration_seconds": 38.4,
		"created_at": "2026-08-16T20:30:00", "lineup": game.player_lineup.duplicate(),
		"strategy_snapshot": {},
	}]
	game.build_battle_history_screen(true)
	await process_frame
	await verify_screen(game, "history")
	game.strategy_messages = ["1、2、5号：集火僧侣", "3号：采集肉", "4号：治疗血量比例最低的队友", "4号别过桥"]
	game.strategy_notice = "策略已保存，等待发送"
	game.strategy_voice_mode = true
	game.show_strategy_screen()
	await process_frame
	await verify_screen(game, "strategy")
	game.queue_free()
	if failures.is_empty():
		print("UI_REGRESSION_TEST_OK /tmp/emerald-ui-*.png")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func capture_screen(game: Node, screen_name: String, callback: Callable) -> void:
	callback.call()
	await process_frame
	await process_frame
	await verify_screen(game, screen_name)

func verify_screen(game: Node, screen_name: String) -> void:
	for node in nodes_below(game):
		var renders_text: bool = node is Label or node is LineEdit or node is OptionButton or (node is Button and node.text != "")
		if renders_text:
			if not node.has_theme_font_override("font"):
				failures.append("%s: text control without bundled Chinese font: %s" % [screen_name, node.name])
		if node is Button and node.visible and not node.flat:
			var rect := Rect2(node.position, node.size)
			if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 720.1 or rect.end.y > 1280.1:
				failures.append("%s: interactive control outside viewport: %s %s" % [screen_name, node.name, rect])
	var image := root.get_texture().get_image()
	if image == null or image.save_png("/tmp/emerald-ui-%s.png" % screen_name) != OK:
		failures.append("%s: screenshot failed" % screen_name)

func nodes_below(parent: Node) -> Array:
	var result: Array = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(nodes_below(child))
	return result
