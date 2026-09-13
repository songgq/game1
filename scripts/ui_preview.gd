extends Control

const W := 720.0
const H := 1280.0
const FONT := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const BG := preload("res://map_preview_portrait.png")
const PANEL := preload("res://assets/ui/Carved_9Slides.png")
const BUTTON_BLUE := preload("res://assets/ui/Button_Blue_9Slides.png")
const BUTTON_RED := preload("res://assets/ui/Button_Red_9Slides.png")
const RIBBON_BLUE := preload("res://assets/ui/Ribbon_Blue_3Slides.png")
const RIBBON_RED := preload("res://assets/ui/Ribbon_Red_3Slides.png")
const RIBBON_YELLOW := preload("res://assets/ui/Ribbon_Yellow_3Slides.png")
const AVATAR := preload("res://assets/ui/Avatars_01.png")
const COIN := preload("res://assets/ui/Coin.png")

var screen_name := "main"
var should_capture := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			screen_name = arg.trim_prefix("--screen=")
		elif arg == "--capture-ui":
			should_capture = true
	build_background()
	match screen_name:
		"saves": build_saves()
		"settings": build_settings()
		_: build_main()
	if should_capture:
		capture_later()

func build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	place(bg, 0, 0, W, H)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.075, 0.095, 0.72)
	place(shade, 0, 0, W, H)
	add_child(shade)
	var top_glow := ColorRect.new()
	top_glow.color = Color(0.08, 0.24, 0.27, 0.28)
	place(top_glow, 0, 0, W, 330)
	add_child(top_glow)

