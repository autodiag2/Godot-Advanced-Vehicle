class_name WheelsVisualizer
extends Window

const WHEEL_NAMES := [
	"FRONT LEFT",
	"FRONT RIGHT",
	"REAR LEFT",
	"REAR RIGHT",
]
const WHEEL_SHORT_NAMES := ["FL", "FR", "RL", "RR"]

var vehicle: BaseCar
var wheels: Array[RaycastSuspension] = []
var selected_wheel_index: int = 0
var wheel_buttons: Array[Button] = []
var wheel_button_styles: Array[StyleBoxFlat] = []

@onready var main_content: BoxContainer = $Frame/Content/MainContent
@onready var wheel_title: Label = $Frame/Content/MainContent/DetailsPanel/DetailsMargin/Details/WheelTitle
@onready var condition_label: Label = $Frame/Content/MainContent/DetailsPanel/DetailsMargin/Details/ConditionLabel
@onready var wear_label: Label = $Frame/Content/MainContent/DetailsPanel/DetailsMargin/Details/WearLabel
@onready var temperature_label: Label = $Frame/Content/MainContent/DetailsPanel/DetailsMargin/Details/TemperatureLabel
@onready var temperature_bar: ColorRect = $Frame/Content/MainContent/DetailsPanel/DetailsMargin/Details/TemperatureBar
@onready var statistics_label: Label = $Frame/Content/MainContent/DetailsPanel/DetailsMargin/Details/StatisticsLabel


func _ready() -> void:
	title = "Wheel Management"
	min_size = Vector2i(320, 280)
	size = Vector2i(940, 660)
	always_on_top = true
	transient = true
	exclusive = false
	popup_window = false
	borderless = true
	wheel_buttons = [
		$Frame/Content/MainContent/DiagramPanel/DiagramMargin/Diagram/FrontRow/FrontLeft,
		$Frame/Content/MainContent/DiagramPanel/DiagramMargin/Diagram/FrontRow/FrontRight,
		$Frame/Content/MainContent/DiagramPanel/DiagramMargin/Diagram/RearRow/RearLeft,
		$Frame/Content/MainContent/DiagramPanel/DiagramMargin/Diagram/RearRow/RearRight,
	]
	for index in range(wheel_buttons.size()):
		wheel_buttons[index].pressed.connect(_select_wheel.bind(index))
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_left = 8.0
		style.content_margin_top = 8.0
		style.content_margin_right = 8.0
		style.content_margin_bottom = 8.0
		wheel_button_styles.append(style)
		for state in ["normal", "hover", "pressed", "focus"]:
			wheel_buttons[index].add_theme_stylebox_override(state, style)
		wheel_buttons[index].add_theme_font_size_override("font_size", 15)
		wheel_buttons[index].add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
		wheel_buttons[index].add_theme_color_override("font_hover_color", Color.WHITE)
	$Frame/Content/Heading/CloseButton.pressed.connect(_on_close)
	$Frame/Content/Footer/ReplaceSelectedButton.pressed.connect(_replace_selected_wheel)
	$Frame/Content/Footer/ReplaceAllButton.pressed.connect(_replace_all_wheels)
	close_requested.connect(_on_close)
	$ResizeGrip.gui_input.connect(_on_resize_grip_input)
	$Frame/Content/Heading.gui_input.connect(_on_heading_input)
	_refresh_display()


func set_vehicle(value: BaseCar) -> void:
	vehicle = value
	wheels.clear()
	if vehicle == null:
		_refresh_display()
		return
	wheels.append(vehicle.wheel_fl)
	wheels.append(vehicle.wheel_fr)
	wheels.append(vehicle.wheel_bl)
	wheels.append(vehicle.wheel_br)
	selected_wheel_index = clampi(selected_wheel_index, 0, wheels.size() - 1)
	_refresh_display()


func present() -> void:
	if not visible:
		var available_size := get_tree().root.size
		var mobile_layout := OS.has_feature("mobile") or available_size.x < 760
		var target_size := Vector2i(
			maxi(300, mini(940, int(float(available_size.x) * 0.96))),
			maxi(280, mini(660, int(float(available_size.y) * 0.92)))
		)
		min_size = Vector2i(
			mini(720, target_size.x),
			mini(520, target_size.y)
		)
		size = target_size
		unresizable = mobile_layout
		$ResizeGrip.visible = not mobile_layout
		main_content.vertical = target_size.x < 680
		if mobile_layout:
			$Frame/Content/Footer/HelpLabel.text = "Select a wheel, then replace it or reset all four."
		popup_centered()
	grab_focus()


