extends TestVehicle

func test_car_accelerates_with_throttle() -> void:
	
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	var initial_velocity := vehicle.linear_velocity
	vehicle.shift_up()
	await _wait_physics_seconds(2)
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4)

	assert_gt(
		-vehicle.linear_velocity.z,
		0.0,
		"Throttle input must accelerate the car forward"
	)

	assert_gt(
		-vehicle.linear_velocity.z,
		-initial_velocity.z,
		"Throttle input must increase forward velocity"
	)

	gut.p("test_car_accelerates_with_throttle DONE")

func test_car_does_not_move_laterally() -> void:

	var initial_position := vehicle.global_position
	await _wait_physics_seconds(4.0)

	var lateral_displacement := absf(vehicle.global_position.x - initial_position.x)
	assert_lt(
		lateral_displacement,
		0.1,
		"Car must not move laterally while accelerating"
	)


func test_car_at_rest_does_not_start_wheels_spinning() -> void:

	assert_false(
		vehicle.engine.combustion_running,
		"Engine must not be running"
	)

	await _wait_physics_seconds(10)
	assert_almost_eq(
		vehicle.wheel_fl.get_spin(),
		0.0,
		0.001,
		"Front-left wheel must not start spinning at rest"
	)
	assert_almost_eq(
		vehicle.wheel_fr.get_spin(),
		0.0,
		0.001,
		"Front-right wheel must not start spinning at rest"
	)
	assert_almost_eq(
		vehicle.wheel_bl.get_spin(),
		0.0,
		0.001,
		"Rear-left wheel must not start spinning at rest"
	)
	assert_almost_eq(
		vehicle.wheel_br.get_spin(),
		0.0,
		0.001,
		"Rear-right wheel must not start spinning at rest"
	)

func test_car_brakes_after_acceleration() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var speed_before_braking := -vehicle.linear_velocity.z
	assert_gt(
		speed_before_braking,
		1.0,
		"Car must be moving before braking"
	)

	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	var speed_after_braking := -vehicle.linear_velocity.z
	assert_lt(
		speed_after_braking,
		speed_before_braking,
		"Braking must reduce the car's forward velocity"
	)


func test_car_stops_after_braking() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var speed_before_braking := -vehicle.linear_velocity.z
	assert_gt(speed_before_braking, 1.0, "Car must be moving before braking")

	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 1.0
	await _wait_physics_seconds(6.0)

	var speed_after_braking := absf(vehicle.linear_velocity.z)
	assert_lt(
		speed_after_braking,
		0.5,
		"Car must nearly stop after sustained braking"
	)


func test_car_accelerates_without_lateral_drift() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	var initial_position := vehicle.global_position

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var lateral_displacement := absf(vehicle.global_position.x - initial_position.x)
	assert_lt(
		lateral_displacement,
		0.1,
		"Car must not move laterally while accelerating"
	)


func test_car_remains_stable_when_braking() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	assert_lt(
		absf(vehicle.linear_velocity.x),
		1.0,
		"Car must not develop significant lateral velocity while braking"
	)
	assert_lt(
		absf(vehicle.angular_velocity.y),
		1.0,
		"Car must not develop significant yaw velocity while braking"
	)


func test_car_coasts_when_throttle_is_released() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var speed_before_coasting := -vehicle.linear_velocity.z
	assert_gt(speed_before_coasting, 1.0, "Car must be moving before coasting")

	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 0.0
	await _wait_physics_seconds(1.0)

	var speed_after_coasting := -vehicle.linear_velocity.z
	assert_gt(
		speed_after_coasting,
		0.0,
		"Car must continue moving after throttle is released"
	)
	assert_lt(
		speed_after_coasting,
		speed_before_coasting,
		"Car should lose speed while coasting"
	)


func test_car_can_accelerate_again_after_braking() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	var speed_after_braking := -vehicle.linear_velocity.z
	assert_lt(speed_after_braking, 5.0, "Car must have slowed down")

	vehicle.input_controller.brake = 0.0
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(3.0)

	var speed_after_reacceleration := -vehicle.linear_velocity.z
	assert_gt(
		speed_after_reacceleration,
		speed_after_braking,
		"Car must accelerate again after braking"
	)


