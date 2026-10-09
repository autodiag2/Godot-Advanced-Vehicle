class_name DifferentialTest
extends GutTest

var differential: Differential
var parameters : DiffParameters
var wheel_bl : RaycastSuspension
var wheel_br : RaycastSuspension
var wheel_fl : RaycastSuspension
var wheel_fr : RaycastSuspension

func before_each():
	differential = Differential.new()
	var car_params : CarParameters = CarParameters.new()
	parameters = car_params.drivetrain.rear_diff
	wheel_fl = RaycastSuspension.new()
	wheel_fl.set_params(car_params.wheel_params_fl)
	wheel_fr = RaycastSuspension.new()
	wheel_fr.set_params(car_params.wheel_params_fr)
	wheel_bl = RaycastSuspension.new()
	wheel_bl.set_params(car_params.wheel_params_bl)
	wheel_br = RaycastSuspension.new()
	wheel_br.set_params(car_params.wheel_params_br)
	differential.initialise(parameters, wheel_bl, wheel_br, wheel_fl, wheel_fr, car_params.drivetrain)

func after_each():
	wheel_bl.free()
	wheel_br.free()
	wheel_fl.free()
	wheel_fr.free()

func test_open_differential_applies_torque_to_both_wheels() -> void:

	differential.set_type(Differential.DIFF_TYPE.OPEN_DIFF)

	var torque := 100.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		delta
	)

	assert_gt(wheel_bl.get_spin(), 0.0)
	assert_gt(wheel_br.get_spin(), 0.0)


func test_open_differential_splits_torque_between_wheels() -> void:
	differential.set_type(Differential.DIFF_TYPE.OPEN_DIFF)

	var torque := 100.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		delta
	)

	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)


func test_locked_differential_accelerates_both_wheels() -> void:

	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	var torque := 100.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		delta
	)

	assert_gt(wheel_bl.get_spin(), 0.0)
	assert_gt(wheel_br.get_spin(), 0.0)

	assert_almost_eq(
		wheel_br.get_spin(),
		wheel_bl.get_spin(),
		0.000001
	)


func test_locked_differential_acceleration_matches_total_inertia() -> void:

	wheel_bl.wheel.inertia = 2.0
	wheel_br.wheel.inertia = 3.0

	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	var torque := 100.0
	var drive_inertia := 5.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		delta
	)

	var expected_acceleration := (
		torque /
		(
			drive_inertia +
			wheel_bl.wheel.inertia +
			wheel_br.wheel.inertia
		)
	)

	var expected_spin := (
		expected_acceleration *
		delta
	)

	assert_almost_eq(
		wheel_bl.get_spin(),
		expected_spin,
		0.000001
	)

	assert_almost_eq(
		wheel_br.get_spin(),
		expected_spin,
		0.000001
	)

func test_locked_differential_accelerates_from_zero_when_drive_torque_exists() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	var drive_torque := 100.0
	var drive_inertia := 0.0
	var delta := 0.1

	assert_eq(wheel_bl.get_spin(), 0.0)
	assert_eq(wheel_br.get_spin(), 0.0)

	differential.apply_torque(
		drive_torque,
		delta
	)

	assert_gt(wheel_bl.get_spin(), 0.0)
	assert_gt(wheel_br.get_spin(), 0.0)
	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)

func test_locked_differential_preserves_zero_speed_without_torque() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	var drive_torque := 0.0
	var drive_inertia := 0.0
	var delta := 0.1

	assert_eq(wheel_bl.get_spin(), 0.0)
	assert_eq(wheel_br.get_spin(), 0.0)

	differential.apply_torque(
		drive_torque,
		delta
	)

	assert_eq(wheel_bl.get_spin(), 0.0)
	assert_eq(wheel_br.get_spin(), 0.0)


func test_locked_differential_brakes_progressively() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	var drive_inertia := 0.0
	var delta := 0.1

	wheel_bl.set_spin(10.0)
	wheel_br.set_spin(10.0)

	var previous_spin : float = wheel_bl.get_spin()

	for i in range(15):
		differential.apply_torque(
			-20.0,
			delta
		)

		assert_lt(wheel_bl.get_spin(), previous_spin)
		assert_almost_eq(
			wheel_bl.get_spin(),
			wheel_br.get_spin(),
			0.000001
		)

		previous_spin = wheel_bl.get_spin()

	assert_lte(wheel_bl.get_spin(), 0.0)
	assert_lte(wheel_br.get_spin(), 0.0)

func test_locked_differential_does_not_use_artificial_five_rad_per_second_stop() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	var drive_inertia := 0.0
	var delta := 0.1

	wheel_bl.set_spin(4.0)
	wheel_br.set_spin(4.0)

	differential.apply_torque(
		-1.0,
		delta
	)

	assert_lt(wheel_bl.get_spin(), 4.0)
	assert_lt(wheel_br.get_spin(), 4.0)
	assert_lt(wheel_bl.get_spin(), 5.0)
	assert_lt(wheel_br.get_spin(), 5.0)
	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)

func test_locked_differential_handles_unequal_initial_wheel_speeds() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	wheel_bl.set_spin(10.0)
	wheel_br.set_spin(5.0)

	differential.apply_torque(0.0, 0.1)

	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)


func test_locked_differential_handles_unequal_wheel_inertias() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	wheel_bl.wheel.inertia = 2.0
	wheel_br.wheel.inertia = 4.0

	differential.apply_torque(120.0, 0.1)

	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)

	assert_gt(wheel_bl.get_spin(), 0.0)


func test_locked_differential_handles_zero_timestep() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	wheel_bl.set_spin(10.0)
	wheel_br.set_spin(10.0)

	differential.apply_torque(100.0, 0.0)

	assert_eq(wheel_bl.get_spin(), 10.0)
	assert_eq(wheel_br.get_spin(), 10.0)


func test_locked_differential_handles_zero_drive_torque_at_equal_speed() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	wheel_bl.set_spin(10.0)
	wheel_br.set_spin(10.0)

	differential.apply_torque(0.0, 0.1)

	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)


func test_locked_differential_reverses_wheel_rotation_under_reverse_torque() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	wheel_bl.set_spin(1.0)
	wheel_br.set_spin(1.0)

	for i in range(20):
		differential.apply_torque(-100.0, 0.1)

	assert_lt(wheel_bl.get_spin(), 0.0)
	assert_lt(wheel_br.get_spin(), 0.0)

	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)


func test_locked_differential_does_not_diverge_under_asymmetric_wheel_inertia() -> void:
	differential.set_type(Differential.DIFF_TYPE.LOCKED)

	wheel_bl.wheel.inertia = 2.0
	wheel_br.wheel.inertia = 4.0

	wheel_bl.set_spin(10.0)
	wheel_br.set_spin(10.0)

	differential.apply_torque(100.0, 0.1)

	assert_almost_eq(
		wheel_bl.get_spin(),
		wheel_br.get_spin(),
		0.000001
	)