func build_main() -> void:
	make_panel(24, 28, 672, 210)
	make_avatar(48, 55, 132)
	make_label("无名勇士", 202, 54, 260, 48, 29, Color("fff1c7"), HORIZONTAL_ALIGNMENT_LEFT)
	make_label("✎", 444, 57, 42, 42, 26, Color("b8eff2"))
	make_label("等级 12", 202, 100, 170, 34, 21, Color("332b34"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	make_progress(202, 141, 280, 38, 0.64, "经验  640 / 1000")
	make_currency(500, 62, "12,580", true)
	make_currency(500, 132, "320", false)

	make_label("翡翠纷争", 80, 292, 560, 88, 54, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 7)
	make_label("EMERALD CLASH", 160, 376, 400, 34, 18, Color("9edce0"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	make_divider(160, 430, 400)
	make_button("开始新游戏", 130, 495, 460, 96, BUTTON_BLUE, 31)
	make_button("读取存档", 130, 624, 460, 96, BUTTON_BLUE, 31)
	make_button("设置", 130, 753, 460, 96, BUTTON_BLUE, 31)
	make_label("点击头像或名称可修改个人资料", 100, 1000, 520, 38, 20, Color("c2dcda"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	make_label("Godot 4.5.2  ·  竖屏对战版", 100, 1204, 520, 30, 16, Color(0.65, 0.78, 0.78, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 2)

func build_saves() -> void:
	make_title("读取存档", RIBBON_BLUE)
	make_save_slot(44, 205, "存档 1", "无名勇士  ·  等级 12", "翡翠河谷  ·  02:46:18", "2026-08-15  14:32", true)
	make_save_slot(44, 455, "存档 2", "空存档", "尚未开始冒险", "", false)
	make_save_slot(44, 705, "存档 3", "青石骑士  ·  等级 7", "翡翠河谷  ·  00:58:42", "2026-08-13  21:08", true)
	make_button("返回主界面", 210, 1060, 300, 82, BUTTON_BLUE, 25)
	make_label("选择存档继续游戏，也可以删除不需要的记录", 70, 1167, 580, 34, 18, Color("bedbd9"), HORIZONTAL_ALIGNMENT_CENTER, 2)

func build_settings() -> void:
	make_title("设置", RIBBON_BLUE)
	make_panel(48, 225, 624, 710)
	make_label("声音", 110, 276, 500, 46, 29, Color("3c3033"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	make_divider(118, 332, 484, Color("8c6860"))
	make_label("音乐", 104, 378, 130, 44, 25, Color("3c3033"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	make_slider(104, 438, 512, 0.70, "70%")
	make_label("音效", 104, 543, 130, 44, 25, Color("3c3033"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	make_slider(104, 603, 512, 0.50, "50%")
	make_label("拖动滑块可调整音量", 104, 704, 512, 34, 18, Color("765b5a"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	make_button("恢复默认", 105, 785, 234, 78, BUTTON_RED, 23)
	make_button("保存设置", 381, 785, 234, 78, BUTTON_BLUE, 23)
	make_button("返回主界面", 210, 1028, 300, 82, BUTTON_BLUE, 25)
	make_label("设置会自动保存在本机", 150, 1144, 420, 34, 18, Color("bedbd9"), HORIZONTAL_ALIGNMENT_CENTER, 2)

func make_title(text: String, ribbon: Texture2D) -> void:
	var r := NinePatchRect.new()
	r.texture = ribbon
	r.patch_margin_left = 64
	r.patch_margin_right = 64
	place(r, 110, 70, 500, 96)
	add_child(r)
	make_label(text, 130, 80, 460, 68, 37, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 5)

func make_panel(x: float, y: float, w: float, h: float) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = PANEL
	p.patch_margin_left = 64
	p.patch_margin_top = 64
	p.patch_margin_right = 64
	p.patch_margin_bottom = 64
	place(p, x, y, w, h)
	add_child(p)
	return p

func make_avatar(x: float, y: float, size: float) -> void:
	var border := NinePatchRect.new()
	border.texture = BUTTON_BLUE
	border.patch_margin_left = 64
	border.patch_margin_top = 64
	border.patch_margin_right = 64
	border.patch_margin_bottom = 64
	place(border, x - 8, y - 8, size + 16, size + 16)
	add_child(border)
	var avatar := TextureRect.new()
	avatar.texture = AVATAR
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	place(avatar, x, y, size, size)
	add_child(avatar)

func make_currency(x: float, y: float, value: String, is_coin: bool) -> void:
	var plate := ColorRect.new()
	plate.color = Color(0.06, 0.12, 0.15, 0.72)
	place(plate, x, y, 168, 52)
	add_child(plate)
	if is_coin:
		var icon := TextureRect.new()
		icon.texture = COIN
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		place(icon, x + 6, y - 2, 56, 56)
		add_child(icon)
	else:
		var gem := Polygon2D.new()
		gem.polygon = PackedVector2Array([Vector2(0, 17), Vector2(15, 0), Vector2(35, 0), Vector2(50, 17), Vector2(25, 47)])
		gem.color = Color("72e6ed")
		gem.position = Vector2(x + 8, y + 2)
		add_child(gem)
	make_label(value, x + 62, y + 4, 98, 42, 21, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 3)

func make_button(text: String, x: float, y: float, w: float, h: float, texture: Texture2D, size: int) -> void:
	var btn := NinePatchRect.new()
	btn.texture = texture
	btn.patch_margin_left = 64
	btn.patch_margin_top = 64
	btn.patch_margin_right = 64
	btn.patch_margin_bottom = 64
	place(btn, x, y, w, h)
	add_child(btn)
	make_label(text, x + 22, y + 7, w - 44, h - 20, size, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 5)

func make_progress(x: float, y: float, w: float, h: float, ratio: float, text: String) -> void:
	var outer := ColorRect.new()
	outer.color = Color("352d3d")
	place(outer, x, y, w, h)
	add_child(outer)
	var inner := ColorRect.new()
	inner.color = Color("52bdc5")
	place(inner, x + 5, y + 5, (w - 10) * ratio, h - 10)
	add_child(inner)
	make_label(text, x, y - 1, w, h, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)

func make_slider(x: float, y: float, w: float, ratio: float, value: String) -> void:
	var groove := ColorRect.new()
	groove.color = Color("4e3d46")
	place(groove, x, y + 17, w, 20)
	add_child(groove)
	var fill := ColorRect.new()
	fill.color = Color("51bfc6")
	place(fill, x + 4, y + 21, (w - 8) * ratio, 12)
	add_child(fill)
	var knob := NinePatchRect.new()
	knob.texture = BUTTON_BLUE
	knob.patch_margin_left = 64
	knob.patch_margin_top = 64
	knob.patch_margin_right = 64
	knob.patch_margin_bottom = 64
	place(knob, x + (w - 8) * ratio - 22, y, 56, 56)
	add_child(knob)
	make_label(value, x + w - 84, y - 46, 84, 34, 19, Color("684d4e"), HORIZONTAL_ALIGNMENT_RIGHT, 0)

func make_save_slot(x: float, y: float, title: String, line1: String, line2: String, date: String, occupied: bool) -> void:
	make_panel(x, y, 632, 212)
	var ribbon: Texture2D = RIBBON_YELLOW if occupied else RIBBON_BLUE
	var r := NinePatchRect.new()
	r.texture = ribbon
	r.patch_margin_left = 64
	r.patch_margin_right = 64
	place(r, x + 22, y + 18, 210, 60)
	add_child(r)
	make_label(title, x + 36, y + 22, 182, 42, 22, Color("fff1c7"), HORIZONTAL_ALIGNMENT_CENTER, 4)
	make_label(line1, x + 42, y + 91, 360, 36, 22 if occupied else 26, Color("403337"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	make_label(line2, x + 42, y + 132, 390, 30, 17, Color("735958"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	make_label(date, x + 42, y + 165, 390, 26, 14, Color("94736c"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	if occupied:
		make_button("读取", x + 464, y + 55, 132, 66, BUTTON_BLUE, 21)
		make_button("删除", x + 464, y + 132, 132, 58, BUTTON_RED, 19)
	else:
		make_label("—", x + 475, y + 91, 110, 48, 30, Color("927870"), HORIZONTAL_ALIGNMENT_CENTER, 0)

func make_divider(x: float, y: float, w: float, color := Color("78bfc1")) -> void:
	var line := ColorRect.new()
	line.color = color
	place(line, x, y, w, 3)
	add_child(line)

func make_label(text: String, x: float, y: float, w: float, h: float, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 3) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color(0.08, 0.10, 0.13, 0.92))
		label.add_theme_constant_override("outline_size", outline)
	place(label, x, y, w, h)
	add_child(label)
	return label

func place(node: Control, x: float, y: float, w: float, h: float) -> void:
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)

func capture_later() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://ui_%s_preview.png" % screen_name
	var error := image.save_png(path)
	print("UI_CAPTURE:", path, " error=", error, " size=", image.get_size())
	get_tree().quit()
