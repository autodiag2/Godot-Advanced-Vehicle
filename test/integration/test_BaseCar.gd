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
