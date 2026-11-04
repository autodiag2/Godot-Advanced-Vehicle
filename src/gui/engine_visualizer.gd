
class_name EngineVisualizer
extends Window

var vehicle: BaseCar
var simulator: EngineSimulator
var engine_parameters: EngineParameters

@onready var identity_label: Label = $Frame/Content/Telemetry/Identity
@onready var rpm_label: Label = $Frame/Content/Telemetry/RPM
@onready var torque_label: Label = $Frame/Content/Telemetry/Torque
@onready var pressure_label: Label = $Frame/Content/Telemetry/Pressure
@onready var engine_cutaway: EngineCutaway = $Frame/Content/ViewportContainer/ViewportMargin/EngineViewport/EngineViewport/EngineCutaway


func _ready() -> void:
	title = "Engine Laboratory"
	min_size = Vector2i(860, 650)
	size = Vector2i(1100, 850)
	always_on_top = true
	transient = true
	exclusive = false
	popup_window = false
	unresizable = false
	$Frame/Content/Heading/CloseButton.pressed.connect(_on_close)
	close_requested.connect(_on_close)
	$ResizeGrip.gui_input.connect(_on_resize_grip_input)
	$Frame/Content/Heading.gui_input.connect(_on_heading_input)
	_update_engine()


func set_vehicle(value: BaseCar) -> void:
	vehicle = value
	simulator = vehicle.engine_controller.simulator
	engine_parameters = vehicle.engine_controller.engine_parameters
	_update_engine()


func _process(_delta: float) -> void:
	if simulator == null or engine_parameters == null:
		return

	var maximum_pressure := 0.0
	for cylinder_index in range(engine_parameters.cylinder_count):
		maximum_pressure = maxf(
			maximum_pressure,
			simulator.get_cylinder_pressure_kpa(cylinder_index)
		)

	var fuel_name := "GASOLINE"
	if engine_parameters.fuel_type == EngineParameters.FuelType.DIESEL:
		fuel_name = "DIESEL / GASOIL"
	var displacement_l := (
		PI *
		pow(engine_parameters.bore_mm, 2.0) *
		0.25 *
		engine_parameters.stroke_mm *
		float(engine_parameters.cylinder_count) /
		1000000.0
	)

	identity_label.text = "%s   ·   INLINE %d   ·   %.2f L" % [
		fuel_name,
		engine_parameters.cylinder_count,
		displacement_l,
	]
	rpm_label.text = "RPM\n%d" % int(simulator.rpm)
	torque_label.text = "CRANK TORQUE\n%.0f N·m" % simulator.output_torque
	pressure_label.text = "PEAK CYLINDER\n%.1f bar" % (maximum_pressure / 100.0)


func _update_engine() -> void:
	if simulator == null or engine_parameters == null or engine_cutaway == null:
		return
	engine_cutaway.configure(simulator, engine_parameters)


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
