extends Control

const ENGINE_BUBBLE_SCENE: PackedScene = preload("res://assets/ui/engine_bubble.tscn")
const SPEED_CONTROL_SCENE: PackedScene = preload("res://assets/ui/speed_control_bubble.tscn")
const WHEELS_BUBBLE_SCENE: PackedScene = preload("res://assets/ui/wheels_bubble.tscn")
const COCKPIT_TEXTURE: Texture2D = preload("res://assets/ui/cockpit_hud.png")

@onready var TireInfoApp = $TireInfoApp
@onready var automatic_transmission = $Menu/VBoxContainer/MarginContainer/VBoxContainer/automatic_transmission
@onready var engine_button: TouchScreenButton = $HBoxContainer/EngineButton
@onready var speed_button: TouchScreenButton = $HBoxContainer/SpeedButton
@onready var wheels_button: TouchScreenButton = $HBoxContainer/WheelsButton

var vehicle: BaseCar
var engine_popup: EngineVisualizer
var speed_popup: SpeedControlVisualizer
var wheels_popup: WheelsVisualizer
var cockpit_root: Control
var cockpit_readouts: Array[Dictionary] = []
var rpm_value_label: Label
var fuel_value_label: Label
var speed_value_label: Label
var gear_value_label: Label


func _ready() -> void:
	_create_cockpit_hud()
	get_viewport().size_changed.connect(_layout_cockpit_hud)
	engine_popup = ENGINE_BUBBLE_SCENE.instantiate() as EngineVisualizer
	add_child(engine_popup)
	engine_popup.hide()
	speed_popup = SPEED_CONTROL_SCENE.instantiate() as SpeedControlVisualizer
	add_child(speed_popup)
	speed_popup.hide()
	wheels_popup = WHEELS_BUBBLE_SCENE.instantiate() as WheelsVisualizer
	add_child(wheels_popup)
	wheels_popup.hide()
	engine_button.pressed.connect(_show_engine_popup)
	speed_button.pressed.connect(_show_speed_popup)
	wheels_button.pressed.connect(_show_wheels_popup)


func _create_cockpit_hud() -> void:
	cockpit_root = Control.new()
	cockpit_root.name = "CockpitHUD"
	cockpit_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cockpit_root.z_index = 8
	add_child(cockpit_root)

	var background := TextureRect.new()
	background.texture = COCKPIT_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cockpit_root.add_child(background)

	rpm_value_label = _add_cockpit_readout(
		"RPM",
		"0000",
		Vector2(0.255, 0.59),
		Vector2(0.19, 0.22),
		0.012,
		0.024
	)
	speed_value_label = _add_cockpit_readout(
		"SPEED",
		"000 km/h",
		Vector2(0.538, 0.59),
		Vector2(0.23, 0.22),
		0.012,
		0.025
	)
	fuel_value_label = _add_cockpit_readout(
		"FUEL",
		"100%",
		Vector2(0.765, 0.61),
		Vector2(0.15, 0.20),
		0.011,
		0.020
	)
	gear_value_label = _add_cockpit_readout(
		"GEAR",
		"N",
		Vector2(0.39, 0.785),
		Vector2(0.09, 0.15),
		0.010,
		0.027
	)
	_layout_cockpit_hud()


func _add_cockpit_readout(
	heading: String,
	initial_value: String,
	center: Vector2,
	extent: Vector2,
	heading_font_ratio: float,
	value_font_ratio: float
) -> Label:
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	cockpit_root.add_child(stack)

	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color(0.72, 0.82, 0.91))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack.add_child(title)

	var value := Label.new()
	value.text = initial_value
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	value.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	value.add_theme_constant_override("shadow_offset_x", 2)
	value.add_theme_constant_override("shadow_offset_y", 2)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack.add_child(value)

	cockpit_readouts.append({
		"container": stack,
		"center": center,
		"extent": extent,
		"title": title,
		"value": value,
		"heading_font_ratio": heading_font_ratio,
		"value_font_ratio": value_font_ratio,
	})
	return value


func _layout_cockpit_hud() -> void:
	if not is_instance_valid(cockpit_root):
		return
	var viewport_size := get_viewport_rect().size
	var width := minf(viewport_size.x * 0.98, 1100.0)
	var height := width * 341.0 / 1024.0
	cockpit_root.position = Vector2(
		(viewport_size.x - width) * 0.5,
		viewport_size.y - height
	)
	cockpit_root.size = Vector2(width, height)

	for readout in cockpit_readouts:
		var box_size: Vector2 = readout.extent * Vector2(width, height)
		var center: Vector2 = readout.center * Vector2(width, height)
		var stack: VBoxContainer = readout.container
		stack.position = center - box_size * 0.5
		stack.size = box_size
		readout.title.add_theme_font_size_override(
			"font_size",
			maxi(9, int(width * float(readout.heading_font_ratio)))
		)
		readout.value.add_theme_font_size_override(
			"font_size",
			maxi(12, int(width * float(readout.value_font_ratio)))
		)


func set_vehicle(value: BaseCar) -> void:
	assert(value != null)
	vehicle = value
	automatic_transmission.onSetVehicle(vehicle)
	if is_instance_valid(engine_popup):
		engine_popup.set_vehicle(vehicle)
	if is_instance_valid(wheels_popup):
		wheels_popup.set_vehicle(vehicle)


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var speed_kmh := vehicle.getSpeedKmH()
	var rpm := vehicle.engine_controller.rpm
	var fuel_capacity := maxf(vehicle.car_params.fuel_tank_size, 0.01)
	var fuel_fraction := clampf(
		vehicle.engine_controller.fuel_litres / fuel_capacity,
		0.0,
		1.0
	)
	var selected_gear := vehicle.powertrain_controller.drivetrain.selected_gear

	rpm_value_label.text = "%04d" % int(rpm)
	speed_value_label.text = "%03d km/h" % int(speed_kmh)
	fuel_value_label.text = "%d%%" % int(round(fuel_fraction * 100.0))
	if selected_gear < 0:
		gear_value_label.text = "R"
	elif selected_gear == 0:
		gear_value_label.text = "N"
	else:
		gear_value_label.text = str(selected_gear)


func _show_engine_popup() -> void:
	if vehicle == null:
		return
	engine_popup.set_vehicle(vehicle)
	engine_popup.present()


func _show_speed_popup() -> void:
	speed_popup.present()


func _show_wheels_popup() -> void:
	if vehicle == null:
		return
	wheels_popup.set_vehicle(vehicle)
	wheels_popup.present()
