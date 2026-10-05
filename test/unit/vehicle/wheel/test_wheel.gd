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

	var expected := (
		0.05 -
		1.0 * tire.radius
	) / 0.1

	assert_almost_eq(
		wheel.slip.y,
		expected,
		0.000001
	)


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


func test_setup_resets_dynamic_state():
	wheel.spin = 20.0
	wheel.slip = Vector2(0.2, 0.3)
	wheel.force = Vector3(1.0, 2.0, 3.0)

	wheel.setup(
		tire,
		15.0,
		0.15
	)

	assert_eq(wheel.spin, 0.0)
	assert_eq(wheel.slip, Vector2.ZERO)
	assert_eq(wheel.force, Vector3.ZERO)


func test_brake_acts_on_stationary_wheel():
	wheel.spin = 0.0
	wheel.force = Vector3.ZERO

	wheel.apply_torque(
		100.0,
		-50.0,
		0.0,
		0.0,
		0.1
	)

	assert_gt(
		wheel.spin,
		0.0
	)

	var wheel_without_brake := WheelController.new()
	wheel_without_brake.setup(
		tire,
		15.0,
		0.15
	)

	wheel_without_brake.apply_torque(
		100.0,
		0.0,
		0.0,
		0.0,
		0.1
	)

	assert_gt(
		wheel_without_brake.spin,
		wheel.spin
	)


func test_brake_locks_stationary_wheel_when_brake_exceeds_drive_torque():
	wheel.spin = 0.0

	wheel.apply_torque(
		100.0,
		100.0,
		0.0,
		0.0,
		0.1
	)

	assert_eq(wheel.spin, 0.0)


func test_brake_opposes_positive_spin():
	wheel.spin = 10.0

	var z_vel := wheel.spin * tire.radius

	wheel.apply_torque(
		0.0,
		-10.0,
		0.0,
		z_vel,
		0.1
	)

	assert_lt(
		wheel.spin,
		10.0
	)


func test_brake_opposes_negative_spin():
	wheel.spin = -10.0

	var z_vel := wheel.spin * tire.radius

	wheel.apply_torque(
		0.0,
		10.0,
		0.0,
		z_vel,
		0.1
	)

	assert_gt(
		wheel.spin,
		-10.0
	)


func test_brake_uses_net_torque_when_wheel_is_stationary():
	wheel.spin = 0.0

	wheel.apply_torque(
		-100.0,
		50.0,
		0.0,
		0.0,
		0.1
	)

	assert_lt(
		wheel.spin,
		0.0
	)


func test_strong_brake_does_not_reverse_positive_spin():
	wheel.spin = 10.0

	var z_vel := wheel.spin * tire.radius

	wheel.apply_torque(
		0.0,
		-10000.0,
		0.0,
		z_vel,
		0.1
	)

	assert_eq(wheel.spin, 0.0)


func test_strong_brake_does_not_reverse_negative_spin():
	wheel.spin = -10.0

	var z_vel := wheel.spin * tire.radius

	wheel.apply_torque(
		0.0,
		10000.0,
		0.0,
		z_vel,
		0.1
	)

	assert_eq(wheel.spin, 0.0)


func test_zero_delta_does_not_modify_spin():
	wheel.spin = 10.0

	var result := wheel.apply_torque(
		100.0,
		0.0,
		0.0,
		10.0,
		0.0
	)

	assert_eq(wheel.spin, 10.0)
	assert_eq(result, 0.0)


func test_negative_delta_does_not_modify_spin():
	wheel.spin = 10.0

	var result := wheel.apply_torque(
		100.0,
		0.0,
		0.0,
		10.0,
		-0.1
	)

	assert_eq(wheel.spin, 10.0)
	assert_eq(result, 0.0)


func test_zero_drive_torque_returns_zero_reaction_ratio():
	wheel.spin = 10.0

	var result := wheel.apply_torque(
		0.0,
		0.0,
		0.0,
		10.0,
		0.1
	)

	assert_eq(result, 0.0)


func test_low_speed_slip_is_continuous():
	wheel.spin = 1.0

	wheel.update_slip(
		0.099,
		0.0
	)

	var slip_below := wheel.slip.y

	wheel.update_slip(
		0.1,
		0.0
	)

	var slip_at := wheel.slip.y

	wheel.update_slip(
		0.101,
		0.0
	)

	var slip_above := wheel.slip.y

	assert_almost_eq(
		slip_below,
		(
			0.099 -
			tire.radius
		) / 0.1,
		0.000001
	)

	assert_almost_eq(
		slip_at,
		(
			0.1 -
			tire.radius
		) / 0.1,
		0.000001
	)

	assert_almost_eq(
		slip_above,
		(
			0.101 -
			tire.radius
		) / 0.101,
		0.000001
	)


