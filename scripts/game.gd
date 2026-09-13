extends Node2D

const VIEW_SIZE := Vector2(720, 1280)
const BRIDGE_LEFT_X := 328.0
const BRIDGE_RIGHT_X := 392.0
const BRIDGE_GROUP_CENTER_X := 360.0
const BRIDGE_GROUP_HALF_WIDTH := 56.0
const FONT := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const MAP_SCRIPT := preload("res://scripts/battle_map.gd")
const UNIT_SCRIPT := preload("res://scripts/unit.gd")
const RESOURCE_SCRIPT := preload("res://scripts/resource_node.gd")
const STRATEGY_RULES := preload("res://scripts/strategy_rules.gd")
const STRATEGY_RUNTIME_SCRIPT := preload("res://scripts/strategy_runtime.gd")
const STRATEGY_RUNTIME_V3_ADAPTER := preload("res://scripts/strategy_v3/strategy_runtime_adapter.gd")
const STRATEGY_EVENT_QUEUE_V3 := preload("res://scripts/strategy_v3/deterministic_event_queue.gd")
const PROJECTILE_ENGINE_SCRIPT := preload("res://scripts/projectile_engine.gd")
const ISLAND_MAP_VIEW_SCRIPT := preload("res://scripts/island/island_map_view.gd")
const PANEL := preload("res://assets/ui/Carved_9Slides.png")
const BUTTON_BLUE := preload("res://assets/ui/Button_Blue_9Slides.png")
const BUTTON_RED := preload("res://assets/ui/Button_Red_9Slides.png")
const ICON_KEYBOARD := preload("res://assets/ui/icon_keyboard.svg")
const ICON_MICROPHONE := preload("res://assets/ui/icon_microphone.svg")
const RIBBON_BLUE := preload("res://assets/ui/Ribbon_Blue_3Slides.png")
const AVATAR := preload("res://assets/ui/Avatars_01.png")
const MAP_PREVIEW := preload("res://map_preview_portrait.png")
const ARROW := preload("res://assets/game/units/archer/arrow.png")
const GOLD_ICON := preload("res://assets/game/resources/gold_icon.png")
const WOOD_ICON := preload("res://assets/game/resources/wood_icon.png")
const MEAT_ICON := preload("res://assets/game/resources/meat_icon.png")
const STONE_ICON := preload("res://assets/game/resources/stone1.png")
const ISLAND_WORKER_IDLE := preload("res://assets/game/units/worker/blue_idle.png")
const ISLAND_WORKER_RUN := preload("res://assets/game/units/worker/blue_run.png")
const ISLAND_WORKER_AXE := preload("res://assets/game/units/worker/blue_axe.png")
const ISLAND_WORKER_PICKAXE := preload("res://assets/game/units/worker/blue_pickaxe.png")
const ISLAND_WORKER_FARM := preload("res://assets/game/units/worker/blue_knife.png")
const HEAL_EFFECT := preload("res://assets/game/units/monk/blue_heal_effect.png")
const MUSIC_LOOP := preload("res://assets/audio/bgm_loop.wav")
const SFX_UI_CLICK := preload("res://assets/audio/ui_click.wav")
const SFX_MELEE_SWING := preload("res://assets/audio/melee_swing.wav")
const SFX_IMPACT := preload("res://assets/audio/impact.wav")
const SFX_ARROW_RELEASE := preload("res://assets/audio/arrow_release.wav")
const SFX_MAGIC_CAST := preload("res://assets/audio/magic_cast.wav")
const SFX_HEAL := preload("res://assets/audio/heal.wav")
const SFX_GATHER_WOOD := preload("res://assets/audio/gather_wood.wav")
const SFX_GATHER_STONE := preload("res://assets/audio/gather_stone.wav")
const SFX_GATHER_GOLD := preload("res://assets/audio/gather_gold.wav")
const SFX_GATHER_MEAT := preload("res://assets/audio/gather_meat.wav")
const SFX_DEATH := preload("res://assets/audio/death.wav")
const SFX_REVIVE := preload("res://assets/audio/revive.wav")
const SFX_DEPOSIT := preload("res://assets/audio/deposit.wav")
const SFX_COUNTDOWN := preload("res://assets/audio/countdown.wav")
const SFX_START := preload("res://assets/audio/start.wav")
const SFX_VICTORY := preload("res://assets/audio/victory.wav")
const SFX_DEFEAT := preload("res://assets/audio/defeat.wav")
const SFX_DRAW := preload("res://assets/audio/draw.wav")
const UNIT_TYPES := ["archer", "lancer", "worker", "monk", "warrior"]
const UNIT_NAMES := {
	"archer": "弓箭手",
	"lancer": "长枪手",
	"worker": "工人",
	"monk": "僧侣",
	"warrior": "战士"
}
const DEFAULT_LINEUP := ["archer", "lancer", "worker", "monk", "warrior"]
const SETUP_SAVE_PATH := "user://battle_setup.cfg"
const ACCOUNT_SAVE_PATH := "user://account.cfg"

var battle_started := false
var battle_finished := false
var units: Array = []
var resources: Array = []
var resource_counts := {
	"blue": {"gold": 0, "stone": 0, "wood": 0, "meat": 0},
	"red": {"gold": 0, "stone": 0, "wood": 0, "meat": 0}
}
var hud_values: Dictionary = {}
var rng := RandomNumberGenerator.new()
var spawn_rng := RandomNumberGenerator.new()
var audio_rng := RandomNumberGenerator.new()
var player_name := "无名勇士"
var player_avatar: Texture2D = AVATAR
var preview_mode := false
var test_mode := false
var pending_combat_events: Array[Dictionary] = []
var combat_flush_scheduled := false
var death_queues := {"blue": [], "red": []}
var audio_root: Node
var music_player: AudioStreamPlayer
var music_volume := 0.48
var sfx_volume := 0.72
var card_decks: Array = []
var deck_names: Array = []
var strategies: Array = []
var current_deck_index := 0
var current_strategy_index := 0
var selected_lineup_slot := 0
var player_lineup: Array = DEFAULT_LINEUP.duplicate()
var strategy_messages: Array = []
var strategy_edit_index := -1
var strategy_edit_text := ""
var strategy_dirty := false
var strategy_send_history: Array = []
var strategy_send_token := 0
var strategy_ready := false
var strategy_notice := ""
var strategy_compiling := false
var active_strategy: Dictionary = {}
var active_strategy_messages: Array = []
var active_compile_binding: Dictionary = {}
var active_battle_request_id := ""
var strategy_runtime: Variant
var strategy_http_request: HTTPRequest
var active_replay: Dictionary = {}
var replay_mode := false
var replay_capture_mode := false
var replay_outcome := ""
var replay_elapsed := 0.0
var replay_frame_index := 0
var replay_units: Dictionary = {}
var replay_resources: Dictionary = {}
var replay_projectiles: Dictionary = {}
var replay_unit_serial := 0
var replay_resource_serial := 0
var replay_strategy_events: Array = []
var replay_projectile_events: Array = []
var projectile_engine: Node
var battle_tick := 0
var battle_elapsed := 0.0
var battle_areas: Array[Dictionary] = []
var battle_snapshot: Dictionary = {}
var strategy_event_queue := STRATEGY_EVENT_QUEUE_V3.new()
var strategy_current_events: Array = []
var account_token := ""
var account_player_id := ""
var cloud_ready := false
var cloud_syncing := false
var cloud_loading := false
var cloud_status := "正在连接云端…"
var player_level := 1
var player_experience := 0
var player_level_start_xp := 0
var player_next_level_xp := 50
var player_gold := 0
var player_diamonds := 0
var battle_history: Array = []
var account_type := "guest"
var account_status := ""
var strategy_dom_callback: JavaScriptObject
var strategy_dom_input_target: LineEdit
var strategy_dom_input_focused := false
var strategy_voice_callback: JavaScriptObject
var strategy_voice_mode := true
var strategy_voice_recording := false
var game_screen_token := 0
var island_payload: Dictionary = {}
var selected_island_plot := 0
var selected_island_worker := ""
var selected_island_object_type := ""
var selected_island_object_id := ""
var selected_island_option_index := 0
var selected_island_crop_index := 0
var pending_island_reveal := 0

func _ready() -> void:
	rng.randomize()
	spawn_rng.randomize()
	audio_rng.randomize()
	ensure_audio_buses()
	load_battle_setup()
	load_account()
	preview_mode = "--battle-preview" in OS.get_cmdline_user_args()
	# Headless fixtures can opt into test mode before entering the tree. Keep
	# that value, but only auto-start when the command-line mode requested it;
	# programmatic fixtures need time to install their snapshot first.
	var command_line_test_mode := "--auto-test" in OS.get_cmdline_user_args()
	test_mode = test_mode or command_line_test_mode
	if not preview_mode and not test_mode:
		load_audio_settings()
		apply_audio_volumes()
		setup_audio_players()
	if test_mode:
		Engine.time_scale = 8.0
	if preview_mode or command_line_test_mode:
		start_game.call_deferred()
	elif test_mode or replay_capture_mode:
		pass
	else:
		show_main_menu()
		ensure_cloud_account.call_deferred()

func _process(_delta: float) -> void:
	if replay_mode:
		update_replay(_delta)
		return
	if not test_mode or not battle_started:
		return
	for candidate in units:
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		if candidate.position.y >= 592.0 and candidate.position.y <= 688.0:
			var on_double_bridge := absf(candidate.position.x - BRIDGE_GROUP_CENTER_X) <= BRIDGE_GROUP_HALF_WIDTH + 0.1
			if not on_double_bridge:
				push_error("RIVER_LIMIT_VIOLATION unit=%s position=%s" % [candidate.unit_type, candidate.position])
				get_tree().quit(2)

func _physics_process(delta: float) -> void:
	if battle_started and not battle_finished and not replay_mode:
		strategy_current_events = strategy_event_queue.collect_for_replan()
		battle_tick += 1
		battle_elapsed += delta

func clear_screen() -> void:
	game_screen_token += 1
	stop_web_voice_capture()
	hide_web_strategy_input()
	battle_started = false
	battle_finished = false
	units.clear()
	resources.clear()
	hud_values.clear()
	pending_combat_events.clear()
	combat_flush_scheduled = false
	death_queues = {"blue": [], "red": []}
	replay_mode = false
	replay_elapsed = 0.0
	replay_frame_index = 0
	replay_units.clear()
	replay_resources.clear()
	replay_projectiles.clear()
	replay_unit_serial = 0
	replay_resource_serial = 0
	replay_strategy_events.clear()
	replay_projectile_events.clear()
	projectile_engine = null
	battle_tick = 0
	battle_elapsed = 0.0
	battle_areas.clear()
	strategy_event_queue = STRATEGY_EVENT_QUEUE_V3.new()
	strategy_current_events.clear()
	for child in get_children():
		if child != audio_root:
			# Screen changes are commonly triggered from a Button.pressed signal.
			# Detach it immediately so replacement controls can keep stable names,
			# then defer destruction until signal emission has finished.
			remove_child(child)
			child.queue_free()

