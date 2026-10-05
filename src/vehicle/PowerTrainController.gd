class_name PowertrainController
extends RefCounted

var drivetrain := DriveTrain.new()
var clutch := Clutch.new()
var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension
var 	engine: EngineController

var clutch_reaction_torque: float = 0.0
var wheel_drive_torque: float = 0.0

var average_front_wheel_speed: float:
	get:
		return (
			(
				wheel_fl.wheel.spin +
				wheel_fr.wheel.spin
			) * 0.5
		)

var average_rear_wheel_speed: float:
	get:
		return (
			(
				wheel_bl.wheel.spin +
				wheel_br.wheel.spin
			) * 0.5
		)

func onGearboxGearChange(gear: int) -> void:
	engine.set_drivetrain_connected(gear == 0 )

func initialize(
	parameters: CarParameters,
	engine_arg: EngineController,
	wheel_fl_arg: RaycastSuspension,
	wheel_fr_arg: RaycastSuspension,
	wheel_bl_arg: RaycastSuspension,
	wheel_br_arg: RaycastSuspension
) -> void:
	clutch.friction = parameters.clutch_friction
	engine = engine_arg
	wheel_fl = wheel_fl_arg
	wheel_fr = wheel_fr_arg
	wheel_bl = wheel_bl_arg
	wheel_br = wheel_br_arg
	drivetrain.setup(
		parameters.drivetrain,
		self
	)

	drivetrain.set_input_inertia(
		parameters.engine.moment
	)


func update_automatic_shifting(
	throttle_input: float,
	brake_input: float,
	longitudinal_speed: float,
	parameters: CarParameters
) -> void:
	var driven_wheel_speed := average_front_wheel_speed

	if (
		parameters.drivetrain.drivetype ==
		parameters.drivetrain.DRIVE_TYPE.RWD
	):
		driven_wheel_speed = average_rear_wheel_speed

	elif (
		parameters.drivetrain.drivetype ==
		parameters.drivetrain.DRIVE_TYPE.AWD
	):
		driven_wheel_speed = (
			average_front_wheel_speed +
			average_rear_wheel_speed
		) * 0.5

	var next_gear_rpm := 0.0
	var previous_gear_rpm := 0.0

	var next_gear := drivetrain.gearbox.selected_gear + 1
	var previous_gear := drivetrain.gearbox.selected_gear - 1

	if (
		next_gear > 0 &&
		next_gear <=
		parameters.drivetrain.gearbox.gear_ratios.size()
	):
		next_gear_rpm = (
			parameters.drivetrain.gearbox.gear_ratios[
				next_gear - 1
			] *
			parameters.drivetrain.final_drive *
			absf(driven_wheel_speed) *
			EngineController.RPM_PER_RADIAN_PER_SECOND
		)

	if (
		previous_gear > 0 &&
		previous_gear <=
		parameters.drivetrain.gearbox.gear_ratios.size()
	):
		previous_gear_rpm = (
			parameters.drivetrain.gearbox.gear_ratios[
				previous_gear - 1
			] *
			parameters.drivetrain.final_drive *
			absf(driven_wheel_speed) *
			EngineController.RPM_PER_RADIAN_PER_SECOND
		)

	var next_gear_torque := (
		engine.calculate_torque(
			next_gear_rpm,
			throttle_input
		)
	)

	var previous_gear_torque := (
		engine.calculate_torque(
			previous_gear_rpm,
			throttle_input
		)
	)

	drivetrain.automatic_shifting(
		engine.output_torque,
		previous_gear_torque,
		next_gear_torque,
		engine.rpm,
		parameters.engine.max_rpm,
		brake_input,
		longitudinal_speed
	)


func update(
	parameters: CarParameters,
	clutch_input: float,
	delta: float
) -> void:
	var gearing := drivetrain.get_gearing()

	if gearing == 0.0:
		clutch.locked = false
		wheel_drive_torque = 0.0
		clutch_reaction_torque = 0.0

		drivetrain.apply_torque(
			wheel_drive_torque,
			clutch_input,
			delta
		)

		return

	var gearbox_shaft_speed := 0.0

	if (
		parameters.drivetrain.drivetype ==
		parameters.drivetrain.DRIVE_TYPE.RWD
	):
		gearbox_shaft_speed = (
			average_rear_wheel_speed *
			gearing
		)

	elif (
		parameters.drivetrain.drivetype ==
		parameters.drivetrain.DRIVE_TYPE.FWD
	):
		gearbox_shaft_speed = (
			average_front_wheel_speed *
			gearing
		)

	elif (
		parameters.drivetrain.drivetype ==
		parameters.drivetrain.DRIVE_TYPE.AWD
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
		drivetrain.get_reaction_torque()
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

	drivetrain.apply_torque(
		wheel_drive_torque,
		clutch_input,
		delta
	)
