extends GutTest


var powertrain: PowertrainController
var engine: EngineController = EngineController.new()
var car: RigidBody3D = RigidBody3D.new()

func before_each() -> void:
	powertrain = PowertrainController.new()
	powertrain.engine = engine
	var parameters := _create_parameters()

	engine = _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		engine,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)
	

func after_each() -> void:
	_free_wheels([powertrain.wheel_bl, powertrain.wheel_br, powertrain.wheel_fl, powertrain.wheel_fr])
	powertrain = null

func after_all():
	car.queue_free()

func assert_float_eq(
	one: float,
	two: float,
	threshold: float = 0.000001
) -> void:
	assert_almost_eq(
		one,
		two,
		threshold
	)

func _create_parameters() -> CarParameters:
	var parameters := CarParameters.new()

	parameters.engine.moment = 1.0
	parameters.clutch_friction = 250.0
	parameters.engine.max_rpm = 6000.0
	parameters.engine.rpm_idle = 800.0
	parameters.engine.max_torque = 200.0

	parameters.drivetrain = DriveTrainParameters.new()
	parameters.drivetrain.gearbox.gear_ratios = [3.0]
	parameters.drivetrain.final_drive = 3.5
	parameters.drivetrain.drivetype = (
		DriveTrainParameters.DRIVE_TYPE.RWD
	)

	parameters.drivetrain.rear_diff = DiffParameters.new()
	parameters.drivetrain.front_diff = DiffParameters.new()
	parameters.drivetrain.center_diff = DiffParameters.new()

	return parameters


func _create_engine(
	parameters_arg: CarParameters
) -> EngineController:
	engine = EngineController.new()

	engine.parameters = parameters_arg.engine
	engine.car_parameters = parameters_arg
	engine.angular_velocity = 100.0
	engine.output_torque = 100.0
	engine.starter = EngineStarterController.new()

	return engine


func _create_wheels() -> Array[RaycastSuspension]:
	var wheels : Array[RaycastSuspension] = [
		RaycastSuspension.new(),
		RaycastSuspension.new(),
		RaycastSuspension.new(),
		RaycastSuspension.new()
	]

	for suspension in wheels:
		suspension.wheel.setup(TireModel.new())

	return wheels

func _free_wheels(wheels: Array) -> void:
	for wheel in wheels:
		wheel.free()

func test_engine_accelerates_car_only_after_engaging_first_gear() -> void:
	var delta := 0.01
	engine.start()

	# Run the engine in neutral.
	for i in range(100):
		powertrain.apply(0.0, 0.0, delta)

	assert_float_eq(
		powertrain.average_rear_wheel_speed,
		0.0
	)
	assert_float_eq(
		powertrain.average_front_wheel_speed,
		0.0
	)

	# Engage first gear and apply throttle.
	powertrain.drivetrain.gearbox.set_gear(1)

	for i in range(100):
		powertrain.apply(0.0, 0.0, delta)

	assert_gt(
		powertrain.average_rear_wheel_speed,
		0.0,
		"Engine torque should accelerate the rear wheels in first gear."
	)

func test_average_rear_wheel_speed_is_calculated_from_wheels() -> void:

	powertrain.wheel_bl.set_spin(10.0)
	powertrain.wheel_br.set_spin(20.0)

	assert_float_eq(
		powertrain.average_rear_wheel_speed,
		15.0
	)



func test_average_front_wheel_speed_is_calculated_from_wheels() -> void:
	powertrain.wheel_fl.set_spin(10.0)
	powertrain.wheel_fr.set_spin(30.0)

	assert_float_eq(
		powertrain.average_front_wheel_speed,
		20.0
	)

func test_fully_disengaged_clutch_transmits_no_drive_torque() -> void:

	engine.angular_velocity = 100.0

	powertrain.apply(
		1.0,
		1.0,
		0.01
	)

	assert_false(
		powertrain.clutch.is_locked()
	)


func test_fully_disengaged_clutch_does_not_make_drive_inertia_zero() -> void:

	engine.parameters.moment = 2.0
	powertrain.drivetrain.gearbox.params.gear_ratios = [3.0]
	powertrain.drivetrain.set_gear(1)

	engine.angular_velocity = 100.0

	powertrain.apply(
		1.0,
		1.0,
		0.01
	)

	assert_gt(
		powertrain.drivetrain.gearbox.drive_inertia,
		0.0
	)


