extends TestBaseCar

func test_car_accelerates_with_throttle() -> void:
	
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	var initial_velocity := car.linear_velocity
	car.shift_up()
	await _wait_physics_seconds(2)
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4)

	assert_gt(
		-car.linear_velocity.z,
		0.0,
		"Throttle input must accelerate the car forward"
	)

	assert_gt(
		-car.linear_velocity.z,
		-initial_velocity.z,
		"Throttle input must increase forward velocity"
	)

	gut.p("test_car_accelerates_with_throttle DONE")

func test_car_does_not_move_laterally() -> void:

	var initial_position := car.global_position
	await _wait_physics_seconds(4.0)

	var lateral_displacement := absf(car.global_position.x - initial_position.x)
	assert_lt(
		lateral_displacement,
		0.1,
		"Car must not move laterally while accelerating"
	)


func test_car_at_rest_does_not_start_wheels_spinning() -> void:

	assert_false(
		car.engine_controller.combustion_running,
		"Engine must not be running"
	)

	await _wait_physics_seconds(10)
	assert_almost_eq(
		car.wheel_fl.get_spin(),
		0.0,
		0.001,
		"Front-left wheel must not start spinning at rest"
	)
	assert_almost_eq(
		car.wheel_fr.get_spin(),
		0.0,
		0.001,
		"Front-right wheel must not start spinning at rest"
	)
	assert_almost_eq(
		car.wheel_bl.get_spin(),
		0.0,
		0.001,
		"Rear-left wheel must not start spinning at rest"
	)
	assert_almost_eq(
		car.wheel_br.get_spin(),
		0.0,
		0.001,
		"Rear-right wheel must not start spinning at rest"
	)

func test_car_brakes_after_acceleration() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var speed_before_braking := -car.linear_velocity.z
	assert_gt(
		speed_before_braking,
		1.0,
		"Car must be moving before braking"
	)

	car.input_controller.throttle = 0.0
	car.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	var speed_after_braking := -car.linear_velocity.z
	assert_lt(
		speed_after_braking,
		speed_before_braking,
		"Braking must reduce the car's forward velocity"
	)


func test_car_stops_after_braking() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var speed_before_braking := -car.linear_velocity.z
	assert_gt(speed_before_braking, 1.0, "Car must be moving before braking")

	car.input_controller.throttle = 0.0
	car.input_controller.brake = 1.0
	await _wait_physics_seconds(6.0)

	var speed_after_braking := absf(car.linear_velocity.z)
	assert_lt(
		speed_after_braking,
		0.5,
		"Car must nearly stop after sustained braking"
	)


func test_car_accelerates_without_lateral_drift() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	var initial_position := car.global_position

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var lateral_displacement := absf(car.global_position.x - initial_position.x)
	assert_lt(
		lateral_displacement,
		0.1,
		"Car must not move laterally while accelerating"
	)


func test_car_remains_stable_when_braking() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	car.input_controller.throttle = 0.0
	car.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	assert_lt(
		absf(car.linear_velocity.x),
		1.0,
		"Car must not develop significant lateral velocity while braking"
	)
	assert_lt(
		absf(car.angular_velocity.y),
		1.0,
		"Car must not develop significant yaw velocity while braking"
	)


func test_car_coasts_when_throttle_is_released() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	var speed_before_coasting := -car.linear_velocity.z
	assert_gt(speed_before_coasting, 1.0, "Car must be moving before coasting")

	car.input_controller.throttle = 0.0
	car.input_controller.brake = 0.0
	await _wait_physics_seconds(1.0)

	var speed_after_coasting := -car.linear_velocity.z
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
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	car.input_controller.throttle = 0.0
	car.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	var speed_after_braking := -car.linear_velocity.z
	assert_lt(speed_after_braking, 5.0, "Car must have slowed down")

	car.input_controller.brake = 0.0
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(3.0)

	var speed_after_reacceleration := -car.linear_velocity.z
	assert_gt(
		speed_after_reacceleration,
		speed_after_braking,
		"Car must accelerate again after braking"
	)


func test_car_does_not_move_when_engine_is_off() -> void:
	await _wait_physics_seconds(4.0)

	var initial_position := car.global_position
	var initial_velocity := car.linear_velocity

	await _wait_physics_seconds(4.0)

	assert_lt(
		car.global_position.distance_to(initial_position),
		0.1,
		"Car must remain approximately stationary with the engine off"
	)
	assert_lt(
		car.linear_velocity.length(),
		initial_velocity.length() + 0.1,
		"Car must not spontaneously accelerate with the engine off"
	)


func test_engine_starts_and_becomes_self_sustaining() -> void:
	assert_false(
		car.engine_controller.combustion_running,
		"Engine must initially be stopped"
	)

	car.start()
	await _wait_physics_seconds(1.0)

	assert_true(
		car.engine_controller.combustion_running,
		"Engine must become self-sustaining after starting"
	)


func test_car_can_shift_up_while_accelerating() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(3.0)

	var speed_before_shift := -car.linear_velocity.z
	assert_gt(speed_before_shift, 1.0, "Car must be moving before shifting")

	car.shift_up()
	await _wait_physics_seconds(2.0)

	var speed_after_shift := -car.linear_velocity.z
	assert_gt(
		speed_after_shift,
		0.0,
		"Car must continue moving after shifting"
	)


func test_car_remains_stationary_in_neutral() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	var initial_position := car.global_position
	await _wait_physics_seconds(4.0)

	assert_lt(
		car.global_position.distance_to(initial_position),
		0.1,
		"Car must remain stationary in neutral without throttle"
	)


func test_all_wheels_remain_in_contact_during_acceleration() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	assert_true(car.wheel_fl.is_colliding(), "Front-left wheel must remain in contact")
	assert_true(car.wheel_fr.is_colliding(), "Front-right wheel must remain in contact")
	assert_true(car.wheel_bl.is_colliding(), "Rear-left wheel must remain in contact")
	assert_true(car.wheel_br.is_colliding(), "Rear-right wheel must remain in contact")


func test_all_wheels_remain_in_contact_during_braking() -> void:
	await _wait_physics_seconds(0.5)
	car.start()
	await _wait_physics_seconds(0.2)

	car.shift_up()
	car.input_controller.throttle = 1.0
	await _wait_physics_seconds(4.0)

	car.input_controller.throttle = 0.0
	car.input_controller.brake = 1.0
	await _wait_physics_seconds(2.0)

	assert_true(car.wheel_fl.is_colliding(), "Front-left wheel must remain in contact")
	assert_true(car.wheel_fr.is_colliding(), "Front-right wheel must remain in contact")
	assert_true(car.wheel_bl.is_colliding(), "Rear-left wheel must remain in contact")
	assert_true(car.wheel_br.is_colliding(), "Rear-right wheel must remain in contact")
