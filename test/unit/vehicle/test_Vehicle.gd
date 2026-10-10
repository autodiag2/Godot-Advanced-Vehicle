extends GutTest

const FIXED_DELTA := 1.0 / 60.0
const SETTLE_FRAMES := 30
const TEST_FRAMES := 240
const RPM_TOLERANCE := 100.0

var vehicle: BaseCar
var floor_body: StaticBody3D


func before_each() -> void:
	vehicle = BaseCar.new()
	vehicle.name = "FakeVehicle"

	# BaseCar resolves these children through @onready paths.
	for wheel_name in [
		"Wheel_fl",
		"Wheel_fr",
		"Wheel_bl",
		"Wheel_br",
	]:
		var wheel := RaycastSuspension.new()
		wheel.name = wheel_name

		var mesh := MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		mesh.mesh = BoxMesh.new()
		wheel.add_child(mesh)

		vehicle.add_child(wheel)

	var engine_sound := AudioStreamPlayer.new()
	engine_sound.name = "EngineSound"
	vehicle.add_child(engine_sound)

	# A real collision surface allows wheel raycasts to contact the ground.
	floor_body = StaticBody3D.new()
	floor_body.name = "TestFloor"

	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100.0, 1.0, 100.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5

	add_child(floor_body)
	add_child(vehicle)

	# Allow _ready() and @onready initialization to complete.
	await get_tree().process_frame
	await get_tree().physics_frame

	vehicle.spawn()

	# Begin tests with no driver input.
	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 0.0
	vehicle.input_controller.handbrake = 0.0
	vehicle.input_controller.clutch = 0.0


func after_each() -> void:
	if is_instance_valid(vehicle):
		vehicle.queue_free()

	if is_instance_valid(floor_body):
		floor_body.queue_free()

	await get_tree().process_frame


func _step_physics(frames: int = 1) -> void:
	for i in range(frames):
		await get_tree().physics_frame


func _run_in_gear(
	gear: int,
	throttle: float,
	clutch: float,
	frames: int = TEST_FRAMES
) -> void:
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(gear)
	vehicle.input_controller.throttle = throttle
	vehicle.input_controller.clutch = clutch
	await _step_physics(frames)


func _rear_wheel_speed() -> float:
	return (
		vehicle.wheel_bl.get_spin()
		+ vehicle.wheel_br.get_spin()
	) * 0.5


func _front_wheel_speed() -> float:
	return (
		vehicle.wheel_fl.get_spin()
		+ vehicle.wheel_fr.get_spin()
	) * 0.5


func _all_wheel_speeds() -> Array[float]:
	return [
		vehicle.wheel_fl.get_spin(),
		vehicle.wheel_fr.get_spin(),
		vehicle.wheel_bl.get_spin(),
		vehicle.wheel_br.get_spin(),
	]


func _assert_finite(value: float, message: String) -> void:
	assert_false(is_nan(value), message + ": value is NaN")
	assert_false(is_inf(value), message + ": value is infinite")


func test_vehicle_initializes_all_four_wheels() -> void:
	assert_not_null(vehicle.wheel_fl)
	assert_not_null(vehicle.wheel_fr)
	assert_not_null(vehicle.wheel_bl)
	assert_not_null(vehicle.wheel_br)

	assert_not_null(vehicle.powertrain_controller.engine)
	assert_not_null(vehicle.powertrain_controller.drivetrain)


func test_zero_throttle_does_not_create_combustion_drive_torque() -> void:
	vehicle.engine.stop()
	vehicle.input_controller.throttle = 0.0

	await _step_physics(SETTLE_FRAMES)

	assert_eq(
		vehicle.engine.output_torque,
		0.0,
		"Stopped engine must not generate combustion torque"
	)


func test_stationary_vehicle_does_not_accelerate_engine_without_starter() -> void:
	vehicle.stop()
	vehicle.engine_starter_controller.stop()
	vehicle.input_controller.throttle = 0.0
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(0)

	await _step_physics(SETTLE_FRAMES)

	var initial_rpm := vehicle.engine.rpm
	await _step_physics(TEST_FRAMES)

	assert_lt(
		absf(vehicle.engine.rpm - initial_rpm),
		RPM_TOLERANCE,
		"Engine RPM must remain stable without combustion or starter torque"
	)


func test_neutral_does_not_transmit_drive_torque_to_wheels() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(0)
	vehicle.input_controller.clutch = 0.0
	vehicle.input_controller.throttle = 0.0

	await _step_physics(SETTLE_FRAMES)

	var initial_speeds := _all_wheel_speeds()
	await _step_physics(TEST_FRAMES)

	var final_speeds := _all_wheel_speeds()

	for i in range(initial_speeds.size()):
		assert_almost_eq(
			final_speeds[i],
			initial_speeds[i],
			0.5,
			"Neutral must not cause wheel acceleration from engine torque"
		)


