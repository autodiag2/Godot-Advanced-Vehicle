class_name BaseCar
extends RigidBody3D

@export var car_params := CarParameters.new()
var joystick: Control
const MPS_TO_KPH: float = 3.6

class CarInputController:
	extends RefCounted

	var throttle: float = 0.0
	var steering: float = 0.0
	var brake: float = 0.0
	var handbrake: bool = false
	var clutch: float = 0.0

	func update(input_joystick: Control) -> void:
		var joystick_output := Vector2.ZERO

		if input_joystick:
			joystick_output = input_joystick.scene.output

		steering = -joystick_output.x

		if joystick_output.y < 0.0:
			throttle = -joystick_output.y
			brake = 0.0
		else:
			throttle = 0.0
			brake = joystick_output.y

		handbrake = Input.is_action_pressed("Handbrake")
		clutch = Input.get_action_strength("Clutch")


class SteeringController:
	extends RefCounted

	var steering_angle: float = 0.0

	func update(
		target_steering: float,
		steering_speed: float,
		delta: float
	) -> void:
		if target_steering < steering_angle:
			steering_angle -= steering_speed * delta

			if target_steering > steering_angle:
				steering_angle = target_steering

		elif target_steering > steering_angle:
			steering_angle += steering_speed * delta

			if target_steering < steering_angle:
				steering_angle = target_steering

	func apply_to_wheels(
		front_left_wheel: RaycastSuspension,
		front_right_wheel: RaycastSuspension,
		max_steering_angle: float
	) -> void:
		front_left_wheel.steer(
			steering_angle,
			max_steering_angle
		)

		front_right_wheel.steer(
			steering_angle,
			max_steering_angle
		)


class BrakeController:
	extends RefCounted

	var front_brake_torque: float = 0.0
	var rear_brake_torque: float = 0.0

	func update(
		brake_input: float,
		handbrake_pressed: bool,
		parameters: CarParameters,
		delta: float
	) -> void:
		var brake_torques := calculate_brake_torques(
			brake_input,
			parameters
		)

		front_brake_torque = brake_torques.x
		rear_brake_torque = brake_torques.y

		if handbrake_pressed:
			rear_brake_torque += parameters.max_handbrake_torque

	func calculate_brake_torques(
		brake_input: float,
		parameters: CarParameters
	) -> Vector2:
		var clamping_force := (
			brake_input *
			parameters.max_brake_force *
			0.5
		)

		var brake_pad_friction := 0.4
		var braking_force: float = (
			2.0 *
			brake_pad_friction *
			clamping_force
		)

		var brake_torques := Vector2.ZERO

		brake_torques.x = (
			braking_force *
			parameters.brake_effective_radius *
			parameters.front_brake_bias
		)

		brake_torques.y = (
			braking_force *
			parameters.brake_effective_radius *
			(
				1.0 -
				parameters.front_brake_bias
			)
		)

		return brake_torques


