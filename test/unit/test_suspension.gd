extends GutTest

var suspension: SuspensionController


func before_each():
	suspension = SuspensionController.new()


func test_initial_state():
	assert_eq(suspension.spring_length, 0.2)
	assert_eq(suspension.spring_stiffness, 45.0)
	assert_eq(suspension.bump, 3.5)
	assert_eq(suspension.rebound, 4.0)
	assert_eq(suspension.anti_roll, 0.0)

	assert_eq(suspension.current_length, 0.2)
	assert_eq(suspension.load_mm, 0.0)
	assert_eq(suspension.previous_load_mm, 0.0)
	assert_eq(suspension.speed_mm_per_second, 0.0)
	assert_eq(suspension.load_newton, 0.0)


func test_setup_changes_parameters():
	suspension.setup(
		0.3,
		50.0,
		4.0,
		5.0,
		10.0
	)

	assert_eq(suspension.spring_length, 0.3)
	assert_eq(suspension.spring_stiffness, 50.0)
	assert_eq(suspension.bump, 4.0)
	assert_eq(suspension.rebound, 5.0)
	assert_eq(suspension.anti_roll, 10.0)
	assert_eq(suspension.current_length, 0.3)


func test_no_compression_produces_zero_load():
	var load := suspension.update(
		0.2,
		0.0,
		0.01
	)

	assert_eq(load, 0.0)
	assert_eq(suspension.load_mm, 0.0)
	assert_eq(suspension.load_newton, 0.0)


func test_compression_produces_spring_and_bump_load():
	var load := suspension.update(
		0.1,
		0.0,
		0.1
	)

	assert_eq(suspension.load_mm, 100.0)
	assert_eq(suspension.speed_mm_per_second, 1000.0)

	# Spring: 100 * 45 = 4500 N
	# Bump: 1000 * 3.5 = 3500 N
	# Total: 8000 N
	assert_eq(load, 8000.0)


func test_full_compression():
	var load := suspension.update(
		0.0,
		0.0,
		0.1
	)

	assert_eq(suspension.load_mm, 200.0)
	assert_eq(suspension.speed_mm_per_second, 2000.0)

	# Spring: 200 * 45 = 9000 N
	# Bump: 2000 * 3.5 = 7000 N
	# Total: 16000 N
	assert_eq(load, 16000.0)


func test_extension_does_not_produce_negative_load():
	var load := suspension.update(
		0.3,
		0.0,
		0.1
	)

	assert_almost_eq(
		suspension.load_mm,
		-100.0,
		0.000001
	)
	assert_eq(load, 0.0)
	assert_eq(suspension.load_newton, 0.0)


func test_bump_damping_during_compression():
	suspension.setup(
		0.2,
		45.0,
		3.5,
		4.0,
		0.0
	)

	suspension.update(
		0.2,
		0.0,
		0.1
	)

	var load := suspension.update(
		0.1,
		0.0,
		0.1
	)

	assert_eq(suspension.load_mm, 100.0)
	assert_eq(suspension.speed_mm_per_second, 1000.0)
	assert_eq(load, 8000.0)


func test_rebound_damping_during_extension():
	suspension.setup(
		0.2,
		45.0,
		3.5,
		4.0,
		0.0
	)

	suspension.update(
		0.1,
		0.0,
		0.1
	)

	var load := suspension.update(
		0.15,
		0.0,
		0.1
	)

	assert_almost_eq(
		suspension.load_mm,
		50.0,
		0.000001
	)

	assert_almost_eq(
		suspension.speed_mm_per_second,
		-500.0,
		0.000001
	)

	var expected := 50.0 * 45.0 - 500.0 * 4.0

	assert_almost_eq(
		load,
		250.0,
		0.000001
	)

	assert_almost_eq(
		load,
		expected,
		0.000001
	)


func test_anti_roll_adds_force_when_wheels_have_different_compression():
	suspension.setup(
		0.2,
		45.0,
		3.5,
		4.0,
		10.0
	)

	var load := suspension.update(
		0.1,
		50.0,
		0.1
	)

	var expected_spring := 100.0 * 45.0
	var expected_bump := 1000.0 * 3.5
	var expected_anti_roll := 10.0 * (100.0 - 50.0)
	var expected := (
		expected_spring +
		expected_bump +
		expected_anti_roll
	)

	assert_eq(suspension.load_mm, 100.0)
	assert_eq(load, expected)
	assert_eq(load, 8500.0)


func test_anti_roll_can_reduce_force():
	suspension.setup(
		0.2,
		45.0,
		3.5,
		4.0,
		10.0
	)

	var load := suspension.update(
		0.1,
		200.0,
		0.1
	)

	var expected_spring := 100.0 * 45.0
	var expected_bump := 1000.0 * 3.5
	var expected_anti_roll := 10.0 * (100.0 - 200.0)
	var expected := (
		expected_spring +
		expected_bump +
		expected_anti_roll
	)

	assert_eq(suspension.load_mm, 100.0)
	assert_eq(load, expected)
	assert_eq(load, 7000.0)


func test_anti_roll_negative_force_is_clamped_to_zero():
	suspension.setup(
		0.2,
		45.0,
		3.5,
		4.0,
		100.0
	)

	var load := suspension.update(
		0.1,
		200.0,
		0.1
	)

	assert_eq(suspension.load_mm, 100.0)
	assert_eq(load, 0.0)
	assert_eq(suspension.load_newton, 0.0)


func test_zero_delta_produces_non_finite_speed():
	suspension.update(
		0.1,
		0.0,
		0.0
	)

	assert_true(
		not is_finite(suspension.speed_mm_per_second)
	)