func show_main_menu() -> void:
	clear_screen()
	var bg := TextureRect.new()
	bg.texture = MAP_PREVIEW
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Cover the logical area added by stretch/aspect=expand on tall phones and
	# wide tablets. The former fixed 720x1280 rectangle exposed the canvas clear
	# color as a blue strip outside the artwork.
	place(bg, -360, -360, 1440, 2000)
	bg.z_index = -10
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.085, 0.72)
	place(shade, -360, -360, 1440, 2000)
	shade.z_index = -9
	add_child(shade)
	make_panel(28, 30, 664, 200)
	var avatar := TextureRect.new()
	avatar.texture = player_avatar
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	place(avatar, 54, 54, 140, 140)
	add_child(avatar)
	var avatar_button := Button.new()
	avatar_button.flat = true
	avatar_button.tooltip_text = "点击上传头像"
	place(avatar_button, 54, 54, 140, 140)
	avatar_button.pressed.connect(open_avatar_dialog)
	add_child(avatar_button)
	var name_edit := LineEdit.new()
	name_edit.text = player_name
	name_edit.placeholder_text = "输入玩家名称"
	name_edit.max_length = 12
	name_edit.position = Vector2(205, 55)
	name_edit.size = Vector2(285, 50)
	name_edit.add_theme_font_override("font", FONT)
	name_edit.add_theme_font_size_override("font_size", 29)
	name_edit.add_theme_color_override("font_color", Color("4a363c"))
	name_edit.text_submitted.connect(update_player_name)
	name_edit.focus_exited.connect(func() -> void: update_player_name(name_edit.text))
	add_child(name_edit)
	make_label("等级 %d" % player_level, 210, 105, 180, 34, 21, Color("3d3037"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	var level_target := player_experience if player_level >= 30 else maxi(player_level_start_xp + 1, player_next_level_xp)
	var level_progress := 1.0 if player_level >= 30 else clampf(float(player_experience - player_level_start_xp) / float(level_target - player_level_start_xp), 0.0, 1.0)
	make_progress(210, 150, 290, 34, level_progress, "经验 %d / %d" % [player_experience, level_target])
	make_label("金币  %d" % player_gold, 500, 60, 165, 42, 20, Color("44353a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	make_label("钻石  %d" % player_diamonds, 500, 122, 165, 42, 20, Color("44353a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	make_ui_button("账号", Rect2(535, 176, 120, 38), show_account_screen, 15, Color("596d72"))
	make_label("翡翠纷争", 80, 295, 560, 82, 52, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 7)
	make_label("EMERALD CLASH", 150, 375, 420, 32, 18, Color("9edce0"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	make_action_button("开始新游戏", Rect2(145, 465, 430, 82), false, show_lineup_screen)
	make_action_button("英雄成长", Rect2(100, 575, 245, 70), false, show_hero_growth_screen)
	make_action_button("我的小岛", Rect2(375, 575, 245, 70), false, show_island_screen)
	make_action_button("历史战斗", Rect2(100, 675, 245, 70), false, show_battle_history)
	make_action_button("设置", Rect2(375, 675, 245, 70), false, show_settings)
	make_label(cloud_status, 80, 800, 560, 36, 17, Color("c2dcda"), HORIZONTAL_ALIGNMENT_CENTER, 2)
	var game_version := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	make_label("游戏版本 v%s" % game_version, 120, 1200, 480, 30, 16, Color(0.65, 0.78, 0.78, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 2)

func show_settings() -> void:
	clear_screen()
	build_menu_background()
	make_title("设置")
	make_panel(55, 245, 610, 650)
	make_label("音乐", 105, 345, 140, 44, 26, Color("45343a"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	var music_value_label := make_label("%d%%" % roundi(music_volume * 100.0), 475, 345, 140, 44, 22, Color("765b5a"), HORIZONTAL_ALIGNMENT_RIGHT, 0)
	var music := HSlider.new()
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.01
	music.value = music_volume
	place(music, 105, 415, 510, 52)
	add_child(music)
	make_label("音效", 105, 520, 140, 44, 26, Color("45343a"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	var sfx_value_label := make_label("%d%%" % roundi(sfx_volume * 100.0), 475, 520, 140, 44, 22, Color("765b5a"), HORIZONTAL_ALIGNMENT_RIGHT, 0)
	var sfx := HSlider.new()
	sfx.min_value = 0.0
	sfx.max_value = 1.0
	sfx.step = 0.01
	sfx.value = sfx_volume
	place(sfx, 105, 590, 510, 52)
	add_child(sfx)
	make_label("设置会自动保存 · 调到0即可静音", 90, 700, 540, 52, 18, Color("765b5a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	music.value_changed.connect(func(value: float) -> void:
		music_volume = value
		music_value_label.text = "%d%%" % roundi(value * 100.0)
		apply_audio_volumes()
	)
	sfx.value_changed.connect(func(value: float) -> void:
		sfx_volume = value
		sfx_value_label.text = "%d%%" % roundi(value * 100.0)
		apply_audio_volumes()
	)
	music.drag_ended.connect(func(_changed: bool) -> void: save_audio_settings())
	sfx.drag_ended.connect(func(changed: bool) -> void:
		save_audio_settings()
		if changed:
			play_sfx(SFX_UI_CLICK, -3.0, 0.0)
	)
	make_action_button("返回主界面", Rect2(205, 1000, 310, 82), false, show_main_menu)

func show_hero_growth_screen() -> void:
	clear_screen()
	build_menu_background()
	make_title("英雄成长")
	make_label("正在读取英雄数据…", 80, 540, 560, 50, 22, Color("d7ebe7"), HORIZONTAL_ALIGNMENT_CENTER, 2)
	make_ui_button("返回", Rect2(25, 25, 115, 48), show_main_menu, 18, Color("596d72"))
	var token := game_screen_token
	var response := await api_request("/heroes", HTTPClient.METHOD_GET)
	if token != game_screen_token:
		return
	_render_hero_growth(response)

func _render_hero_growth(response: Dictionary) -> void:
	clear_screen()
	build_menu_background()
	make_title("英雄成长")
	make_ui_button("返回", Rect2(25, 25, 115, 48), show_main_menu, 18, Color("596d72"))
	make_label("玩家等级 %d  ·  金币 %d" % [player_level, player_gold], 155, 165, 410, 42, 21, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 2)
	if not bool(response.get("ok", false)):
		make_panel(70, 330, 580, 260)
		make_label("英雄数据暂时无法读取\n请确认云端连接后重试", 110, 390, 500, 100, 23, Color("743d43"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		make_ui_button("重试", Rect2(240, 535, 240, 64), show_hero_growth_screen, 20)
		return
	var scroll := ScrollContainer.new()
	place(scroll, 45, 225, 630, 900)
	add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(610, 0)
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for hero_value in response.get("heroes", []):
		var hero: Dictionary = hero_value
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(595, 172)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e8ddb8")
		style.border_color = Color("8c7358")
		style.set_border_width_all(3)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		card.add_theme_stylebox_override("panel", style)
		list.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)
		var title := Label.new()
		title.text = "%s  Lv%d/%d  ·  %s" % [hero["name"], hero["level"], hero["maxLevel"], hero["role"]]
		title.add_theme_font_override("font", FONT)
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", Color("49383a"))
		box.add_child(title)
		var stats: Dictionary = hero["battleStats"]
		var stat_label := Label.new()
		stat_label.text = "生命 %d  物攻 %d  物防 %d  魔防 %d  技能 %d" % [stats["maxHp"], stats["physicalAttack"], stats["physicalDefense"], stats["magicDefense"], stats["skillPower"]]
		stat_label.add_theme_font_override("font", FONT)
		stat_label.add_theme_font_size_override("font_size", 16)
		stat_label.add_theme_color_override("font_color", Color("70575a"))
		box.add_child(stat_label)
		var row := HBoxContainer.new()
		box.add_child(row)
		var cost_label := Label.new()
		var next: Variant = hero.get("nextUpgrade")
		cost_label.text = "已满级" if next == null else "英雄卡 %d/%d  金币 %d" % [hero["cardCount"], next["heroCards"], next["coins"]]
		cost_label.custom_minimum_size = Vector2(390, 54)
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_override("font", FONT)
		cost_label.add_theme_font_size_override("font_size", 18)
		cost_label.add_theme_color_override("font_color", Color("49383a"))
		row.add_child(cost_label)
		var upgrade := Button.new()
		upgrade.text = "升级"
		upgrade.custom_minimum_size = Vector2(155, 54)
		upgrade.add_theme_font_override("font", FONT)
		upgrade.add_theme_font_size_override("font_size", 20)
		upgrade.disabled = next == null or int(hero["cardCount"]) < int(next["heroCards"]) or player_gold < int(next["coins"])
		upgrade.pressed.connect(_upgrade_hero.bind(String(hero["heroId"]), int(hero["level"]), upgrade))
		row.add_child(upgrade)

func _upgrade_hero(hero_id: String, expected_level: int, button: Button) -> void:
	button.disabled = true
	button.text = "处理中"
	var request_id := "hero_%d_%d" % [Time.get_ticks_msec(), randi()]
	var response := await api_request("/heroes/%s/upgrade" % hero_id, HTTPClient.METHOD_POST, {"requestId": request_id, "expectedLevel": expected_level})
	if bool(response.get("ok", false)):
		player_gold = int(response.get("coins", player_gold))
		var growth: Dictionary = response.get("playerGrowth", {})
		player_level = int(growth.get("level", player_level))
		player_experience = int(growth.get("xp", player_experience))
		player_level_start_xp = int(growth.get("currentLevelCumulativeXp", player_level_start_xp))
		var next_value: Variant = growth.get("nextLevelCumulativeXp")
		player_next_level_xp = player_experience if next_value == null else int(next_value)
		show_hero_growth_screen()
	else:
		button.text = "失败"
		var error: Variant = response.get("error", {})
		button.tooltip_text = String(error.get("message", "升级失败")) if error is Dictionary else "升级失败"

func show_island_screen() -> void:
	clear_screen()
	build_menu_background()
	make_title("我的小岛")
	make_label("正在加载岛屿…", 80, 540, 560, 50, 22, Color("d7ebe7"), HORIZONTAL_ALIGNMENT_CENTER, 2)
	make_ui_button("返回", Rect2(25, 25, 115, 48), show_main_menu, 18, Color("596d72"))
	var token := game_screen_token
	var response := await api_request("/island", HTTPClient.METHOD_GET)
	if token != game_screen_token:
		return
	_render_island(response)

func _render_island(response: Dictionary) -> void:
	clear_screen()
	selected_island_plot = 0
	island_payload = response.duplicate(true)
	if not bool(response.get("ok", false)):
		build_menu_background()
		make_title("我的小岛")
		make_label("岛屿数据暂时无法读取", 100, 500, 520, 60, 24, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 2)
		make_ui_button("返回", Rect2(205, 780, 310, 64), show_main_menu, 20, Color("596d72"))
		return
	var workers: Array = response.get("islandWorkers", [])
	if not workers.is_empty() and (selected_island_worker.is_empty() or not workers.any(func(value: Dictionary) -> bool: return str(value.get("workerId", "")) == selected_island_worker)):
		selected_island_worker = str(workers[0].get("workerId", ""))
	var view := ISLAND_MAP_VIEW_SCRIPT.new()
	view.name = "IslandMapView"
	view.z_index = -100
	place(view, 0, 0, 720, 1280)
	view.configure(response)
	view.plot_selected.connect(_select_island_plot)
	view.worker_selected.connect(_select_island_worker)
	view.object_selected.connect(_select_island_object)
	view.ground_selected.connect(_move_island_worker)
	add_child(view)
	if not selected_island_worker.is_empty():
		view.select_worker(selected_island_worker)
	if pending_island_reveal > 0:
		view.reveal_plot(pending_island_reveal)
		pending_island_reveal = 0
	var header := NinePatchRect.new()
	header.texture = PANEL
	header.patch_margin_left = 48
	header.patch_margin_top = 32
	header.patch_margin_right = 48
	header.patch_margin_bottom = 32
	place(header, 0, 0, 720, 78)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	make_label("我的小岛 · Lv%d" % int(response["playerLevel"]), 150, 13, 420, 48, 26, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 2)
	make_ui_button("返回", Rect2(18, 14, 110, 48), show_main_menu, 18, Color("596d72"))
	_build_island_resource_strip()
	_build_island_worker_dock()
	var footer := NinePatchRect.new()
	footer.name = "IslandFooter"
	footer.texture = PANEL
	footer.patch_margin_left = 64
	footer.patch_margin_top = 64
	footer.patch_margin_right = 64
	footer.patch_margin_bottom = 64
	place(footer, 0, 1080, 720, 200)
	add_child(footer)
	var hint := make_label("点击空地移动 · 点击资源、农田或建筑安排任务", 30, 1095, 660, 38, 18, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 5)
	hint.name = "IslandPlotInfo"
	var option := make_ui_button("选项", Rect2(20, 1155, 165, 58), _island_option_action, 17, Color("596d72"))
	option.name = "IslandOptionButton"
	option.disabled = true
	var unlock := make_ui_button("选择目标", Rect2(200, 1155, 310, 58), _island_primary_action, 20, Color("287e8a"))
	unlock.name = "IslandUnlockButton"
	unlock.disabled = true
	var batch := make_ui_button("批量", Rect2(525, 1155, 175, 58), _island_batch_action, 17, Color("596d72"))
	batch.name = "IslandBatchButton"
	batch.disabled = true
	if not selected_island_worker.is_empty():
		_select_island_worker(selected_island_worker)
	if not test_mode:
		_schedule_island_runtime_sync.call_deferred(game_screen_token)

func _select_island_plot(plot_id: int) -> void:
	selected_island_plot = plot_id
	var plot: Dictionary = {}
	for value in island_payload.get("plots", []):
		if int(value["plotId"]) == plot_id:
			plot = value
			break
	var info := get_node_or_null("IslandPlotInfo") as Label
	var unlock := get_node_or_null("IslandUnlockButton") as Button
	var option := get_node_or_null("IslandOptionButton") as Button
	if plot.is_empty() or info == null or unlock == null:
		return
	if option != null:
		option.text = "选项"
		option.disabled = true
	if String(plot["status"]) == "UNLOCKED":
		info.text = "%d号地 · 已解锁" % plot_id
		unlock.text = "已解锁"
		unlock.disabled = true
	else:
		var costs: Array[String] = []
		for cost in plot.get("costState", []):
			costs.append("%s %d/%d" % [cost["name"], cost["available"], cost["required"]])
		info.text = "%d号地 · 需Lv%d · %s" % [plot_id, plot["requiredPlayerLevel"], "  ".join(costs)]
		unlock.text = "解锁%d号地" % plot_id
		unlock.disabled = not bool(plot.get("canUnlock", false))

func _select_island_worker(worker_id: String) -> void:
	selected_island_worker = worker_id
	selected_island_object_type = ""
	selected_island_object_id = ""
	var view := get_node_or_null("IslandMapView")
	if view != null:
		view.select_worker(worker_id)
	_build_island_worker_dock()
	var worker: Dictionary = {}
	for value in island_payload.get("islandWorkers", []):
		if String(value.get("workerId", "")) == worker_id:
			worker = value
			break
	var info := get_node_or_null("IslandPlotInfo") as Label
	var action := get_node_or_null("IslandUnlockButton") as Button
	var option := get_node_or_null("IslandOptionButton") as Button
	var batch := get_node_or_null("IslandBatchButton") as Button
	if info != null:
		info.text = _island_worker_status_text(worker)
	if action != null:
		action.text = "选择目标"
		action.disabled = true
	if option != null:
		option.text = "选项"
		option.disabled = true
	if batch != null:
		batch.disabled = true

func _select_island_object(object_type: String, object_id: String) -> void:
	var changed_target := selected_island_object_type != object_type or selected_island_object_id != object_id
	selected_island_object_type = object_type
	selected_island_object_id = object_id
	selected_island_plot = 0
	if changed_target:
		selected_island_option_index = 0
		selected_island_crop_index = 0
	var info := get_node_or_null("IslandPlotInfo") as Label
	var action := get_node_or_null("IslandUnlockButton") as Button
	var option := get_node_or_null("IslandOptionButton") as Button
	var batch := get_node_or_null("IslandBatchButton") as Button
	if selected_island_worker.is_empty():
		if info != null: info.text = "请先选择一名岛屿工人"
		if action != null: action.disabled = true
		if option != null: option.disabled = true
		if batch != null: batch.disabled = true
		return
	var owner := _island_target_owner(object_id)
	if not owner.is_empty() and owner != selected_island_worker and object_type in ["resource", "farm"]:
		if info != null: info.text = "该目标已由%s安排" % owner.replace("island_worker_", "工人")
		if action != null: action.disabled = true
		if option != null: option.disabled = true
		if batch != null: batch.disabled = true
		return
	if object_type == "resource":
		if option != null: option.disabled = true
		if batch != null: batch.disabled = true
		if info != null: info.text = "正在为%s安排采集…" % selected_island_worker.replace("island_worker_", "工人")
		_enqueue_island_task(_resource_task_type(object_id), [object_id])
		return
	if object_type == "farm":
		var farm := _island_farm(object_id)
		var mature := farm.get("cropId") != null and int(farm.get("readyAt", 0)) <= int(island_payload.get("serverTime", 0))
		var crop := _selected_farm_crop(farm)
		if info != null: info.text = "成熟农田" if mature else ("空农田 · 当前%s" % String(crop.get("name", "无可用作物")) if farm.get("cropId") == null else "作物成长中")
		if action != null:
			var seed_item := String(crop.get("seedItemId", ""))
			action.text = "收获" if mature else ("播种%s" % String(crop.get("name", "")) if _island_available_item(seed_item) > 0 else "购买%s种子" % String(crop.get("name", "")))
			action.disabled = (farm.get("cropId") != null and not mature) or crop.is_empty()
		if option != null:
			option.text = "切换作物"
			option.disabled = farm.get("cropId") != null or _available_crops_for_farm(farm).size() <= 1
		if batch != null:
			batch.text = "批量收获" if mature else "批量播种"
			batch.disabled = action.disabled
		return
	if object_type == "building":
		var building := _island_building(object_id)
		if String(building.get("state", "READY")) == "FOUNDATION":
			if info != null: info.text = "固定地基 · 材料满足后可安排建造"
			if action != null: action.text = "建造"
			if action != null: action.disabled = false
			if option != null: option.disabled = true
			if batch != null: batch.disabled = true
			return
		var recipe := _selected_building_recipe()
		if info != null: info.text = "选择制作：%s" % String(recipe.get("name", "暂无可用配方"))
		if action != null:
			action.text = "制作%s" % String(recipe.get("name", ""))
			action.disabled = recipe.is_empty()
		if option != null:
			option.text = "切换配方"
			option.disabled = _recipes_for_selected_building().size() <= 1
		if batch != null:
			batch.text = "连续制作"
			batch.disabled = recipe.is_empty()

func _island_primary_action() -> void:
	if selected_island_plot >= 5:
		_unlock_selected_plot()
		return
	if selected_island_worker.is_empty() or selected_island_object_id.is_empty():
		return
	if selected_island_object_type == "farm":
		var farm := _island_farm(selected_island_object_id)
		if farm.get("cropId") == null:
			var crop := _selected_farm_crop(farm)
			if crop.is_empty(): return
			if _island_available_item(String(crop["seedItemId"])) <= 0:
				_buy_island_seed(String(crop["id"]), 1)
			else:
				_enqueue_island_task("PLANT_CROP", [selected_island_object_id], {"cropId":crop["id"]})
		elif int(farm.get("readyAt", 0)) <= int(island_payload.get("serverTime", 0)):
			_enqueue_island_task("HARVEST_CROP", [selected_island_object_id])
	elif selected_island_object_type == "building":
		var building := _island_building(selected_island_object_id)
		if String(building.get("state", "READY")) == "FOUNDATION":
			_enqueue_island_task("BUILD_BUILDING", [selected_island_object_id])
			return
		var recipe := _selected_building_recipe()
		if not recipe.is_empty():
			_enqueue_island_task("PROCESS_MATERIAL", [selected_island_object_id], {"recipeId":recipe["id"], "quantity":1})

func _island_batch_action() -> void:
	if selected_island_object_type == "building":
		var recipe := _selected_building_recipe()
		if not recipe.is_empty():
			_enqueue_island_task("PROCESS_MATERIAL", [selected_island_object_id], {"recipeId":recipe["id"], "quantity":5})
		return
	if selected_island_object_type != "farm" or selected_island_worker.is_empty():
		return
	var selected_farm := _island_farm(selected_island_object_id)
	var harvest := selected_farm.get("cropId") != null and int(selected_farm.get("readyAt", 0)) <= int(island_payload.get("serverTime", 0))
	var crop := _selected_farm_crop(selected_farm)
	if not harvest and crop.is_empty(): return
	var targets: Array[String] = []
	for value in island_payload.get("farmPlots", []):
		if harvest:
			if value.get("cropId") != null and int(value.get("readyAt", 0)) <= int(island_payload.get("serverTime", 0)) and value.get("reservedByTaskId") == null:
				targets.append(String(value["farmPlotId"]))
		elif value.get("cropId") == null and value.get("reservedByTaskId") == null and String(value.get("farmType", "")) in crop.get("allowedFarmTypes", []):
			targets.append(String(value["farmPlotId"]))
	if targets.is_empty(): return
	_enqueue_island_task("BATCH_HARVEST" if harvest else "BATCH_PLANT", targets, {} if harvest else {"cropId":crop["id"]})

func _island_option_action() -> void:
	if selected_island_object_type == "building":
		var recipes := _recipes_for_selected_building()
		if recipes.size() <= 1: return
		selected_island_option_index = (selected_island_option_index + 1) % recipes.size()
		_select_island_object("building", selected_island_object_id)
	elif selected_island_object_type == "farm":
		var farm := _island_farm(selected_island_object_id)
		var crops := _available_crops_for_farm(farm)
		if crops.size() <= 1: return
		selected_island_crop_index = (selected_island_crop_index + 1) % crops.size()
		_select_island_object("farm", selected_island_object_id)

func _enqueue_island_task(task_type: String, targets: Array, extra := {}) -> void:
	var body := {"requestId":"island_task_%d_%d" % [Time.get_ticks_msec(), randi()], "type":task_type, "targetIds":targets, "quantity":1}
	for key in extra: body[key] = extra[key]
	var response := await api_request("/island/workers/%s/tasks" % selected_island_worker, HTTPClient.METHOD_POST, body)
	if bool(response.get("ok", false)):
		show_island_screen()
	else:
		var error: Dictionary = response.get("error", {})
		var info := get_node_or_null("IslandPlotInfo") as Label
		if info != null: info.text = String(error.get("message", "任务未能加入队列"))


func _move_island_worker(cell: Vector2i) -> void:
	if selected_island_worker.is_empty():
		return
	selected_island_object_type = ""
	selected_island_object_id = ""
	_enqueue_island_task("MOVE_TO_CELL", [], {"targetCell":[cell.x, cell.y]})


func _cancel_island_queue(task_ids: Array) -> void:
	if selected_island_worker.is_empty() or task_ids.is_empty():
		return
	var body := {"requestId":"island_cancel_%d_%d" % [Time.get_ticks_msec(), randi()], "taskIds":task_ids}
	var response := await api_request("/island/workers/%s/tasks/cancel" % selected_island_worker, HTTPClient.METHOD_POST, body)
	if bool(response.get("ok", false)):
		show_island_screen()
	else:
		var error: Dictionary = response.get("error", {})
		var info := get_node_or_null("IslandPlotInfo") as Label
		if info != null: info.text = str(error.get("message", "任务取消失败"))


func _island_target_owner(object_id: String) -> String:
	for worker in island_payload.get("islandWorkers", []):
		for group in worker.get("queue", []):
			if str(group.get("state", "")) in ["COMPLETED", "SKIPPED", "CANCELLED"]:
				continue
			if object_id in group.get("targetIds", []):
				return str(worker.get("workerId", ""))
	return ""

func _resource_task_type(object_id: String) -> String:
	for value in island_payload.get("resourceNodes", []):
		if String(value["instanceId"]) == object_id:
			return "GATHER_TREE" if "tree" in String(value["resourceType"]) else "GATHER_ORE"
	return "GATHER_TREE"

func _island_farm(object_id: String) -> Dictionary:
	for value in island_payload.get("farmPlots", []):
		if String(value["farmPlotId"]) == object_id: return value
	return {}

func _island_available_item(item_id: String) -> int:
	for value in island_payload.get("inventory", []):
		if String(value["itemId"]) == item_id: return int(value.get("availableQuantity", 0))
	return 0

func _available_crops_for_farm(farm: Dictionary) -> Array:
	var result := []
	var farm_type := String(farm.get("farmType", ""))
	for crop in island_payload.get("crops", []):
		if farm_type in crop.get("allowedFarmTypes", []):
			result.append(crop)
	return result

func _selected_farm_crop(farm: Dictionary) -> Dictionary:
	var crops := _available_crops_for_farm(farm)
	return {} if crops.is_empty() else crops[selected_island_crop_index % crops.size()]

func _island_worker_status_text(worker: Dictionary) -> String:
	var worker_name := String(worker.get("workerId", "")).replace("island_worker_", "工人")
	var queue: Array = worker.get("queue", [])
	var quantity := 0
	for group in queue:
		if String(group.get("state", "")) not in ["COMPLETED", "SKIPPED", "CANCELLED"]:
			quantity += int(group.get("quantity", 1))
	var state_names := {"IDLE":"空闲", "TRAVELING":"前往中", "WORKING":"工作中", "RETURNING":"返回箱子", "DEPOSITING":"存放中"}
	return "%s已选中·%s · 待办%d次 · 请点击目标" % [worker_name, state_names.get(String(worker.get("state", "IDLE")), "空闲"), quantity]


func _build_island_worker_dock() -> void:
	var old := get_node_or_null("IslandWorkerDock")
	if old != null:
		remove_child(old)
		old.queue_free()
	var dock := Control.new()
	dock.name = "IslandWorkerDock"
	dock.z_index = 20
	place(dock, 8, 136, 704, 84)
	add_child(dock)
	var worker_panel := NinePatchRect.new()
	worker_panel.texture = PANEL
	worker_panel.patch_margin_left = 28
	worker_panel.patch_margin_top = 24
	worker_panel.patch_margin_right = 28
	worker_panel.patch_margin_bottom = 24
	worker_panel.position = Vector2.ZERO
	worker_panel.size = Vector2(62, 84)
	dock.add_child(worker_panel)
	var workers: Array = island_payload.get("islandWorkers", [])
	for index in range(mini(5, workers.size())):
		var worker: Dictionary = workers[index]
		var button := TextureButton.new()
		button.name = "IslandWorkerButton%d" % (index + 1)
		button.texture_normal = _island_frame_texture(ISLAND_WORKER_IDLE)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.tooltip_text = "选择工人%d" % (index + 1)
		button.position = Vector2(5, 6 + index * 70)
		button.size = Vector2(52, 62)
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", 14)
		button.modulate = Color("fff2a3") if str(worker.get("workerId", "")) == selected_island_worker else Color.WHITE
		button.pressed.connect(_select_island_worker.bind(str(worker.get("workerId", ""))))
		worker_panel.add_child(button)
	worker_panel.size.y = maxf(84.0, 12.0 + mini(5, workers.size()) * 70.0)

	var queue_panel := NinePatchRect.new()
	queue_panel.name = "IslandWorkerQueuePanel"
	queue_panel.texture = PANEL
	queue_panel.patch_margin_left = 34
	queue_panel.patch_margin_top = 24
	queue_panel.patch_margin_right = 34
	queue_panel.patch_margin_bottom = 24
	queue_panel.position = Vector2(70, 0)
	queue_panel.size = Vector2(634, 84)
	dock.add_child(queue_panel)
	var title := Label.new()
	title.text = "%s队列" % selected_island_worker.replace("island_worker_", "工人")
	title.position = Vector2(16, 5)
	title.size = Vector2(86, 24)
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("fff1c7"))
	queue_panel.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(98, 6)
	scroll.size = Vector2(520, 70)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_panel.add_child(scroll)
	var row := HBoxContainer.new()
	row.name = "IslandWorkerQueueRow"
	row.add_theme_constant_override("separation", 7)
	row.custom_minimum_size = Vector2(510, 64)
	scroll.add_child(row)
	var selected := _selected_island_worker_data()
	var shown := 0
	for group_value in selected.get("queue", []):
		var group: Dictionary = group_value
		if str(group.get("state", "")) in ["COMPLETED", "SKIPPED", "CANCELLED"]:
			continue
		row.add_child(_build_island_queue_icon(group))
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "空闲 · 点击地图安排任务"
		empty.custom_minimum_size = Vector2(300, 60)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_override("font", FONT)
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color("d8e8e5"))
		row.add_child(empty)


func _build_island_queue_icon(group: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64, 64)
	var icon := TextureRect.new()
	icon.texture = _island_queue_texture(str(group.get("type", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4, 6)
	icon.size = Vector2(50, 50)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var cancel := Button.new()
	cancel.text = "×"
	cancel.tooltip_text = "本轮完成后取消" if str(group.get("state", "")) in ["TRAVELING", "WORKING", "RETURNING", "DEPOSITING", "IN_PROGRESS"] else "取消队列任务"
	cancel.position = Vector2(42, 0)
	cancel.size = Vector2(22, 22)
	cancel.add_theme_font_size_override("font_size", 16)
	cancel.pressed.connect(_cancel_island_queue.bind(group.get("taskIds", []).duplicate()))
	holder.add_child(cancel)
	if int(group.get("quantity", 1)) > 1:
		var quantity := Label.new()
		quantity.text = "×%d" % int(group.get("quantity", 1))
		quantity.position = Vector2(34, 42)
		quantity.size = Vector2(28, 20)
		quantity.add_theme_font_override("font", FONT)
		quantity.add_theme_font_size_override("font_size", 13)
		quantity.add_theme_color_override("font_color", Color("fff1c7"))
		holder.add_child(quantity)
	if bool(group.get("cancelRequested", false)):
		icon.modulate = Color(0.65, 0.7, 0.7, 0.72)
	return holder


func _selected_island_worker_data() -> Dictionary:
	for worker in island_payload.get("islandWorkers", []):
		if str(worker.get("workerId", "")) == selected_island_worker:
			return worker
	return {}


func _island_frame_texture(texture: Texture2D) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 192, 192)
	return atlas


func _island_queue_texture(task_type: String) -> Texture2D:
	if task_type == "GATHER_TREE": return _island_frame_texture(ISLAND_WORKER_AXE)
	if task_type in ["GATHER_ORE", "GATHER_STONE", "GATHER_GOLD"]: return _island_frame_texture(ISLAND_WORKER_PICKAXE)
	if task_type in ["PLANT_CROP", "HARVEST_CROP", "BATCH_PLANT", "BATCH_HARVEST"]: return _island_frame_texture(ISLAND_WORKER_FARM)
	if task_type == "MOVE_TO_CELL": return _island_frame_texture(ISLAND_WORKER_RUN)
	return _island_frame_texture(ISLAND_WORKER_IDLE)

func _build_island_resource_strip() -> void:
	var strip := NinePatchRect.new()
	strip.name = "IslandResourceStrip"
	strip.texture = PANEL
	strip.patch_margin_left = 40
	strip.patch_margin_top = 24
	strip.patch_margin_right = 40
	strip.patch_margin_bottom = 24
	place(strip, 100, 72, 520, 54)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var values := [
		[WOOD_ICON, "木材", _island_available_item("wood")],
		[STONE_ICON, "矿石", _island_available_item("ore")],
		[GOLD_ICON, "金币", player_gold],
	]
	for index in range(values.size()):
		var icon := TextureRect.new()
		icon.texture = values[index][0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		place(icon, 122 + index * 168, 80, 34, 34)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var value_label := make_label("%s %d" % [values[index][1], values[index][2]], 158 + index * 168, 80, 120, 34, 16, Color("fff1c7"), HORIZONTAL_ALIGNMENT_LEFT, 6)
		value_label.name = "IslandResourceValue%d" % index

func _schedule_island_runtime_sync(token: int) -> void:
	var delay := _next_island_sync_delay()
	if delay < 0.0:
		return
	await get_tree().create_timer(delay).timeout
	if token != game_screen_token or get_node_or_null("IslandMapView") == null:
		return
	var response := await api_request("/island", HTTPClient.METHOD_GET)
	if token != game_screen_token or not bool(response.get("ok", false)):
		return
	island_payload = response.duplicate(true)
	var view := get_node_or_null("IslandMapView")
	if view != null:
		view.update_server_state(response)
		if not selected_island_worker.is_empty(): view.select_worker(selected_island_worker)
	_update_island_resource_values()
	_build_island_worker_dock()
	if selected_island_plot >= 5:
		_select_island_plot(selected_island_plot)
	elif not selected_island_object_id.is_empty() and selected_island_object_type in ["farm", "building"]:
		_select_island_object(selected_island_object_type, selected_island_object_id)
	elif not selected_island_worker.is_empty():
		_select_island_worker_status_only(selected_island_worker)
	_schedule_island_runtime_sync.call_deferred(token)


func _next_island_sync_delay() -> float:
	var server_now := int(island_payload.get("serverTime", 0))
	var earliest_end := 0
	var has_queued := false
	for worker in island_payload.get("islandWorkers", []):
		var active: Variant = worker.get("activeTask")
		if active is Dictionary and not active.is_empty():
			var plan: Dictionary = active.get("plan", {})
			var end_at := int(plan.get("activatedAt", server_now))
			for step in plan.get("steps", []):
				end_at += int(step.get("durationMs", 0))
			if earliest_end == 0 or end_at < earliest_end:
				earliest_end = end_at
		for group in worker.get("queue", []):
			if str(group.get("state", "")) not in ["COMPLETED", "SKIPPED", "CANCELLED"]:
				has_queued = true
	if earliest_end > 0:
		return maxf(0.25, float(earliest_end - server_now) / 1000.0 + 0.18)
	return 0.5 if has_queued else -1.0

func _update_island_resource_values() -> void:
	var values := [["木材",_island_available_item("wood")],["矿石",_island_available_item("ore")],["金币",player_gold]]
	for index in range(values.size()):
		var label := get_node_or_null("IslandResourceValue%d" % index) as Label
		if label != null: label.text = "%s %d" % [values[index][0],values[index][1]]

func _select_island_worker_status_only(worker_id: String) -> void:
	for value in island_payload.get("islandWorkers", []):
		if String(value.get("workerId", "")) == worker_id:
			var info := get_node_or_null("IslandPlotInfo") as Label
			if info != null: info.text = _island_worker_status_text(value)
			return

func _buy_island_seed(crop_id: String, quantity: int) -> void:
	var response := await api_request("/island/seeds/%s/buy" % crop_id, HTTPClient.METHOD_POST, {"requestId":"seed_%d_%d" % [Time.get_ticks_msec(),randi()],"quantity":quantity})
	if bool(response.get("ok",false)):
		player_gold = int(response.get("coins",player_gold))
		show_island_screen()
	else:
		var error: Dictionary = response.get("error",{})
		var info := get_node_or_null("IslandPlotInfo") as Label
		if info != null: info.text = String(error.get("message","种子购买失败"))

func _island_building(object_id: String) -> Dictionary:
	for value in island_payload.get("buildings", []):
		if String(value["buildingId"]) == object_id: return value
	return {}

func _recipes_for_selected_building() -> Array:
	var building_type := ""
	for value in island_payload.get("buildings", []):
		if String(value["buildingId"]) == selected_island_object_id:
			building_type = String(value["buildingType"])
			break
	var result := []
	for recipe in island_payload.get("recipes", []):
		if String(recipe["buildingType"]) == building_type: result.append(recipe)
	return result

func _selected_building_recipe() -> Dictionary:
	var recipes := _recipes_for_selected_building()
	return {} if recipes.is_empty() else recipes[selected_island_option_index % recipes.size()]

func _unlock_selected_plot() -> void:
	if selected_island_plot < 5:
		return
	var button := get_node_or_null("IslandUnlockButton") as Button
	if button != null:
		button.disabled = true
		button.text = "解锁中"
	var request_id := "plot_%d_%d" % [Time.get_ticks_msec(), randi()]
	var response := await api_request("/island/plots/%d/unlock" % selected_island_plot, HTTPClient.METHOD_POST, {"requestId": request_id})
	if bool(response.get("ok", false)):
		pending_island_reveal = selected_island_plot
		show_island_screen()
	elif button != null:
		button.text = "解锁失败"

func build_menu_background() -> void:
	var bg := TextureRect.new()
	bg.texture = MAP_PREVIEW
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	place(bg, -360, -360, 1440, 2000)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.075, 0.78)
	place(shade, -360, -360, 1440, 2000)
	add_child(shade)

func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func setup_audio_players() -> void:
	audio_root = Node.new()
	audio_root.name = "AudioRoot"
	add_child(audio_root)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	var loop_stream = MUSIC_LOOP.duplicate()
	if loop_stream is AudioStreamWAV:
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop_stream.loop_begin = 0
		loop_stream.loop_end = int(loop_stream.get_length() * loop_stream.mix_rate)
	music_player.stream = loop_stream
	audio_root.add_child(music_player)
	music_player.play()

func load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)

func save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save("user://audio_settings.cfg")

func apply_audio_volumes() -> void:
	set_bus_linear_volume("Music", music_volume)
	set_bus_linear_volume("SFX", sfx_volume)

func set_bus_linear_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func play_sfx(stream: AudioStream, volume_db := 0.0, pitch_variation := 0.035) -> void:
	if test_mode or stream == null or audio_root == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = audio_rng.randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	audio_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_attack_sfx(unit_type: String) -> void:
	match unit_type:
		"archer": play_sfx(SFX_ARROW_RELEASE, -4.0, 0.025)
		"monk": play_sfx(SFX_MAGIC_CAST, -5.0, 0.025)
		_: play_sfx(SFX_MELEE_SWING, -6.0, 0.05)

func play_damage_sfx() -> void:
	play_sfx(SFX_IMPACT, -5.0, 0.05)

func play_heal_sfx() -> void:
	play_sfx(SFX_HEAL, -5.0, 0.025)

func play_death_sfx() -> void:
	play_sfx(SFX_DEATH, -4.0, 0.04)

func play_resource_hit_sfx(kind: String) -> void:
	match kind:
		"wood": play_sfx(SFX_GATHER_WOOD, -5.0, 0.05)
		"meat": play_sfx(SFX_GATHER_MEAT, -6.0, 0.05)
		"gold": play_sfx(SFX_GATHER_GOLD, -5.0, 0.035)
		_: play_sfx(SFX_GATHER_STONE, -5.0, 0.04)

func update_player_name(value: String) -> void:
	var cleaned := value.strip_edges()
	player_name = cleaned if cleaned != "" else "无名勇士"
	if cloud_ready:
		sync_profile.call_deferred()

func open_avatar_dialog() -> void:
	var dialog := FileDialog.new()
	dialog.title = "选择玩家头像"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ; PNG 图片", "*.jpg, *.jpeg ; JPEG 图片"])
	dialog.size = Vector2i(620, 760)
	dialog.file_selected.connect(func(path: String) -> void:
		var image := Image.new()
		if image.load(path) == OK:
			player_avatar = ImageTexture.create_from_image(image)
			show_main_menu()
	)
	add_child(dialog)
	dialog.popup_centered()

func load_battle_setup() -> void:
	card_decks.clear()
	deck_names.clear()
	strategies.clear()
	for index in 5:
		card_decks.append(DEFAULT_LINEUP.duplicate())
		deck_names.append("卡组 %d" % (index + 1))
	for index in 20:
		strategies.append({"name": "策略 %02d" % (index + 1), "messages": [], "compiled": {}, "compiled_lineup": []})
	var config := ConfigFile.new()
	if config.load(SETUP_SAVE_PATH) == OK:
		for index in 5:
			deck_names[index] = String(config.get_value("decks", "name_%d" % index, deck_names[index]))
			var saved_lineup: Variant = config.get_value("decks", "lineup_%d" % index, DEFAULT_LINEUP.duplicate())
			card_decks[index] = normalize_lineup(saved_lineup)
		for index in 20:
			var strategy_name := String(config.get_value("strategies", "name_%d" % index, strategies[index]["name"]))
			var saved_messages: Variant = config.get_value("strategies", "messages_%d" % index, [])
			var saved_compiled: Variant = config.get_value("strategies", "compiled_%d" % index, {})
			var saved_compiled_lineup: Variant = config.get_value("strategies", "compiled_lineup_%d" % index, [])
			strategies[index] = {
				"name": strategy_name,
				"messages": normalize_messages(saved_messages),
				"compiled": saved_compiled if saved_compiled is Dictionary else {},
				"compiled_lineup": normalize_lineup(saved_compiled_lineup) if saved_compiled_lineup is Array and saved_compiled_lineup.size() == 5 else []
			}
	current_deck_index = clampi(int(config.get_value("selection", "deck", 0)), 0, 4) if config.load(SETUP_SAVE_PATH) == OK else 0
	current_strategy_index = clampi(int(config.get_value("selection", "strategy", 0)), 0, 19) if config.load(SETUP_SAVE_PATH) == OK else 0
	player_lineup = card_decks[current_deck_index].duplicate()
	strategy_messages = Array(strategies[current_strategy_index]["messages"]).duplicate()
	active_strategy = get_saved_compiled_strategy(current_strategy_index)
	active_strategy_messages = strategy_messages.duplicate() if not active_strategy.is_empty() else []

func normalize_lineup(value: Variant) -> Array:
	var result: Array = []
	if value is Array and value.size() >= 2 and value.size() <= 5:
		for entry in value:
			var kind := String(entry)
			result.append(kind if kind in UNIT_TYPES else "")
		while result.size() < 5: result.append("")
	if result.size() != 5:
		return DEFAULT_LINEUP.duplicate()
	return result

func active_player_lineup() -> Array:
	var result: Array = []
	for value in player_lineup:
		var kind := str(value)
		if kind not in UNIT_TYPES: break
		result.append(kind)
	return result

func normalize_messages(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for entry in value:
			var message := String(entry).strip_edges()
			if message != "":
				result.append(message)
	return result

func save_battle_setup() -> void:
	var config := ConfigFile.new()
	for index in 5:
		config.set_value("decks", "name_%d" % index, deck_names[index])
		config.set_value("decks", "lineup_%d" % index, card_decks[index])
	for index in 20:
		config.set_value("strategies", "name_%d" % index, strategies[index]["name"])
		config.set_value("strategies", "messages_%d" % index, strategies[index]["messages"])
		config.set_value("strategies", "compiled_%d" % index, strategies[index].get("compiled", {}))
		config.set_value("strategies", "compiled_lineup_%d" % index, strategies[index].get("compiled_lineup", []))
	config.set_value("selection", "deck", current_deck_index)
	config.set_value("selection", "strategy", current_strategy_index)
	config.save(SETUP_SAVE_PATH)
	if cloud_ready and not cloud_loading:
		sync_state_to_cloud.call_deferred()

func load_account() -> void:
	var config := ConfigFile.new()
	if config.load(ACCOUNT_SAVE_PATH) == OK:
		account_token = String(config.get_value("account", "token", ""))
		account_player_id = String(config.get_value("account", "player_id", ""))

func save_account() -> void:
	var config := ConfigFile.new()
	config.set_value("account", "token", account_token)
	config.set_value("account", "player_id", account_player_id)
	config.save(ACCOUNT_SAVE_PATH)

func api_base_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin")
		if origin != null and String(origin).begins_with("http"):
			return String(origin) + "/game_1/api/v1"
	return "http://127.0.0.1:19031"

func api_headers(authenticated := true) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated and account_token != "":
		headers.append("Authorization: Bearer " + account_token)
	return headers

func api_request(path: String, method: HTTPClient.Method, body: Dictionary = {}, authenticated := true) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 30.0
	(audio_root if audio_root != null else self).add_child(request)
	var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var start_error := request.request(api_base_url() + path, api_headers(authenticated), method, payload)
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": "request_start_failed"}
	var completed: Array = await request.request_completed
	request.queue_free()
	if completed.size() < 4 or int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "request_failed"}
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	return Dictionary(parsed) if parsed is Dictionary else {"ok": false, "error": "invalid_response"}

func ensure_cloud_account() -> void:
	var response: Dictionary
	var new_account := account_token == ""
	if new_account:
		response = await api_request("/account/guest", HTTPClient.METHOD_POST, {"display_name": player_name}, false)
	else:
		response = await api_request("/account/me", HTTPClient.METHOD_GET)
		# Guest tokens can become invalid after a server/database migration. A
		# stale local token must not permanently disable cloud history; renew the
		# anonymous account once, then persist the replacement token.
		if not bool(response.get("ok", false)) and String(response.get("error", "")) == "unauthorized":
			account_token = ""
			account_player_id = ""
			new_account = true
			response = await api_request("/account/guest", HTTPClient.METHOD_POST, {"display_name": player_name}, false)
	if not bool(response.get("ok", false)):
		cloud_ready = false
		cloud_status = "云端暂不可用 · 本地数据仍可使用"
		return
	if new_account:
		account_token = String(response.get("token", ""))
	var player: Dictionary = response.get("player", {})
	apply_cloud_player(player)
	account_player_id = String(player.get("id", account_player_id))
	save_account()
	cloud_ready = false
	cloud_status = "游客账号 · 正在同步云端数据"
	if new_account:
		await sync_state_to_cloud(true)
	else:
		await load_state_from_cloud()
	cloud_ready = true
	cloud_status = ("正式账号" if account_type == "registered" else "游客账号") + " · 数据已连接云端"
	await refresh_game_home()

func refresh_game_home() -> void:
	var response := await api_request("/home", HTTPClient.METHOD_GET)
	if not bool(response.get("ok", false)):
		return
	var growth: Dictionary = response.get("playerGrowth", {})
	player_level = int(growth.get("level", player_level))
	player_experience = int(growth.get("xp", player_experience))
	player_level_start_xp = int(growth.get("currentLevelCumulativeXp", player_level_start_xp))
	var next_value: Variant = growth.get("nextLevelCumulativeXp")
	player_next_level_xp = player_experience if next_value == null else int(next_value)

func apply_cloud_player(player: Dictionary) -> void:
	if player.is_empty():
		return
	player_name = String(player.get("display_name", player_name))
	account_type = String(player.get("account_type", account_type))
	player_level = int(player.get("level", player_level))
	player_experience = int(player.get("experience", player_experience))
	player_gold = int(player.get("gold", player_gold))
	player_diamonds = int(player.get("diamonds", player_diamonds))
	cloud_status = ("正式账号" if account_type == "registered" else "游客账号") + " · 云端已连接"

func show_account_screen() -> void:
	clear_screen()
	build_menu_background()
	make_title("玩家账号")
	make_panel(55, 245, 610, 700)
	make_label("当前：%s" % ("正式账号" if account_type == "registered" else "游客账号"), 105, 300, 510, 44, 24, Color("45343a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	make_label("绑定后可在其他设备登录并恢复卡组、策略和战绩", 85, 350, 550, 52, 17, Color("765b5a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var username := LineEdit.new()
	username.placeholder_text = "用户名：4-24位英文、数字或下划线"
	username.max_length = 24
	username.position = Vector2(115, 430)
	username.size = Vector2(490, 58)
	username.add_theme_font_override("font", FONT)
	username.add_theme_font_size_override("font_size", 19)
	add_child(username)
	var password := LineEdit.new()
	password.placeholder_text = "密码：至少8位"
	password.secret = true
	password.max_length = 72
	password.position = Vector2(115, 515)
	password.size = Vector2(490, 58)
	password.add_theme_font_override("font", FONT)
	password.add_theme_font_size_override("font_size", 19)
	add_child(password)
	make_label(account_status, 100, 595, 520, 58, 17, Color("9d4f55"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var bind_button := make_ui_button("绑定当前游客账号", Rect2(115, 675, 235, 66), register_account.bind(username, password), 18, Color("287e8a"))
	bind_button.disabled = account_type == "registered"
	make_ui_button("登录已有账号", Rect2(370, 675, 235, 66), login_account.bind(username, password), 18, Color("a76e28"))
	make_ui_button("返回主界面", Rect2(205, 835, 310, 66), show_main_menu, 20, Color("596d72"))

func register_account(username: LineEdit, password: LineEdit) -> void:
	var response := await api_request("/account/register", HTTPClient.METHOD_POST, {"username": username.text, "password": password.text})
	if bool(response.get("ok", false)):
		apply_cloud_player(Dictionary(response.get("player", {})))
		account_status = "绑定成功，当前数据已保留"
	else:
		account_status = account_error_text(String(response.get("error", "register_failed")))
	show_account_screen()

func login_account(username: LineEdit, password: LineEdit) -> void:
	var response := await api_request("/account/login", HTTPClient.METHOD_POST, {"username": username.text, "password": password.text}, false)
	if bool(response.get("ok", false)):
		account_token = String(response.get("token", ""))
		apply_cloud_player(Dictionary(response.get("player", {})))
		account_player_id = String(response.get("player", {}).get("id", ""))
		save_account()
		cloud_ready = true
		await load_state_from_cloud()
		account_status = "登录成功，云端数据已恢复"
	else:
		account_status = account_error_text(String(response.get("error", "login_failed")))
	show_account_screen()

func account_error_text(code: String) -> String:
	match code:
		"username_format": return "用户名只能使用4-24位英文、数字或下划线"
		"password_length": return "密码长度需要在8-72位之间"
		"username_taken": return "这个用户名已经被使用"
		"invalid_credentials": return "用户名或密码不正确"
		"account_not_guest": return "当前账号已经完成绑定"
	return "账号操作失败，请稍后重试"

func sync_profile() -> void:
	if not cloud_ready:
		return
	var response := await api_request("/account/profile", HTTPClient.METHOD_POST, {"display_name": player_name})
	if bool(response.get("ok", false)):
		apply_cloud_player(Dictionary(response.get("player", {})))

func cloud_decks_payload() -> Array:
	var result: Array = []
	for index in 5:
		result.append({"name": String(deck_names[index]), "lineup": Array(card_decks[index]).duplicate()})
	return result

func cloud_strategies_payload() -> Array:
	var result: Array = []
	for index in 20:
		result.append({
			"name": String(strategies[index].get("name", "策略 %02d" % (index + 1))),
			"messages": Array(strategies[index].get("messages", [])).duplicate(),
			"compiled": Dictionary(strategies[index].get("compiled", {})).duplicate(true),
			"compiled_lineup": Array(strategies[index].get("compiled_lineup", [])).duplicate(),
		})
	return result

func sync_state_to_cloud(force := false) -> void:
	if (not cloud_ready and not force) or cloud_syncing:
		return
	cloud_syncing = true
	var response := await api_request("/state", HTTPClient.METHOD_POST, {
		"decks": cloud_decks_payload(),
		"strategies": cloud_strategies_payload(),
		"settings": {"music": music_volume, "sfx": sfx_volume, "selected_deck": current_deck_index, "selected_strategy": current_strategy_index},
	})
	cloud_syncing = false
	cloud_status = "游客账号 · 云端已同步" if bool(response.get("ok", false)) else "云端同步失败 · 已保存在本地"

func load_state_from_cloud() -> void:
	var response := await api_request("/state", HTTPClient.METHOD_GET)
	if not bool(response.get("ok", false)):
		return
	var state: Dictionary = response.get("state", {})
	var remote_decks: Variant = state.get("decks", [])
	var remote_strategies: Variant = state.get("strategies", [])
	if remote_decks is Array and remote_decks.size() == 5:
		cloud_loading = true
		for index in 5:
			if remote_decks[index] is Dictionary:
				deck_names[index] = String(remote_decks[index].get("name", deck_names[index]))
				card_decks[index] = normalize_lineup(remote_decks[index].get("lineup", card_decks[index]))
		if remote_strategies is Array and remote_strategies.size() == 20:
			for index in 20:
				if remote_strategies[index] is Dictionary:
					strategies[index] = Dictionary(remote_strategies[index]).duplicate(true)
		var settings: Dictionary = state.get("settings", {})
		current_deck_index = clampi(int(settings.get("selected_deck", current_deck_index)), 0, 4)
		current_strategy_index = clampi(int(settings.get("selected_strategy", current_strategy_index)), 0, 19)
		player_lineup = Array(card_decks[current_deck_index]).duplicate()
		strategy_messages = Array(strategies[current_strategy_index].get("messages", [])).duplicate()
		save_battle_setup()
		cloud_loading = false
	cloud_status = "游客账号 · 云端数据已载入"

func show_battle_history() -> void:
	clear_screen()
	build_menu_background()
	make_title("历史战斗")
	make_panel(30, 165, 660, 1000)
	make_label("正在读取云端战绩……", 80, 560, 560, 50, 21, Color("59434a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var response := await api_request("/battles?limit=20", HTTPClient.METHOD_GET)
	battle_history = Array(response.get("battles", [])) if bool(response.get("ok", false)) else []
	build_battle_history_screen(bool(response.get("ok", false)))

func build_battle_history_screen(success: bool) -> void:
	clear_screen()
	build_menu_background()
	make_title("历史战斗")
	make_panel(30, 165, 660, 1000)
	if not success:
		make_label("读取失败，请检查网络后重试", 80, 540, 560, 60, 22, Color("9d4f55"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	elif battle_history.is_empty():
		make_label("还没有战斗记录\n完成一局后会自动保存在这里", 80, 500, 560, 100, 22, Color("59434a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	else:
		var scroll := ScrollContainer.new()
		place(scroll, 55, 195, 610, 845)
		add_child(scroll)
		var list := VBoxContainer.new()
		list.custom_minimum_size = Vector2(585, 0)
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)
		for index in mini(20, battle_history.size()):
			var battle: Dictionary = battle_history[index]
			var outcome := String(battle.get("outcome", "draw"))
			var result_name := "胜利" if outcome == "victory" else ("失败" if outcome == "defeat" else "平局")
			var created := String(battle.get("created_at", "")).replace("T", " ")
			if created.length() > 16:
				created = created.substr(0, 16)
			var snapshot: Dictionary = battle.get("strategy_snapshot", {}) if battle.get("strategy_snapshot", {}) is Dictionary else {}
			var strategy_name := String(snapshot.get("strategy_name", "默认战术"))
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(585, 82)
			row.add_theme_constant_override("separation", 10)
			var description := create_label("%s · %s\n%s · %.1f秒" % [result_name, strategy_name, created, float(battle.get("duration_seconds", 0.0))], 0, 0, 0, 0, 17, Color("3f514d"), HORIZONTAL_ALIGNMENT_LEFT, 0)
			description.custom_minimum_size = Vector2(440, 72)
			description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(description)
			var replay_button := Button.new()
			replay_button.text = "回放"
			replay_button.custom_minimum_size = Vector2(120, 52)
			replay_button.add_theme_font_override("font", FONT)
			replay_button.add_theme_font_size_override("font_size", 17)
			replay_button.add_theme_color_override("font_color", Color("fff7df"))
			var replay_style := StyleBoxFlat.new()
			replay_style.bg_color = Color("287e8a")
			replay_style.corner_radius_top_left = 8
			replay_style.corner_radius_top_right = 8
			replay_style.corner_radius_bottom_left = 8
			replay_style.corner_radius_bottom_right = 8
			replay_button.add_theme_stylebox_override("normal", replay_style)
			replay_button.pressed.connect(func() -> void:
				play_sfx(SFX_UI_CLICK, -4.0, 0.02)
				play_history_battle(index)
			)
			row.add_child(replay_button)
			list.add_child(row)
	make_ui_button("返回主界面", Rect2(205, 1080, 310, 64), show_main_menu, 20, Color("596d72"))

func play_history_battle(index: int) -> void:
	if index < 0 or index >= battle_history.size():
		return
	var battle: Dictionary = battle_history[index]
	var response := await api_request("/battles/%s/replay" % String(battle.get("id", "")), HTTPClient.METHOD_GET)
	if not bool(response.get("ok", false)):
		cloud_status = "历史回放读取失败"
		return
	active_replay = Dictionary(response.get("replay", {})).duplicate(true)
	active_strategy = Dictionary(battle.get("strategy_snapshot", {})).duplicate(true)
	player_lineup = normalize_lineup(battle.get("lineup", DEFAULT_LINEUP))
	start_game()

func show_lineup_screen() -> void:
	strategy_send_token += 1
	clear_screen()
	build_menu_background()
	make_title("战前编队")
	make_panel(30, 165, 660, 920)
	make_label("选择卡组", 55, 190, 125, 46, 20, Color("49373d"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	var deck_select := OptionButton.new()
	deck_select.name = "DeckTemplateSelect"
	for index in 5:
		deck_select.add_item(String(deck_names[index]), index)
	deck_select.select(current_deck_index)
	deck_select.position = Vector2(180, 190)
	deck_select.size = Vector2(205, 48)
	deck_select.add_theme_font_override("font", FONT)
	deck_select.add_theme_font_size_override("font_size", 19)
	deck_select.get_popup().add_theme_font_override("font", FONT)
	deck_select.get_popup().add_theme_font_size_override("font_size", 19)
	deck_select.item_selected.connect(select_card_deck)
	add_child(deck_select)
	var deck_name_edit := LineEdit.new()
	deck_name_edit.text = String(deck_names[current_deck_index])
	deck_name_edit.max_length = 12
	deck_name_edit.placeholder_text = "卡组名称"
	deck_name_edit.position = Vector2(400, 190)
	deck_name_edit.size = Vector2(210, 48)
	deck_name_edit.add_theme_font_override("font", FONT)
	deck_name_edit.add_theme_font_size_override("font_size", 18)
	add_child(deck_name_edit)
	make_ui_button("保存卡组", Rect2(400, 250, 105, 46), save_current_deck.bind(deck_name_edit), 17)
	make_ui_button("清空", Rect2(515, 250, 95, 46), clear_current_deck, 17, Color("9d4f55"))
	make_label("出战位置（点击位置后再选择单位）", 55, 305, 610, 42, 20, Color("59434a"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	for index in 5:
		build_lineup_slot(index)
	make_label("可选单位 · 可以重复选择", 55, 600, 610, 40, 20, Color("59434a"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	for index in UNIT_TYPES.size():
		build_unit_choice(index, String(UNIT_TYPES[index]))
	var complete := is_lineup_complete()
	make_label("已选择%d名英雄，可以继续" % active_player_lineup().size() if complete else "请从1号起连续选择2-5名英雄", 80, 905, 560, 34, 18, Color("3f826f") if complete else Color("a14f51"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	make_ui_button("返回", Rect2(80, 1115, 180, 68), show_main_menu, 23, Color("596d72"))
	var next_button := make_ui_button("下一步：团队策略", Rect2(285, 1115, 355, 68), open_strategy_screen, 23, Color("287e8a"))
	next_button.disabled = not complete

func build_lineup_slot(index: int) -> void:
	var x := 45.0 + index * 128.0
	var box := ColorRect.new()
	box.color = Color("d9bb72") if index == selected_lineup_slot else Color("e7d7b0")
	place(box, x, 355, 116, 220)
	add_child(box)
	make_label("%d号" % (index + 1), x + 5, 360, 106, 35, 21, Color("49373d"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var kind := String(player_lineup[index])
	if kind in UNIT_TYPES:
		var portrait := TextureRect.new()
		portrait.texture = get_unit_portrait(kind)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		place(portrait, x + 5, 395, 106, 120)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(portrait)
		make_label(String(UNIT_NAMES[kind]), x + 4, 520, 108, 38, 17, Color("49373d"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	else:
		make_label("＋", x + 5, 405, 106, 100, 46, Color("8b7457"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		make_label("待选择", x + 4, 520, 108, 38, 17, Color("765f56"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var hit := Button.new()
	hit.flat = true
	place(hit, x, 355, 116, 220)
	hit.pressed.connect(select_lineup_slot.bind(index))
	add_child(hit)

func build_unit_choice(index: int, kind: String) -> void:
	var x := 45.0 + index * 128.0
	var box := ColorRect.new()
	box.color = Color("c9e0d5")
	place(box, x, 650, 116, 205)
	add_child(box)
	var portrait := TextureRect.new()
	portrait.texture = get_unit_portrait(kind)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	place(portrait, x + 4, 660, 108, 135)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	make_label(String(UNIT_NAMES[kind]), x + 4, 800, 108, 38, 17, Color("30464a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var hit := Button.new()
	hit.flat = true
	place(hit, x, 650, 116, 205)
	hit.pressed.connect(assign_lineup_unit.bind(kind))
	add_child(hit)

func get_unit_portrait(kind: String) -> Texture2D:
	var path := "res://assets/game/units/worker/blue_idle.png"
	var frame_size := 192
	match kind:
		"archer": path = "res://assets/game/units/archer/blue.png"
		"lancer":
			path = "res://assets/game/units/lancer/blue_idle.png"
			frame_size = 320
		"monk": path = "res://assets/game/units/monk/blue_idle.png"
		"warrior": path = "res://assets/game/units/warrior/blue.png"
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(0, 0, frame_size, frame_size)
	return atlas

func select_card_deck(index: int) -> void:
	current_deck_index = clampi(index, 0, 4)
	player_lineup = Array(card_decks[current_deck_index]).duplicate()
	selected_lineup_slot = 0
	save_battle_setup()
	show_lineup_screen()

func select_lineup_slot(index: int) -> void:
	selected_lineup_slot = clampi(index, 0, 4)
	show_lineup_screen()

func assign_lineup_unit(kind: String) -> void:
	player_lineup[selected_lineup_slot] = kind
	if selected_lineup_slot < 4:
		selected_lineup_slot += 1
	show_lineup_screen()

func save_current_deck(name_edit: LineEdit) -> void:
	var cleaned_name := name_edit.text.strip_edges()
	deck_names[current_deck_index] = cleaned_name if cleaned_name != "" else "卡组 %d" % (current_deck_index + 1)
	card_decks[current_deck_index] = player_lineup.duplicate()
	save_battle_setup()
	show_lineup_screen()

func clear_current_deck() -> void:
	player_lineup = ["", "", "", "", ""]
	selected_lineup_slot = 0
	show_lineup_screen()

func is_lineup_complete() -> bool:
	if player_lineup.size() != 5:
		return false
	var count := active_player_lineup().size()
	if count < 2 or count > 5: return false
	for index in range(count, 5):
		if str(player_lineup[index]) in UNIT_TYPES: return false
	return true

func open_strategy_screen() -> void:
	if not is_lineup_complete():
		return
	card_decks[current_deck_index] = player_lineup.duplicate()
	strategy_messages = Array(strategies[current_strategy_index]["messages"]).duplicate()
	active_strategy = get_saved_compiled_strategy(current_strategy_index)
	active_strategy_messages = strategy_messages.duplicate() if not active_strategy.is_empty() else []
	strategy_edit_index = -1
	strategy_edit_text = ""
	strategy_dirty = false
	strategy_send_history.clear()
	strategy_ready = false
	strategy_compiling = false
	strategy_voice_mode = true
	strategy_voice_recording = false
	strategy_notice = "输入策略后保存，并发送给全队"
	show_strategy_screen()

func show_strategy_screen() -> void:
	clear_screen()
	build_menu_background()
	make_title("团队战斗策略")
	make_panel(30, 165, 660, 975)
	var strategy_select := OptionButton.new()
	strategy_select.name = "StrategyTemplateSelect"
	for index in 20:
		strategy_select.add_item(String(strategies[index]["name"]), index)
	strategy_select.select(current_strategy_index)
	strategy_select.position = Vector2(55, 190)
	strategy_select.size = Vector2(210, 48)
	strategy_select.add_theme_font_override("font", FONT)
	strategy_select.add_theme_font_size_override("font_size", 18)
	strategy_select.get_popup().add_theme_font_override("font", FONT)
	strategy_select.get_popup().add_theme_font_size_override("font_size", 18)
	strategy_select.disabled = strategy_compiling
	strategy_select.item_selected.connect(select_strategy_template)
	add_child(strategy_select)
	var strategy_name_edit := LineEdit.new()
	strategy_name_edit.text = String(strategies[current_strategy_index]["name"])
	strategy_name_edit.max_length = 14
	strategy_name_edit.placeholder_text = "策略名称"
	strategy_name_edit.position = Vector2(280, 190)
	strategy_name_edit.size = Vector2(210, 48)
	strategy_name_edit.add_theme_font_override("font", FONT)
	strategy_name_edit.add_theme_font_size_override("font_size", 18)
	strategy_name_edit.editable = not strategy_compiling
	add_child(strategy_name_edit)
	var input := LineEdit.new()
	var save_strategy_button := make_ui_button("保存策略", Rect2(505, 190, 135, 48), save_current_strategy.bind(strategy_name_edit, input), 17, Color("287e8a"))
	save_strategy_button.disabled = strategy_compiling
	make_label("本次出战队员", 55, 250, 220, 34, 18, Color("59434a"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	for index in active_player_lineup().size():
		build_strategy_hero(index)
	var chat_bg := ColorRect.new()
	chat_bg.name = "StrategyChatBackground"
	chat_bg.color = Color("ededed")
	place(chat_bg, 55, 410, 610, 475)
	add_child(chat_bg)
	var scroll := ScrollContainer.new()
	scroll.name = "StrategyChatScroll"
	place(scroll, 70, 425, 580, 390 if strategy_edit_index >= 0 else 445)
	add_child(scroll)
	var messages_box := VBoxContainer.new()
	messages_box.custom_minimum_size = Vector2(550, 0)
	messages_box.add_theme_constant_override("separation", 8)
	scroll.add_child(messages_box)
	build_strategy_chat(messages_box)
	scroll_strategy_chat_to_bottom.call_deferred(scroll.get_instance_id())
	input.text = strategy_edit_text
	input.name = "StrategyCommandInput"
	input.placeholder_text = "输入团队策略指令……"
	input.max_length = 100
	input.position = Vector2(145, 900)
	input.size = Vector2(390, 54)
	input.add_theme_font_override("font", FONT)
	input.add_theme_font_size_override("font_size", 18)
	input.text_submitted.connect(func(_value: String) -> void: commit_strategy_message(input))
	input.editable = not strategy_compiling
	input.visible = not strategy_voice_mode and not OS.has_feature("web")
	add_child(input)
	var composer_bg := ColorRect.new()
	composer_bg.name = "StrategyComposerBackground"
	composer_bg.color = Color("f7f7f7")
	place(composer_bg, 55, 890, 610, 74)
	composer_bg.z_index = 1
	add_child(composer_bg)
	var mode_button := make_ui_button("", Rect2(65, 900, 70, 54), toggle_strategy_input_mode, 17, Color("596d72"))
	mode_button.name = "StrategyComposerToggle"
	mode_button.icon = ICON_KEYBOARD if strategy_voice_mode else ICON_MICROPHONE
	mode_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_button.disabled = strategy_compiling
	var action_button: Button
	if strategy_voice_mode:
		action_button = make_ui_button("按住 说话", Rect2(145, 900, 510, 54), func() -> void: pass, 19, Color("ffffff"))
		action_button.name = "StrategyVoiceButton"
		action_button.add_theme_color_override("font_color", Color("202020"))
		action_button.add_theme_color_override("font_pressed_color", Color("202020"))
		action_button.button_down.connect(start_strategy_voice_recording.bind(action_button))
		action_button.button_up.connect(stop_strategy_voice_recording.bind(action_button))
	else:
		action_button = make_ui_button("发送", Rect2(545, 900, 110, 54), commit_strategy_message.bind(input), 18, Color("07c160"))
		action_button.name = "StrategySendButton"
	action_button.disabled = strategy_compiling
	input.z_index = 2
	mode_button.z_index = 2
	action_button.z_index = 2
	input.focus_entered.connect(set_strategy_keyboard_layout.bind(true, input, mode_button, action_button, composer_bg, chat_bg, scroll))
	input.focus_exited.connect(set_strategy_keyboard_layout.bind(false, input, mode_button, action_button, composer_bg, chat_bg, scroll))
	if strategy_edit_index >= 0:
		var edit_bar := ColorRect.new()
		edit_bar.name = "StrategyEditBar"
		edit_bar.color = Color("f7f7f7")
		place(edit_bar, 70, 822, 580, 58)
		add_child(edit_bar)
		var edit_status := make_label("正在编辑第%d条" % (strategy_edit_index + 1), 85, 834, 245, 34, 15, Color("596d72"), HORIZONTAL_ALIGNMENT_LEFT, 2)
		edit_status.name = "StrategyEditStatus"
		var cancel_edit_button := make_ui_button("取消编辑", Rect2(350, 829, 135, 44), cancel_strategy_message_edit, 15, Color("596d72"))
		cancel_edit_button.name = "StrategyCancelEditButton"
		cancel_edit_button.disabled = strategy_compiling
		var delete_message_button := make_ui_button("删除这条", Rect2(500, 829, 135, 44), delete_strategy_message, 15, Color("9d4f55"))
		delete_message_button.name = "StrategyDeleteMessageButton"
		delete_message_button.disabled = strategy_compiling
	var notice_label := make_label(strategy_notice, 65, 965, 455, 38, 16, Color("9d4f55") if strategy_dirty else Color("456c66"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	notice_label.name = "StrategyNotice"
	var share_button := make_ui_button("分享码", Rect2(530, 965, 110, 38), share_current_strategy, 15, Color("287e8a"))
	share_button.disabled = strategy_compiling or active_strategy.get("schemaVersion") != "3.0" or active_strategy_messages != strategy_messages
	make_ui_button("取消并返回" if strategy_compiling else "返回编队", Rect2(55, 1030, 170, 62), cancel_strategy_compile if strategy_compiling else show_lineup_screen, 20, Color("596d72"))
	var send_button := make_ui_button("理解策略中…" if strategy_compiling else "发送策略", Rect2(240, 1030, 200, 62), send_team_strategy.bind(input), 20, Color("a76e28"))
	send_button.disabled = strategy_compiling
	var battle_button := make_ui_button("开始战斗", Rect2(455, 1030, 185, 62), start_battle_from_strategy, 20, Color("287e8a"))
	battle_button.disabled = not strategy_ready
	var share_input := LineEdit.new()
	share_input.name = "StrategyShareCodeInput"
	share_input.placeholder_text = "输入策略分享码 STG-XXXXX"
	share_input.max_length = 9
	share_input.position = Vector2(55, 1105)
	share_input.size = Vector2(430, 45)
	share_input.add_theme_font_override("font", FONT)
	share_input.add_theme_font_size_override("font_size", 16)
	add_child(share_input)
	make_ui_button("导入", Rect2(500, 1105, 140, 45), import_shared_strategy.bind(share_input), 17, Color("a76e28"))
	if not strategy_voice_mode:
		setup_web_strategy_input.call_deferred(input.get_instance_id())

func set_strategy_keyboard_layout(active: bool, input: LineEdit, mode_button: Button, action_button: Button, composer_bg: ColorRect, chat_bg: ColorRect, scroll: ScrollContainer) -> void:
	if not is_instance_valid(input) or not is_instance_valid(mode_button) or not is_instance_valid(action_button) or not is_instance_valid(composer_bg) or not is_instance_valid(chat_bg) or not is_instance_valid(scroll):
		return
	if active:
		# Mobile browsers overlay the virtual keyboard on the Web canvas instead
		# of resizing Godot's 720x1280 viewport. Keep the active editor inside
		# the upper, still-visible part of a portrait phone screen.
		chat_bg.size.y = 220.0
		scroll.size.y = 125.0
		composer_bg.position.y = 555.0
		composer_bg.z_index = 29
		input.position.y = 565.0
		mode_button.position.y = 565.0
		action_button.position.y = 565.0
		input.z_index = 30
		mode_button.z_index = 30
		action_button.z_index = 30
		scroll_strategy_chat_to_bottom.call_deferred(scroll.get_instance_id())
	else:
		chat_bg.size.y = 475.0
		scroll.size.y = 390.0 if strategy_edit_index >= 0 else 445.0
		composer_bg.position.y = 890.0
		input.position.y = 900.0
		mode_button.position.y = 900.0
		action_button.position.y = 900.0
		composer_bg.z_index = 1
		input.z_index = 2
		mode_button.z_index = 2
		action_button.z_index = 2

func set_strategy_keyboard_layout_from_nodes(active: bool) -> void:
	var input := get_node_or_null("StrategyCommandInput") as LineEdit
	var mode_button := get_node_or_null("StrategyComposerToggle") as Button
	var action_button := get_node_or_null("StrategySendButton") as Button
	var composer_bg := get_node_or_null("StrategyComposerBackground") as ColorRect
	var chat_bg := get_node_or_null("StrategyChatBackground") as ColorRect
	var scroll := get_node_or_null("StrategyChatScroll") as ScrollContainer
	if input != null and mode_button != null and action_button != null and composer_bg != null and chat_bg != null and scroll != null:
		set_strategy_keyboard_layout(active, input, mode_button, action_button, composer_bg, chat_bg, scroll)

func toggle_strategy_input_mode() -> void:
	if strategy_compiling:
		return
	strategy_voice_mode = not strategy_voice_mode
	strategy_voice_recording = false
	strategy_notice = "按住说话，松开后转成文字" if strategy_voice_mode else "可输入或长按粘贴，完成后点发送"
	show_strategy_screen()

func setup_web_strategy_input(input_instance_id: int) -> void:
	if not OS.has_feature("web"):
		return
	var input := instance_from_id(input_instance_id) as LineEdit
	if input == null or not is_instance_valid(input):
		return
	strategy_dom_input_target = input
	input.visible = false
	var mode_button := get_node_or_null("StrategyComposerToggle") as Button
	var send_button := get_node_or_null("StrategySendButton") as Button
	if mode_button != null:
		mode_button.visible = false
	if send_button != null:
		send_button.visible = false
	strategy_dom_callback = JavaScriptBridge.create_callback(_on_web_strategy_input_event)
	var window := JavaScriptBridge.get_interface("window")
	window.emeraldStrategyInputCallback = strategy_dom_callback
	var initial_value := JSON.stringify(input.text)
	var web_chat_entries: Array = []
	for message in strategy_messages:
		web_chat_entries.append({"kind": "self", "text": String(message)})
	for history_value in strategy_send_history:
		if not history_value is Dictionary:
			continue
		var history: Dictionary = history_value
		web_chat_entries.append({"kind": "divider", "text": "第%d次策略下发" % int(history.get("revision", 1))})
		var replies: Array = history.get("replies", []) if history.get("replies", []) is Array else []
		for hero_index in int(history.get("count", 0)):
			var kind := String(player_lineup[hero_index])
			web_chat_entries.append({
				"kind": "ally", "slot": hero_index + 1, "name": "%d号·%s" % [hero_index + 1, UNIT_NAMES[kind]],
				"text": String(replies[hero_index]) if hero_index < replies.size() else "%d号收到" % (hero_index + 1),
			})
		if not str(history.get("review", "")).is_empty():
			web_chat_entries.append({"kind":"divider", "text":str(history.get("review", ""))})
	var message_values := JSON.stringify(web_chat_entries)
	JavaScriptBridge.eval("""
		(() => {
			const old = document.getElementById('emerald-strategy-composer');
			if (old) old.remove();
			const oldOverlay = document.getElementById('emerald-strategy-editor');
			if (oldOverlay) oldOverlay.remove();
			const canvas = document.getElementById('canvas');
			if (!canvas) return;
			const uiFont = '-apple-system,BlinkMacSystemFont,"PingFang SC","Noto Sans CJK SC","Microsoft YaHei",sans-serif';
			const overlay = document.createElement('section');
			overlay.id = 'emerald-strategy-editor';
			overlay.style.cssText = `position:fixed;z-index:2147482900;display:none;box-sizing:border-box;flex-direction:column;margin:0;background:#ededed;color:#191919;font-family:${uiFont};overflow:hidden;`;
			const header = document.createElement('header');
			header.style.cssText = 'height:52px;min-height:52px;display:flex;align-items:center;justify-content:center;background:#f7f7f7;border-bottom:1px solid #dcdcdc;font-size:17px;font-weight:600;letter-spacing:.2px;';
			header.textContent = '团队战斗策略';
			const messages = document.createElement('div');
			messages.style.cssText = 'flex:1;box-sizing:border-box;display:flex;flex-direction:column;gap:10px;padding:16px 14px 84px;overflow:auto;-webkit-overflow-scrolling:touch;';
			const savedMessages = %s;
			if (Array.isArray(savedMessages) && savedMessages.length) {
				for (const entry of savedMessages) {
					if (!entry || !entry.kind) continue;
					if (entry.kind === 'divider') {
						const divider = document.createElement('div'); divider.textContent = String(entry.text || '');
						divider.style.cssText = 'align-self:center;color:#999;font-size:12px;padding:3px 8px;'; messages.appendChild(divider); continue;
					}
					const row = document.createElement('div');
					row.style.cssText = `display:flex;align-items:flex-start;gap:8px;justify-content:${entry.kind === 'self' ? 'flex-end' : 'flex-start'};`;
					if (entry.kind === 'ally') {
						const avatar = document.createElement('div'); avatar.textContent = String(entry.slot || '');
						avatar.style.cssText = 'width:38px;height:38px;flex:none;border-radius:6px;background:#477d86;color:#fff;display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:600;box-shadow:inset 0 0 0 1px rgba(0,0,0,.08);';
						row.appendChild(avatar);
					}
					const column = document.createElement('div'); column.style.cssText = 'max-width:78%%;display:flex;flex-direction:column;gap:3px;';
					if (entry.kind === 'ally') { const name = document.createElement('div'); name.textContent = String(entry.name || ''); name.style.cssText = 'color:#888;font-size:11px;padding-left:2px;'; column.appendChild(name); }
					const bubble = document.createElement('div'); bubble.textContent = String(entry.text || '');
					bubble.style.cssText = `box-sizing:border-box;padding:9px 12px;border-radius:6px;background:${entry.kind === 'self' ? '#95ec69' : '#fff'};color:#191919;font-size:16px;line-height:1.45;white-space:pre-wrap;word-break:break-word;box-shadow:0 1px 1px rgba(0,0,0,.05);`;
					column.appendChild(bubble); row.appendChild(column); messages.appendChild(row);
				}
			} else {
				const hint = document.createElement('div');
				hint.textContent = '输入一条战斗指令，发送后可继续补充或修改';
				hint.style.cssText = 'margin:auto;text-align:center;color:#999;font-size:14px;line-height:1.6;';
				messages.appendChild(hint);
			}
			overlay.appendChild(header); overlay.appendChild(messages);
			const bar = document.createElement('div');
			bar.id = 'emerald-strategy-composer';
			bar.style.cssText = 'position:fixed;z-index:2147483000;visibility:hidden;box-sizing:border-box;display:flex;align-items:center;gap:10px;padding:10px;margin:0;background:#f7f7f7;overflow:hidden;contain:layout paint;';
			const toggle = document.createElement('button');
			toggle.type = 'button';
			toggle.setAttribute('aria-label', '切换到语音输入');
			toggle.innerHTML = '<svg viewBox="0 0 24 24" width="25" height="25" aria-hidden="true"><rect x="7" y="3" width="10" height="14" rx="5" fill="none" stroke="currentColor" stroke-width="2"/><path d="M4.5 11.5a7.5 7.5 0 0 0 15 0M12 19v3M8.5 22h7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>';
			toggle.style.cssText = '-webkit-appearance:none;appearance:none;width:70px;height:54px;flex:none;display:flex;align-items:center;justify-content:center;padding:0;margin:0;border:0;border-radius:7px;background:#596d72;color:#fff;';
			const field = document.createElement('input');
			field.id = 'emerald-strategy-input';
			field.type = 'text';
			field.maxLength = 100;
			field.value = %s;
			field.placeholder = '输入团队策略指令……';
			field.autocomplete = 'off';
			field.spellcheck = false;
			field.enterKeyHint = 'send';
			field.style.cssText = `-webkit-appearance:none;appearance:none;height:54px;min-width:0;flex:1;box-sizing:border-box;margin:0;background:#fff;color:#222;border:1px solid #d9d9d9;border-radius:7px;padding:0 10px;outline:none;font-family:${uiFont};-webkit-user-select:text;user-select:text;touch-action:auto;`;
			const send = document.createElement('button');
			send.type = 'button'; send.textContent = '发送';
			send.style.cssText = `-webkit-appearance:none;appearance:none;width:110px;height:54px;flex:none;padding:0;margin:0;border:0;border-radius:7px;background:#07c160;color:#fff;font-family:${uiFont};font-size:18px;`;
			let focused = false;
			const place = () => {
				const rect = canvas.getBoundingClientRect();
				const scale = rect.width / 720;
				const viewport = window.visualViewport;
				if (focused && viewport) {
					overlay.style.display = 'flex';
					overlay.style.left = viewport.offsetLeft + 'px'; overlay.style.top = viewport.offsetTop + 'px';
					overlay.style.width = viewport.width + 'px'; overlay.style.height = viewport.height + 'px';
					bar.style.left = viewport.offsetLeft + 'px';
					bar.style.top = (viewport.offsetTop + viewport.height - 64) + 'px';
					bar.style.width = viewport.width + 'px'; bar.style.height = '64px';
					bar.style.padding = '8px 10px'; bar.style.gap = '8px';
					bar.style.borderTop = '1px solid #d8d8d8';
					toggle.style.width = '42px'; toggle.style.height = '48px'; toggle.style.background = 'transparent'; toggle.style.color = '#333';
					field.style.height = '48px'; field.style.fontSize = '16px'; field.style.border = '0';
					send.style.width = '64px'; send.style.height = '48px'; send.style.fontSize = '16px'; send.style.borderRadius = '5px';
					messages.scrollTop = messages.scrollHeight;
				} else {
					overlay.style.display = 'none';
					let left = rect.left + 55 * scale;
					let width = 610 * scale;
					if (viewport) {
						width = Math.min(width, viewport.width - 16);
						left = Math.max(viewport.offsetLeft + 8, Math.min(left, viewport.offsetLeft + viewport.width - width - 8));
					}
					bar.style.left = left + 'px'; bar.style.top = (rect.top + 890 * scale) + 'px';
					bar.style.width = width + 'px'; bar.style.height = (74 * scale) + 'px';
					bar.style.padding = (10 * scale) + 'px'; bar.style.gap = (10 * scale) + 'px'; bar.style.borderTop = '0';
					toggle.style.width = (70 * scale) + 'px'; toggle.style.height = (54 * scale) + 'px'; toggle.style.background = '#596d72'; toggle.style.color = '#fff';
					field.style.height = (54 * scale) + 'px'; field.style.fontSize = Math.max(16, 18 * scale) + 'px'; field.style.border = '1px solid #d9d9d9';
					send.style.width = (110 * scale) + 'px'; send.style.height = (54 * scale) + 'px'; send.style.fontSize = '18px'; send.style.borderRadius = '7px';
				}
				bar.style.visibility = 'visible';
			};
			const settle = () => { place(); requestAnimationFrame(place); setTimeout(place, 80); setTimeout(place, 280); };
			field.addEventListener('focus', () => { focused = true; settle(); window.emeraldStrategyInputCallback('focus', field.value); });
			field.addEventListener('blur', () => { focused = false; place(); window.emeraldStrategyInputCallback('blur', field.value); });
			field.addEventListener('input', () => window.emeraldStrategyInputCallback('input', field.value));
			field.addEventListener('keydown', event => {
				if (event.key === 'Enter' && !event.isComposing) {
					event.preventDefault();
					window.emeraldStrategyInputCallback('submit', field.value);
					field.blur();
				}
			});
			toggle.addEventListener('pointerdown', event => event.preventDefault());
			send.addEventListener('pointerdown', event => event.preventDefault());
			toggle.addEventListener('click', () => window.emeraldStrategyInputCallback('toggle', field.value));
			send.addEventListener('click', () => window.emeraldStrategyInputCallback('submit', field.value));
			window.addEventListener('resize', place, {passive:true});
			if (window.visualViewport) {
				window.visualViewport.addEventListener('resize', place, {passive:true});
				window.visualViewport.addEventListener('scroll', place, {passive:true});
			}
			bar.appendChild(toggle); bar.appendChild(field); bar.appendChild(send);
			document.body.appendChild(overlay);
			document.body.appendChild(bar);
			place();
		})();
	""" % [message_values, initial_value], true)

func hide_web_strategy_input() -> void:
	strategy_dom_input_focused = false
	strategy_dom_input_target = null
	if OS.has_feature("web"):
		JavaScriptBridge.eval("const bar=document.getElementById('emerald-strategy-composer');if(bar)bar.remove();const overlay=document.getElementById('emerald-strategy-editor');if(overlay)overlay.remove();", true)

func _on_web_strategy_input_event(arguments: Array) -> void:
	if strategy_dom_input_target == null or not is_instance_valid(strategy_dom_input_target):
		return
	var event_name := String(arguments[0]) if not arguments.is_empty() else ""
	var value := String(arguments[1]) if arguments.size() > 1 else ""
	strategy_dom_input_target.text = value.left(strategy_dom_input_target.max_length)
	match event_name:
		"focus":
			strategy_dom_input_focused = true
		"blur":
			strategy_dom_input_focused = false
		"submit":
			commit_strategy_message.call_deferred(strategy_dom_input_target)
		"toggle":
			strategy_edit_text = strategy_dom_input_target.text
			toggle_strategy_input_mode.call_deferred()

func restore_strategy_keyboard_layout_later(input_instance_id: int) -> void:
	await get_tree().create_timer(0.3).timeout
	if strategy_dom_input_focused:
		return
	var input := instance_from_id(input_instance_id) as LineEdit
	if input != null and is_instance_valid(input):
		set_strategy_keyboard_layout_from_nodes(false)

func start_strategy_voice_recording(button: Button) -> void:
	if strategy_compiling or strategy_voice_recording:
		return
	if not OS.has_feature("web"):
		strategy_notice = "当前平台暂不支持语音输入，请切换到文字"
		update_strategy_voice_status(button, "按住 说话")
		return
	strategy_voice_recording = true
	update_strategy_voice_status(button, "松开 结束")
	strategy_voice_callback = JavaScriptBridge.create_callback(_on_strategy_voice_event)
	var window := JavaScriptBridge.get_interface("window")
	window.emeraldVoiceCallback = strategy_voice_callback
	var endpoint := api_base_url() + "/speech/transcribe"
	JavaScriptBridge.eval("""
		(() => {
			const notify = (event, value = '') => window.emeraldVoiceCallback(event, value);
			if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) { notify('error', 'unsupported'); return; }
			window.emeraldVoiceShouldStop = false;
			window.emeraldStopVoiceRecording = () => {
				window.emeraldVoiceShouldStop = true;
				if (window.emeraldVoiceFinish) window.emeraldVoiceFinish();
			};
			(async () => {
				let stream, context, source, processor, silentGain, timer;
				try {
					notify('requesting');
					stream = await navigator.mediaDevices.getUserMedia({audio:{channelCount:1,echoCancellation:true,noiseSuppression:true,autoGainControl:true}});
					context = new (window.AudioContext || window.webkitAudioContext)();
					await context.resume();
					source = context.createMediaStreamSource(stream);
					processor = context.createScriptProcessor(4096, 1, 1);
					const chunks = [];
					let samples = 0;
					let finished = false;
					processor.onaudioprocess = event => {
						if (samples < context.sampleRate * 20) {
							const chunk = new Float32Array(event.inputBuffer.getChannelData(0));
							chunks.push(chunk); samples += chunk.length;
						}
					};
					source.connect(processor);
					// ScriptProcessor must stay connected in Chromium to receive
					// callbacks. Route it through a zero-gain node so microphone
					// audio is never played back through the speakers.
					silentGain = context.createGain(); silentGain.gain.value = 0;
					processor.connect(silentGain); silentGain.connect(context.destination);
					notify('recording');
					const finish = async () => {
						if (finished) return;
						finished = true;
						clearTimeout(timer);
						processor.disconnect(); silentGain.disconnect(); source.disconnect(); stream.getTracks().forEach(track => track.stop());
						if (samples < context.sampleRate * 0.65) { await context.close(); notify('error', 'too_short'); return; }
						const merged = new Float32Array(samples);
						let offset = 0; for (const chunk of chunks) { merged.set(chunk, offset); offset += chunk.length; }
						// Remove microphone DC offset, reject actual silence locally and
						// apply bounded gain for quiet phone/embedded-browser microphones.
						let mean = 0; for (let i=0;i<merged.length;i++) mean += merged[i]; mean /= merged.length;
						let peak = 0, energy = 0;
						for (let i=0;i<merged.length;i++) { const value=merged[i]-mean; peak=Math.max(peak,Math.abs(value)); energy+=value*value; }
						const rms = Math.sqrt(energy / merged.length);
						if (peak < 0.012 || rms < 0.0012) { await context.close(); notify('error', 'no_voice'); return; }
						const voiceGain = Math.min(6, Math.max(1, 0.82 / peak));
						const inputRate = context.sampleRate; await context.close();
						const targetRate = 16000, ratio = inputRate / targetRate, outputLength = Math.floor(merged.length / ratio);
						const pcm = new Int16Array(outputLength);
						for (let i = 0; i < outputLength; i++) {
							const start = Math.floor(i * ratio), end = Math.min(Math.floor((i + 1) * ratio), merged.length);
							let sum = 0; for (let j = start; j < end; j++) sum += merged[j];
							const sample = Math.max(-1, Math.min(1, (sum / Math.max(1, end - start) - mean) * voiceGain));
							pcm[i] = sample < 0 ? sample * 32768 : sample * 32767;
						}
						const buffer = new ArrayBuffer(44 + pcm.length * 2), view = new DataView(buffer);
						const write = (pos, text) => { for (let i = 0; i < text.length; i++) view.setUint8(pos + i, text.charCodeAt(i)); };
						write(0,'RIFF'); view.setUint32(4,36+pcm.length*2,true); write(8,'WAVE'); write(12,'fmt ');
						view.setUint32(16,16,true); view.setUint16(20,1,true); view.setUint16(22,1,true); view.setUint32(24,targetRate,true);
						view.setUint32(28,targetRate*2,true); view.setUint16(32,2,true); view.setUint16(34,16,true); write(36,'data'); view.setUint32(40,pcm.length*2,true);
						for (let i=0;i<pcm.length;i++) view.setInt16(44+i*2,pcm[i],true);
						const bytes = new Uint8Array(buffer); let binary = '';
						for (let i=0;i<bytes.length;i+=0x8000) binary += String.fromCharCode(...bytes.subarray(i,i+0x8000));
						notify('transcribing');
						const response = await fetch(%s,{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+%s},body:JSON.stringify({format:'wav',audio_base64:btoa(binary)})});
						const data = await response.json().catch(() => ({}));
						if (!response.ok || !data.ok) throw new Error(data.error || 'request_failed');
						notify('result', data.text || '');
					};
					window.emeraldVoiceFinish = finish;
					timer = setTimeout(finish, 20000);
					if (window.emeraldVoiceShouldStop) finish();
				} catch (error) {
					if (stream) stream.getTracks().forEach(track => track.stop());
					if (context && context.state !== 'closed') context.close();
					notify('error', error && error.message ? error.message : 'request_failed');
				}
			})();
		})();
	""" % [JSON.stringify(endpoint), JSON.stringify(account_token)], true)

func stop_strategy_voice_recording(button: Button) -> void:
	if not strategy_voice_recording:
		return
	strategy_voice_recording = false
	update_strategy_voice_status(button, "正在识别…")
	stop_web_voice_capture()

func stop_web_voice_capture() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.emeraldStopVoiceRecording)window.emeraldStopVoiceRecording();", true)

func update_strategy_voice_status(button: Button, text: String) -> void:
	if button != null and is_instance_valid(button):
		button.text = text
	var label := get_node_or_null("StrategyNotice") as Label
	if label != null:
		label.text = strategy_notice

func _on_strategy_voice_event(arguments: Array) -> void:
	var event_name := String(arguments[0]) if not arguments.is_empty() else ""
	var value := String(arguments[1]) if arguments.size() > 1 else ""
	var button := get_node_or_null("StrategyVoiceButton") as Button
	match event_name:
		"requesting":
			strategy_notice = "请允许浏览器使用麦克风"
		"recording":
			strategy_notice = "正在录音，松开后识别（最长20秒）"
			if not strategy_voice_recording:
				stop_web_voice_capture()
		"transcribing":
			strategy_notice = "腾讯云正在把语音转成文字…"
		"result":
			strategy_voice_recording = false
			strategy_edit_text = value.strip_edges().left(100)
			strategy_voice_mode = false
			strategy_notice = "语音已转成文字，请确认后发送"
			show_strategy_screen.call_deferred()
			return
		"error":
			strategy_voice_recording = false
			if value == "speech_not_configured":
				strategy_notice = "腾讯云语音识别尚未配置，请先用文字输入"
			elif value == "too_short":
				strategy_notice = "录音太短，请按住后再说"
			elif value == "no_voice":
				strategy_notice = "没有录到声音，请检查麦克风后重试"
			elif value == "speech_not_recognized":
				strategy_notice = "没有识别出文字，请靠近麦克风清楚地再说一次"
			elif value == "NotAllowedError" or "Permission" in value:
				strategy_notice = "没有麦克风权限，请在浏览器设置中允许"
			else:
				strategy_notice = "语音识别失败，请重试或切换文字"
	update_strategy_voice_status(button, "按住 说话")

func build_strategy_hero(index: int) -> void:
	var x := 55.0 + index * 122.0
	var kind := String(player_lineup[index])
	var portrait := TextureRect.new()
	portrait.texture = get_unit_portrait(kind)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	place(portrait, x, 282, 100, 88)
	add_child(portrait)
	make_label("%d号·%s" % [index + 1, UNIT_NAMES[kind]], x - 5, 365, 110, 30, 14, Color("49373d"), HORIZONTAL_ALIGNMENT_CENTER, 0)

func build_strategy_chat(container: VBoxContainer) -> void:
	if strategy_messages.is_empty():
		var empty := create_label("暂无消息\n像微信聊天一样，在下方输入策略", 0, 0, 540, 82, 15, Color("999999"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		empty.custom_minimum_size = Vector2(540, 82)
		container.add_child(empty)
	for index in strategy_messages.size():
		var message_text := String(strategy_messages[index])
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(540, 58)
		row.add_theme_constant_override("separation", 8)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var message_button := Button.new()
		message_button.text = "%s%s" % [message_text, "  [已修改]" if strategy_dirty and index == strategy_edit_index else ""]
		message_button.custom_minimum_size = Vector2(clampf(70.0 + message_text.length() * 16.0, 150.0, 405.0), 50)
		message_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		message_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_button.add_theme_font_override("font", FONT)
		message_button.add_theme_font_size_override("font_size", 16)
		message_button.add_theme_color_override("font_color", Color("1f1f1f"))
		message_button.add_theme_color_override("font_disabled_color", Color("1f1f1f"))
		message_button.disabled = strategy_compiling
		var message_style := StyleBoxFlat.new()
		message_style.bg_color = Color("95ec69")
		message_style.corner_radius_top_left = 6
		message_style.corner_radius_top_right = 6
		message_style.corner_radius_bottom_left = 6
		message_style.corner_radius_bottom_right = 6
		message_style.content_margin_left = 12
		message_style.content_margin_right = 12
		message_style.content_margin_top = 8
		message_style.content_margin_bottom = 8
		message_button.add_theme_stylebox_override("normal", message_style)
		message_button.add_theme_stylebox_override("hover", message_style)
		message_button.add_theme_stylebox_override("pressed", message_style)
		message_button.add_theme_stylebox_override("disabled", message_style)
		message_button.pressed.connect(edit_strategy_message.bind(index))
		row.add_child(message_button)
		var player_portrait := TextureRect.new()
		player_portrait.texture = player_avatar
		player_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		player_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		player_portrait.custom_minimum_size = Vector2(46, 46)
		row.add_child(player_portrait)
		container.add_child(row)
	for history_index in strategy_send_history.size():
		var history: Dictionary = strategy_send_history[history_index]
		var divider := create_label("第%d次策略下发" % int(history["revision"]), 0, 0, 540, 34, 13, Color("999999"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		divider.custom_minimum_size = Vector2(540, 34)
		container.add_child(divider)
		for hero_index in int(history["count"]):
			var kind := String(player_lineup[hero_index])
			var reply_row := HBoxContainer.new()
			reply_row.custom_minimum_size = Vector2(540, 72)
			reply_row.add_theme_constant_override("separation", 8)
			var avatar := TextureRect.new()
			avatar.texture = get_unit_portrait(kind)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar.custom_minimum_size = Vector2(46, 46)
			reply_row.add_child(avatar)
			var reply_column := VBoxContainer.new()
			reply_column.add_theme_constant_override("separation", 2)
			var hero_name := create_label("%d号·%s" % [hero_index + 1, UNIT_NAMES[kind]], 0, 0, 405, 20, 12, Color("888888"), HORIZONTAL_ALIGNMENT_LEFT, 0)
			hero_name.custom_minimum_size = Vector2(405, 20)
			reply_column.add_child(hero_name)
			var replies: Array = history.get("replies", [])
			var reply_text := String(replies[hero_index]) if hero_index < replies.size() else "%d号收到" % (hero_index + 1)
			var reply_width := clampf(70.0 + reply_text.length() * 15.0, 150.0, 405.0)
			var reply_panel := PanelContainer.new()
			var reply_style := StyleBoxFlat.new()
			reply_style.bg_color = Color.WHITE
			reply_style.corner_radius_top_left = 6
			reply_style.corner_radius_top_right = 6
			reply_style.corner_radius_bottom_left = 6
			reply_style.corner_radius_bottom_right = 6
			reply_style.content_margin_left = 12
			reply_style.content_margin_right = 12
			reply_style.content_margin_top = 8
			reply_style.content_margin_bottom = 8
			reply_panel.add_theme_stylebox_override("panel", reply_style)
			reply_panel.custom_minimum_size = Vector2(reply_width, 46)
			var reply := create_label(reply_text, 0, 0, 0, 0, 16, Color("1f1f1f"), HORIZONTAL_ALIGNMENT_LEFT, 0)
			reply.custom_minimum_size = Vector2(reply_width - 24.0, 30)
			reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reply_panel.add_child(reply)
			reply_column.add_child(reply_panel)
			reply_row.add_child(reply_column)
			var reply_spacer := Control.new()
			reply_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reply_row.add_child(reply_spacer)
			container.add_child(reply_row)
		var review_text := str(history.get("review", ""))
		if not review_text.is_empty():
			var review := create_label(review_text, 10, 0, 520, 0, 14, Color("9d4f55"), HORIZONTAL_ALIGNMENT_LEFT, 0)
			review.custom_minimum_size = Vector2(520, 48)
			review.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(review)

func scroll_strategy_chat_to_bottom(scroll_instance_id: int) -> void:
	await get_tree().process_frame
	var scroll := instance_from_id(scroll_instance_id) as ScrollContainer
	if scroll != null and is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func select_strategy_template(index: int) -> void:
	strategy_send_token += 1
	current_strategy_index = clampi(index, 0, 19)
	strategy_messages = Array(strategies[current_strategy_index]["messages"]).duplicate()
	active_strategy = get_saved_compiled_strategy(current_strategy_index)
	active_strategy_messages = strategy_messages.duplicate() if not active_strategy.is_empty() else []
	strategy_edit_index = -1
	strategy_edit_text = ""
	strategy_dirty = false
	strategy_send_history.clear()
	strategy_ready = false
	strategy_notice = "已切换策略模板"
	save_battle_setup()
	show_strategy_screen()

func commit_strategy_message(input: LineEdit) -> void:
	var message := input.text.strip_edges()
	if message == "":
		strategy_notice = "策略内容不能为空"
		show_strategy_screen()
		return
	strategy_send_token += 1
	if strategy_edit_index >= 0 and strategy_edit_index < strategy_messages.size():
		strategy_messages[strategy_edit_index] = message
	else:
		strategy_messages.append(message)
	strategy_edit_index = -1
	strategy_edit_text = ""
	strategy_dirty = true
	strategy_ready = false
	strategy_notice = "策略已修改，请保存并重新发送"
	show_strategy_screen()

func edit_strategy_message(index: int) -> void:
	strategy_send_token += 1
	strategy_edit_index = index
	strategy_edit_text = String(strategy_messages[index])
	strategy_voice_mode = false
	strategy_notice = "正在编辑第%d条指令" % (index + 1)
	show_strategy_screen()

func cancel_strategy_message_edit() -> void:
	strategy_edit_index = -1
	strategy_edit_text = ""
	strategy_notice = "已取消编辑"
	show_strategy_screen()

func delete_strategy_message() -> void:
	strategy_send_token += 1
	if strategy_edit_index >= 0 and strategy_edit_index < strategy_messages.size():
		strategy_messages.remove_at(strategy_edit_index)
	strategy_edit_index = -1
	strategy_edit_text = ""
	strategy_dirty = true
	strategy_ready = false
	strategy_notice = "指令已删除，请保存并重新发送"
	show_strategy_screen()

func apply_pending_strategy_input(input: LineEdit) -> bool:
	if input == null or not is_instance_valid(input):
		return false
	var message := input.text.strip_edges()
	if message == "":
		return false
	if strategy_edit_index >= 0 and strategy_edit_index < strategy_messages.size():
		strategy_messages[strategy_edit_index] = message
	else:
		strategy_messages.append(message)
	strategy_edit_index = -1
	strategy_edit_text = ""
	strategy_dirty = true
	strategy_ready = false
	input.text = ""
	return true

func save_current_strategy(name_edit: LineEdit, input: LineEdit = null) -> void:
	apply_pending_strategy_input(input)
	var cleaned_name := name_edit.text.strip_edges()
	var compiled_matches := active_strategy_messages == strategy_messages and not active_strategy.is_empty()
	strategies[current_strategy_index] = {
		"name": cleaned_name if cleaned_name != "" else "策略 %02d" % (current_strategy_index + 1),
		"messages": strategy_messages.duplicate(),
		"compiled": active_strategy.duplicate(true) if compiled_matches else {},
		"compiled_lineup": player_lineup.duplicate() if compiled_matches else []
	}
	strategy_dirty = false
	strategy_notice = "策略已保存到第%02d号模板" % (current_strategy_index + 1)
	save_battle_setup()
	show_strategy_screen()

func send_team_strategy(input: LineEdit = null) -> void:
	apply_pending_strategy_input(input)
	if strategy_messages.is_empty() or strategy_compiling:
		strategy_notice = "请至少添加一条策略指令"
		show_strategy_screen()
		return
	strategy_send_token += 1
	var token := strategy_send_token
	strategy_ready = false
	strategy_compiling = true
	strategy_edit_index = -1
	strategy_edit_text = ""
	var revision := strategy_send_history.size() + 1
	strategy_send_history.append({"revision": revision, "count": 0, "replies": []})
	strategy_notice = "队员正在理解策略，请稍候……"
	show_strategy_screen()
	var previous_strategy := active_strategy.duplicate(true)
	var previous_messages := active_strategy_messages.duplicate()
	var previous_replay := active_replay.duplicate(true)
	var response := await request_compiled_strategy()
	if token != strategy_send_token:
		strategy_compiling = false
		return
	var replies: Array = []
	var battle_lineup := active_player_lineup()
	if bool(response.get("ok", false)):
		var candidate_strategy := Dictionary(response["strategy"]).duplicate(true)
		active_strategy = candidate_strategy
		active_strategy_messages = strategy_messages.duplicate()
		active_compile_binding = Dictionary(response.get("binding", {})).duplicate(true)
		active_battle_request_id = "mobile_" + str(Time.get_unix_time_from_system()) + "_" + str(rng.randi())
		active_replay = {}
		var rejected_texts: Array[String] = []
		for intent_result in active_strategy.get("intentResults", []):
			if str(intent_result.get("status", "")) != "accepted":
				rejected_texts.append(str(intent_result.get("displayReason", intent_result.get("reasonCode", "无法执行"))))
		strategy_send_history[strategy_send_history.size() - 1]["review"] = ("未执行的策略：" + "；".join(rejected_texts)) if not rejected_texts.is_empty() else ""
		for hero_index in battle_lineup.size():
			if bool(response.get("ok", false)):
				var summaries: Dictionary = active_strategy.get("unit_summaries", {})
				var summary := String(summaries.get(str(hero_index + 1), ""))
				replies.append("%d号·%s：%s" % [hero_index+1,UNIT_NAMES.get(battle_lineup[hero_index],battle_lineup[hero_index]),summary])
			else:
				replies.append(STRATEGY_RULES.failure_reply(String(battle_lineup[hero_index]), hero_index + 1))
		if bool(response.get("ok", false)) and not strategy_dirty:
			strategies[current_strategy_index]["compiled"] = active_strategy.duplicate(true)
			strategies[current_strategy_index]["compiled_lineup"] = player_lineup.duplicate()
			save_battle_setup()
		strategy_notice = ("部分策略无法执行，请核对红色说明后再确认" if str(active_strategy.get("status", "accepted")) == "partial" else "请核对系统实际执行描述，确认后开始模拟")
	else:
		active_strategy = previous_strategy
		active_strategy_messages = previous_messages
		active_replay = previous_replay
		for hero_index in battle_lineup.size():
			replies.append(STRATEGY_RULES.failure_reply(String(battle_lineup[hero_index]), hero_index + 1))
		strategy_notice = "策略解析失败，将沿用上次有效策略" if not active_strategy.is_empty() else "策略解析失败，本局将使用默认战术"
	strategy_send_history[strategy_send_history.size() - 1]["replies"] = replies
	for hero_index in battle_lineup.size():
		await get_tree().create_timer(0.28).timeout
		if token != strategy_send_token:
			strategy_compiling = false
			return
		strategy_send_history[strategy_send_history.size() - 1]["count"] = hero_index + 1
		show_strategy_screen()
	strategy_ready = bool(response.get("ok", false))
	strategy_compiling = false
	if bool(response.get("ok", false)):
		strategy_notice = "编译预览已确认，点击开始后由服务器模拟"
	show_strategy_screen()

func request_compiled_strategy() -> Dictionary:
	var battle_lineup := active_player_lineup()
	var lineup_key := JSON.stringify(battle_lineup).sha256_text().substr(0, 20)
	var snapshot_id := "mobile_" + account_player_id.replace("-", "").substr(0, 12) + "_" + lineup_key
	var snapshot_response := await api_request("/strategy/v3/snapshots", HTTPClient.METHOD_POST,
		{"snapshotId":snapshot_id,"lineup":battle_lineup})
	if not bool(snapshot_response.get("ok", false)): return {"ok":false,"error":snapshot_response.get("error","snapshot_failed")}
	var messages: Array = []
	for index in strategy_messages.size(): messages.append({"id":"m%d" % (index+1),"text":str(strategy_messages[index])})
	var strategy_name := str(strategies[current_strategy_index].get("name", "玩家策略"))
	var parsed := await api_request("/strategy/v3/compile", HTTPClient.METHOD_POST,
		{"snapshotId":snapshot_id,"strategyName":strategy_name,"messages":messages})
	if not bool(parsed.get("ok", false)): return {"ok":false,"error":parsed.get("error","compile_failed")}
	var binding := {"compileId":str(parsed.get("compileId","")),"snapshotHash":str(parsed.get("snapshotHash","")),"planHash":str(parsed.get("planHash",""))}
	var document := {"schemaVersion":"3.0","strategyName":strategy_name,"status":str(parsed.get("status","accepted")),"renderedText":str(parsed.get("renderedText","")),
		"unit_summaries":Dictionary(parsed.get("unitSummaries", {})).duplicate(true),"intentResults":Array(parsed.get("intentResults", [])).duplicate(true),
		"compileBinding":binding.duplicate(true)}
	return {"ok":true,"strategy":document,"binding":binding}

func request_battle_replay(strategy: Dictionary) -> Dictionary:
	if active_compile_binding.is_empty() and strategy.get("compileBinding") is Dictionary:
		active_compile_binding = Dictionary(strategy["compileBinding"]).duplicate(true)
	if active_compile_binding.is_empty(): return {"ok":false,"error":"compile_binding_missing"}
	var payload := {"compileId":active_compile_binding.get("compileId"),"confirmed":true,
		"battleRequestId":active_battle_request_id,"mode":"practice","snapshotHash":active_compile_binding.get("snapshotHash"),
		"planHash":active_compile_binding.get("planHash")}
	var last_error := "simulation_failed"
	# A phone changing radio/Wi-Fi or the browser closing the previous compile
	# connection can fail before the POST reaches the server. Retry once with the
	# same deterministic seed; the server-side replay cache keeps it idempotent.
	for attempt in 2:
		var request := HTTPRequest.new()
		strategy_http_request = request
		request.timeout = 20.0
		(audio_root if audio_root != null else self).add_child(request)
		var error := request.request(api_base_url() + "/strategy/v3/confirm-and-simulate", api_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))
		if error != OK:
			last_error = "simulation_start_%d" % int(error)
			request.queue_free()
			strategy_http_request = null
			await get_tree().process_frame
			continue
		var completed: Array = await request.request_completed
		request.queue_free()
		strategy_http_request = null
		if completed.size() >= 4 and int(completed[0]) == HTTPRequest.RESULT_SUCCESS and int(completed[1]) == 200:
			var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
			if parsed is Dictionary and bool(parsed.get("ok", false)) and parsed.get("result", {}).get("replay") is Dictionary:
				return {"ok": true, "replay": parsed["result"]["replay"],"battleId":parsed.get("battleId")}
		if completed.size() >= 2:
			last_error = "simulation_result_%d_http_%d" % [int(completed[0]), int(completed[1])]
		if completed.size() >= 4:
			var error_payload: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
			if error_payload is Dictionary and error_payload.has("error"):
				last_error += "_" + JSON.stringify(error_payload["error"])
		await get_tree().create_timer(0.15).timeout
	return {"ok": false, "error": last_error}

func share_current_strategy() -> void:
	if active_strategy.get("schemaVersion") != "3.0": return
	var binding: Dictionary = active_strategy.get("compileBinding", {})
	if binding.is_empty(): return
	strategy_notice = "正在生成分享码……"
	show_strategy_screen()
	var response := await api_request("/strategy/v3/packages", HTTPClient.METHOD_POST,
		{"compileId":binding.get("compileId"),"strategyName":str(strategies[current_strategy_index].get("name","玩家策略")),
		"isPublic":true,"allowCopy":true})
	if bool(response.get("ok", false)):
		var code := str(response.get("strategy", {}).get("share", {}).get("shareCode", ""))
		strategy_notice = "分享码：" + code + "（已复制）"
		strategies[current_strategy_index]["share_code"] = code
		if OS.has_feature("web"): JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(%s)" % JSON.stringify(code))
		else: DisplayServer.clipboard_set(code)
	else: strategy_notice = "分享码生成失败，请确认编译尚未过期"
	show_strategy_screen()

func import_shared_strategy(input: LineEdit) -> void:
	var code := input.text.strip_edges().to_upper()
	if code.is_empty(): return
	strategy_notice = "正在校验分享策略……"
	show_strategy_screen()
	var preview := await api_request("/strategy/v3/share/" + code.uri_encode(), HTTPClient.METHOD_GET)
	if not bool(preview.get("ok", false)) or not bool(preview.get("canImport", false)):
		strategy_notice = "分享码无效、版本不兼容或缺少英雄"
		show_strategy_screen()
		return
	var imported := await api_request("/strategy/v3/share/" + code.uri_encode() + "/import", HTTPClient.METHOD_POST,
		{"ownedHeroes":Array(UNIT_TYPES)})
	if bool(imported.get("ok", false)):
		var summary: Dictionary = imported.get("strategy", {})
		var imported_text := str(summary.get("strategyText", {}).get("original", "")).strip_edges()
		strategy_messages = Array(imported_text.split("\n", false)) if not imported_text.is_empty() else []
		active_strategy = {}
		active_strategy_messages = []
		active_compile_binding = {}
		active_replay = {}
		strategy_ready = false
		strategy_dirty = true
		strategies[current_strategy_index] = {"name":str(summary.get("strategyName", "导入策略")),
			"messages":strategy_messages.duplicate(),"compiled":{},"compiled_lineup":[]}
		strategy_notice = "导入成功：%s。使用前请按当前阵容重新发送编译" % str(summary.get("strategyName", "策略"))
		save_battle_setup()
	else: strategy_notice = "导入失败，请稍后重试"
	show_strategy_screen()

func cancel_strategy_compile() -> void:
	strategy_send_token += 1
	strategy_compiling = false
	if strategy_http_request != null and is_instance_valid(strategy_http_request):
		strategy_http_request.cancel_request()
		strategy_http_request.queue_free()
	strategy_http_request = null
	show_lineup_screen()

func strategy_api_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin")
		if origin != null and String(origin).begins_with("http"):
			return String(origin) + "/game_1/api/strategy"
	return "http://127.0.0.1:19031/compile"

func simulation_api_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin")
		if origin != null and String(origin).begins_with("http"):
			return String(origin) + "/game_1/api/simulate"
	return "http://127.0.0.1:19031/simulate"

func get_saved_compiled_strategy(index: int) -> Dictionary:
	if index < 0 or index >= strategies.size():
		return {}
	var entry: Dictionary = strategies[index]
	var compiled: Variant = entry.get("compiled", {})
	var compiled_lineup: Variant = entry.get("compiled_lineup", [])
	if compiled_lineup is Array and Array(compiled_lineup) == player_lineup:
		if STRATEGY_RULES.validate_document(compiled, player_lineup): return Dictionary(compiled).duplicate(true)
		if compiled is Dictionary and compiled.get("schemaVersion") == "3.0" and compiled.get("compileBinding") is Dictionary:
			return Dictionary(compiled).duplicate(true)
	return {}

func start_battle_from_strategy() -> void:
	if not strategy_ready:
		return
	strategy_send_token += 1
	strategy_ready = false
	strategy_notice = "服务器正在确定性模拟战斗……"
	show_strategy_screen()
	var replay_response := await request_battle_replay(active_strategy)
	if not bool(replay_response.get("ok", false)):
		strategy_ready = true
		strategy_notice = "模拟失败，可安全重试；不会重复生成战斗"
		show_strategy_screen()
		return
	active_replay = Dictionary(replay_response["replay"]).duplicate(true)
	start_game()

func make_ui_button(text: String, rect: Rect2, callback: Callable, font_size := 20, background := Color("287e8a")) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("fff7df"))
	button.add_theme_color_override("font_disabled_color", Color("b9b6aa"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", normal)
	var disabled := normal.duplicate()
	disabled.bg_color = Color("777b78")
	button.add_theme_stylebox_override("disabled", disabled)
	button.pressed.connect(func() -> void:
		play_sfx(SFX_UI_CLICK, -4.0, 0.02)
		callback.call()
	)
	add_child(button)
	return button

func start_game() -> void:
	clear_screen()
	replay_mode = not active_replay.is_empty() and not replay_capture_mode
	strategy_runtime = STRATEGY_RUNTIME_V3_ADAPTER.new() if active_strategy.get("schemaVersion") == "3.0" else STRATEGY_RUNTIME_SCRIPT.new()
	strategy_runtime.setup(self, active_strategy)
	for team_name in ["blue", "red"]:
		resource_counts[team_name] = {"gold": 0, "stone": 0, "wood": 0, "meat": 0}
	initialize_battle_areas()
	var map := Node2D.new()
	map.name = "BattleMap"
	map.set_script(MAP_SCRIPT)
	add_child(map)
	projectile_engine = PROJECTILE_ENGINE_SCRIPT.new()
	projectile_engine.name = "ProjectileEngine"
	add_child(projectile_engine)
	projectile_engine.setup(self)
	await get_tree().process_frame
	if replay_mode:
		spawn_replay_initial_state()
	else:
		spawn_mirrored_resources()
		spawn_units()
	build_hud()
	if preview_mode:
		capture_battle_preview.call_deferred()
	countdown()

func set_battle_seed(value: int) -> void:
	# Named streams isolate gameplay subsystems: adding an audio random draw can
	# never change resource placement, target selection, or another subsystem.
	rng.seed = value
	spawn_rng.seed = value ^ 0x535041574E
	audio_rng.seed = value ^ 0x415544494F

func spawn_mirrored_resources() -> void:
	var occupied: Array[Vector2] = []
	var setup := {"gold": 4, "stone": 8, "wood": 8, "meat": 5}
	for kind: String in setup:
		for index in int(setup[kind]):
			var top_position := find_spawn_position(occupied, kind)
			occupied.append(top_position)
			create_resource("red", kind, top_position, index)
			create_resource("blue", kind, Vector2(top_position.x, VIEW_SIZE.y - top_position.y), index)

func find_spawn_position(occupied: Array[Vector2], kind: String) -> Vector2:
	var result := Vector2(360, 360)
	for attempt in 400:
		var candidate := Vector2(spawn_rng.randf_range(48.0, 672.0), spawn_rng.randf_range(205.0, 535.0))
		if kind in ["gold", "wood"]:
			candidate.y = clampf(candidate.y, 225.0, 520.0)
		var valid := true
		for previous in occupied:
			if candidate.distance_to(previous) < 58.0:
				valid = false
				break
		if valid:
			result = candidate
			break
	return result

func create_resource(team_name: String, kind: String, spawn_position: Vector2, variant: int, forced_replay_id := "") -> Node2D:
	var node := Node2D.new()
	node.set_script(RESOURCE_SCRIPT)
	add_child(node)
	replay_resource_serial += 1
	node.replay_id = forced_replay_id if forced_replay_id != "" else "r_%s_%d" % [team_name, replay_resource_serial]
	node.setup(self, team_name, kind, spawn_position, variant)
	resources.append(node)
	replay_resources[node.replay_id] = node
	return node

func spawn_units() -> void:
	var enemy_kinds := DEFAULT_LINEUP
	var battle_lineup := active_player_lineup()
	var team_size := clampi(battle_lineup.size(), 2, 5)
	var positions: Array[float] = []
	if team_size == 5:
		positions.assign([72.0, 216.0, 360.0, 504.0, 648.0])
	else:
		for index in team_size: positions.append(VIEW_SIZE.x * float(index + 1) / float(team_size + 1))
	for index in team_size:
		create_unit("red", String(enemy_kinds[index]), Vector2(positions[index], 128), index + 1)
		var player_kind := String(battle_lineup[index]) if index < battle_lineup.size() else String(DEFAULT_LINEUP[index])
		create_unit("blue", player_kind, Vector2(positions[index], VIEW_SIZE.y - 128.0), index + 1)

func create_unit(team_name: String, kind: String, spawn_position: Vector2, strategy_slot := 0, forced_replay_id := "") -> Node2D:
	var node := Node2D.new()
	node.set_script(UNIT_SCRIPT)
	add_child(node)
	replay_unit_serial += 1
	node.replay_id = forced_replay_id if forced_replay_id != "" else "u_%s_%d_%d" % [team_name, strategy_slot, replay_unit_serial]
	node.setup(self, team_name, kind, spawn_position)
	node.strategy_slot = strategy_slot
	node.configure_skills(skill_configs_for(team_name, strategy_slot))
	units.append(node)
	replay_units[node.replay_id] = node
	return node

func skill_configs_for(team_name: String, slot: int) -> Array:
	if team_name != "blue": return []
	for hero in battle_snapshot.get("teams", {}).get("blue", {}).get("heroes", []):
		if int(hero.get("slotNo", 0)) == slot: return Array(hero.get("skills", [])).duplicate(true)
	return []

func spawn_replay_initial_state() -> void:
	var initial: Dictionary = active_replay.get("initial", {})
	for value in initial.get("resources", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var p: Array = item.get("position", [0, 0])
		create_resource(String(item.get("team", "blue")), String(item.get("resource_type", "stone")), Vector2(float(p[0]), float(p[1])), int(item.get("variant", 0)), String(item.get("id", "")))
	for value in initial.get("units", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var p: Array = item.get("position", [0, 0])
		create_unit(String(item.get("team", "blue")), String(item.get("unit_type", "warrior")), Vector2(float(p[0]), float(p[1])), int(item.get("slot", 0)), String(item.get("id", "")))

func update_replay(delta: float) -> void:
	if not battle_started or battle_finished:
		return
	var frames: Array = active_replay.get("frames", [])
	if frames.is_empty():
		finish_replay()
		return
	replay_elapsed += delta
	while replay_frame_index + 1 < frames.size() and float(frames[replay_frame_index + 1].get("time", 0.0)) <= replay_elapsed:
		replay_frame_index += 1
	apply_replay_frame(Dictionary(frames[replay_frame_index]))
	if replay_frame_index + 1 < frames.size():
		var current_time := float(frames[replay_frame_index].get("time", 0.0))
		var next_time := float(frames[replay_frame_index + 1].get("time", current_time))
		var ratio := clampf((replay_elapsed - current_time) / maxf(0.001, next_time - current_time), 0.0, 1.0)
		interpolate_replay_positions(Dictionary(frames[replay_frame_index]), Dictionary(frames[replay_frame_index + 1]), ratio)
	if replay_frame_index >= frames.size() - 1 and replay_elapsed >= float(active_replay.get("duration", 0.0)):
		finish_replay()

func apply_replay_frame(frame: Dictionary) -> void:
	for value in frame.get("units", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var replay_id := String(item.get("id", ""))
		var p: Array = item.get("position", [0, 0])
		var unit_value: Variant = replay_units.get(replay_id)
		var unit: Node2D = unit_value if is_instance_valid(unit_value) else null
		if unit == null:
			unit = create_unit(String(item.get("team", "blue")), String(item.get("unit_type", "warrior")), Vector2(float(p[0]), float(p[1])), int(item.get("slot", 0)), replay_id)
			spawn_heal_effect(unit)
			show_float_text(unit.global_position - Vector2(0, 55), "消耗1肉 · 重生", Color("ffe36e"))
		unit.position = Vector2(float(p[0]), float(p[1]))
		var next_hp := int(item.get("hp", unit.hp))
		if next_hp < unit.hp:
			unit.damage_flash_time = unit.DAMAGE_FLASH_DURATION
			play_damage_sfx()
		elif next_hp > unit.hp:
			spawn_heal_effect(unit)
			play_heal_sfx()
		unit.hp = next_hp
		unit.update_health_bar()
		var next_state := String(item.get("state", "idle"))
		var target_id := String(item.get("target", ""))
		var target_value: Variant = replay_units.get(target_id)
		var replay_target: Node2D = target_value if is_instance_valid(target_value) else null
		if replay_target != null and is_instance_valid(replay_target):
			unit.face_position(replay_target.position)
		if bool(item.get("dead", false)):
			unit.dead = true
			unit.hp_back.visible = false
			unit.hp_fill.visible = false
			next_state = "dead"
		if unit.state != next_state:
			unit.play_state(next_state, true)
			if next_state == "attack":
				play_attack_sfx(unit.unit_type)
	apply_replay_projectiles(frame)
	for value in frame.get("resources", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var replay_id := String(item.get("id", ""))
		var resource_value: Variant = replay_resources.get(replay_id)
		var resource: Node2D = resource_value if is_instance_valid(resource_value) else null
		if resource == null:
			continue
		var p: Array = item.get("position", [resource.position.x, resource.position.y])
		resource.position = Vector2(float(p[0]), float(p[1]))
		var next_charges := int(item.get("charges", resource.charges))
		while is_instance_valid(resource) and not resource.depleted and resource.charges > next_charges:
			resource.hit_resource()
	var counts: Dictionary = frame.get("resources_held", {})
	if counts.has("blue"):
		resource_counts["blue"] = Dictionary(counts["blue"]).duplicate()
		for kind in hud_values:
			hud_values[kind].text = str(resource_counts["blue"].get(kind, 0))

func interpolate_replay_positions(current: Dictionary, following: Dictionary, ratio: float) -> void:
	var next_units: Dictionary = {}
	for value in following.get("units", []):
		if value is Dictionary:
			next_units[String(value.get("id", ""))] = value
	for value in current.get("units", []):
		if not value is Dictionary:
			continue
		var replay_id := String(value.get("id", ""))
		if not next_units.has(replay_id):
			continue
		var unit_value: Variant = replay_units.get(replay_id)
		var unit: Node2D = unit_value if is_instance_valid(unit_value) else null
		if unit == null:
			continue
		var a: Array = value.get("position", [unit.position.x, unit.position.y])
		var b: Array = next_units[replay_id].get("position", a)
		unit.position = Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b[0]), float(b[1])), ratio)
	var next_resources: Dictionary = {}
	for value in following.get("resources", []):
		if value is Dictionary:
			next_resources[String(value.get("id", ""))] = value
	for value in current.get("resources", []):
		if not value is Dictionary:
			continue
		var replay_id := String(value.get("id", ""))
		if not next_resources.has(replay_id):
			continue
		var resource_value: Variant = replay_resources.get(replay_id)
		var resource: Node2D = resource_value if is_instance_valid(resource_value) else null
		if resource == null:
			continue
		var a: Array = value.get("position", [resource.position.x, resource.position.y])
		var b: Array = next_resources[replay_id].get("position", a)
		resource.position = Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b[0]), float(b[1])), ratio)
	var next_projectiles: Dictionary = {}
	for value in following.get("projectiles", []):
		if value is Dictionary: next_projectiles[String(value.get("id", ""))] = value
	for value in current.get("projectiles", []):
		if not value is Dictionary: continue
		var projectile_id := String(value.get("id", ""))
		if not next_projectiles.has(projectile_id): continue
		var sprite_value: Variant = replay_projectiles.get(projectile_id)
		var sprite: Sprite2D = sprite_value if is_instance_valid(sprite_value) else null
		if sprite == null: continue
		var a: Array = value.get("position", [sprite.position.x, sprite.position.y])
		var b: Array = next_projectiles[projectile_id].get("position", a)
		sprite.position = Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b[0]), float(b[1])), ratio)

func apply_replay_projectiles(frame: Dictionary) -> void:
	var visible_ids: Dictionary = {}
	for value in frame.get("projectiles", []):
		if not value is Dictionary: continue
		var item: Dictionary = value
		var projectile_id := String(item.get("id", ""))
		visible_ids[projectile_id] = true
		var sprite_value: Variant = replay_projectiles.get(projectile_id)
		var sprite: Sprite2D = sprite_value if is_instance_valid(sprite_value) else null
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.texture = ARROW
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 64, 64)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(0.55, 0.55)
			sprite.z_index = 100
			add_child(sprite)
			replay_projectiles[projectile_id] = sprite
		var p: Array = item.get("position", [0, 0])
		sprite.position = Vector2(float(p[0]), float(p[1]))
		sprite.rotation = float(item.get("rotation", 0.0))
	for projectile_id in replay_projectiles.keys():
		if not visible_ids.has(projectile_id):
			var sprite: Variant = replay_projectiles[projectile_id]
			if is_instance_valid(sprite): sprite.queue_free()
			replay_projectiles.erase(projectile_id)

func finish_replay() -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_started = false
	show_result(String(active_replay.get("result", {}).get("outcome", "draw")))

func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var bar := ColorRect.new()
	bar.color = Color(0.035, 0.08, 0.10, 0.94)
	bar.position = Vector2.ZERO
	bar.size = Vector2(720, 96)
	layer.add_child(bar)
	var name_label := create_label(player_name, 18, 8, 190, 35, 22, Color("fff1c7"), HORIZONTAL_ALIGNMENT_LEFT, 3)
	layer.add_child(name_label)
	var stats_label := create_label("蓝方", 18, 47, 110, 28, 16, Color("68d4e0"), HORIZONTAL_ALIGNMENT_LEFT, 2)
	layer.add_child(stats_label)
	var kinds := ["gold", "stone", "wood", "meat"]
	var icons: Array[Texture2D] = [GOLD_ICON, STONE_ICON, WOOD_ICON, MEAT_ICON]
	for index in kinds.size():
		var x := 205.0 + index * 126.0
		var icon := TextureRect.new()
		icon.texture = make_icon_atlas(icons[index], kinds[index])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(x, 18)
		icon.size = Vector2(50, 50)
		layer.add_child(icon)
		var value := create_label("0", x + 48, 23, 66, 40, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3)
		layer.add_child(value)
		hud_values[kinds[index]] = value
	var strategy_text := active_strategy_hud_text()
	if strategy_text != "":
		var strategy_label := create_label("策略生效：" + strategy_text, 12, 73, 696, 21, 13, Color("b9ebe4"), HORIZONTAL_ALIGNMENT_CENTER, 2)
		layer.add_child(strategy_label)

func active_strategy_hud_text() -> String:
	if active_strategy.is_empty():
		return "默认AI"
	if active_strategy.get("schemaVersion") == "3.0":
		return String(active_strategy.get("strategyName", "Strategy 3.0 玩家策略"))
	var target_names := {"monk": "僧侣", "archer": "弓箭手", "lancer": "长枪手", "warrior": "战士", "worker": "工人"}
	var resource_names := {"meat": "肉", "wood": "木头", "stone": "石头", "gold": "金矿"}
	var parts: Array[String] = []
	for value_directive in active_strategy.get("directives", []):
		if not value_directive is Dictionary:
			continue
		for value_action in value_directive.get("actions", []):
			if not value_action is Dictionary:
				continue
			var action: Dictionary = value_action
			var description := ""
			match String(action.get("type", "")):
				"attack", "set_target":
					var target := String(action.get("target_type", action.get("target_sort", "")))
					if target_names.has(target):
						description = "优先攻击%s" % target_names[target]
				"gather":
					var resource := String(action.get("resource", ""))
					if resource_names.has(resource):
						description = "工人采集%s" % resource_names[resource]
				"heal": description = "僧侣优先治疗"
				"retreat": description = "低血撤退"
			if description != "" and description not in parts:
				parts.append(description)
	return " · ".join(parts) if not parts.is_empty() else String(active_strategy.get("strategy_name", "玩家策略"))

func make_icon_atlas(texture: Texture2D, kind: String) -> Texture2D:
	if kind == "stone":
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 128, 128)
	return atlas

func countdown() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var label := create_label("5", 170, 480, 380, 220, 112, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 10)
	layer.add_child(label)
	for number in range(5, 0, -1):
		label.text = str(number)
		play_sfx(SFX_COUNTDOWN, -5.0, 0.0)
		label.scale = Vector2(1.25, 1.25)
		label.pivot_offset = label.size / 2.0
		create_tween().tween_property(label, "scale", Vector2.ONE, 0.35)
		await get_tree().create_timer(0.08 if test_mode else 1.0).timeout
	label.text = "开始！"
	play_sfx(SFX_START, -2.0, 0.0)
	label.add_theme_font_size_override("font_size", 70)
	battle_started = true
	await get_tree().create_timer(0.8).timeout
	layer.queue_free()

func get_nearest_enemy(unit: Node2D) -> Node2D:
	if strategy_runtime != null and strategy_runtime.is_active() and unit.team == "blue":
		return strategy_runtime.select_enemy(unit, units)
	var nearest: Node2D
	var best := INF
	for candidate in units:
		if not is_instance_valid(candidate) or candidate.dead or candidate.team == unit.team or not can_see_unit(unit, candidate):
			continue
		var distance: float = unit.position.distance_to(candidate.position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest

func has_living_non_worker_combatants(team_name: String) -> bool:
	for candidate in units:
		if not is_instance_valid(candidate) or candidate.dead or candidate.team != team_name:
			continue
		if candidate.unit_type in ["archer", "lancer", "warrior", "monk"]:
			return true
	return false

func spawn_heal_effect(healed_unit: Node2D) -> void:
	if healed_unit == null or not is_instance_valid(healed_unit):
		return
	var frames := SpriteFrames.new()
	frames.add_animation("heal")
	frames.set_animation_speed("heal", 11.0)
	frames.set_animation_loop("heal", false)
	for frame_index in 11:
		var atlas := AtlasTexture.new()
		atlas.atlas = HEAL_EFFECT
		atlas.region = Rect2(frame_index * 192, 0, 192, 192)
		frames.add_frame("heal", atlas)
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.scale = Vector2(0.55, 0.55)
	effect.position = Vector2(0, -4)
	effect.z_index = 20
	healed_unit.add_child(effect)
	effect.animation_finished.connect(effect.queue_free)
	effect.play("heal")

func get_nearest_injured_ally(unit: Node2D) -> Node2D:
	if strategy_runtime != null and strategy_runtime.is_active() and unit.team == "blue":
		return strategy_runtime.select_injured_ally(unit, units)
	var nearest: Node2D
	var best := INF
	for candidate in units:
		if not is_instance_valid(candidate) or candidate.dead or candidate.team != unit.team or candidate == unit:
			continue
		if candidate.hp >= candidate.max_hp:
			continue
		var distance: float = unit.position.distance_to(candidate.position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest

func get_nearest_resource(unit: Node2D, preferred_type := "") -> Node2D:
	var nearest: Node2D
	var best := INF
	for candidate in resources:
		if not is_instance_valid(candidate) or candidate.depleted or candidate.team != unit.team:
			continue
		if preferred_type != "" and candidate.resource_type != preferred_type:
			continue
		var distance: float = unit.position.distance_to(candidate.position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest

func area_type_at(position: Vector2) -> String:
	var area := area_at(position)
	if not area.is_empty(): return str(area["type"])
	if position.y > 706.0: return "ally_side"
	if position.y < 574.0: return "enemy_side"
	if position.y >= 592.0 and position.y <= 688.0:
		return "left_bridge" if absf(position.x - BRIDGE_LEFT_X) <= absf(position.x - BRIDGE_RIGHT_X) else "right_bridge"
	return "open_ground"

func nearest_area_position(unit: Node, area_type: String) -> Vector2:
	var candidates: Array = battle_areas.filter(func(area): return area.get("type") == area_type and bool(area.get("is_passable", true)))
	if not candidates.is_empty():
		candidates.sort_custom(func(a: Dictionary, b: Dictionary):
			var ad: float = unit.position.distance_squared_to(Vector2(a["center"])); var bd: float = unit.position.distance_squared_to(Vector2(b["center"]))
			if not is_equal_approx(ad, bd): return ad < bd
			return str(a["id"]) < str(b["id"]))
		return Vector2(candidates[0]["center"])
	match area_type:
		"ally_side", "spawn_zone", "ally_fountain": return unit.home_position
		"enemy_side", "enemy_fountain": return Vector2(unit.home_position.x, VIEW_SIZE.y - unit.home_position.y)
		"left_bridge": return Vector2(BRIDGE_LEFT_X, 640.0)
		"right_bridge": return Vector2(BRIDGE_RIGHT_X, 640.0)
	return unit.position

func strategy_position_reference(unit: Node, reference: String) -> Vector2:
	if reference.begins_with("resource:"):
		var resource := get_nearest_resource(unit, reference.trim_prefix("resource:"))
		return resource.position if resource != null else unit.position
	return unit.position

func initialize_battle_areas() -> void:
	battle_areas.clear()
	var supported_area_types: Array = battle_snapshot.get("map", {}).get("supportedAreaTypes", [])
	if not supported_area_types.has("bush"):
		return
	var upper := [Vector2(150,250),Vector2(570,260),Vector2(260,430),Vector2(470,450)]
	var serial := 0
	for center in upper:
		serial += 1
		battle_areas.append({"id":"bush_top_%02d" % serial,"type":"bush","center":center,"radius":34.0,"is_passable":true,"blocks_vision":true})
		battle_areas.append({"id":"bush_bottom_%02d" % serial,"type":"bush","center":Vector2(center.x,VIEW_SIZE.y-center.y),"radius":34.0,"is_passable":true,"blocks_vision":true})

func area_at(position: Vector2, area_type := "") -> Dictionary:
	var matches: Array = []
	for area in battle_areas:
		if area_type != "" and area.get("type") != area_type: continue
		if position.distance_to(Vector2(area["center"])) <= float(area.get("radius", 0.0)): matches.append(area)
	if matches.is_empty(): return {}
	matches.sort_custom(func(a: Dictionary,b: Dictionary): return str(a["id"]) < str(b["id"]))
	return matches[0]

func can_see_unit(observer: Node, target: Node) -> bool:
	if observer == null or target == null or not is_instance_valid(observer) or not is_instance_valid(target): return false
	if observer.team == target.team: return true
	var target_bush := area_at(target.position, "bush")
	if target_bush.is_empty(): return true
	var observer_bush := area_at(observer.position, "bush")
	return not observer_bush.is_empty() and observer_bush.get("id") == target_bush.get("id")

func get_strategy_movement_action(unit: Node) -> Dictionary:
	if strategy_runtime == null:
		return {}
	return strategy_runtime.movement_action(unit)

func get_strategy_movement_destination(unit: Node, action: Dictionary) -> Variant:
	if strategy_runtime == null:
		return null
	return strategy_runtime.movement_destination(unit, action)

func get_strategy_skill_action(unit: Node) -> Dictionary:
	if strategy_runtime == null or not strategy_runtime.has_method("skill_action"): return {}
	return strategy_runtime.skill_action(unit)

func get_strategy_role_target(unit: Node, role: String) -> Variant:
	if strategy_runtime == null or not strategy_runtime.has_method("role_target"): return null
	return strategy_runtime.role_target(unit, role)

func spawn_skill_projectile(source: Node2D, skill_target: Node2D, damage: int, config: Dictionary, skill_id: String) -> void:
	if projectile_engine != null and is_instance_valid(projectile_engine):
		projectile_engine.spawn_configured(source, skill_target, damage, config, "skill:" + skill_id)

func constrain_strategy_destination(unit: Node, destination: Vector2) -> Vector2:
	if strategy_runtime == null or not strategy_runtime.is_active() or unit.team != "blue":
		return destination
	return strategy_runtime.constrain_destination(unit, destination)

func strategy_holds_position(unit: Node) -> bool:
	return strategy_runtime != null and strategy_runtime.holds_position(unit)

func get_strategy_resource_type(unit: Node) -> String:
	if strategy_runtime == null:
		return ""
	return strategy_runtime.preferred_resource(unit)

func strategy_forces_monk_combat(unit: Node) -> bool:
	if strategy_runtime == null or not strategy_runtime.is_active() or unit.team != "blue":
		return false
	var has_combat: bool = strategy_runtime.has_explicit_action(unit, "combat", ["attack", "set_target"])
	var has_support: bool = strategy_runtime.has_explicit_action(unit, "support", ["heal"])
	return has_combat and not has_support

func get_unit_by_slot(team_name: String, slot: int) -> Node2D:
	if slot <= 0:
		return null
	for candidate in units:
		if is_instance_valid(candidate) and not candidate.dead and candidate.team == team_name and int(candidate.strategy_slot) == slot:
			return candidate
	return null

func count_attackers_targeting(team_name: String, combat_target: Node) -> int:
	var count := 0
	for candidate in units:
		if is_instance_valid(candidate) and not candidate.dead and candidate.team == team_name and candidate.target == combat_target:
			count += 1
	return count

func intended_attackers_of(protected_unit: Node) -> Array:
	if protected_unit == null or not is_instance_valid(protected_unit): return []
	var attackers: Array = []
	for candidate in units:
		if is_instance_valid(candidate) and not candidate.dead and candidate.team != protected_unit.team and candidate.target == protected_unit:
			attackers.append(candidate)
	attackers.sort_custom(func(a, b):
		var ad: float = protected_unit.position.distance_squared_to(a.position); var bd: float = protected_unit.position.distance_squared_to(b.position)
		if not is_equal_approx(ad, bd): return ad < bd
		return str(a.replay_id) < str(b.replay_id))
	return attackers

func line_block_position(attacker: Node, protected_unit: Node, blocker: Node, predict := true) -> Vector2:
	if attacker == null or protected_unit == null or blocker == null: return blocker.position if blocker != null else Vector2.ZERO
	var attacker_position: Vector2 = attacker.position
	var protected_position: Vector2 = protected_unit.position
	if predict:
		var projectile_speed := 640.0
		var windup_remaining := maxf(0.0, float(attacker.action_cooldown))
		if str(attacker.state) == "attack" and attacker.has_method("attack_impact_time"):
			windup_remaining = maxf(0.0, float(attacker.attack_impact_time()) - float(attacker.state_time))
		attacker_position += Vector2(attacker.last_move_direction) * float(attacker.move_speed) * windup_remaining
		protected_position += Vector2(protected_unit.last_move_direction) * float(protected_unit.move_speed) * windup_remaining
		# Two fixed iterations predict the target at projectile intersection time
		# without introducing an unbounded solver into the deterministic Tick.
		for _iteration in 2:
			var travel_time: float = attacker_position.distance_to(protected_position) / projectile_speed
			protected_position = protected_unit.position + Vector2(protected_unit.last_move_direction) * float(protected_unit.move_speed) * (windup_remaining + travel_time)
	var toward_attacker := protected_position.direction_to(attacker_position)
	if toward_attacker.is_zero_approx(): return protected_position
	var desired := protected_position + toward_attacker * 38.0
	return constrain_unit_position(blocker.position, desired)

func get_next_waypoint(origin: Vector2, destination: Vector2, committed_bridge_x := 0.0) -> Vector2:
	const TOP_BANK := 574.0
	const BOTTOM_BANK := 706.0
	var crosses_down := destination.y > BOTTOM_BANK and origin.y < BOTTOM_BANK
	var crosses_up := destination.y < TOP_BANK and origin.y > TOP_BANK
	if crosses_down or crosses_up:
		var left_cost := absf(origin.x - BRIDGE_LEFT_X) + absf(destination.x - BRIDGE_LEFT_X)
		var right_cost := absf(origin.x - BRIDGE_RIGHT_X) + absf(destination.x - BRIDGE_RIGHT_X)
		var bridge_x := committed_bridge_x if committed_bridge_x > 0.0 else (BRIDGE_LEFT_X if left_cost <= right_cost else BRIDGE_RIGHT_X)
		if crosses_down:
			if origin.y < TOP_BANK - 5.0 and (absf(origin.x - bridge_x) > 8.0):
				return Vector2(bridge_x, TOP_BANK - 5.0)
			return Vector2(bridge_x, BOTTOM_BANK + 5.0)
		if origin.y > BOTTOM_BANK + 5.0 and (absf(origin.x - bridge_x) > 8.0):
			return Vector2(bridge_x, BOTTOM_BANK + 5.0)
		return Vector2(bridge_x, TOP_BANK - 5.0)
	return destination

func constrain_unit_position(origin: Vector2, proposed: Vector2) -> Vector2:
	const RIVER_TOP := 592.0
	const RIVER_BOTTOM := 688.0
	var result := Vector2(clampf(proposed.x, 18.0, 702.0), clampf(proposed.y, 105.0, 1235.0))
	if result.y < RIVER_TOP or result.y > RIVER_BOTTOM:
		return result
	var bridge_x := BRIDGE_LEFT_X if absf(result.x - BRIDGE_LEFT_X) <= absf(result.x - BRIDGE_RIGHT_X) else BRIDGE_RIGHT_X
	if absf(result.x - BRIDGE_GROUP_CENTER_X) <= BRIDGE_GROUP_HALF_WIDTH:
		result.x = clampf(result.x, BRIDGE_GROUP_CENTER_X - BRIDGE_GROUP_HALF_WIDTH, BRIDGE_GROUP_CENTER_X + BRIDGE_GROUP_HALF_WIDTH)
		return result
	# Water is a hard obstacle. A unit approaching from land remains on its
	# current bank; a legacy/edge position inside the river is snapped onto
	# the nearest bridge corridor so it cannot continue walking on water.
	if origin.y < RIVER_TOP:
		result.y = RIVER_TOP - 1.0
	elif origin.y > RIVER_BOTTOM:
		result.y = RIVER_BOTTOM + 1.0
	else:
		result.x = bridge_x
	return result

func spawn_arrow(source: Node2D, arrow_target: Node2D, damage: int) -> void:
	if projectile_engine != null and is_instance_valid(projectile_engine):
		projectile_engine.spawn_basic_attack(source, arrow_target, damage)

func record_projectile_event(event: Dictionary) -> void:
	replay_projectile_events.append(event.duplicate(true))

func queue_damage(source: Node, combat_target: Node, amount: int) -> void:
	queue_combat_event(combat_target, amount, 0, source)

func record_strategy_target_selection(source: Node, combat_target: Node) -> void:
	if not replay_capture_mode or source == null or not is_instance_valid(source) or source.team != "blue" or combat_target == null or not is_instance_valid(combat_target):
		return
	var action: Dictionary = strategy_runtime.first_action(source, "combat", ["set_target", "attack"]) if strategy_runtime != null and strategy_runtime.is_active() else {}
	var preferred_type := String(action.get("target_type", ""))
	var preferred_alive := false
	if preferred_type != "":
		for candidate in units:
			if is_instance_valid(candidate) and not candidate.dead and candidate.team != source.team and candidate.unit_type == preferred_type:
				preferred_alive = true
				break
	replay_strategy_events.append({
		"type": "target_selected", "time": snappedf(replay_elapsed, 0.01), "source_slot": source.strategy_slot,
		"target_type": combat_target.unit_type, "preferred_type": preferred_type, "preferred_alive": preferred_alive,
	})

func record_strategy_heal_selection(source: Node, combat_target: Node) -> void:
	if not replay_capture_mode or source == null or not is_instance_valid(source) or combat_target == null or not is_instance_valid(combat_target):
		return
	var preferred: Node2D = strategy_runtime.select_injured_ally(source, units) if strategy_runtime != null and strategy_runtime.is_active() else combat_target
	replay_strategy_events.append({
		"type": "heal_selected", "time": snappedf(replay_elapsed, 0.01), "source_slot": source.strategy_slot,
		"target_slot": combat_target.strategy_slot, "target_ratio": float(combat_target.hp) / float(combat_target.max_hp),
		"lowest_ratio": float(preferred.hp) / float(preferred.max_hp) if preferred != null else 1.0,
		"lowest_slot": int(preferred.strategy_slot) if preferred != null else 0,
	})

func record_strategy_skill_cast(source: Node, skill_target: Node, config: Dictionary) -> void:
	if source == null or not is_instance_valid(source) or skill_target == null or not is_instance_valid(skill_target): return
	replay_strategy_events.append({"type":"skill_cast","time":snappedf(replay_elapsed,0.01),"source_slot":source.strategy_slot,
		"sourceUnitId":source.replay_id,"targetUnitId":skill_target.replay_id,"skillNo":int(config.get("skillNo",0)),
		"skillId":str(config.get("skillId","")),"effectType":str(config.get("effect",{}).get("type",""))})

func emit_strategy_event(event_type: String, source: Variant = null, target_value: Variant = null, event_type_order := 0) -> void:
	var event := {"type":event_type,"phaseOrder":14,"eventTypeOrder":event_type_order,
		"sourceEntityId":str(source.replay_id) if source != null and is_instance_valid(source) else "",
		"targetEntityId":str(target_value.replay_id) if target_value != null and is_instance_valid(target_value) else "",
		"sourceSlot":int(source.strategy_slot) if source != null and is_instance_valid(source) else 0,
		"targetSlot":int(target_value.strategy_slot) if target_value != null and is_instance_valid(target_value) else 0}
	strategy_event_queue.enqueue(event)

func queue_heal(source: Node, combat_target: Node, amount: int) -> void:
	queue_combat_event(combat_target, 0, amount, source)

func queue_combat_event(combat_target: Node, damage: int, healing: int, source: Variant = null) -> void:
	if combat_target == null or not is_instance_valid(combat_target) or combat_target.dead:
		return
	pending_combat_events.append({"target": combat_target, "source":source, "damage": damage, "healing": healing})
	if not combat_flush_scheduled:
		combat_flush_scheduled = true
		resolve_combat_events.call_deferred()

func resolve_combat_events() -> void:
	combat_flush_scheduled = false
	var events := pending_combat_events.duplicate()
	pending_combat_events.clear()
	var totals: Dictionary = {}
	for event: Dictionary in events:
		var combat_target: Node = event["target"]
		if not is_instance_valid(combat_target) or combat_target.dead:
			continue
		var key := combat_target.get_instance_id()
		if not totals.has(key):
			totals[key] = {"target": combat_target, "damage": 0, "healing": 0, "damageSources":[]}
		totals[key]["damage"] += int(event["damage"])
		totals[key]["healing"] += int(event["healing"])
		if int(event["damage"]) > 0 and event.get("source") != null and is_instance_valid(event.get("source")):
			totals[key]["damageSources"].append(event["source"])
	for key in totals:
		var total: Dictionary = totals[key]
		var combat_target: Node = total["target"]
		if is_instance_valid(combat_target) and not combat_target.dead:
			var damage_sources: Array = total.get("damageSources", [])
			damage_sources.sort_custom(func(a, b): return str(a.replay_id) < str(b.replay_id))
			for source in damage_sources: emit_strategy_event("damage_received", source, combat_target, 10)
			combat_target.resolve_combat(int(total["damage"]), int(total["healing"]))

func add_resource(team_name: String, kind: String, amount: int) -> void:
	resource_counts[team_name][kind] += amount
	play_sfx(SFX_DEPOSIT, -5.0, 0.025)
	if test_mode:
		print("RESOURCE_DEPOSIT team=", team_name, " kind=", kind, " value=", resource_counts[team_name][kind])
	if team_name == "blue" and hud_values.has(kind):
		hud_values[kind].text = str(resource_counts[team_name][kind])
	if kind == "meat":
		try_revive.call_deferred(team_name)

func unit_died(_unit: Node2D) -> void:
	emit_strategy_event("unit_died", _unit, _unit, 30)
	if test_mode:
		print("UNIT_DIED team=", _unit.team, " type=", _unit.unit_type)
	death_queues[_unit.team].append({
		"unit_type": _unit.unit_type,
		"spawn_position": _unit.home_position,
		"strategy_slot": _unit.strategy_slot,
		"strategy_gather_counts": _unit.strategy_gather_counts.duplicate()
	})
	try_revive.call_deferred(_unit.team)
	check_battle_end.call_deferred()

func try_revive(team_name: String) -> void:
	if not death_queues.has(team_name):
		return
	while int(resource_counts[team_name]["meat"]) > 0 and not death_queues[team_name].is_empty():
		var fallen: Dictionary = death_queues[team_name].pop_front()
		resource_counts[team_name]["meat"] -= 1
		if team_name == "blue" and hud_values.has("meat"):
			hud_values["meat"].text = str(resource_counts[team_name]["meat"])
		var revived := create_unit(team_name, String(fallen["unit_type"]), Vector2(fallen["spawn_position"]), int(fallen.get("strategy_slot", 0)))
		revived.strategy_gather_counts = Dictionary(fallen.get("strategy_gather_counts", revived.strategy_gather_counts)).duplicate()
		spawn_heal_effect(revived)
		play_sfx(SFX_REVIVE, -2.0, 0.015)
		show_float_text(revived.global_position - Vector2(0, 55), "消耗1肉 · 重生", Color("ffe36e"))
		if test_mode:
			print("UNIT_REVIVED team=", team_name, " type=", fallen["unit_type"], " meat=", resource_counts[team_name]["meat"])

func check_battle_end() -> void:
	if battle_finished:
		return
	var blue_can_fight := 0
	var red_can_fight := 0
	for candidate in units:
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		if candidate.unit_type not in ["archer", "lancer", "warrior", "monk", "worker"]:
			continue
		if candidate.team == "blue":
			blue_can_fight += 1
		else:
			red_can_fight += 1
	if blue_can_fight == 0 or red_can_fight == 0:
		battle_finished = true
		battle_started = false
		var outcome := "draw" if blue_can_fight == 0 and red_can_fight == 0 else ("victory" if blue_can_fight > 0 else "defeat")
		show_result(outcome)

func show_result(outcome: String) -> void:
	replay_outcome = outcome
	if replay_capture_mode:
		return
	if test_mode:
		print("AUTO_TEST_COMPLETE outcome=", outcome, " resources=", resource_counts)
		Engine.time_scale = 1.0
		get_tree().quit()
		return
	var result_sfx: AudioStream = SFX_DRAW if outcome == "draw" else (SFX_VICTORY if outcome == "victory" else SFX_DEFEAT)
	play_sfx(result_sfx, -1.0, 0.0)
	var layer := CanvasLayer.new()
	layer.layer = 150
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.07, 0.76)
	shade.position = Vector2.ZERO
	shade.size = VIEW_SIZE
	layer.add_child(shade)
	var result_title := "平局" if outcome == "draw" else ("胜利！" if outcome == "victory" else "失败")
	var title := create_label(result_title, 100, 410, 520, 130, 72, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 8)
	layer.add_child(title)
	var summary := create_label("金 %d   石 %d   木 %d   肉 %d" % [resource_counts.blue.gold, resource_counts.blue.stone, resource_counts.blue.wood, resource_counts.blue.meat], 80, 565, 560, 60, 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)
	layer.add_child(summary)
	var button := Button.new()
	button.text = "返回主界面"
	button.position = Vector2(205, 700)
	button.size = Vector2(310, 82)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 25)
	button.pressed.connect(show_main_menu)
	layer.add_child(button)

func show_float_text(world_position: Vector2, text: String, color: Color) -> void:
	var label := create_label(text, world_position.x - 45, world_position.y - 22, 90, 40, 20, color, HORIZONTAL_ALIGNMENT_CENTER, 3)
	label.z_index = 140
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35.0, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(label.queue_free)

func make_title(text: String) -> void:
	var ribbon := NinePatchRect.new()
	ribbon.texture = RIBBON_BLUE
	ribbon.patch_margin_left = 64
	ribbon.patch_margin_right = 64
	place(ribbon, 110, 75, 500, 96)
	add_child(ribbon)
	make_label(text, 130, 82, 460, 70, 38, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 5)

func make_panel(x: float, y: float, width: float, height: float) -> void:
	var panel := NinePatchRect.new()
	panel.texture = PANEL
	panel.patch_margin_left = 64
	panel.patch_margin_top = 64
	panel.patch_margin_right = 64
	panel.patch_margin_bottom = 64
	place(panel, x, y, width, height)
	add_child(panel)

func make_action_button(text: String, rect: Rect2, red: bool, callback: Callable) -> void:
	var visual := NinePatchRect.new()
	visual.texture = BUTTON_RED if red else BUTTON_BLUE
	visual.patch_margin_left = 64
	visual.patch_margin_top = 64
	visual.patch_margin_right = 64
	visual.patch_margin_bottom = 64
	visual.position = rect.position
	visual.size = rect.size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	var button := Button.new()
	button.text = text
	button.position = rect.position + Vector2(16, 6)
	button.size = rect.size - Vector2(32, 18)
	button.flat = true
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color("fff1c7"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("d7f4f2"))
	button.pressed.connect(func() -> void:
		play_sfx(SFX_UI_CLICK, -4.0, 0.02)
		callback.call()
	)
	add_child(button)

func make_progress(x: float, y: float, width: float, height: float, ratio: float, text: String) -> void:
	var outer := ColorRect.new()
	outer.color = Color("352d3d")
	place(outer, x, y, width, height)
	add_child(outer)
	var inner := ColorRect.new()
	inner.color = Color("52bdc5")
	place(inner, x + 5, y + 5, (width - 10) * ratio, height - 10)
	add_child(inner)
	make_label(text, x, y - 1, width, height, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 2)

func make_label(text: String, x: float, y: float, width: float, height: float, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 3) -> Label:
	var label := create_label(text, x, y, width, height, size, color, align, outline)
	add_child(label)
	return label

func create_label(text: String, x: float, y: float, width: float, height: float, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 3) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.size = Vector2(width, height)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.11, 0.94))
		label.add_theme_constant_override("outline_size", outline)
	return label

func place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)

func capture_battle_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.65).timeout
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://battle_gameplay_preview.png")
	print("BATTLE_PREVIEW_RESULT:", error, " size=", image.get_size())
	get_tree().quit()
