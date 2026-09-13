extends SceneTree

var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	var waited := 0.0
	while not game.cloud_ready and waited < 10.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(game.cloud_ready, "guest cloud account was not initialized")
	check(game.account_token.length() > 20, "account token was not persisted")
	game.player_lineup = ["warrior", "lancer", "archer", "monk", "worker"]
	game.strategy_messages = ["1号先攻击僧侣", "5号采集肉"]
	var compiled: Dictionary = await game.request_compiled_strategy()
	check(bool(compiled.get("ok", false)), "strategy compile failed")
	if not bool(compiled.get("ok", false)):
		_finish()
		return
	game.active_battle_request_id = "cloud_history_" + str(Time.get_ticks_usec())
	var replay_response: Dictionary = await game.request_battle_replay(Dictionary(compiled["strategy"]))
	if not bool(replay_response.get("ok", false)):
		print("CLOUD_HISTORY_REPLAY_ERROR ", replay_response)
	check(bool(replay_response.get("ok", false)), "authoritative simulation failed")
	var history: Dictionary = await game.api_request("/battles?limit=5", HTTPClient.METHOD_GET)
	check(bool(history.get("ok", false)), "history request failed")
	check(not Array(history.get("battles", [])).is_empty(), "simulated battle was not persisted")
	if not Array(history.get("battles", [])).is_empty():
		var battle: Dictionary = history["battles"][0]
		var stored: Dictionary = await game.api_request("/battles/%s/replay" % String(battle["id"]), HTTPClient.METHOD_GET)
		check(bool(stored.get("ok", false)), "stored replay could not be loaded")
		check(Array(stored.get("replay", {}).get("frames", [])).size() > 10, "stored replay has no frames")
	_finish()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CLOUD_HISTORY_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
