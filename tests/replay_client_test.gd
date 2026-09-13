extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var file := FileAccess.open("/tmp/replay_test.json", FileAccess.READ)
	check(file != null, "server replay fixture is missing")
	if file == null:
		quit(1)
		return
	var envelope: Variant = JSON.parse_string(file.get_as_text())
	check(envelope is Dictionary and bool(envelope.get("ok", false)), "invalid replay envelope")
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.active_replay = Dictionary(envelope["replay"]).duplicate(true)
	game.player_lineup = ["warrior", "lancer", "archer", "monk", "worker"]
	game.active_strategy = {}
	Engine.time_scale = 30.0
	await game.start_game()
	var wall_frames := 0
	while not game.battle_finished and wall_frames < 1000:
		await process_frame
		wall_frames += 1
	check(game.replay_mode, "client did not enter replay-only mode")
	check(game.battle_finished, "client replay did not finish")
	check(game.replay_outcome == String(envelope["replay"]["result"]["outcome"]), "client result differs from server result")
	check(game.replay_frame_index == Array(envelope["replay"]["frames"]).size() - 1, "client did not consume all server frames")
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("REPLAY_CLIENT_TEST_OK outcome=", game.replay_outcome, " frames=", game.replay_frame_index + 1)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