class EngineController:
	extends RefCounted

	const PETROL_KG_PER_LITRE: float = 0.7489
	const RPM_PER_RADIAN_PER_SECOND: float = 60.0 / TAU
	const NEWTON_METRE_RPM_TO_KW: int = 9549

	var rpm: float = 0.0
	var angular_velocity: float = 0.0
	var output_torque: float = 0.0
	var net_torque: float = 0.0
	var reaction_torque: float = 0.0
	var fuel_litres: float = 0.0

	func initialize(
		parameters: CarParameters,
		car: RigidBody3D
	) -> void:
		fuel_litres = (
			parameters.fuel_tank_size *
			parameters.fuel_percentage *
			0.01
		)

		car.mass += (
			fuel_litres *
			PETROL_KG_PER_LITRE
		)

	func update(
		parameters: CarParameters,
		throttle_input: float,
		delta: float
	) -> void:
		output_torque = calculate_torque(
			rpm,
			throttle_input,
			parameters
		)

		net_torque = (
			output_torque +
			reaction_torque
		)

		rpm += (
			RPM_PER_RADIAN_PER_SECOND *
			delta *
			net_torque /
			parameters.engine_moment
		)

		angular_velocity = (
			rpm /
			RPM_PER_RADIAN_PER_SECOND
		)

		if rpm >= parameters.max_engine_rpm:
			output_torque = 0.0
			rpm -= 500.0

	func calculate_torque(
		engine_rpm: float,
		throttle_input: float,
		parameters: CarParameters
	) -> float:
		var rpm_factor: float = clamp(
			engine_rpm /
			parameters.max_engine_rpm,
			0.0,
			1.0
		)

		var torque_curve_factor: float = (
			parameters.torque_curve.sample_baked(
				rpm_factor
			)
		)

		var engine_braking_torque: float = (
			-parameters.engine_brake *
			rpm_factor
		)

		var maximum_torque: float = (
			torque_curve_factor *
			parameters.max_torque
		)

		var throttle_factor := (
			parameters.throttle_model.sample_baked(
				throttle_input
			)
		)

		return lerpf(
			engine_braking_torque,
			maximum_torque,
			throttle_factor
		)

	func clamp_to_idle(parameters: CarParameters) -> void:
		rpm = max(
			rpm,
			parameters.rpm_idle
		)

	func consume_fuel(
		parameters: CarParameters,
		car: RigidBody3D,
		delta: float
	) -> void:
		var fuel_consumed: float = (
			parameters.engine_bsfc *
			max(output_torque, 0.0) *
			rpm *
			delta /
			(
				3600.0 *
				PETROL_KG_PER_LITRE *
				NEWTON_METRE_RPM_TO_KW
			)
		)

		fuel_consumed = min(
			fuel_consumed,
			fuel_litres
		)

		fuel_consumed = max(
			fuel_consumed,
			0.0
		)

		fuel_litres -= fuel_consumed

		car.mass -= (
			fuel_consumed *
			PETROL_KG_PER_LITRE
		)

	func update_sound(
		parameters: CarParameters,
		audio_player: AudioStreamPlayer
	) -> void:
		var pitch_scale: float = rpm / 1000.0

		if (
			rpm >= parameters.rpm_idle &&
			rpm < parameters.max_engine_rpm
		):
			if audio_player.stream != parameters.engine_sound:
				audio_player.set_stream(
					parameters.engine_sound
				)

			if !audio_player.playing:
				audio_player.play()

		if pitch_scale > 0.1:
			audio_player.pitch_scale = pitch_scale

	func stop_sound(
		audio_player: AudioStreamPlayer
	) -> void:
		audio_player.stop()


