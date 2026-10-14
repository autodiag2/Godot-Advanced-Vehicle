class_name PowertrainController
extends Controller

var 	engine: EngineController
var clutch := Clutch.new()
var drivetrain := DriveTrain.new()
var tcu: TCU = TCU.new()
var wheel_fl: WheelCorner
var wheel_fr: WheelCorner
var wheel_bl: WheelCorner
var wheel_br: WheelCorner
var wheels: Array[WheelCorner]:
	get:
		return [wheel_bl,wheel_br,wheel_fl,wheel_fr]
	set(value):
		assert(false)
var parameters: CarParameters

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

func _init() -> void:
	TAG_NAME = "POWERTRAIN"

func onGearboxGearChange(gear: int) -> void:
	engine.set_drivetrain_connected(gear != 0 )

func initialize(
	parameters_arg: CarParameters,
	engine_arg: EngineController,
	wheel_fl_arg: WheelCorner,
	wheel_fr_arg: WheelCorner,
	wheel_bl_arg: WheelCorner,
	wheel_br_arg: WheelCorner
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
	tcu.link(parameters, engine, drivetrain.gearbox, wheel_fl, wheel_fr, wheel_bl, wheel_br)

func apply(
	throttle_input: float,
	clutch_input: float,
	delta: float
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

	var drivetrain_torque := drivetrain.calculate_torque()
	var drivetrain_av := drivetrain.get_av()
	var drivetrain_inertia := drivetrain.calculate_inertia()

	var reaction_torques := clutch.get_reaction_torques(
		engine_av,
		drivetrain_av,
		engine_torque,
		drivetrain_torque,
		engine_inertia,
		drivetrain_inertia,
		clutch_input,
		delta
	)
	
	engine.apply(throttle_input, delta, reaction_torques.y)
	
	drivetrain.apply_torque(-reaction_torques.x, delta)

func brake(clamping_factor: float):
	assert(0.0 <= clamping_factor)
	assert(clamping_factor <= 1.0)
	drivetrain.brake(clamping_factor)

func handbrake(clamping_factor: float):
	assert(0.0 <= clamping_factor)
	assert(clamping_factor <= 1.0)
	drivetrain.handbrake(clamping_factor)