func test_stationary_spinning_wheel_has_finite_slip():
	wheel.spin = 10.0

	wheel.update_slip(
		0.0,
		0.0
	)

	assert_true(
		is_finite(wheel.slip.y)
	)


func test_stationary_undriven_wheel_has_no_longitudinal_slip():
	wheel.spin = 0.0

	wheel.update_slip(
		0.0,
		0.0
	)

	assert_eq(
		wheel.slip.y,
		0.0
	)


func test_low_speed_slip_uses_speed_threshold():
	wheel.spin = 1.0

	wheel.update_slip(
		0.05,
		0.0
	)

	var expected := (
		0.05 -
		tire.radius
	) / 0.1

	assert_almost_eq(
		wheel.slip.y,
		expected,
		0.000001
	)

func test_drive_inertia_affects_undriven_wheel_synchronization():
	wheel.spin = 0.0

	var drive_inertia := wheel.inertia

	wheel.apply_torque(
		0.0,
		0.0,
		drive_inertia,
		1.0 * tire.radius,
		0.1
	)

	var expected_target := 1.0
	var expected := (
		expected_target -
		0.0
	)

	assert_almost_eq(
		wheel.spin,
		expected,
		0.000001
	)

func test_drive_torque_increases_spin_proportionally_to_delta() -> void:
	wheel.spin = 0.0

	wheel.apply_torque(
		100.0,
		0.0,
		0.0,
		0.0,
		0.1
	)

	var spin_at_0_1 := wheel.spin

	wheel.spin = 0.0

	wheel.apply_torque(
		100.0,
		0.0,
		0.0,
		0.0,
		0.2
	)

	assert_almost_eq(
		wheel.spin,
		spin_at_0_1 * 2.0,
		0.000001
	)


func test_drive_torque_accelerates_wheel_from_existing_spin() -> void:
	wheel.spin = 5.0

	wheel.apply_torque(
		100.0,
		0.0,
		0.0,
		5.0 * tire.radius,
		0.1
	)

	assert_gt(
		wheel.spin,
		5.0
	)


func test_drive_torque_reaction_ratio_matches_spin_change() -> void:
	wheel.spin = 0.0

	var drive_torque := 100.0
	var delta := 0.1

	var result := wheel.apply_torque(
		drive_torque,
		0.0,
		0.0,
		0.0,
		delta
	)

	var expected := (
		wheel.spin * wheel.inertia /
		(drive_torque * delta)
	)

	assert_almost_eq(
		result,
		expected,
		0.000001
	)


func test_drive_inertia_reduces_wheel_acceleration() -> void:
	var wheel_without_drive_inertia := WheelController.new()
	wheel_without_drive_inertia.setup(tire, 15.0, 0.15)

	var wheel_with_drive_inertia := WheelController.new()
	wheel_with_drive_inertia.setup(tire, 15.0, 0.15)

	var drive_torque := 100.0
	var delta := 0.1
	var drive_inertia := wheel.inertia

	wheel_without_drive_inertia.apply_torque(
		drive_torque,
		0.0,
		0.0,
		0.0,
		delta
	)

	wheel_with_drive_inertia.apply_torque(
		drive_torque,
		0.0,
		drive_inertia,
		0.0,
		delta
	)

	assert_gt(
		wheel_without_drive_inertia.spin,
		wheel_with_drive_inertia.spin
	)


func test_wheel_force_reaction_torque_changes_spin() -> void:
	wheel.spin = 10.0
	wheel.force.y = -100.0

	var initial_spin := wheel.spin

	wheel.apply_torque(
		0.0,
		0.0,
		0.0,
		initial_spin * tire.radius,
		0.1
	)

	assert_lt(
		wheel.spin,
		initial_spin
	)


func test_drive_torque_overcomes_opposing_tire_reaction() -> void:
	wheel.spin = 0.0
	wheel.force.y = -50.0

	wheel.apply_torque(
		100.0,
		0.0,
		0.0,
		0.0,
		0.1
	)

	assert_gt(
		wheel.spin,
		0.0
	)
