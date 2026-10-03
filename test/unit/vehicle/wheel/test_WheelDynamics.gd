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
