extends GutTest


func _create_wheel_dynamics() -> WheelDynamicsController:
	var wheel := WheelController.new()
	var tire := TireModel.new()
	var suspension := SuspensionController.new()

	wheel.setup(tire)
	var dynamics := WheelDynamicsController.new()
	dynamics.setup(wheel, suspension)

	return dynamics


func test_below_speed_threshold_does_not_create_lateral_slip() -> void:
	var dynamics := _create_wheel_dynamics()

	var planar_velocity := Vector2(
		0.034027,
		0.007327
	)

	assert_lt(
		planar_velocity.length(),
		dynamics.wheel.speed_threshold,
		"Test velocity must be below the wheel speed threshold"
	)

	dynamics.update(
		Vector3(
			planar_velocity.x,
			0.0,
			planar_velocity.y
		),
		5000.0,
		1.0,
		0.016
	)

	assert_almost_eq(
		dynamics.wheel.slip.x,
		0.0,
		0.000001,
		"Below-threshold planar velocity must produce zero lateral slip"
	)


func test_above_speed_threshold_calculates_lateral_slip() -> void:
	var dynamics := _create_wheel_dynamics()

	var planar_velocity := Vector2(
		1.0,
		1.0
	)

	assert_gt(
		planar_velocity.length(),
		dynamics.wheel.speed_threshold,
		"Test velocity must be above the wheel speed threshold"
	)

	dynamics.update(
		Vector3(
			planar_velocity.x,
			0.0,
			planar_velocity.y
		),
		5000.0,
		1.0,
		0.016
	)

	assert_ne(
		dynamics.wheel.slip.x,
		0.0,
		"Above-threshold planar velocity must calculate lateral slip"
	)

func test_lateral_slip_matches_planar_velocity_direction() -> void:
	var dynamics := _create_wheel_dynamics()

	var local_velocity := Vector3(
		1.0,
		0.0,
		1.0
	)

	dynamics.update(
		local_velocity,
		5000.0,
		1.0,
		0.016
	)

	var expected_slip := atan2(
		-1.0,
		1.0
	)

	assert_almost_eq(
		dynamics.wheel.slip.x,
		expected_slip,
		0.000001,
		"Lateral slip must match the planar velocity direction"
	)


func test_lateral_slip_is_independent_of_planar_velocity_magnitude() -> void:
	var dynamics := _create_wheel_dynamics()

	var direction := Vector2(1.0, 2.0)
	var local_velocity := Vector3(
		direction.x,
		0.0,
		direction.y
	)

	dynamics.update(
		local_velocity,
		5000.0,
		1.0,
		0.016
	)

	var expected_slip := atan2(
		-direction.x,
		direction.y
	)

	assert_almost_eq(
		dynamics.wheel.slip.x,
		expected_slip,
		0.000001,
		"Lateral slip must depend on velocity direction"
	)

	dynamics.update(
		Vector3(
			direction.x * 10.0,
			0.0,
			direction.y * 10.0
		),
		5000.0,
		1.0,
		0.016
	)

	assert_almost_eq(
		dynamics.wheel.slip.x,
		expected_slip,
		0.000001,
		"Scaling planar velocity must not change slip angle"
	)


func test_near_zero_planar_velocity_does_not_define_lateral_slip() -> void:
	var dynamics := _create_wheel_dynamics()

	var local_velocity := Vector3(
		0.034027,
		0.0,
		0.007327
	)

	dynamics.update(
		local_velocity,
		5000.0,
		1.0,
		0.016
	)

	assert_lt(
		Vector2(
			local_velocity.x,
			local_velocity.z
		).length(),
		dynamics.wheel.speed_threshold,
		"Test velocity must be below the wheel speed threshold"
	)

	assert_almost_eq(
		dynamics.wheel.slip.x,
		0.0,
		0.000001,
		"Near-zero planar velocity must not define a lateral slip angle"
	)