func test_car_does_not_move_when_engine_is_off() -> void:
	await _wait_physics_seconds(4.0)

	var initial_position := vehicle.global_position
	var initial_velocity := vehicle.linear_velocity

	await _wait_physics_seconds(4.0)

	assert_lt(
		vehicle.global_position.distance_to(initial_position),
		0.1,
		"Car must remain approximately stationary with the engine off"
	)
	assert_lt(
		vehicle.linear_velocity.length(),
		initial_velocity.length() + 0.1,
		"Car must not spontaneously accelerate with the engine off"
	)


func test_engine_starts_and_becomes_self_sustaining() -> void:
	assert_false(
		vehicle.engine.combustion_running,
		"Engine must initially be stopped"
	)

	vehicle.start()
	await _wait_physics_seconds(1.0)

	assert_true(
		vehicle.engine.combustion_running,
		"Engine must become self-sustaining after starting"
	)


func test_car_can_shift_up_while_accelerating() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(3.0)

	var speed_before_shift := -vehicle.linear_velocity.z
	assert_gt(speed_before_shift, 1.0, "Car must be moving before shifting")

	vehicle.shift_up()
	await _wait_physics_seconds(2.0)

	var speed_after_shift := -vehicle.linear_velocity.z
	assert_gt(
		speed_after_shift,
		0.0,
		"Car must continue moving after shifting"
	)


func test_car_remains_stationary_in_neutral() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	var initial_position := vehicle.global_position
	await _wait_physics_seconds(4.0)

	assert_lt(
		vehicle.global_position.distance_to(initial_position),
		0.1,
		"Car must remain stationary in neutral without throttle"
	)


func test_all_wheels_remain_in_contact_during_acceleration() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	assert_true(vehicle.wheel_fl.is_colliding(), "Front-left wheel must remain in contact")
	assert_true(vehicle.wheel_fr.is_colliding(), "Front-right wheel must remain in contact")
	assert_true(vehicle.wheel_bl.is_colliding(), "Rear-left wheel must remain in contact")
	assert_true(vehicle.wheel_br.is_colliding(), "Rear-right wheel must remain in contact")


func test_all_wheels_remain_in_contact_during_braking() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	vehicle.input_controller.throttle = 0.0
	vehicle.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	assert_true(vehicle.wheel_fl.is_colliding(), "Front-left wheel must remain in contact")
	assert_true(vehicle.wheel_fr.is_colliding(), "Front-right wheel must remain in contact")
	assert_true(vehicle.wheel_bl.is_colliding(), "Rear-left wheel must remain in contact")
	assert_true(vehicle.wheel_br.is_colliding(), "Rear-right wheel must remain in contact")

func test_car_move_but_dont_go_to_full_rpm_under_first_gear() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 0.0

	await _wait_physics_seconds(0.5)

	assert_gt(
		-vehicle.linear_velocity.z,
		0.0,
		"Car must be moving under zero throttle in first gear"
	)

	assert_lt(vehicle.engine.rpm, vehicle.engine.parameters.rpm_idle + 1000.0)
	assert_gt(vehicle.engine.rpm, vehicle.engine.parameters.rpm_idle - 1000.0)
	assert_lt(
		vehicle.engine.rpm,
		vehicle.parameters.engine.max_rpm,
		"Engine must not reach maximum RPM idle torque"
	)

func test_car_does_not_immediately_reach_max_rpm_in_first_gear() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0

	await _wait_physics_seconds(4.0)

	assert_gt(
		-vehicle.linear_velocity.z,
		0.0,
		"Car must be moving under full throttle in first gear"
	)

	assert_lt(
		vehicle.engine.rpm,
		vehicle.parameters.engine.max_rpm,
		"Engine must not reach maximum RPM under normal acceleration"
	)

func test_car_reaches_20_kmh_in_first_gear() -> void:
	await _wait_physics_seconds(0.5)
	vehicle.start()
	await _wait_physics_seconds(0.2)

	vehicle.shift_up()
	vehicle.input_controller.throttle = 1.0

	await _wait_physics_seconds(4.0)

	assert_gt(
		vehicle.getSpeedKmH(),
		20,
		"Car must exceed 20 km/h in first gear under full throttle"
	)
