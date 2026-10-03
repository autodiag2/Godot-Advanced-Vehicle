extends GutTest


var powertrain: PowertrainController


func before_each() -> void:
	powertrain = PowertrainController.new()


func after_each() -> void:
	powertrain = null


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


func test_powertrain_initializes_clutch_friction() -> void:
	var parameters := _create_parameters()
	parameters.clutch_friction = 300.0

	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	assert_float_eq(
		powertrain.clutch.friction,
		300.0
	)


func test_powertrain_initializes_drivetrain_engine_inertia() -> void:
	var parameters := _create_parameters()
	parameters.engine_moment = 2.5
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	assert_float_eq(
		powertrain.drivetrain._engine_inertia,
		2.5
	)


func test_average_rear_wheel_speed_is_calculated_from_wheels() -> void:
	var wheels := _create_wheels()

	powertrain.wheel_bl = wheels[2]
	powertrain.wheel_br = wheels[3]

	wheels[2].wheel.spin = 10.0
	wheels[3].wheel.spin = 20.0

	assert_float_eq(
		powertrain.average_rear_wheel_speed,
		15.0
	)

	_free_wheels(wheels)


func test_average_front_wheel_speed_is_calculated_from_wheels() -> void:
	var wheels := _create_wheels()

	powertrain.wheel_fl = wheels[0]
	powertrain.wheel_fr = wheels[1]

	wheels[0].wheel.spin = 10.0
	wheels[1].wheel.spin = 30.0

	assert_float_eq(
		powertrain.average_front_wheel_speed,
		20.0
	)

	_free_wheels(wheels)


func test_fully_disengaged_clutch_transmits_no_drive_torque() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_float_eq(
		powertrain.wheel_drive_torque,
		0.0
	)

	assert_float_eq(
		powertrain.clutch_reaction_torque,
		0.0
	)

	assert_false(
		powertrain.clutch.locked
	)

	_free_wheels(wheels)


func test_fully_disengaged_clutch_does_not_make_drive_inertia_zero() -> void:
	var parameters := _create_parameters()
	parameters.engine_moment = 2.0
	parameters.drivetrain_params.gear_ratios = [3.0]

	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(1)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_gt(
		powertrain.drivetrain.drive_inertia,
		0.0
	)

	_free_wheels(wheels)


func test_fully_engaged_clutch_can_transmit_engine_torque() -> void:
	var parameters := _create_parameters()
	parameters.clutch_friction = 1000.0

	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(1)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_gt(
		absf(powertrain.wheel_drive_torque),
		0.0
	)

	_free_wheels(wheels)


func test_clutch_reaction_torque_opposes_engine_torque() -> void:
	var parameters := _create_parameters()
	parameters.clutch_friction = 1000.0

	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(1)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_lte(
		powertrain.clutch_reaction_torque,
		0.0
	)

	_free_wheels(wheels)


func test_fully_disengaged_clutch_does_not_remain_locked() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.clutch.locked = true

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_false(
		powertrain.clutch.locked
	)

	_free_wheels(wheels)


func test_reengaging_after_disengaged_clutch_can_transmit_torque() -> void:
	var parameters := _create_parameters()
	parameters.clutch_friction = 1000.0

	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(1)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_false(
		powertrain.clutch.locked
	)

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_gt(
		absf(powertrain.wheel_drive_torque),
		0.0
	)

	_free_wheels(wheels)


func test_neutral_does_not_produce_wheel_drive_torque() -> void:
	var parameters := _create_parameters()
	parameters.drivetrain_params.gear_ratios = [3.0]

	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(0)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_float_eq(
		powertrain.drivetrain.get_gearing(),
		0.0
	)

	_free_wheels(wheels)


