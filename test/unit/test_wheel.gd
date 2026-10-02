extends GutTest

var wheel: WheelController
var tire: TireModel


func before_each():
	wheel = WheelController.new()
	tire = TireModel.new()

	wheel.setup(
		tire,
		15.0,
		0.15
	)


func test_initial_state():
	assert_eq(wheel.mass, 15.0)
	assert_eq(wheel.ackermann, 0.15)
	assert_eq(wheel.spin, 0.0)
	assert_eq(wheel.slip, Vector2.ZERO)
	assert_eq(wheel.force, Vector3.ZERO)


func test_setup_calculates_wheel_inertia():
	var expected := 0.5 * 15.0 * pow(tire.radius, 2)

	assert_eq(wheel.inertia, expected)

func test_update_slip_lateral():
	wheel.update_slip(
		10.0,
		0.2
	)

	assert_almost_eq(
		wheel.slip.x,
		0.2,
		0.000001
	)


func test_update_slip_longitudinal():
	wheel.spin = 20.0

	wheel.update_slip(
		10.0,
		0.0
	)

	var expected := (
		10.0 -
		20.0 * tire.radius
	) / 10.0

	assert_almost_eq(
		wheel.slip.y,
		expected,
		0.000001
	)


func test_update_slip_below_speed_threshold():
	wheel.spin = 1.0

	wheel.update_slip(
		0.05,
		0.2
	)

	assert_almost_eq(
		wheel.slip.x,
		0.2,
		0.000001
	)

	assert_eq(wheel.slip.y, 0.0)

func test_update_force():
	wheel.update_slip(
		10.0,
		0.1
	)

	var force := wheel.update_force(
		1000.0,
		1.0
	)

	assert_eq(force, wheel.force)


func test_set_and_get_spin():
	wheel.set_spin(12.0)

	assert_eq(wheel.get_spin(), 12.0)


func test_reaction_torque():
	wheel.force.y = 100.0

	assert_eq(
		wheel.get_reaction_torque(),
		100.0 * tire.radius
	)


func test_steer_zero():
	assert_eq(
		wheel.steer(0.0, 0.3),
		0.0
	)


func test_steer_positive():
	var input := 0.5
	var max_steer := 0.3

	var correction := (
		1.0 -
		cos(abs(input) * 0.5 * PI)
	) * wheel.ackermann

	var expected := max_steer * (
		input +
		correction
	)

	assert_almost_eq(
		wheel.steer(input, max_steer),
		expected,
		0.000001
	)


func test_steer_negative():
	var input := -0.5
	var max_steer := 0.3

	var correction := (
		1.0 -
		cos(abs(input) * 0.5 * PI)
	) * wheel.ackermann

	var expected := max_steer * (
		input -
		correction
	)

	assert_almost_eq(
		wheel.steer(input, max_steer),
		expected,
		0.000001
	)


func test_steer_is_symmetric():
	var positive := wheel.steer(
		0.5,
		0.3
	)

	var negative := wheel.steer(
		-0.5,
		0.3
	)

	assert_almost_eq(
		positive,
		-negative,
		0.000001
	)


func test_steer_without_ackermann():
	wheel.ackermann = 0.0

	assert_eq(
		wheel.steer(0.5, 0.3),
		0.15
	)

	assert_eq(
		wheel.steer(-0.5, 0.3),
		-0.15
	)
