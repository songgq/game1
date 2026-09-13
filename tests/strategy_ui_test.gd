extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.player_lineup = ["warrior", "lancer", "archer", "monk", "worker"]
	game.strategy_messages = ["1号走左桥，然后去砍树", "4号优先治疗1号，不要治疗工人"]
	game.strategy_dirty = false
	game.strategy_ready = true
	game.strategy_notice = "全队已确认，可以开始战斗"
	game.strategy_send_history = [{
		"revision": 1,
		"count": 5,
		"replies": [
			"能做的部分收到！不过我这把剑是打仗的，不是砍树的！",
			"2号收到！",
			"明白，3号按计划行动！",
			"4号听清楚了！",
			"5号收到！"
		]
	}]
	game.show_strategy_screen()
	await process_frame
	await process_frame
	var found_refusal := false
	var found_battle_button := false
	for node in nodes_below(game):
		if node is Label and "不是砍树" in node.text:
			found_refusal = true
		if node is Button and node.text == "开始战斗" and not node.disabled:
			found_battle_button = true
	if not found_refusal or not found_battle_button:
		push_error("strategy UI content/state mismatch")
		quit(1)
		return
	var voice_button := game.get_node_or_null("StrategyVoiceButton") as Button
	var mode_button := game.get_node_or_null("StrategyComposerToggle") as Button
	var strategy_select := game.get_node_or_null("StrategyTemplateSelect") as OptionButton
	var chat_scroll := game.get_node_or_null("StrategyChatScroll") as ScrollContainer
	if voice_button == null or mode_button == null or mode_button.text != "" or mode_button.icon == null or strategy_select == null or not strategy_select.get_popup().has_theme_font_override("font") or chat_scroll == null or game.get_node_or_null("StrategyPasteButton") != null:
		push_error("default voice composer mismatch")
		quit(1)
		return
	var voice_image := root.get_texture().get_image()
	if voice_image == null or voice_image.save_png("/tmp/emerald-strategy-voice-ui.png") != OK:
		push_error("strategy voice UI screenshot failed")
		quit(1)
		return
	game.toggle_strategy_input_mode()
	await process_frame
	var strategy_input := game.get_node_or_null("StrategyCommandInput") as LineEdit
	mode_button = game.get_node_or_null("StrategyComposerToggle") as Button
	var send_button := game.get_node_or_null("StrategySendButton") as Button
	chat_scroll = game.get_node_or_null("StrategyChatScroll") as ScrollContainer
	if strategy_input == null or mode_button == null or mode_button.text != "" or mode_button.icon == null or send_button == null or chat_scroll == null:
		push_error("strategy text composer missing")
		quit(1)
		return
	strategy_input.grab_focus()
	await process_frame
	await process_frame
	if strategy_input.position.y != 565.0 or mode_button.position.y != 565.0 or send_button.position.y != 565.0 or chat_scroll.size.y != 125.0:
		push_error("strategy keyboard layout did not move above virtual keyboard")
		quit(1)
		return
	var keyboard_image := root.get_texture().get_image()
	if keyboard_image == null or keyboard_image.save_png("/tmp/emerald-strategy-keyboard-ui.png") != OK:
		push_error("strategy keyboard UI screenshot failed")
		quit(1)
		return
	strategy_input.release_focus()
	await process_frame
	if strategy_input.position.y != 900.0 or mode_button.position.y != 900.0 or send_button.position.y != 900.0 or chat_scroll.size.y != 445.0:
		push_error("strategy keyboard layout did not restore after focus")
		quit(1)
		return
	game.edit_strategy_message(1)
	await process_frame
	await process_frame
	var edit_bar := game.get_node_or_null("StrategyEditBar") as ColorRect
	var cancel_edit := game.get_node_or_null("StrategyCancelEditButton") as Button
	var delete_message := game.get_node_or_null("StrategyDeleteMessageButton") as Button
	var composer := game.get_node_or_null("StrategyComposerBackground") as ColorRect
	chat_scroll = game.get_node_or_null("StrategyChatScroll") as ScrollContainer
	if edit_bar == null or cancel_edit == null or delete_message == null or composer == null or chat_scroll == null:
		push_error("strategy edit action bar missing")
		quit(1)
		return
	if chat_scroll.size.y != 390.0 or delete_message.position.y + delete_message.size.y >= composer.position.y:
		push_error("strategy edit actions overlap composer")
		quit(1)
		return
	var edit_image := root.get_texture().get_image()
	if edit_image == null or edit_image.save_png("/tmp/emerald-strategy-edit-ui.png") != OK:
		push_error("strategy edit UI screenshot failed")
		quit(1)
		return
	var image := root.get_texture().get_image()
	var save_error := image.save_png("/tmp/emerald-strategy-ui.png")
	if save_error != OK:
		push_error("strategy UI screenshot failed")
		quit(1)
		return
	print("STRATEGY_UI_TEST_OK /tmp/emerald-strategy-ui.png")
	quit(0)

func nodes_below(parent: Node) -> Array:
	var result: Array = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(nodes_below(child))
	return result