class PowertrainController:
	extends RefCounted

	var drivetrain := DriveTrain.new()
	var clutch := Clutch.new()

	var clutch_reaction_torque: float = 0.0
	var wheel_drive_torque: float = 0.0

	var average_front_wheel_speed: float = 0.0
	var average_rear_wheel_speed: float = 0.0

	func initialize(parameters: CarParameters) -> void:
		clutch.friction = parameters.clutch_friction

		drivetrain.drivetrain_params = (
			parameters.drivetrain_params
		)

		drivetrain.set_input_inertia(
			parameters.engine_moment
		)

	func update_automatic_shifting(
		engine: EngineController,
		throttle_input: float,
		brake_input: float,
		longitudinal_speed: float,
		parameters: CarParameters
	) -> void:
		var driven_wheel_speed := average_front_wheel_speed

		if (
			parameters.drivetrain_params.drivetype ==
			parameters.drivetrain_params.DRIVE_TYPE.RWD
		):
			driven_wheel_speed = average_rear_wheel_speed

		elif (
			parameters.drivetrain_params.drivetype ==
			parameters.drivetrain_params.DRIVE_TYPE.AWD
		):
			driven_wheel_speed = (
				average_front_wheel_speed +
				average_rear_wheel_speed
			) * 0.5

		var next_gear_rpm := 0.0
		var previous_gear_rpm := 0.0

		var next_gear := drivetrain.selected_gear + 1
		var previous_gear := drivetrain.selected_gear - 1

		if (
			next_gear > 0 &&
			next_gear <=
			parameters.drivetrain_params.gear_ratios.size()
		):
			next_gear_rpm = (
				parameters.drivetrain_params.gear_ratios[
					next_gear - 1
				] *
				parameters.drivetrain_params.final_drive *
				driven_wheel_speed *
				EngineController.RPM_PER_RADIAN_PER_SECOND
			)

		if (
			previous_gear > 0 &&
			previous_gear <=
			parameters.drivetrain_params.gear_ratios.size()
		):
			previous_gear_rpm = (
				parameters.drivetrain_params.gear_ratios[
					previous_gear - 1
				] *
				parameters.drivetrain_params.final_drive *
				driven_wheel_speed *
				EngineController.RPM_PER_RADIAN_PER_SECOND
			)

		var next_gear_torque := (
			engine.calculate_torque(
				next_gear_rpm,
				throttle_input,
				parameters
			)
		)

		var previous_gear_torque := (
			engine.calculate_torque(
				previous_gear_rpm,
				throttle_input,
				parameters
			)
		)

		drivetrain.automatic_shifting(
			engine.output_torque,
			previous_gear_torque,
			next_gear_torque,
			engine.rpm,
			parameters.max_engine_rpm,
			brake_input,
			longitudinal_speed
		)

	func update_wheel_speeds(
		front_left_wheel: RaycastSuspension,
		front_right_wheel: RaycastSuspension,
		rear_left_wheel: RaycastSuspension,
		rear_right_wheel: RaycastSuspension
	) -> void:
		average_rear_wheel_speed = (
			(
				rear_left_wheel.spin +
				rear_right_wheel.spin
			) * 0.5
		)

		average_front_wheel_speed = (
			(
				front_left_wheel.spin +
				front_right_wheel.spin
			) * 0.5
		)

	func freewheel(
		front_left_wheel: RaycastSuspension,
		front_right_wheel: RaycastSuspension,
		rear_left_wheel: RaycastSuspension,
		rear_right_wheel: RaycastSuspension,
		front_brake_torque: float,
		rear_brake_torque: float,
		delta: float
	) -> void:
		clutch_reaction_torque = 0.0
		wheel_drive_torque = 0.0
		drivetrain.reaction_torque = 0.0

		front_left_wheel.apply_torque(
			0.0,
			front_brake_torque,
			0.0,
			delta
		)

		front_right_wheel.apply_torque(
			0.0,
			front_brake_torque,
			0.0,
			delta
		)

		rear_left_wheel.apply_torque(
			0.0,
			rear_brake_torque,
			0.0,
			delta
		)

		rear_right_wheel.apply_torque(
			0.0,
			rear_brake_torque,
			0.0,
			delta
		)

		update_wheel_speeds(
			front_left_wheel,
			front_right_wheel,
			rear_left_wheel,
			rear_right_wheel
		)

	func engage(
		engine: EngineController,
		parameters: CarParameters,
		clutch_input: float,
		front_left_wheel: RaycastSuspension,
		front_right_wheel: RaycastSuspension,
		rear_left_wheel: RaycastSuspension,
		rear_right_wheel: RaycastSuspension,
		front_brake_torque: float,
		rear_brake_torque: float,
		delta: float
	) -> void:
		update_wheel_speeds(
			front_left_wheel,
			front_right_wheel,
			rear_left_wheel,
			rear_right_wheel
		)

		var gearbox_shaft_speed := 0.0

		if (
			parameters.drivetrain_params.drivetype ==
			parameters.drivetrain_params.DRIVE_TYPE.RWD
		):
			gearbox_shaft_speed = (
				average_rear_wheel_speed *
				drivetrain.get_gearing()
			)

		elif (
			parameters.drivetrain_params.drivetype ==
			parameters.drivetrain_params.DRIVE_TYPE.FWD
		):
			gearbox_shaft_speed = (
				average_front_wheel_speed *
				drivetrain.get_gearing()
			)

		elif (
			parameters.drivetrain_params.drivetype ==
			parameters.drivetrain_params.DRIVE_TYPE.AWD
		):
			gearbox_shaft_speed = (
				(
					average_front_wheel_speed +
					average_rear_wheel_speed
				) *
				0.5 *
				drivetrain.get_gearing()
			)

		var speed_error := (
			engine.angular_velocity -
			gearbox_shaft_speed
		)

		var clutch_kick: float = (
			abs(speed_error) * 0.2
		)

		var reaction_torque: float = (
			drivetrain.reaction_torque
		)

		var clutch_slip_torque: float = (
			0.8 * clutch.friction
		)

		var reaction_torques: Vector2 = (
			clutch.get_reaction_torques(
				engine.angular_velocity,
				gearbox_shaft_speed,
				engine.output_torque,
				reaction_torque,
				clutch_slip_torque,
				clutch_kick
			)
		)

		if clutch.locked:
			reaction_torques.x = (
				engine.output_torque
			)

		wheel_drive_torque = (
			reaction_torques.x *
			(
				1.0 -
				clutch_input
			)
		)

		clutch_reaction_torque = (
			reaction_torques.y *
			(
				1.0 -
				clutch_input
			)
		)

		drivetrain.drivetrain(
			wheel_drive_torque,
			rear_brake_torque,
			front_brake_torque,
			[
				rear_left_wheel,
				rear_right_wheel,
				front_left_wheel,
				front_right_wheel
			],
			clutch_input,
			delta
		)