func test_fully_engaged_clutch_can_transmit_engine_torque() -> void:
	pending("TODO")


func test_clutch_reaction_torque_opposes_engine_torque() -> void:
	pending("TODO")


func test_fully_disengaged_clutch_does_not_remain_locked() -> void:
	#powertrain.clutch.locked = true
	
	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.apply(
		1.0,
		1.0,
		0.01
	)

	assert_false(
		powertrain.clutch.is_locked()
	)


func test_reengaging_after_disengaged_clutch_can_transmit_torque() -> void:
	powertrain.clutch.friction = 1000.0

	powertrain.drivetrain.set_gear(1)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.apply(
		1.0,
		1.0,
		0.01
	)

	assert_false(
		powertrain.clutch.is_locked()
	)

	powertrain.apply(
		1.0,
		0.0,
		0.01
	)

	pending("TODO")


func test_neutral_does_not_produce_wheel_drive_torque() -> void:
	powertrain.drivetrain.gearbox.params.gear_ratios = [3.0]

	powertrain.drivetrain.set_gear(0)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.apply(
		1.0,
		0.0,
		0.01
	)

	assert_float_eq(
		powertrain.drivetrain.get_gearing(),
		0.0
	)

func test_engage_unlocks_clutch_when_fully_disengaged() -> void:

	#powertrain.clutch.locked = true

	powertrain.apply(
		1.0,
		1.0,
		0.01
	)

	assert_false(
		powertrain.clutch.is_locked()
	)


func test_engage_clears_drivetrain_reaction_torque_in_neutral() -> void:
	powertrain.drivetrain.set_gear(0)

	powertrain.apply(
		1.0,
		1.0,
		0.01
	)

	assert_float_eq(
		powertrain.drivetrain.apply_torque(1000.0, 0.1),
		0.0
	)

func test_average_wheel_speeds_are_live_getters() -> void:
	powertrain.wheel_fl.set_spin(10.0)
	powertrain.wheel_fr.set_spin(30.0)
	powertrain.wheel_bl.set_spin(20.0)
	powertrain.wheel_br.set_spin(40.0)

	assert_float_eq(
		powertrain.average_front_wheel_speed,
		20.0
	)

	assert_float_eq(
		powertrain.average_rear_wheel_speed,
		30.0
	)

	powertrain.wheel_fl.set_spin(50.0)
	powertrain.wheel_fr.set_spin(70.0)
	powertrain.wheel_bl.set_spin(60.0)
	powertrain.wheel_br.set_spin(80.0)

	assert_float_eq(
		powertrain.average_front_wheel_speed,
		60.0
	)

	assert_float_eq(
		powertrain.average_rear_wheel_speed,
		70.0
	)


func test_first_gear_closed_throttle_engine_stabilizes_at_idle() -> void:
	for corner in powertrain.wheels:
		corner.wheel.setup(CurveTireModel.new())

	engine.parameters.rpm_idle = 800.0
	engine.parameters.max_rpm = 6000.0

	powertrain.drivetrain.set_gear(1)

	engine.rpm = engine.parameters.rpm_idle

	for i in range(1000):
		powertrain.apply(
			0.0,
			0.0,
			0.01
		)

	assert_gt(
		engine.rpm,
		0.0
	)

	assert_lt(
		engine.rpm,
		engine.parameters.max_rpm
	)

	assert_almost_eq(
		engine.rpm,
		engine.parameters.rpm_idle,
		300.0
	)

func test_selecting_neutral_does_not_stop_running_engine() -> void:

	engine.parameters.rpm_idle = 800.0

	powertrain.drivetrain.set_gear(1)

	engine.rpm = engine.parameters.rpm_idle

	powertrain.apply(
		1.0,
		0.0,
		0.01
	)

	powertrain.drivetrain.set_gear(0)

	powertrain.apply(
		1.0,
		0.0,
		0.01
	)

	assert_gt(
		engine.rpm,
		0.0
	)
