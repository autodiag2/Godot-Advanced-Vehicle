extends Control

var world_sim: WorldSim
var current_level := 0

@onready var preview: TextureRect = $VBoxContainer/Preview
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var previous_button: Button = $VBoxContainer/HBoxContainer/PreviousButton
@onready var next_button: Button = $VBoxContainer/HBoxContainer/NextButton
@onready var play_button: Button = $VBoxContainer/HBoxContainer/PlayButton

func _ready() -> void:
	world_sim = get_tree().root.find_child("WorldSim", true, false) as WorldSim
	assert(world_sim != null)

	previous_button.pressed.connect(previous_level)
	next_button.pressed.connect(next_level)
	play_button.pressed.connect(load_level)

	update_ui()

func update_ui() -> void:
	var levels := world_sim.world_scenes

	if levels.is_empty():
		level_label.text = "No levels found"
		preview.texture = null
		previous_button.disabled = true
		next_button.disabled = true
		play_button.disabled = true
		return

	var world := levels[current_level].instantiate()

	level_label.text = world.get("level_name") if "level_name" in world else levels[current_level].resource_path.get_base_dir().get_file()
	preview.texture = world.get("preview") if "preview" in world else null

	world.free()

	previous_button.disabled = current_level == 0
	next_button.disabled = current_level >= levels.size() - 1
	play_button.disabled = false

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
