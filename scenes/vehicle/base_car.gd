class_name BaseCar
extends RigidBody3D

@export var car_params := CarParameters.new()
@export var joystick: Control
const MPS_TO_KPH: float = 3.6

######## CONSTANTS ########

var input_controller := CarInputController.new()
var steering_controller := SteeringController.new()
var brake_controller := BrakeController.new()
var engine_controller := EngineController.new()
var powertrain_controller := PowertrainController.new()
var suspension := SuspensionSystemController.new()
var motion_controller := VehicleMotionController.new()

@onready var wheel_fl = $Wheel_fl as RaycastSuspension
@onready var wheel_fr = $Wheel_fr as RaycastSuspension
@onready var wheel_bl = $Wheel_bl as RaycastSuspension
@onready var wheel_br = $Wheel_br as RaycastSuspension
@onready var engine_audio_player = $EngineSound


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
		self
	)

	powertrain_controller.initialize(
		car_params
	)

	motion_controller.initialize(
		self
	)


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

	powertrain_controller.update_wheel_speeds(
		wheel_fl,
		wheel_fr,
		wheel_bl,
		wheel_br
	)

	engine_controller.reaction_torque = (
		powertrain_controller.clutch_reaction_torque
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

	if powertrain_controller.drivetrain.selected_gear == 0:
		powertrain_controller.freewheel(
			wheel_fl,
			wheel_fr,
			wheel_bl,
			wheel_br,
			brake_controller.front_left_brake_torque,
			brake_controller.front_right_brake_torque,
			brake_controller.rear_left_brake_torque,
			brake_controller.rear_right_brake_torque,
			delta
		)
	else:
		powertrain_controller.engage(
			engine_controller,
			car_params,
			input_controller.clutch,
			wheel_fl,
			wheel_fr,
			wheel_bl,
			wheel_br,
			brake_controller.front_left_brake_torque,
			brake_controller.front_right_brake_torque,
			brake_controller.rear_left_brake_torque,
			brake_controller.rear_right_brake_torque,
			delta
		)

	engine_controller.clamp_to_idle(
		car_params
	)

	engine_controller.consume_fuel(
		car_params,
		self,
		delta
	)

	if engine_controller.fuel_litres <= 0.0:
		engine_controller.fuel_litres = 0.0
		engine_controller.output_torque = 0.0
		engine_controller.rpm = 0.0
		engine_controller.stop_sound(
			engine_audio_player
		)
	else:
		engine_controller.update_sound(
			car_params,
			engine_audio_player
		)

	motion_controller.apply_aerodynamic_drag(
		self,
		car_params
	)


func getSpeedKmH() -> int:
	return int(motion_controller.longitudinal_velocity *
		MPS_TO_KPH
	)


func shift_up() -> void:
	powertrain_controller.drivetrain.shift_up()


func shift_down() -> void:
	powertrain_controller.drivetrain.shift_down()
