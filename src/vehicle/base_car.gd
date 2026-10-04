class_name BaseCar
extends RigidBody3D

@export var car_params := CarParameters.new()
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

func _ready() -> void:
	add_to_group("player_car")

	car_params.wheel_params_fl.ackermann = (
		car_params.ackermann
	)

	car_params.wheel_params_fr.ackermann = (
		-car_params.ackermann
	)

	wheel_fl.set_params(
		car_params.wheel_params_fl.duplicate(true)
	)

	wheel_fr.set_params(
		car_params.wheel_params_fr.duplicate(true)
	)

	wheel_bl.set_params(
		car_params.wheel_params_bl.duplicate(true)
	)

	wheel_br.set_params(
		car_params.wheel_params_br.duplicate(true)
	)

	brake_controller.setup(
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br
	)

	engine_controller.initialize(
		car_params,
		self,
		engine_starter_controller,
		$EngineSound
	)
	engine_controller.add_listener(engine_starter_controller)

	powertrain_controller.initialize(
		car_params,
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br
	)

	motion_controller.initialize(
		self
	)

func start():
	engine_starter_controller.start()

func stop():
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ShiftUp"):
		shift_up()

	if event.is_action_pressed("ShiftDown"):
		shift_down()


func _physics_process(delta: float) -> void:
	print("START wheel sping = " + str(wheel_bl.wheel.get_spin()))
	input_controller.update(
		joystick
	)

	brake_controller.update(
		input_controller.brake,
		input_controller.handbrake,
		car_params,
		delta
	)

	motion_controller.update(
		self,
		delta
	)

	steering_controller.update(
		input_controller.steering,
		car_params.steer_speed,
		delta
	)

	steering_controller.apply_to_wheels(
		wheel_fl,
		wheel_fr,
		car_params.max_steer
	)

	engine_controller.update(
		car_params,
		input_controller.throttle,
		delta
	)

	powertrain_controller.update_automatic_shifting(
		engine_controller,
		input_controller.throttle,
		input_controller.brake,
		motion_controller.longitudinal_velocity,
		car_params
	)

	suspension.apply_forces(
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br,
		delta
	)

	print("MIDDLE wheel spin = " + str(wheel_bl.wheel.get_spin()))

	powertrain_controller.update(
		engine_controller,
		car_params,
		input_controller.clutch,
		delta
	)
	print("MIDDLE2 wheel spin = " + str(wheel_bl.wheel.get_spin()))

	engine_controller.reaction_torque = (
		powertrain_controller.clutch_reaction_torque
	)
	print("MIDDLE3 wheel spin = " + str(wheel_bl.wheel.get_spin()))

	engine_controller.clamp_to_idle(
		car_params
	)
	print("MIDDLE4 wheel spin = " + str(wheel_bl.wheel.get_spin()))

	engine_controller.consume_fuel(
		car_params,
		self,
		delta
	)
	print("MIDDLE5 wheel spin = " + str(wheel_bl.wheel.get_spin()))

	motion_controller.apply_aerodynamic_drag(
		self,
		car_params
	)
	print("END wheel sping = " + str(wheel_bl.wheel.get_spin()))

func getSpeedKmH() -> int:
	return int(motion_controller.longitudinal_velocity *
		MPS_TO_KPH
	)


func shift_up() -> void:
	powertrain_controller.drivetrain.shift_up()


func shift_down() -> void:
	powertrain_controller.drivetrain.shift_down()
