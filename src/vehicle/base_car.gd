class_name BaseCar
extends RigidBody3D

@export var parameters := CarParameters.new()
var joystick: Control
const MPS_TO_KPH: float = 3.6

######## CONSTANTS ########

var input_controller := CarInputController.new()
var steering_controller := SteeringController.new()
var brake_controller := BrakeController.new()
var engine_controller := EngineController.new()
var engine_starter_controller := EngineStarterController.new()
var powertrain_controller := PowertrainController.new()
var suspension := SuspensionSystemController.new()
var motion_controller := VehicleMotionController.new()

@onready var wheel_fl = $Wheel_fl as RaycastSuspension
@onready var wheel_fr = $Wheel_fr as RaycastSuspension
@onready var wheel_bl = $Wheel_bl as RaycastSuspension
@onready var wheel_br = $Wheel_br as RaycastSuspension

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

	brake_controller.setup(
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br
	)

	engine_controller.initialize(
		parameters,
		self,
		engine_starter_controller,
		$EngineSound
	)

	powertrain_controller.initialize(
		parameters,
		engine_controller,
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br
	)

func _ready() -> void:
	add_to_group("player_car")
	engine_controller.add_listener(engine_starter_controller)

	motion_controller.initialize(
		self
	)
	
	set_parameters(parameters)

func start():
	engine_starter_controller.start()

func stop():
	engine_controller.stop()

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

	powertrain_controller.update_automatic_shifting(
		input_controller.throttle,
		input_controller.brake,
		motion_controller.longitudinal_velocity
	)

	suspension.apply_forces(
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br,
		delta
	)

	powertrain_controller.apply(
		input_controller.throttle,
		input_controller.clutch,
		delta,
		self
	)

	engine_controller.reaction_torque = (
		powertrain_controller.clutch_reaction_torque
	)

	motion_controller.apply_aerodynamic_drag(
		self,
		parameters
	)

func getSpeedKmH() -> int:
	return int(motion_controller.longitudinal_velocity *
		MPS_TO_KPH
	)


func shift_up() -> void:
	powertrain_controller.drivetrain.gearbox.shift_up()


func shift_down() -> void:
	powertrain_controller.drivetrain.gearbox.shift_down()
