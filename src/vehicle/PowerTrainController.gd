class_name PowertrainController
extends RefCounted

var 	engine: EngineController
var clutch := Clutch.new()
var drivetrain := DriveTrain.new()
var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension

var parameters: CarParameters

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
	engine.set_drivetrain_connected(gear != 0 )

func initialize(
	parameters_arg: CarParameters,
	engine_arg: EngineController,
	wheel_fl_arg: RaycastSuspension,
	wheel_fr_arg: RaycastSuspension,
	wheel_bl_arg: RaycastSuspension,
	wheel_br_arg: RaycastSuspension
) -> void:
	assert(parameters_arg != null)
	parameters = parameters_arg
	clutch.friction = parameters.clutch_friction
	engine = engine_arg
	wheel_fl = wheel_fl_arg
	wheel_fl.set_params(parameters.wheel_params_fl)
	wheel_fr = wheel_fr_arg
	wheel_fr.set_params(parameters.wheel_params_fr)
	wheel_bl = wheel_bl_arg
	wheel_bl.set_params(parameters.wheel_params_bl)
	wheel_br = wheel_br_arg
	wheel_br.set_params(parameters.wheel_params_br)

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
	longitudinal_speed: float
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
			throttle_input,
			next_gear_rpm
		)
	)

	var previous_gear_torque := (
		engine.calculate_torque(
			throttle_input,
			previous_gear_rpm
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


func apply(
	throttle_input: float,
	clutch_input: float,
	delta: float,
	car: RigidBody3D,
	dryRun: bool = false
):
	assert(0.0 <= throttle_input)
	assert(throttle_input <= 1.0)
	assert(0.0 <= clutch_input)
	assert(clutch_input <= 1.0)
	assert(0.0 <= delta)

	var engine_torque := engine.calculate_torque(
		throttle_input
	)
	var engine_av := engine.angular_velocity
	var engine_inertia := parameters.engine.moment

	print("engine_torque=", engine_torque, " engine_av=", engine_av, " engine_inertia=", engine_inertia)
	var drivetrain_torque := drivetrain.calculate_torque(delta)
	var drivetrain_av := drivetrain.get_av()
	var drivetrain_inertia := drivetrain.calculate_inertia()
	print("drivetrain_torque=", drivetrain_torque, " drivetrain_av=", drivetrain_av, " drivetrain_inertia=", drivetrain_inertia)
	var reaction_torques := clutch.get_reaction_torques(
		engine_av,
		drivetrain_av,
		engine_torque,
		drivetrain_torque,
		engine_inertia,
		drivetrain_inertia,
		clutch_input
	)
	assert(absf(reaction_torques.x) == absf(reaction_torques.y))
	print("clutch reaction(Tc)=", absf(reaction_torques.x))

	engine.apply(
		throttle_input,
		delta,
		reaction_torques.y
	)
	
	drivetrain.apply_torque(reaction_torques.x, delta)
