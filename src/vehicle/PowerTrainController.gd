class_name PowertrainController
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
			absf(driven_wheel_speed) *
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
			absf(driven_wheel_speed) *
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
			rear_left_wheel.wheel.spin +
			rear_right_wheel.wheel.spin
		) * 0.5
	)

	average_front_wheel_speed = (
		(
			front_left_wheel.wheel.spin +
			front_right_wheel.wheel.spin
		) * 0.5
	)


func update(
	engine: EngineController,
	parameters: CarParameters,
	clutch_input: float,
	front_left_wheel: RaycastSuspension,
	front_right_wheel: RaycastSuspension,
	rear_left_wheel: RaycastSuspension,
	rear_right_wheel: RaycastSuspension,
	front_left_brake_torque: float,
	front_right_brake_torque: float,
	rear_left_brake_torque: float,
	rear_right_brake_torque: float,
	delta: float
) -> void:
	var front_brake_torque := (
		front_left_brake_torque +
		front_right_brake_torque
	)

	var rear_brake_torque := (
		rear_left_brake_torque +
		rear_right_brake_torque
	)

	update_wheel_speeds(
		front_left_wheel,
		front_right_wheel,
		rear_left_wheel,
		rear_right_wheel
	)

	var gearing := drivetrain.get_gearing()

	if gearing == 0.0:
		clutch.locked = false
		wheel_drive_torque = 0.0
		clutch_reaction_torque = 0.0
		drivetrain.reaction_torque = 0.0

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

		return

	var gearbox_shaft_speed := 0.0

	if (
		parameters.drivetrain_params.drivetype ==
		parameters.drivetrain_params.DRIVE_TYPE.RWD
	):
		gearbox_shaft_speed = (
			average_rear_wheel_speed *
			gearing
		)

	elif (
		parameters.drivetrain_params.drivetype ==
		parameters.drivetrain_params.DRIVE_TYPE.FWD
	):
		gearbox_shaft_speed = (
			average_front_wheel_speed *
			gearing
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
			gearing
		)

	var reaction_torque: float = (
		drivetrain.reaction_torque
	)

	var clutch_slip_torque: float = (
		0.8 *
		clutch.friction *
		(1.0 - clutch_input)
	)

	var clutch_kick := 0.0

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

	if clutch_input >= 1.0:
		clutch.locked = false
		reaction_torques = Vector2.ZERO

	wheel_drive_torque = reaction_torques.x

	clutch_reaction_torque = reaction_torques.y

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
