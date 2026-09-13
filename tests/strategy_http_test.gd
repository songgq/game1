extends SceneTree

const RULES := preload("res://scripts/strategy_rules.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lineup := ["warrior", "lancer", "archer", "monk", "worker"]
	var request := HTTPRequest.new()
	request.timeout = 245.0
	root.add_child(request)
	var payload := JSON.stringify({"lineup": lineup, "messages": ["1号战士去砍树"]})
	var start_error := request.request("http://127.0.0.1:19031/compile", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, payload)
	if start_error != OK:
		fail("request start failed: %d" % start_error)
		return
	var completed: Array = await request.request_completed
	if completed.size() < 4 or int(completed[0]) != HTTPRequest.RESULT_SUCCESS or int(completed[1]) != 200:
		fail("request failed: %s" % [completed])
		return
	var response: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	if not response is Dictionary or not bool(response.get("ok", false)):
		fail("invalid API envelope")
		return
	var strategy: Variant = response.get("strategy")
	if not RULES.validate_document(strategy, lineup):
		fail("client rejected strategy document")
		return
	var result := RULES.result_for_slot(strategy, 1)
	var reply := RULES.build_reply(result, "warrior", 1, 1)
	if String(result.get("status")) != "rejected" or "收到" in reply:
		fail("illegal gather did not produce rejection")
		return
	print("STRATEGY_HTTP_TEST_OK reply=", reply)
	request.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
