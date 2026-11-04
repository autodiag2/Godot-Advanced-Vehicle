extends Control

const PREVIEW_BORDER_WIDTH := 4

var world_sim: WorldSim
var current_level := 0

@onready var preview_frame: PanelContainer = $VBoxContainer/PreviewFrame
@onready var preview: TextureRect = $VBoxContainer/PreviewFrame/TextureRect
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var previous_button: Button = $VBoxContainer/HBoxContainer/PreviousButton
@onready var next_button: Button = $VBoxContainer/HBoxContainer/NextButton
@onready var play_button: Button = $VBoxContainer/HBoxContainer/PlayButton

func _ready() -> void:
	world_sim = get_tree().root.find_child("WorldSim", true, false) as WorldSim
	assert(world_sim != null)

	_setup_preview_frame()

	previous_button.pressed.connect(previous_level)
	next_button.pressed.connect(next_level)
	play_button.pressed.connect(load_level)

	update_ui()


func _setup_preview_frame() -> void:
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


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
