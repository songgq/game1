extends SceneTree

const STATE_MACHINE := preload("res://scripts/strategy_v3/rule_state_machine.gd")
const RULE_ARBITER := preload("res://scripts/strategy_v3/rule_arbiter.gd")
const RESOURCE_ARBITER := preload("res://scripts/strategy_v3/action_resource_arbiter.gd")
const TARGET_ROLES := preload("res://scripts/strategy_v3/target_roles.gd")
const EVENT_QUEUE := preload("res://scripts/strategy_v3/deterministic_event_queue.gd")
const CONDITION := preload("res://scripts/strategy_v3/condition_evaluator.gd")
const SELECTOR := preload("res://scripts/strategy_v3/selector_engine.gd")
const RUNTIME := preload("res://scripts/strategy_v3/strategy_runtime_v3.gd")
const PHASE_MACHINE := preload("res://scripts/strategy_v3/phase_machine.gd")

var failures: Array = []

func _initialize() -> void:
	test_state_machine()
	test_arbitration()
	test_event_latency_and_order()
	test_target_ownership()
	test_condition_and_selector()
	test_runtime_commit()
	test_runtime_preempt_resume()
	test_recovery_cancel_and_restart()
	test_interrupt_denied_then_deferred()
	test_hysteresis_and_never_retrigger()
	test_active_action_is_not_recommitted()
	test_fallback_and_target_binding()
	test_multi_resource_atomicity()
	test_bounded_phase_machine()
	if failures.is_empty():
		print("STRATEGY_V3_RUNTIME_SEMANTICS_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func base_rule(id: String, priority: String, channel: String, resource: String) -> Dictionary:
	return {"id": id, "actorIds": ["blue_3"], "channel": channel, "priorityClass": priority,
		"priorityModifier": 0, "specificityClass": "EXACT", "sourceOrder": 1,
		"when": {"op":"eq","left":{"node":"field","path":"self.is_alive"},"right":{"node":"const","value":true}},
		"targetBinding": null, "resourceClaims": [{"resource":resource,"mode":"exclusive"}],
		"action": {"opcode":"move_to_position","interruptClass":"TACTICAL_MOVE","interruptibleBy":["EMERGENCY_SURVIVAL","SYSTEM_FORCE"]},
		"until": null, "fallback": null, "runtimePrerequisites": [],
		"execution":{"recoveryPolicy":"resume","retriggerPolicy":"on_condition_reenter","minActiveTicks":2,"cooldownTicks":2,"replanIntervalTicks":6,"replanEvents":["damage_received"]},
		"sourceMessageIds":["m1"]}

func test_state_machine() -> void:
	var machine := STATE_MACHINE.new()
	var rule := base_rule("r1", "TACTICAL_MOVE", "locomotion", "MOVE")
	machine.register_rule(rule)
	check(machine.observe_condition(rule, true, 1) == "PENDING", "when enter should pend")
	check(machine.commit("r1", 1) and machine.state("r1") == "ACTIVE", "commit should activate")
	check(not machine.complete_if_allowed(rule, true, 2), "minimum active ticks should block early completion")
	check(machine.complete_if_allowed(rule, true, 3), "until should complete after minimum")
	check(machine.observe_condition(rule, false, 4) == "COMPLETED", "terminal rule should observe false without immediate rearm")
	check(machine.observe_condition(rule, true, 5) == "PENDING", "condition reentry after cooldown should rearm")
	check(not machine.transition("r1", "COMPLETED", 6, "ILLEGAL"), "pending cannot skip commit")

func test_arbitration() -> void:
	var low := base_rule("low", "TACTICAL_MOVE", "locomotion", "MOVE")
	var high := base_rule("high", "EMERGENCY_SURVIVAL", "survival", "MOVE")
	high["action"]["interruptClass"] = "EMERGENCY_SURVIVAL"
	var channels := RULE_ARBITER.new().winners_by_channel([low, high])
	check(channels.size() == 2, "each channel should produce a winner")
	var result := RESOURCE_ARBITER.new().arbitrate(channels)
	check(result["granted"].size() == 1 and result["granted"][0]["id"] == "high", "only survival should win MOVE")
	var old := base_rule("old", "TACTICAL_MOVE", "locomotion", "MOVE")
	var latest := base_rule("latest", "TACTICAL_MOVE", "locomotion", "MOVE"); latest["sourceOrder"] = 2
	check(RULE_ARBITER.new().winners_by_channel([old, latest])["locomotion"]["id"] == "latest",
		"later message must win an otherwise equal channel arbitration")

func test_event_latency_and_order() -> void:
	var queue := EVENT_QUEUE.new()
	queue.enqueue({"phaseOrder":14,"eventTypeOrder":2,"sourceEntityId":"b","targetEntityId":"x"})
	queue.enqueue({"phaseOrder":14,"eventTypeOrder":1,"sourceEntityId":"a","targetEntityId":"x"})
	var events := queue.collect_for_replan()
	check(events.size() == 2 and events[0]["sourceEntityId"] == "a", "prior tick events should be stably sorted")
	queue.enqueue({"phaseOrder":14,"eventTypeOrder":1,"sourceEntityId":"c"})
	check(queue.current_events.is_empty(), "late event must not enter current tick queue")

func test_target_ownership() -> void:
	var roles := TARGET_ROLES.new()
	var first := roles.acquire("attack_target", "enemy_1", "r1", 10, 20, "on_rule_end")
	roles.acquire("attack_target", "enemy_2", "r2", 11, 21, "on_rule_end")
	check(roles.is_owned("attack_target", "r1", int(first["generation"])), "target lock must reject another owner before lockUntilTick")
	roles.acquire("attack_target", "enemy_2", "r2", 20, 30, "on_rule_end")
	check(not roles.is_owned("attack_target", "r1", int(first["generation"])), "replacement after lock must invalidate old generation")
	roles.release_for_rule("r2")
	check(roles.get_role("attack_target").is_empty(), "owner end should release target")

func test_condition_and_selector() -> void:
	var evaluator := CONDITION.new()
	var ast := {"op":"lt","left":{"node":"field","path":"self.hp_percent"},"right":{"node":"const","value":0.3}}
	check(evaluator.evaluate(ast, {"self":{"hp_percent":0.2}}), "typed condition should evaluate")
	var candidates := [{"id":"b","slot_no":2,"distance_to_self":5.0,"is_alive":true},{"id":"a","slot_no":1,"distance_to_self":5.0,"is_alive":true}]
	var selector := {"scope":"enemy_units","filters":[{"field":"is_alive","op":"eq","value":{"node":"const","value":true}}],"sort":[{"field":"distance_to_self","order":"asc"}],"limit":1}
	var selected := SELECTOR.new().select(selector, candidates)
	check(selected.size() == 1 and selected[0]["id"] == "a", "selector ties should use slot then id")

func test_runtime_commit() -> void:
	var rule := base_rule("r1", "TACTICAL_MOVE", "locomotion", "MOVE")
	var runtime := RUNTIME.new()
	var plan := {"units":{"blue_3":{"rules":[rule]}}}
	check(runtime.setup(plan, "blue_3"), "runtime should bind actor")
	var result := runtime.replan({"self":{"is_alive":true}}, 1)
	check(result["committed"].size() == 1 and runtime.states.state("r1") == "ACTIVE", "runtime should atomically commit pending rule")

func test_runtime_preempt_resume() -> void:
	var low := base_rule("low", "TACTICAL_MOVE", "locomotion", "MOVE")
	var high := base_rule("high", "EMERGENCY_SURVIVAL", "survival", "MOVE")
	high["when"] = {"op":"eq","left":{"node":"field","path":"self.is_under_attack"},"right":{"node":"const","value":true}}
	high["until"] = {"op":"eq","left":{"node":"field","path":"self.is_under_attack"},"right":{"node":"const","value":false}}
	high["execution"]["minActiveTicks"] = 0
	high["action"]["interruptClass"] = "EMERGENCY_SURVIVAL"
	var runtime := RUNTIME.new()
	runtime.setup({"units":{"blue_3":{"rules":[low, high]}}}, "blue_3")
	runtime.replan({"self":{"is_alive":true,"is_under_attack":false}}, 1)
	check(runtime.states.state("low") == "ACTIVE", "low movement should start first")
	runtime.replan({"self":{"is_alive":true,"is_under_attack":true},"events":[{"type":"damage_received"}]}, 2)
	check(runtime.states.state("low") == "SUSPENDED" and runtime.states.state("high") == "ACTIVE", "survival should suspend lower MOVE only after commit")
	runtime.replan({"self":{"is_alive":true,"is_under_attack":false}}, 8)
	check(runtime.states.state("high") == "COMPLETED" and runtime.states.state("low") == "ACTIVE", "suspended movement should resume after survival ends")
	check(str(runtime.action_state.active_by_resource.get("MOVE", {}).get("id", "")) == "low", "resumed rule should reacquire MOVE")

func test_recovery_cancel_and_restart() -> void:
	for policy in ["cancel", "restart"]:
		var low := base_rule("low_" + policy, "TACTICAL_MOVE", "locomotion", "MOVE")
		low["execution"]["recoveryPolicy"] = policy
		var high := base_rule("high_" + policy, "EMERGENCY_SURVIVAL", "survival", "MOVE")
		high["when"] = {"op":"eq","left":{"node":"field","path":"self.is_under_attack"},"right":{"node":"const","value":true}}
		high["until"] = {"op":"eq","left":{"node":"field","path":"self.is_under_attack"},"right":{"node":"const","value":false}}
		high["execution"]["minActiveTicks"] = 0
		high["action"]["interruptClass"] = "EMERGENCY_SURVIVAL"
		var runtime := RUNTIME.new(); runtime.setup({"units":{"blue_3":{"rules":[low, high]}}}, "blue_3")
		runtime.replan({"self":{"is_alive":true,"is_under_attack":false}}, 1)
		runtime.replan({"self":{"is_alive":true,"is_under_attack":true},"events":[{"type":"damage_received"}]}, 2)
		check(runtime.states.state(low["id"]) == ("CANCELLED" if policy == "cancel" else "SUSPENDED"), policy + " must enter its specified interrupted state")
		runtime.replan({"self":{"is_alive":true,"is_under_attack":false}}, 8)
		check(runtime.states.state(low["id"]) == ("CANCELLED" if policy == "cancel" else "ACTIVE"), policy + " recovery result is incorrect")

func test_interrupt_denied_then_deferred() -> void:
	var active := base_rule("uninterruptible", "TACTICAL_MOVE", "locomotion", "MOVE")
	active["action"]["interruptibleBy"] = ["SYSTEM_FORCE"]
	var candidate := base_rule("deferred", "EMERGENCY_SURVIVAL", "survival", "MOVE")
	candidate["action"]["interruptClass"] = "EMERGENCY_SURVIVAL"
	var arbiter := RESOURCE_ARBITER.new()
	var denied := arbiter.arbitrate({"survival":candidate}, {"MOVE":active})
	check(denied["granted"].is_empty() and denied["rejected"].size() == 1, "disallowed interrupt must be deferred")
	var later := arbiter.arbitrate({"survival":candidate}, {})
	check(later["granted"].size() == 1 and later["granted"][0]["id"] == "deferred", "deferred candidate must commit after lock release")

func test_hysteresis_and_never_retrigger() -> void:
	var retreat := base_rule("hysteresis", "COMBAT_POSITIONING", "survival", "MOVE")
	retreat["when"] = {"op":"lt","left":{"node":"field","path":"self.distance_to_threat"},"right":{"node":"const","value":70.0}}
	retreat["until"] = {"op":"gte","left":{"node":"field","path":"self.distance_to_threat"},"right":{"node":"const","value":85.0}}
	retreat["execution"]["minActiveTicks"] = 0
	retreat["execution"]["replanIntervalTicks"] = 1
	var runtime := RUNTIME.new(); runtime.setup({"units":{"blue_3":{"rules":[retreat]}}}, "blue_3")
	runtime.replan({"self":{"is_alive":true,"distance_to_threat":69.0}}, 1)
	runtime.replan({"self":{"is_alive":true,"distance_to_threat":75.0}}, 2)
	check(runtime.states.state("hysteresis") == "ACTIVE", "exit threshold gap must prevent threshold chatter")
	runtime.replan({"self":{"is_alive":true,"distance_to_threat":85.0}}, 3)
	check(runtime.states.state("hysteresis") == "COMPLETED", "exit threshold must complete hysteresis action")
	var once := base_rule("once", "IDLE", "locomotion", "MOVE")
	once["execution"]["retriggerPolicy"] = "never"; once["execution"]["minActiveTicks"] = 0
	var machine := STATE_MACHINE.new(); machine.register_rule(once)
	machine.observe_condition(once, true, 1); machine.commit("once", 1); machine.complete_if_allowed(once, true, 1)
	machine.observe_condition(once, false, 2); machine.observe_condition(once, true, 3)
	check(machine.state("once") == "COMPLETED", "never rule must remain terminal after condition reentry")

func test_active_action_is_not_recommitted() -> void:
	var rule := base_rule("continuous", "TACTICAL_MOVE", "locomotion", "MOVE")
	var runtime := RUNTIME.new(); runtime.setup({"units":{"blue_3":{"rules":[rule]}}}, "blue_3")
	runtime.replan({"self":{"is_alive":true}}, 1)
	var activation := int(runtime.states.records["continuous"]["activation"])
	var started := int(runtime.action_state.started_tick_by_rule["continuous"])
	runtime.replan({"self":{"is_alive":true}}, 2)
	check(int(runtime.states.records["continuous"]["activation"]) == activation and int(runtime.action_state.started_tick_by_rule["continuous"]) == started,
		"active action must continue across ticks without duplicate commit")

func test_fallback_and_target_binding() -> void:
	var follow := base_rule("follow", "FOLLOW", "locomotion", "MOVE")
	follow["targetBinding"] = {"writeRole":"follow_target","selector":{"scope":"ally_units","filters":[{"field":"slot_no","op":"eq","value":{"node":"const","value":2}}],"sort":[{"field":"slot_no","order":"asc"}],"limit":1},"releasePolicy":"on_target_invalid"}
	follow["resourceClaims"].append({"resource":"TARGET_ROLE:follow_target","mode":"exclusive"})
	follow["action"] = {"opcode":"follow","targetRef":"follow_target","interruptClass":"TACTICAL_MOVE","interruptibleBy":["SYSTEM_FORCE","EMERGENCY_SURVIVAL"]}
	follow["fallback"] = {"opcode":"hold_position","allowCombat":true}
	var runtime := RUNTIME.new()
	runtime.setup({"units":{"blue_3":{"rules":[follow]}}}, "blue_3")
	runtime.replan({"self":{"is_alive":true},"candidateScopes":{"ally_units":[]}}, 1)
	var lease: Dictionary = runtime.action_state.active_by_resource.get("MOVE", {})
	check(bool(lease.get("_usingFallback", false)) and lease.get("action", {}).get("opcode") == "hold_position", "empty selector should commit the explicit fallback")
	check(runtime.target_roles.get_role("follow_target").is_empty(), "fallback must not invent a missing target role")
	runtime.replan({"self":{"is_alive":true},"candidateScopes":{"ally_units":[{"id":"ally_2","slot_no":2,"is_alive":true}]}}, 7)
	lease = runtime.action_state.active_by_resource.get("MOVE", {})
	check(not bool(lease.get("_usingFallback", false)) and not runtime.target_roles.get_role("follow_target").is_empty(),
		"active fallback must recover to the primary action when a valid target appears")

func test_multi_resource_atomicity() -> void:
	var active := base_rule("locked", "CRITICAL_SKILL", "combat", "PRIMARY_COMBAT")
	active["action"]["interruptibleBy"] = ["SYSTEM_FORCE"]
	var skill := base_rule("skill", "COMBAT", "combat", "PRIMARY_COMBAT")
	skill["resourceClaims"].append({"resource":"SKILL_SLOT:1","mode":"exclusive"})
	var channels := {"combat":skill}
	var result := RESOURCE_ARBITER.new().arbitrate(channels, {"PRIMARY_COMBAT":active})
	check(result["granted"].is_empty(), "multi-resource bundle must fail completely when one resource is locked")
	check(result["leases"].has("PRIMARY_COMBAT") and not result["leases"].has("SKILL_SLOT:1"), "failed bundle must not retain a partial skill lease")

func test_bounded_phase_machine() -> void:
	var machine := PHASE_MACHINE.new()
	var definitions := [{"id":"ambush","actorId":"blue_3","initialState":"approach","states":["approach","waiting","attack"],
		"transitions":[{"from":"approach","to":"waiting","whenRuleId":"enter","requiredState":"COMPLETED"},
			{"from":"waiting","to":"attack","whenRuleId":"wait","requiredState":"COMPLETED"}]}]
	check(machine.setup(definitions, "blue_3"), "bounded phase machine should bind its actor")
	check(machine.advance({"enter":"ACTIVE"}, 1).is_empty(), "phase must not advance before prerequisite terminal state")
	check(machine.advance({"enter":"COMPLETED"}, 2).size() == 1 and machine.current_state["ambush"] == "waiting", "completed approach should enter waiting")
	check(machine.advance({"wait":"COMPLETED"}, 3).size() == 1 and machine.current_state["ambush"] == "attack", "completed wait should enter attack")
