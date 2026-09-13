extends Node2D

const VIEW_SIZE := Vector2(720, 1280)
const CELL := 32
const COLS := 22
const ROWS := 40
const MAP_LEFT := 8
const RIVER_Y := 592
const RIVER_HEIGHT := 96

const WATER_PATH := "res://assets/terrain/water.png"
const FLAT_PATH := "res://assets/terrain/ground_flat.png"
const ELEVATION_PATH := "res://assets/terrain/ground_elevation.png"
const BRIDGE_PATH := "res://assets/terrain/bridges.png"
const TREE_PATH := "res://assets/deco/trees.png"

var water: TextureRect
var water_time := 0.0

func _ready() -> void:
	build_land()
	build_river()
	build_paths()
	build_platforms()
	build_bridges()
	build_decorations()
	build_overlay()
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()

func build_land() -> void:
	var background := ColorRect.new()
	background.name = "LandBase"
	background.position = Vector2(-360, -360)
	background.size = Vector2(1440, 2000)
	background.color = Color("75a96a")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -20
	add_child(background)

	# The visual grid is 22 x 40 at 32 px. Source tiles are sampled at 64 px
	# and rendered at 50%, preserving crisp pixel edges.
	for row in ROWS:
		for col in COLS:
			var tile := add_atlas_sprite(
				"Grass_%02d_%02d" % [col, row],
				FLAT_PATH,
				Rect2(64, 64, 64, 64),
				cell_center(col, row),
				Vector2(0.5, 0.5),
				-10
			)
			var mirrored_row: int = min(row, ROWS - 1 - row)
			var shade := 0.96 + float((col * 3 + mirrored_row * 5) % 5) * 0.012
			tile.modulate = Color(shade, shade, shade, 1.0)

func build_river() -> void:
	water = TextureRect.new()
	water.name = "CentralRiver"
	water.texture = load(WATER_PATH)
	water.position = Vector2(-64, RIVER_Y)
	water.size = Vector2(848, RIVER_HEIGHT)
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water.stretch_mode = TextureRect.STRETCH_TILE
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.z_index = -5
	add_child(water)

	add_bank_foam(RIVER_Y + 4)
	add_bank_foam(RIVER_Y + RIVER_HEIGHT - 4)

func add_bank_foam(y_position: float) -> void:
	var foam := Line2D.new()
	foam.name = "RiverBankFoam"
	foam.width = 3.0
	foam.default_color = Color(0.76, 0.94, 0.86, 0.82)
	foam.z_index = -3
	for x in range(0, 737, 16):
		foam.add_point(Vector2(x, y_position + sin(float(x) * 0.075) * 3.0))
	add_child(foam)

func build_paths() -> void:
	# A broad central dirt lane connects both teams to the joined double bridge.
	for row in range(5, 18):
		for col in range(9, 13):
			add_path_tile(col, row)
	for row in range(22, 35):
		for col in range(9, 13):
			add_path_tile(col, row)

func add_path_tile(col: int, row: int) -> void:
	var tile := add_atlas_sprite(
		"Path_%02d_%02d" % [col, row],
		FLAT_PATH,
		Rect2(384, 64, 64, 64),
		cell_center(col, row),
		Vector2(0.5, 0.5),
		-8
	)
	tile.modulate = Color(1.0, 0.96, 0.86, 0.92)

func build_platforms() -> void:
	var x_positions := [72.0, 216.0, 360.0, 504.0, 648.0]
	for index in x_positions.size():
		add_platform(Vector2(x_positions[index], 128), Color("df5c67"), "RedPlatform%d" % (index + 1))
		add_platform(Vector2(x_positions[index], 1152), Color("4c9de8"), "BluePlatform%d" % (index + 1))

func add_platform(position: Vector2, team_color: Color, node_name: String) -> void:
	# One row by three columns: 96 x 32 px after the 50% source scale.
	add_atlas_sprite(node_name, ELEVATION_PATH, Rect2(0, 448, 192, 64), position, Vector2(0.5, 0.5), 2)
	var marker := Polygon2D.new()
	marker.name = node_name + "Marker"
	marker.position = position
	marker.polygon = PackedVector2Array([
		Vector2(-34, -8), Vector2(34, -8), Vector2(42, 0),
		Vector2(34, 8), Vector2(-34, 8), Vector2(-42, 0)
	])
	marker.color = Color(team_color, 0.50)
	marker.z_index = 3
	add_child(marker)

func build_bridges() -> void:
	# The full 64 x 192 source region includes both wooden end caps.
	# The two 64 px bridges touch at x=360 and form one centered double bridge.
	for bridge_x in [328.0, 392.0]:
		add_atlas_sprite(
			"Bridge",
			BRIDGE_PATH,
			Rect2(0, 64, 64, 192),
			Vector2(bridge_x, 640),
			Vector2.ONE,
			5
		)

func build_decorations() -> void:
	# Only the smallest mushroom and smallest bush remain. Positions are mirrored.
	for position in [Vector2(130, 310), Vector2(590, 350)]:
		add_mirrored_texture("SmallMushroom", "res://assets/deco/01.png", position, Vector2(0.72, 0.72), 4)
	for position in [Vector2(150, 250), Vector2(570, 260), Vector2(260, 430), Vector2(470, 450)]:
		add_mirrored_texture("SmallBush", "res://assets/deco/07.png", position, Vector2(0.78, 0.78), 4)

func build_overlay() -> void:
	pass

func add_mirrored_atlas(node_name: String, texture_path: String, region: Rect2, upper_position: Vector2, sprite_scale: Vector2, layer: int) -> void:
	add_atlas_sprite(node_name + "Top", texture_path, region, upper_position, sprite_scale, layer)
	add_atlas_sprite(node_name + "Bottom", texture_path, region, Vector2(upper_position.x, VIEW_SIZE.y - upper_position.y), sprite_scale, layer)

func add_mirrored_texture(node_name: String, texture_path: String, upper_position: Vector2, sprite_scale: Vector2, layer: int) -> void:
	add_texture_sprite(node_name + "Top", texture_path, upper_position, sprite_scale, layer)
	add_texture_sprite(node_name + "Bottom", texture_path, Vector2(upper_position.x, VIEW_SIZE.y - upper_position.y), sprite_scale, layer)

func make_label(text: String, position: Vector2, size: Vector2, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.10, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label

func cell_center(col: int, row: int) -> Vector2:
	return Vector2(MAP_LEFT + col * CELL + CELL * 0.5, row * CELL + CELL * 0.5)

func add_atlas_sprite(node_name: String, texture_path: String, region: Rect2, position: Vector2, sprite_scale: Vector2, layer: int) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(texture_path)
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = atlas
	sprite.position = position
	sprite.scale = sprite_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = layer
	add_child(sprite)
	return sprite

func add_texture_sprite(node_name: String, texture_path: String, position: Vector2, sprite_scale: Vector2, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(texture_path)
	sprite.position = position
	sprite.scale = sprite_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = layer
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	water_time += delta
	if water:
		water.position.x = -64.0 + fmod(water_time * 4.0, 64.0)

func capture_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://map_preview_portrait.png")
	print("MAP_PREVIEW_RESULT:", error)
	get_tree().quit()