class SuspensionController:
	extends RefCounted

	var compression: Array = [
		0.5,
		0.5,
		0.5,
		0.5
	]

	func apply_forces(
		front_left_wheel: RaycastSuspension,
		front_right_wheel: RaycastSuspension,
		rear_left_wheel: RaycastSuspension,
		rear_right_wheel: RaycastSuspension,
		delta: float
	) -> void:
		var previous_compression := compression.duplicate()

		compression[2] = (
			rear_left_wheel.apply_forces(
				previous_compression[3],
				delta
			)
		)

		compression[3] = (
			rear_right_wheel.apply_forces(
				previous_compression[2],
				delta
			)
		)

		compression[0] = (
			front_right_wheel.apply_forces(
				previous_compression[1],
				delta
			)
		)

		compression[1] = (
			front_left_wheel.apply_forces(
				previous_compression[0],
				delta
			)
		)


class VehicleMotionController:
	extends RefCounted

	var local_velocity := Vector3.ZERO
	var longitudinal_velocity: float = 0.0
	var lateral_velocity: float = 0.0

	var previous_position := Vector3.ZERO

	func initialize(car: Node3D) -> void:
		previous_position = car.global_transform.origin

	func update(
		car: Node3D,
		delta: float
	) -> void:
		local_velocity = (
			(
				car.global_transform.origin -
				previous_position
			) /
			delta *
			car.global_transform.basis
		)

		previous_position = (
			car.global_transform.origin
		)

		longitudinal_velocity = (
			-local_velocity.z
		)

		lateral_velocity = (
			local_velocity.x
		)

	func apply_aerodynamic_drag(
		car: RigidBody3D,
		parameters: CarParameters
	) -> void:
		var speed: float = (
			sqrt(
				lateral_velocity *
				lateral_velocity +
				longitudinal_velocity *
				longitudinal_velocity
			)
		)

		var aerodynamic_drag_coefficient: float = (
			0.5 *
			parameters.cd *
			parameters.frontal_area *
			parameters.air_density
		)

		var drag_force := Vector2.ZERO

		drag_force.y = (
			clamp(
				aerodynamic_drag_coefficient *
				longitudinal_velocity *
				speed,
				-100000.0,
				100000.0
			)
		)

		drag_force.x = (
			clamp(
				-aerodynamic_drag_coefficient *
				lateral_velocity *
				speed,
				-100000.0,
				100000.0
			)
		)

		car.apply_central_force(
			car.global_transform.basis.z.normalized() *
			drag_force.y
		)

		car.apply_central_force(
			car.global_transform.basis.x.normalized() *
			drag_force.x
		)


######## CONSTANTS ########

var input_controller := CarInputController.new()
var steering_controller := SteeringController.new()
var brake_controller := BrakeController.new()
var engine_controller := EngineController.new()
var powertrain_controller := PowertrainController.new()
var suspension_controller := SuspensionController.new()
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

	suspension_controller.apply_forces(
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
			brake_controller.front_brake_torque,
			brake_controller.rear_brake_torque,
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
			brake_controller.front_brake_torque,
			brake_controller.rear_brake_torque,
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

func spawn():
	pass

func set_parameters(parameters: CarParameters):
	self.car_params = parameters

@warning_ignore("shadowed_variable")
func set_joystick(joystick: Control):
	self.joystick = joystick