func _process(_delta: float) -> void:
	if visible:
		_refresh_display()


func _refresh_display() -> void:
	if not is_node_ready():
		return
	for index in range(wheel_buttons.size()):
		var button := wheel_buttons[index]
		if index >= wheels.size() or not is_instance_valid(wheels[index]):
			button.text = "%s\n—" % WHEEL_SHORT_NAMES[index]
			button.disabled = true
			continue
		button.disabled = false
		var wheel := wheels[index]
		var wear := clampf(wheel.tire_wear, 0.0, 1.0)
		var condition_color := Color(0.12, 0.78, 0.24).lerp(
			Color(0.88, 0.12, 0.10),
			wear
		)
		button.text = "%s\n%.0f%%" % [
			WHEEL_SHORT_NAMES[index],
			(1.0 - wear) * 100.0,
		]
		wheel_button_styles[index].bg_color = condition_color
		wheel_button_styles[index].border_color = (
			Color(0.55, 0.84, 1.0)
			if index == selected_wheel_index
			else Color(0.12, 0.18, 0.25)
		)
		wheel_button_styles[index].set_border_width_all(
			3 if index == selected_wheel_index else 1
		)
	if wheels.is_empty() or selected_wheel_index >= wheels.size():
		wheel_title.text = "NO VEHICLE"
		condition_label.text = "CONDITION  —"
		wear_label.text = "TREAD WEAR  —"
		temperature_label.text = "TEMPERATURE  —"
		temperature_bar.color = Color(0.15, 0.2, 0.27)
		statistics_label.text = "Wheel telemetry is unavailable."
		return
	var wheel := wheels[selected_wheel_index]
	if not is_instance_valid(wheel) or wheel.tire_model == null:
		return
	var tire_model := wheel.tire_model
	var wear := clampf(wheel.tire_wear, 0.0, 1.0)
	var condition := 1.0 - wear
	var temperature := tire_model.tire_temp
	wheel_title.text = "%s  ·  %s" % [
		WHEEL_NAMES[selected_wheel_index],
		WHEEL_SHORT_NAMES[selected_wheel_index],
	]
	condition_label.text = "CONDITION     %.1f%%" % (condition * 100.0)
	wear_label.text = "TREAD WEAR    %.1f%%" % (wear * 100.0)
	temperature_label.text = "TEMPERATURE   %.1f °C" % temperature
	temperature_bar.color = _temperature_color(tire_model)
	statistics_label.text = (
		"TIRE WIDTH       %.0f mm\n" +
		"TIRE RADIUS      %.0f mm\n" +
		"WHEEL SPEED      %.0f rpm\n" +
		"NORMAL LOAD      %.0f N\n" +
		"LATERAL SLIP     %.1f%%\n" +
		"LONGITUDINAL SLIP %.1f%%"
	) % [
		wheel.tire_width * 1000.0,
		wheel.tire_radius * 1000.0,
		wheel.spin * 60.0 / TAU,
		wheel.y_force,
		absf(wheel.slip_vec.x) * 100.0,
		absf(wheel.slip_vec.y) * 100.0,
	]


func _temperature_color(tire_model: BaseTireModel) -> Color:
	if tire_model.tire_temp < tire_model.opt_tire_temp:
		return Color.AQUA.lerp(
			Color.GREEN,
			clampf(
				tire_model.tire_temp / maxf(tire_model.opt_tire_temp, 0.01),
				0.0,
				1.0
			)
		)
	var amount := (
		tire_model.tire_temp - tire_model.opt_tire_temp
	) / maxf(
		tire_model.max_tire_temp - tire_model.opt_tire_temp,
		0.01
	)
	return Color.GREEN.lerp(Color.FIREBRICK, clampf(amount, 0.0, 1.0))


func _select_wheel(index: int) -> void:
	if index < 0 or index >= wheels.size():
		return
	selected_wheel_index = index
	_refresh_display()


func _replace_selected_wheel() -> void:
	if selected_wheel_index >= 0 and selected_wheel_index < wheels.size():
		var wheel := wheels[selected_wheel_index]
		if is_instance_valid(wheel):
			wheel.replace_tire()
	_refresh_display()


func _replace_all_wheels() -> void:
	for wheel in wheels:
		if is_instance_valid(wheel):
			wheel.replace_tire()
	_refresh_display()


func _on_close() -> void:
	hide()


func _on_heading_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_drag()
	elif event is InputEventScreenTouch and event.pressed:
		start_drag()


func _on_resize_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_resize(DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT)
	elif event is InputEventScreenTouch and event.pressed:
		start_resize(DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT)
