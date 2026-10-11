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


func test_powertrain_faster_than_engine_synchronizes_with_sufficient_clutch_torque() -> void:
	var reaction_torques := clutch.get_reaction_torques(
		5.0, 10.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	assert_float_eq(reaction_torques.x, -25.0)
	assert_float_eq(reaction_torques.y, 25.0)


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

func test_realistic_slipping_clutch_reduces_relative_speed() -> void:
	var engine_av := 100.0
	var drivetrain_av := 0.0
	var engine_inertia := 1.0
	var drivetrain_inertia := 1.0
	var delta := 0.01

	var reaction_torques := clutch.get_reaction_torques(
		engine_av,
		drivetrain_av,
		0.0,
		0.0,
		engine_inertia,
		drivetrain_inertia,
		0.0,
		delta
	)

	var next_engine_av := engine_av + reaction_torques.y / engine_inertia * delta
	var next_drivetrain_av := drivetrain_av + reaction_torques.x / drivetrain_inertia * delta

	assert_lt(
		absf(next_engine_av - next_drivetrain_av),
		absf(engine_av - drivetrain_av)
	)


func test_realistic_clutch_does_not_reverse_relative_speed_when_slipping() -> void:
	var engine_av := 10.0
	var drivetrain_av := 0.0
	var delta := 0.01

	var reaction_torques := clutch.get_reaction_torques(
		engine_av,
		drivetrain_av,
		0.0,
		0.0,
		1.0,
		1.0,
		0.0,
		delta
	)

	var next_engine_av := engine_av + reaction_torques.y * delta
	var next_drivetrain_av := drivetrain_av + reaction_torques.x * delta

	assert_gte(
		next_engine_av - next_drivetrain_av,
		0.0,
		"Slipping clutch should not reverse the relative shaft speed in one step."
	)


func test_realistic_clutch_torque_opposes_relative_rotation() -> void:
	var engine_faster := clutch.get_reaction_torques(
		20.0, 5.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.01
	)

	assert_lte(engine_faster.y, 0.0)
	assert_gte(engine_faster.x, 0.0)

	var drivetrain_faster := clutch.get_reaction_torques(
		5.0, 20.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.01
	)

	assert_gte(drivetrain_faster.y, 0.0)
	assert_lte(drivetrain_faster.x, 0.0)


func test_realistic_fully_engaged_clutch_synchronizes_when_capacity_is_sufficient() -> void:
	var engine_av := 10.0
	var drivetrain_av := 9.0
	var engine_inertia := 2.0
	var drivetrain_inertia := 3.0
	var delta := 0.1

	var reaction_torques := clutch.get_reaction_torques(
		engine_av,
		drivetrain_av,
		0.0,
		0.0,
		engine_inertia,
		drivetrain_inertia,
		0.0,
		delta
	)

	var next_engine_av := engine_av + reaction_torques.y / engine_inertia * delta
	var next_drivetrain_av := drivetrain_av + reaction_torques.x / drivetrain_inertia * delta

	assert_almost_eq(
		next_engine_av,
		next_drivetrain_av,
		0.000001,
		"With sufficient clutch capacity, the shafts should synchronize."
	)
	assert_true(clutch.is_locked())


func test_realistic_clutch_torque_decreases_as_clutch_is_disengaged() -> void:
	var fully_engaged := clutch.get_reaction_torques(
		20.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.01
	)

	var half_engaged := clutch.get_reaction_torques(
		20.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5, 0.01
	)

	var fully_disengaged := clutch.get_reaction_torques(
		20.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.01
	)

	assert_gt(absf(fully_engaged.x), absf(half_engaged.x))
	assert_gt(absf(half_engaged.x), absf(fully_disengaged.x))
	assert_float_eq(fully_disengaged.x, 0.0)


func test_realistic_clutch_conserves_angular_momentum_without_external_torque() -> void:
	var engine_inertia := 2.0
	var drivetrain_inertia := 3.0
	var engine_av := 100.0
	var drivetrain_av := 0.0
	var delta := 0.01

	var initial_momentum := (
		engine_inertia * engine_av +
		drivetrain_inertia * drivetrain_av
	)

	var reaction_torques := clutch.get_reaction_torques(
		engine_av,
		drivetrain_av,
		0.0,
		0.0,
		engine_inertia,
		drivetrain_inertia,
		0.0,
		delta
	)

	var next_engine_av := engine_av + reaction_torques.y / engine_inertia * delta
	var next_drivetrain_av := drivetrain_av + reaction_torques.x / drivetrain_inertia * delta

	var final_momentum := (
		engine_inertia * next_engine_av +
		drivetrain_inertia * next_drivetrain_av
	)

	assert_almost_eq(
		final_momentum,
		initial_momentum,
		0.000001,
		"Internal clutch torque must conserve total angular momentum."
	)


func test_realistic_clutch_lock_state_matches_synchronization_result() -> void:
	clutch.get_reaction_torques(
		10.0, 9.9, 0.0, 0.0, 1.0, 1.0, 0.0, 0.1
	)

	assert_true(clutch.is_locked())

	var slipping_torques := clutch.get_reaction_torques(
		10.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.01
	)

	assert_false(clutch.is_locked())
	assert_float_eq(slipping_torques.x, 250.0)

func test_realism_clutch_never_adds_energy_without_external_torque() -> void:
	var engine_inertia := 2.0
	var drivetrain_inertia := 3.0
	var engine_av := 100.0
	var drivetrain_av := 0.0
	var initial_energy := (
		0.5 * engine_inertia * engine_av * engine_av +
		0.5 * drivetrain_inertia * drivetrain_av * drivetrain_av
	)

	var reaction_torques := clutch.get_reaction_torques(
		engine_av, drivetrain_av,
		0.0, 0.0,
		engine_inertia, drivetrain_inertia,
		0.0, 0.01
	)

	var next_engine_av := engine_av + reaction_torques.y / engine_inertia * 0.01
	var next_drivetrain_av := drivetrain_av + reaction_torques.x / drivetrain_inertia * 0.01
	var final_energy := (
		0.5 * engine_inertia * next_engine_av * next_engine_av +
		0.5 * drivetrain_inertia * next_drivetrain_av * next_drivetrain_av
	)

	assert_lte(
		final_energy,
		initial_energy + 0.000001,
		"Passive clutch friction must not increase total rotational kinetic energy."
	)


func test_realism_clutch_conserves_angular_momentum_over_repeated_steps() -> void:
	var engine_inertia := 2.0
	var drivetrain_inertia := 3.0
	var engine_av := 100.0
	var drivetrain_av := 0.0
	var delta := 0.001

	var initial_momentum := engine_inertia * engine_av + drivetrain_inertia * drivetrain_av

	for i in range(100):
		var reaction_torques := clutch.get_reaction_torques(
			engine_av, drivetrain_av,
			0.0, 0.0,
			engine_inertia, drivetrain_inertia,
			0.0, delta
		)

		engine_av += reaction_torques.y / engine_inertia * delta
		drivetrain_av += reaction_torques.x / drivetrain_inertia * delta

	var final_momentum := engine_inertia * engine_av + drivetrain_inertia * drivetrain_av

	assert_almost_eq(
		final_momentum,
		initial_momentum,
		0.000001,
		"Equal-and-opposite internal torques must conserve angular momentum."
	)


func test_realism_clutch_slip_dissipates_energy_over_repeated_steps() -> void:
	var engine_inertia := 2.0
	var drivetrain_inertia := 3.0
	var engine_av := 100.0
	var drivetrain_av := 0.0
	var delta := 0.001

	var initial_energy := (
		0.5 * engine_inertia * engine_av * engine_av +
		0.5 * drivetrain_inertia * drivetrain_av * drivetrain_av
	)

	for i in range(100):
		var reaction_torques := clutch.get_reaction_torques(
			engine_av, drivetrain_av,
			0.0, 0.0,
			engine_inertia, drivetrain_inertia,
			0.0, delta
		)

		engine_av += reaction_torques.y / engine_inertia * delta
		drivetrain_av += reaction_torques.x / drivetrain_inertia * delta

	var final_energy := (
		0.5 * engine_inertia * engine_av * engine_av +
		0.5 * drivetrain_inertia * drivetrain_av * drivetrain_av
	)

	assert_lt(
		final_energy,
		initial_energy,
		"Clutch slip should dissipate kinetic energy until the shafts synchronize."
	)


func test_realism_clutch_never_reverses_relative_speed_while_slipping() -> void:
	var engine_av := 10.0
	var drivetrain_av := 0.0
	var delta := 0.01

	var reaction_torques := clutch.get_reaction_torques(
		engine_av, drivetrain_av,
		0.0, 0.0,
		1.0, 1.0,
		0.0, delta
	)

	engine_av += reaction_torques.y * delta
	drivetrain_av += reaction_torques.x * delta

	assert_gte(
		engine_av - drivetrain_av,
		0.0,
		"Clutch friction should not overshoot and reverse relative shaft speed in one step."
	)


func test_realism_locked_clutch_produces_common_final_speed() -> void:
	var engine_inertia := 2.0
	var drivetrain_inertia := 3.0
	var engine_av := 10.0
	var drivetrain_av := 9.9
	var delta := 0.1

	var reaction_torques := clutch.get_reaction_torques(
		engine_av, drivetrain_av,
		0.0, 0.0,
		engine_inertia, drivetrain_inertia,
		0.0, delta
	)

	engine_av += reaction_torques.y / engine_inertia * delta
	drivetrain_av += reaction_torques.x / drivetrain_inertia * delta

	assert_true(clutch.is_locked())
	assert_almost_eq(
		engine_av,
		drivetrain_av,
		0.000001,
		"A locked clutch must leave both shafts at the same speed."
	)


func test_realism_locked_clutch_common_speed_conserves_momentum() -> void:
	var engine_inertia := 2.0
	var drivetrain_inertia := 3.0
	var engine_av := 10.0
	var drivetrain_av := 9.9
	var delta := 0.1

	var initial_momentum := (
		engine_inertia * engine_av +
		drivetrain_inertia * drivetrain_av
	)

	var reaction_torques := clutch.get_reaction_torques(
		engine_av, drivetrain_av,
		0.0, 0.0,
		engine_inertia, drivetrain_inertia,
		0.0, delta
	)

	engine_av += reaction_torques.y / engine_inertia * delta
	drivetrain_av += reaction_torques.x / drivetrain_inertia * delta

	var final_momentum := (
		engine_inertia * engine_av +
		drivetrain_inertia * drivetrain_av
	)

	assert_almost_eq(
		final_momentum,
		initial_momentum,
		0.000001,
		"Clutch synchronization must conserve total angular momentum."
	)


func test_realism_fully_disengaged_clutch_does_not_change_shaft_speeds() -> void:
	var engine_av := 100.0
	var drivetrain_av := 0.0
	var delta := 0.01

	var reaction_torques := clutch.get_reaction_torques(
		engine_av, drivetrain_av,
		0.0, 0.0,
		1.0, 1.0,
		1.0, delta
	)

	engine_av += reaction_torques.y * delta
	drivetrain_av += reaction_torques.x * delta

	assert_float_eq(engine_av, 100.0)
	assert_float_eq(drivetrain_av, 0.0)

func test_realism_clutch_capacity_boundary_controls_lock_state() -> void:
	var synchronizing_torque := clutch.friction

	var exactly_at_limit := clutch.get_reaction_torques(
		10.0, 0.0,
		0.0, 0.0,
		1.0, 1.0,
		0.0, 0.02
	)

	assert_float_eq(exactly_at_limit.x, synchronizing_torque)
	assert_true(clutch.is_locked())

	var above_limit := clutch.get_reaction_torques(
		10.0, 0.0,
		0.0, 0.0,
		1.0, 1.0,
		0.0, 0.019
	)

	assert_float_eq(above_limit.x, synchronizing_torque)
	assert_false(clutch.is_locked())
