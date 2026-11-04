extends Control

const PREVIEW_BORDER_WIDTH := 4
const PREVIEW_ASPECT_RATIO := 16.0 / 9.0

var world_sim: WorldSim
var current_level := 0
var menu_content: VBoxContainer
var level_content: VBoxContainer
var settings_controls: BoxContainer
var settings_label: Label
var automatic_transmission: CheckButton
var restart_button: Button
var settings_margin: MarginContainer

@onready var preview_frame: PanelContainer = $VBoxContainer/PreviewFrame
@onready var preview: TextureRect = $VBoxContainer/PreviewFrame/TextureRect
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var previous_button: Button = $VBoxContainer/HBoxContainer/PreviousButton
@onready var next_button: Button = $VBoxContainer/HBoxContainer/NextButton
@onready var play_button: Button = $VBoxContainer/HBoxContainer/PlayButton


func _ready() -> void:
	world_sim = get_tree().root.find_child("WorldSim", true, false) as WorldSim
	assert(world_sim != null)

	menu_content = get_parent() as VBoxContainer
	level_content = $VBoxContainer
	settings_label = menu_content.get_node("Label") as Label
	settings_margin = menu_content.get_node("MarginContainer") as MarginContainer
	settings_controls = settings_margin.get_node("VBoxContainer") as BoxContainer
	automatic_transmission = settings_controls.get_node("automatic_transmission") as CheckButton
	restart_button = settings_controls.get_node("restart_sim") as Button
	menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_setup_preview_frame()

	previous_button.pressed.connect(previous_level)
	next_button.pressed.connect(next_level)
	play_button.pressed.connect(load_level)
	get_viewport().size_changed.connect(_layout_menu)

	update_ui()
	_layout_menu()


func _setup_preview_frame() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	settings_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_controls.add_theme_constant_override("separation", 12)
	settings_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for button in [automatic_transmission, restart_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_FILL

	var button_row := previous_button.get_parent() as HBoxContainer
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for button in [previous_button, next_button, play_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.06)
	style.border_color = Color.WHITE
	style.set_border_width_all(PREVIEW_BORDER_WIDTH)
	preview_frame.add_theme_stylebox_override("panel", style)

	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = PREVIEW_BORDER_WIDTH
	preview.offset_top = PREVIEW_BORDER_WIDTH
	preview.offset_right = -PREVIEW_BORDER_WIDTH
	preview.offset_bottom = -PREVIEW_BORDER_WIDTH
	preview.custom_minimum_size = Vector2.ZERO
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _layout_menu() -> void:
	if not is_instance_valid(menu_content) or not is_instance_valid(level_content):
		return

	var viewport_size := get_viewport_rect().size
	var horizontal_margin := clampf(viewport_size.x * 0.025, 12.0, 48.0)
	var vertical_margin := clampf(viewport_size.y * 0.02, 8.0, 24.0)
	menu_content.offset_left = horizontal_margin
	menu_content.offset_top = vertical_margin
	menu_content.offset_right = -horizontal_margin
	menu_content.offset_bottom = -vertical_margin

	var short_side := minf(viewport_size.x, viewport_size.y)
	var title_font_size := clampi(int(short_side * 0.045), 20, 42)
	var button_font_size := clampi(int(short_side * 0.032), 14, 24)
	var button_height := clampf(viewport_size.y * 0.09, 44.0, 72.0)
	var available_width := maxf(viewport_size.x - horizontal_margin * 2.0, 180.0)
	var preview_height := minf(
		viewport_size.y * 0.58,
		available_width / PREVIEW_ASPECT_RATIO
	)
	preview_height = clampf(preview_height, 100.0, 720.0)
	var preview_width := preview_height * PREVIEW_ASPECT_RATIO

	menu_content.add_theme_constant_override("separation", 6)
	settings_label.custom_minimum_size.y = title_font_size * 1.25
	settings_label.add_theme_font_size_override("font_size", title_font_size)
	settings_margin.add_theme_constant_override("margin_left", 0)
	settings_margin.add_theme_constant_override("margin_top", 18)
	settings_margin.add_theme_constant_override("margin_right", 0)
	settings_margin.add_theme_constant_override("margin_bottom", 4)
	level_label.add_theme_font_size_override("font_size", title_font_size)
	preview_frame.custom_minimum_size = Vector2(preview_width, preview_height)

	for button in [automatic_transmission, restart_button, previous_button, next_button, play_button]:
		button.custom_minimum_size.y = button_height
		button.add_theme_font_size_override("font_size", button_font_size)


func update_ui() -> void:
	var levels := world_sim.world_scenes

	if levels.is_empty():
		level_label.text = "No levels found"
		preview.texture = null
		previous_button.disabled = true
		next_button.disabled = true
		play_button.disabled = true
		return

	current_level = clampi(current_level, 0, levels.size() - 1)

	var scene := levels[current_level]
	var world := scene.instantiate()

	var level_name: Variant = world.get("level_name") if "level_name" in world else null
	if level_name != null and not str(level_name).is_empty():
		level_label.text = str(level_name)
	else:
		level_label.text = scene.resource_path.get_base_dir().get_file()

	var world_preview: Variant = world.get("preview") if "preview" in world else null

	if world_preview is Texture2D:
		preview.texture = world_preview
	else:
		preview.texture = _load_default_preview(scene)

	world.free()

	previous_button.disabled = current_level == 0
	next_button.disabled = current_level >= levels.size() - 1
	play_button.disabled = false


func _load_default_preview(scene: PackedScene) -> Texture2D:
	var folder := scene.resource_path.get_base_dir()

	for filename in [
		"preview.tres",
		"preview.png",
		"preview.webp",
		"preview.jpg",
		"preview.jpeg",
		"preview.svg"
	]:
		var path := folder.path_join(filename)

		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture != null:
				return texture

	return null


func previous_level() -> void:
	if current_level > 0:
		current_level -= 1
		update_ui()


func next_level() -> void:
	if current_level < world_sim.world_scenes.size() - 1:
		current_level += 1
		update_ui()


func load_level() -> void:
	if not world_sim.world_scenes.is_empty():
		world_sim.load_world(world_sim.world_scenes[current_level])
