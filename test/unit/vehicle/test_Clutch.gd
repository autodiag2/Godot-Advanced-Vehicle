extends GutTest


var clutch: Clutch


func before_each() -> void:
	clutch = Clutch.new()


func assert_float_eq(one: float, two: float, threshold: float = 0.000001) -> void:
	assert_almost_eq(
		one,
		two,
		threshold
	)


func test_equal_zero_speed_produces_no_reaction_torque() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		0.0,
		0.0,
		0.0,
		0.0,
		1.0,
		1.0,
		0.0
	)

	assert_float_eq(
		reaction_torques.x,
		0.0
	)
	assert_float_eq(
		reaction_torques.y,
		0.0
	)


func test_equal_speed_produces_no_reaction_torque() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.0,
		10.0,
		0.0,
		0.0,
		1.0,
		1.0,
		0.0
	)

	assert_float_eq(
		reaction_torques.x,
		0.0
	)
	assert_float_eq(
		reaction_torques.y,
		0.0
	)


func test_small_speed_difference_produces_locked_reaction_torque() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.1,
		10.0,
		100.0,
		0.0,
		1.0,
		1.0,
		0.0
	)

	# alpha = (100 - 0) / (1 + 1) = 50 rad/s²
	# Tc = 0 + 1 * 50 = 50 Nm
	assert_float_eq(
		reaction_torques.x,
		50.0
	)

	assert_float_eq(
		reaction_torques.y,
		-50.0
	)


func test_engine_faster_than_powertrain_reacts_against_engine() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.0,
		5.0,
		100.0,
		0.0,
		1.0,
		1.0,
		0.0
	)

	assert_float_eq(
		reaction_torques.x,
		250.0
	)

	assert_float_eq(
		reaction_torques.y,
		-250.0
	)


func test_powertrain_faster_than_engine_reacts_against_powertrain() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		5.0,
		10.0,
		0.0,
		100.0,
		1.0,
		1.0,
		0.0
	)

	assert_float_eq(
		reaction_torques.x,
		-250.0
	)

	assert_float_eq(
		reaction_torques.y,
		250.0
	)


func test_clutch_input_reduces_maximum_torque() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.0,
		5.0,
		1000.0,
		0.0,
		1.0,
		1.0,
		0.5
	)

	assert_float_eq(
		reaction_torques.x,
		125.0
	)

	assert_float_eq(
		reaction_torques.y,
		-125.0
	)


func test_fully_disengaged_clutch_produces_no_torque() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.0,
		5.0,
		1000.0,
		0.0,
		1.0,
		1.0,
		1.0
	)

	assert_float_eq(
		reaction_torques.x,
		0.0
	)

	assert_float_eq(
		reaction_torques.y,
		0.0
	)


func test_locked_clutch_uses_both_inertias() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.1,
		10.0,
		100.0,
		20.0,
		2.0,
		3.0,
		0.0
	)

	# alpha = (100 - 20) / (2 + 3) = 16 rad/s²
	# Tc = 20 + 3 * 16 = 68 Nm
	assert_float_eq(
		reaction_torques.x,
		68.0
	)

	assert_float_eq(
		reaction_torques.y,
		-68.0
	)


func test_reaction_torques_are_equal_and_opposite() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.0,
		5.0,
		100.0,
		0.0,
		1.0,
		1.0,
		0.0
	)

	assert_float_eq(
		reaction_torques.x,
		-reaction_torques.y
	)
