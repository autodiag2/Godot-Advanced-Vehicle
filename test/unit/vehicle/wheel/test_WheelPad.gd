extends GutTest


var pad: WheelPad

func assert_float_eq(one: float, two: float, threshold: float = 0.000001) -> void:
	assert_almost_eq(
		one,
		two,
		threshold
	)

func before_each() -> void:
	pad = WheelPad.new()


func test_default_values() -> void:
	assert_eq(pad.friction, 0.4)
	assert_eq(pad.min_friction, 0.2)
	assert_eq(pad.usage, 0.0)
	assert_eq(pad.max_usage_energy, 1000000.0)


func test_get_friction_at_zero_usage() -> void:
	pad.friction = 0.4
	pad.min_friction = 0.2
	pad.usage = 0.0

	assert_eq(
		pad.get_friction(),
		0.4
	)


func test_get_friction_at_half_usage() -> void:
	pad.friction = 0.4
	pad.min_friction = 0.2
	pad.usage = 0.5

	assert_almost_eq(
		pad.get_friction(),
		0.3,
		0.000001
	)


func test_get_friction_at_full_usage() -> void:
	pad.friction = 0.4
	pad.min_friction = 0.2
	pad.usage = 1.0

	assert_eq(
		pad.get_friction(),
		0.2
	)


func test_calculate_braking_force_at_zero_usage() -> void:
	pad.friction = 0.4
	pad.min_friction = 0.2
	pad.usage = 0.0

	var force := pad.calculate_braking_force(1000.0)

	assert_eq(
		force,
		400.0
	)


func test_calculate_braking_force_decreases_with_usage() -> void:
	pad.friction = 0.4
	pad.min_friction = 0.2

	pad.usage = 0.0
	var new_force := pad.calculate_braking_force(1000.0)

	pad.usage = 0.5
	var half_force := pad.calculate_braking_force(1000.0)

	pad.usage = 1.0
	var worn_force := pad.calculate_braking_force(1000.0)

	assert_gt(new_force, half_force)
	assert_gt(half_force, worn_force)

	assert_float_eq(new_force, 400.0)
	assert_float_eq(half_force, 300.0)
	assert_float_eq(worn_force, 200.0)
	
func test_update_usage_increases_usage() -> void:
	pad.max_usage_energy = 1000.0

	pad.update_usage(
		100.0,
		10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		1.0
	)


func test_update_usage_accumulates_energy() -> void:
	pad.max_usage_energy = 100000.0

	pad.update_usage(
		100.0,
		10.0,
		1.0
	)

	assert_almost_eq(
		pad.usage,
		0.01,
		0.000001
	)

	pad.update_usage(
		100.0,
		10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		0.02
	)


func test_update_usage_uses_absolute_energy() -> void:
	pad.max_usage_energy = 100000.0

	pad.update_usage(
		-100.0,
		10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		0.01
	)

	pad.update_usage(
		100.0,
		-10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		0.02
	)


func test_update_usage_does_nothing_with_zero_delta() -> void:
	pad.usage = 0.25

	pad.update_usage(
		100.0,
		10.0,
		0.0
	)

	assert_eq(
		pad.usage,
		0.25
	)


func test_update_usage_does_nothing_with_negative_delta() -> void:
	pad.usage = 0.25

	pad.update_usage(
		100.0,
		10.0,
		-1.0
	)

	assert_eq(
		pad.usage,
		0.25
	)


func test_update_usage_saturates_at_one() -> void:
	pad.max_usage_energy = 1000.0

	pad.update_usage(
		1000.0,
		10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		1.0
	)

	pad.update_usage(
		1000.0,
		10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		1.0
	)


func test_zero_brake_torque_does_not_increase_usage() -> void:
	pad.max_usage_energy = 1000.0

	pad.update_usage(
		0.0,
		100.0,
		1.0
	)

	assert_eq(
		pad.usage,
		0.0
	)


func test_zero_spin_does_not_increase_usage() -> void:
	pad.max_usage_energy = 1000.0

	pad.update_usage(
		100.0,
		0.0,
		1.0
	)

	assert_eq(
		pad.usage,
		0.0
	)


func test_braking_force_uses_minimum_friction_when_fully_worn() -> void:
	pad.friction = 0.5
	pad.min_friction = 0.1
	pad.usage = 1.0

	assert_almost_eq(
		pad.get_friction(),
		0.1,
		0.000001
	)

	assert_almost_eq(
		pad.calculate_braking_force(1000.0),
		100.0,
		0.000001
	)

func test_usage_does_not_change_when_max_usage_energy_is_zero() -> void:
	pad.max_usage_energy = 0.0

	pad.update_usage(
		100.0,
		10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		0.0
	)


func test_usage_does_not_change_when_max_usage_energy_is_negative() -> void:
	pad.max_usage_energy = -1.0

	pad.update_usage(
		100.0,
		10.0,
		1.0
	)

	assert_eq(
		pad.usage,
		0.0
	)
