extends GutTest


var clutch: Clutch


func before_each() -> void:
	clutch = Clutch.new()


func assert_float_eq(one: float, two: float, threshold: float = 0.000001) -> void:
	assert_almost_eq(one, two, threshold)


func test_equal_zero_speed_produces_no_reaction_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	assert_float_eq(reaction_torques.x, 0.0)
	assert_float_eq(reaction_torques.y, 0.0)


func test_equal_speed_produces_no_reaction_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.0, 10.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	assert_float_eq(reaction_torques.x, 0.0)
	assert_float_eq(reaction_torques.y, 0.0)


func test_small_speed_difference_calculates_synchronizing_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.1, 10.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	# Required torque = (0.1 / 0.1) / (1 / 1 + 1 / 1) = 0.5 Nm.
	assert_float_eq(reaction_torques.x, 0.5)
	assert_float_eq(reaction_torques.y, -0.5)
	assert_true(clutch.is_locked())


func test_engine_faster_than_powertrain_limited_by_clutch_friction() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.0, 5.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	assert_float_eq(reaction_torques.x, 25.0)
	assert_float_eq(reaction_torques.y, -25.0)


func test_powertrain_faster_than_engine_limited_by_clutch_friction() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		5.0, 10.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	assert_float_eq(reaction_torques.x, -25.0)
	assert_float_eq(reaction_torques.y, 25.0)
	assert_false(clutch.is_locked())


func test_clutch_input_reduces_maximum_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.0, 5.0, 0.0, 0.0, 1.0, 1.0, 0.5, 0.1
	)

	assert_float_eq(reaction_torques.x, 25.0)
	assert_float_eq(reaction_torques.y, -25.0)
	assert_true(clutch.is_locked())

func test_fully_disengaged_clutch_produces_no_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.0, 5.0, 1000.0, 0.0, 1.0, 1.0, 1.0, 0.1
	)

	assert_float_eq(reaction_torques.x, 0.0)
	assert_float_eq(reaction_torques.y, 0.0)
	assert_false(clutch.is_locked())


func test_synchronizing_torque_uses_both_inertias() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.1, 10.0, 0.0, 0.0, 2.0, 3.0, 0.0, 0.1
	)

	# Required torque = (0.1 / 0.1) / (1 / 2 + 1 / 3) = 1.2 Nm.
	assert_float_eq(reaction_torques.x, 1.2)
	assert_float_eq(reaction_torques.y, -1.2)
	assert_true(clutch.is_locked())


func test_external_torques_are_included_in_synchronizing_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.1, 10.0, 100.0, 20.0, 2.0, 3.0, 0.0, 0.1
	)


	assert_float_eq(reaction_torques.x, 53.2)
	assert_float_eq(reaction_torques.y, -53.2)
	assert_true(clutch.is_locked())

func test_reaction_torques_are_equal_and_opposite() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.0, 5.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	assert_float_eq(reaction_torques.x, -reaction_torques.y)


func test_zero_delta_produces_no_reaction_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.0, 5.0, 100.0, 0.0, 1.0, 1.0, 0.0, 0.0
	)

	assert_float_eq(reaction_torques.x, 0.0)
	assert_float_eq(reaction_torques.y, 0.0)

func test_clutch_torque_is_limited_by_friction() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		10.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.01
	)

	# Required synchronizing torque is 500 Nm, exceeding the 250 Nm limit.
	assert_float_eq(reaction_torques.x, 250.0)
	assert_float_eq(reaction_torques.y, -250.0)
	assert_false(clutch.is_locked())
