class_name Vehicle
extends RigidBody3D

@export var parameters := CarParameters.new()
var joystick: Control
const MPS_TO_KPH: float = 3.6

######## CONSTANTS ########

var input_controller := CarInputController.new()
var steering_controller := SteeringController.new()
var brake_controller := BrakeController.new()
var engine := EngineController.new()
var powertrain := PowertrainController.new()
var suspension := SuspensionSystemController.new()
var motion_controller := VehicleMotionController.new()

@onready var wheel_fl = $Wheel_fl as RaycastSuspension
@onready var wheel_fr = $Wheel_fr as RaycastSuspension
@onready var wheel_bl = $Wheel_bl as RaycastSuspension
@onready var wheel_br = $Wheel_br as RaycastSuspension

func set_print_debug(state: bool):
	engine.controller_debug_print_enabled = state
	engine.starter.parent.controller_debug_print_enabled = state
	powertrain.controller_debug_print_enabled = state
	powertrain.drivetrain.controller_debug_print_enabled = state
	powertrain.drivetrain.differential.controller_debug_print_enabled = state
	powertrain.drivetrain.gearbox.controller_debug_print_enabled = state
	for wheel in [wheel_bl, wheel_br, wheel_fl, wheel_fr]:
		wheel.parent.controller_debug_print_enabled = state
		wheel.wheel.controller_debug_print_enabled = state
		wheel.dynamics.controller_debug_print_enabled = state

func spawn():
	for wheel in [wheel_bl,wheel_br, wheel_fl, wheel_fr]:
		wheel.spawn()

func set_joystick(value: Control) -> void:
	joystick = value

func getBrakePadsUsagePercent() -> Array:
	return [
		wheel_fl.brake_disc.inner_pad.usage,
		wheel_fr.brake_disc.inner_pad.usage,
		wheel_bl.brake_disc.inner_pad.usage,
		wheel_br.brake_disc.inner_pad.usage
	]

func set_parameters(parameters_arg: CarParameters):
	parameters = parameters_arg
	parameters.wheel_params_fl.ackermann = (
		parameters.ackermann
	)

	parameters.wheel_params_fr.ackermann = (
		-parameters.ackermann
	)

	wheel_fl.set_params(
		parameters.wheel_params_fl.duplicate(true)
	)

	wheel_fr.set_params(
		parameters.wheel_params_fr.duplicate(true)
	)

	wheel_bl.set_params(
		parameters.wheel_params_bl.duplicate(true)
	)

	wheel_br.set_params(
		parameters.wheel_params_br.duplicate(true)
	)

	brake_controller.setup(powertrain)

	engine.initialize(
		parameters,
		self,
		$EngineSound
	)

	powertrain.initialize(
		parameters,
		engine,
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br
	)

func _ready() -> void:
	add_to_group("player_car")

	motion_controller.initialize(
		self
	)
	
	set_parameters(parameters)

func start():
	engine.start()

func stop():
	engine.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ShiftUp"):
		shift_up()

	if event.is_action_pressed("ShiftDown"):
		shift_down()


func _physics_process(delta: float) -> void:
	input_controller.update(
		joystick
	)

	brake_controller.update(
		input_controller.brake,
		input_controller.handbrake,
		parameters,
		delta
	)

	motion_controller.update(
		self,
		delta
	)

	steering_controller.update(
		input_controller.steering,
		parameters.steer_speed,
		delta
	)

	steering_controller.apply_to_wheels(
		wheel_fl,
		wheel_fr,
		parameters.max_steer
	)

	powertrain.tcu.update(
		input_controller.throttle,
		input_controller.brake,
		motion_controller.longitudinal_velocity,
		delta
	)

	suspension.apply_forces(
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br,
		delta
	)

	powertrain.apply(
		input_controller.throttle,
		input_controller.clutch,
		delta
	)

	motion_controller.apply_aerodynamic_drag(
		self,
		parameters
	)

func getSpeedKmH() -> int:
	return int(-linear_velocity.z * MPS_TO_KPH)

func shift_up() -> void:
	powertrain.drivetrain.gearbox.shift_up()

func shift_down() -> void:
	powertrain.drivetrain.gearbox.shift_down()