func test_zero_throttle_in_first_gear_does_not_raise_engine_to_high_rpm() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.clutch = 0.0
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(1)

	await _step_physics(SETTLE_FRAMES)

	var initial_rpm := vehicle.engine.rpm
	await _step_physics(TEST_FRAMES)

	assert_lt(
		vehicle.engine.rpm,
		vehicle.engine.parameters.rpm_idle + 1000.0,
		"Zero throttle must not cause uncontrolled engine acceleration"
	)
	assert_lt(
		absf(vehicle.engine.rpm - initial_rpm),
		1500.0,
		"Engine RPM must not rise uncontrollably in first gear"
	)


func test_open_throttle_in_neutral_does_not_drive_wheels() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(0)

	await _run_in_gear(0, 0.5, 0.0, TEST_FRAMES)

	assert_almost_eq(
		_rear_wheel_speed(),
		0.0,
		1.0,
		"Engine revving in neutral must not drive the rear wheels"
	)


func test_throttle_in_first_gear_transmits_torque_to_rear_wheels() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(1)
	vehicle.input_controller.clutch = 0.0

	await _step_physics(SETTLE_FRAMES)

	var initial_rear_speed := _rear_wheel_speed()
	vehicle.input_controller.throttle = 0.5

	await _step_physics(TEST_FRAMES)

	assert_gt(
		absf(_rear_wheel_speed() - initial_rear_speed),
		0.1,
		"Throttle in first gear must change driven-wheel speed"
	)


func test_disengaged_clutch_prevents_engine_torque_from_driving_wheels() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(1)
	vehicle.input_controller.clutch = 1.0

	await _step_physics(SETTLE_FRAMES)

	var initial_rear_speed := _rear_wheel_speed()
	vehicle.input_controller.throttle = 0.5

	await _step_physics(TEST_FRAMES)

	assert_almost_eq(
		_rear_wheel_speed(),
		initial_rear_speed,
		1.0,
		"Fully disengaged clutch must isolate engine torque from the wheels"
	)


func test_reengaging_clutch_transmits_torque_after_disengagement() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(1)
	vehicle.input_controller.throttle = 0.5
	vehicle.input_controller.clutch = 1.0

	await _step_physics(SETTLE_FRAMES)

	var initial_speed := _rear_wheel_speed()
	await _step_physics(60)

	vehicle.input_controller.clutch = 0.0
	await _step_physics(TEST_FRAMES)

	assert_gt(
		absf(_rear_wheel_speed() - initial_speed),
		0.1,
		"Reengaging the clutch must restore torque transmission"
	)


func test_engine_rpm_remains_finite_under_load() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()

	await _run_in_gear(1, 0.5, 0.0, TEST_FRAMES)

	_assert_finite(vehicle.engine.rpm, "Engine RPM")
	_assert_finite(vehicle.engine.angular_velocity, "Engine angular velocity")
	_assert_finite(vehicle.engine.output_torque, "Engine output torque")


func test_wheel_speeds_remain_finite_under_load() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()

	await _run_in_gear(1, 0.75, 0.0, TEST_FRAMES)

	for speed in _all_wheel_speeds():
		_assert_finite(speed, "Wheel angular velocity")


func test_neutral_selection_does_not_stop_running_engine() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.input_controller.throttle = 0.3

	await _run_in_gear(1, 0.3, 0.0, 60)

	var rpm_before_neutral := vehicle.engine.rpm

	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(0)
	await _step_physics(60)

	assert_true(
		vehicle.engine.combustion_running,
		"Selecting neutral must not directly stop combustion"
	)
	assert_gt(
		vehicle.engine.rpm,
		0.0,
		"Engine must continue rotating in neutral"
	)
	assert_gt(
		rpm_before_neutral,
		0.0,
		"Engine must have been rotating before selecting neutral"
	)


func test_braking_does_not_create_engine_drive_torque() -> void:
	vehicle.stop()
	vehicle.engine_starter_controller.stop()
	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 1.0
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(0)

	await _step_physics(TEST_FRAMES)

	assert_eq(
		vehicle.engine.output_torque,
		0.0,
		"Braking with zero throttle and stopped combustion must not create engine torque"
	)


func test_engine_does_not_exceed_rpm_limiter() -> void:
	vehicle.start()
	vehicle.engine_starter_controller.stop()
	vehicle.powertrain_controller.drivetrain.gearbox.set_gear(0)

	vehicle.engine.rpm = vehicle.engine.parameters.max_rpm - 100.0
	vehicle.input_controller.throttle = 1.0

	await _step_physics(TEST_FRAMES)

	assert_lte(
		vehicle.engine.rpm,
		vehicle.engine.parameters.max_rpm + RPM_TOLERANCE,
		"Engine RPM must remain bounded by the rev limiter"
	)
