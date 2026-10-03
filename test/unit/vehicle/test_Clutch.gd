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
		200.0
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
		200.0
	)

	assert_float_eq(
		reaction_torques.x,
		0.0
	)
	assert_float_eq(
		reaction_torques.y,
		0.0
	)


func test_small_speed_difference_produces_no_reaction_torque() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.1,
		10.0,
		0.0,
		0.0,
		200.0
	)

	assert_float_eq(
		reaction_torques.x,
		0.0
	)
	assert_float_eq(
		reaction_torques.y,
		0.0
	)


func test_engine_faster_than_gearbox_reacts_against_engine() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.0,
		5.0,
		0.0,
		0.0,
		200.0
	)

	assert_float_eq(
		reaction_torques.x,
		-250.0
	)

	assert_float_eq(
		reaction_torques.y,
		250.0
	)

func test_gearbox_faster_than_engine_reacts_against_gearbox() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		5.0,
		10.0,
		0.0,
		0.0,
		200.0
	)

	assert_float_eq(
		reaction_torques.x,
		-250.0
	)
	assert_float_eq(
		reaction_torques.y,
		250.0
	)


func test_kick_increases_clutch_torque() -> void:
	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.0,
		5.0,
		0.0,
		0.0,
		200.0,
		100.0
	)

	assert_float_eq(
		reaction_torques.x,
		350.0
	)
	assert_float_eq(
		reaction_torques.y,
		-350.0
	)


func test_locking_occurs_when_speed_difference_is_small() -> void:
	clutch.locked = false

	var reaction_torques: Vector2 = clutch.get_reaction_torques(
		10.1,
		10.0,
		0.0,
		0.0,
		200.0
	)

	assert_true(
		clutch.locked
	)

	assert_float_eq(
		reaction_torques.x,
		0.0
	)

	assert_float_eq(
		reaction_torques.y,
		0.0
	)
