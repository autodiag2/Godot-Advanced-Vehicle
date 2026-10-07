class_name DifferentialTest
extends GutTest


func _create_wheel() -> FakeWheel:
	var wheel := FakeWheel.new()
	wheel.wheel.inertia = 1.0
	return wheel


func _create_differential(diff_type: Differential.DIFF_TYPE) -> Differential:
	var differential := Differential.new()

	var parameters := DiffParameters.new()
	parameters.diff_type = diff_type

	differential.initialise(parameters)

	return differential


func test_open_differential_applies_torque_to_both_wheels() -> void:
	var left := _create_wheel()
	var right := _create_wheel()

	var differential := _create_differential(
		Differential.DIFF_TYPE.OPEN_DIFF
	)

	var wheels := [
		left,
		right
	]

	var torque := 100.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		wheels,
		0.0,
		1.0,
		delta
	)

	assert_gt(left.get_spin(), 0.0)
	assert_gt(right.get_spin(), 0.0)


func test_open_differential_splits_torque_between_wheels() -> void:
	var left := _create_wheel()
	var right := _create_wheel()

	var differential := _create_differential(
		Differential.DIFF_TYPE.OPEN_DIFF
	)

	var wheels := [
		left,
		right
	]

	var torque := 100.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		wheels,
		0.0,
		1.0,
		delta
	)

	assert_almost_eq(
		left.get_spin(),
		right.get_spin(),
		0.000001
	)


func test_locked_differential_accelerates_both_wheels() -> void:
	var left := _create_wheel()
	var right := _create_wheel()

	var differential := _create_differential(
		Differential.DIFF_TYPE.LOCKED
	)

	var wheels := [
		left,
		right
	]

	var torque := 100.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		wheels,
		0.0,
		1.0,
		delta
	)

	assert_gt(left.get_spin(), 0.0)
	assert_gt(right.get_spin(), 0.0)

	assert_almost_eq(
		left.get_spin(),
		right.get_spin(),
		0.000001
	)


func test_locked_differential_acceleration_matches_total_inertia() -> void:
	var left := _create_wheel()
	var right := _create_wheel()

	left.wheel.inertia = 2.0
	right.wheel.inertia = 3.0

	var differential := _create_differential(
		Differential.DIFF_TYPE.LOCKED
	)

	var wheels := [
		left,
		right
	]

	var torque := 100.0
	var drive_inertia := 5.0
	var delta := 0.1

	differential.apply_torque(
		torque,
		wheels,
		drive_inertia,
		1.0,
		delta
	)

	var expected_acceleration := (
		torque /
		(
			drive_inertia +
			left.wheel.inertia +
			right.wheel.inertia
		)
	)

	var expected_spin := (
		expected_acceleration *
		delta
	)

	assert_almost_eq(
		left.get_spin(),
		expected_spin,
		0.000001
	)

	assert_almost_eq(
		right.get_spin(),
		expected_spin,
		0.000001
	)