func _create_parameters() -> CarParameters:
	var parameters := CarParameters.new()

	parameters.engine_moment = 1.0
	parameters.clutch_friction = 250.0
	parameters.max_engine_rpm = 6000.0
	parameters.rpm_idle = 800.0
	parameters.max_torque = 200.0

	parameters.drivetrain_params = DriveTrainParameters.new()
	parameters.drivetrain_params.gear_ratios = [3.0]
	parameters.drivetrain_params.final_drive = 3.5
	parameters.drivetrain_params.drivetype = (
		DriveTrainParameters.DRIVE_TYPE.RWD
	)

	parameters.drivetrain_params.rear_diff = DiffParameters.new()
	parameters.drivetrain_params.front_diff = DiffParameters.new()
	parameters.drivetrain_params.center_diff = DiffParameters.new()

	return parameters


func _create_engine(
	parameters: CarParameters
) -> EngineController:
	var engine := EngineController.new()

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	return engine


func test_engage_clears_clutch_reaction_torque_when_fully_disengaged() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.clutch_reaction_torque = 100.0

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_float_eq(
		powertrain.clutch_reaction_torque,
		0.0
	)

	_free_wheels(wheels)


func test_engage_clears_wheel_drive_torque_when_fully_disengaged() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.wheel_drive_torque = 100.0

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_float_eq(
		powertrain.wheel_drive_torque,
		0.0
	)

	_free_wheels(wheels)


func test_engage_unlocks_clutch_when_fully_disengaged() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.clutch.locked = true

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_false(
		powertrain.clutch.locked
	)

	_free_wheels(wheels)


func test_engage_clears_drivetrain_reaction_torque_in_neutral() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.drivetrain.reaction_torque = 100.0

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(0)

	powertrain.update(
		engine,
		parameters,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_float_eq(
		powertrain.drivetrain.reaction_torque,
		0.0
	)

	_free_wheels(wheels)


func test_average_wheel_speeds_are_live_getters() -> void:
	var wheels := _create_wheels()

	powertrain.initialize(
		_create_parameters(),
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	wheels[0].wheel.spin = 10.0
	wheels[1].wheel.spin = 30.0
	wheels[2].wheel.spin = 20.0
	wheels[3].wheel.spin = 40.0

	assert_float_eq(
		powertrain.average_front_wheel_speed,
		20.0
	)

	assert_float_eq(
		powertrain.average_rear_wheel_speed,
		30.0
	)

	wheels[0].wheel.spin = 50.0
	wheels[1].wheel.spin = 70.0
	wheels[2].wheel.spin = 60.0
	wheels[3].wheel.spin = 80.0

	assert_float_eq(
		powertrain.average_front_wheel_speed,
		60.0
	)

	assert_float_eq(
		powertrain.average_rear_wheel_speed,
		70.0
	)

	_free_wheels(wheels)


func _create_wheels() -> Array:
	var wheels := [
		RaycastSuspension.new(),
		RaycastSuspension.new(),
		RaycastSuspension.new(),
		RaycastSuspension.new()
	]

	for suspension in wheels:
		suspension.wheel.setup(TireModel.new())

	return wheels


func test_selecting_neutral_does_not_stop_running_engine() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	parameters.rpm_idle = 800.0

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(1)

	engine.rpm = parameters.rpm_idle

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	powertrain.drivetrain.set_selected_gear(0)

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_gt(
		engine.rpm,
		0.0
	)

	_free_wheels(wheels)


func test_selecting_neutral_removes_clutch_reaction_torque() -> void:
	var parameters := _create_parameters()
	var engine := _create_engine(parameters)
	var wheels := _create_wheels()

	powertrain.initialize(
		parameters,
		wheels[0],
		wheels[1],
		wheels[2],
		wheels[3]
	)

	powertrain.drivetrain.set_selected_gear(1)

	engine.angular_velocity = 100.0
	engine.output_torque = 100.0

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	powertrain.drivetrain.set_selected_gear(0)

	powertrain.update(
		engine,
		parameters,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.01
	)

	assert_float_eq(
		powertrain.clutch_reaction_torque,
		0.0
	)

	assert_float_eq(
		powertrain.wheel_drive_torque,
		0.0
	)

	_free_wheels(wheels)


func _free_wheels(wheels: Array) -> void:
	for wheel in wheels:
		wheel.free()
