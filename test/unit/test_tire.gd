extends GutTest

var tire: TireModel


func before_each():
	tire = TireModel.new()


func test_initial_wear():
	assert_eq(tire.tire_wear, 0.0)


func test_rolling_resistance_at_rest():
	assert_eq(tire.get_rolling_resistance(1000.0, 0.0), 0.0)


func test_rolling_resistance_forward():
	assert_eq(tire.get_rolling_resistance(1000.0, 10.0), -10.0)


func test_rolling_resistance_backward():
	assert_eq(tire.get_rolling_resistance(1000.0, -10.0), 10.0)


func test_wear_increases():
	var wear: float = tire.update_tire_wear(
		1.0,
		Vector2(1.0, 0.0),
		1000.0,
		1.0
	)

	assert_gt(wear, 0.0)


func test_temperature_heats_with_slip():
	tire.tire_temp = 20.0

	var temperature : float = tire.update_tire_temp(
		Vector2(1.0, 0.0),
		1000.0,
		10.0,
		1.0,
		20.0,
		0.1
	)

	assert_gt(temperature, 20.0)


func test_temperature_does_not_cool_at_ambient():
	tire.tire_temp = 20.0

	var temperature : float = tire.update_tire_temp(
		Vector2.ZERO,
		1000.0,
		0.0,
		1.0,
		20.0,
		0.1
	)

	assert_eq(temperature, 20.0)


func test_temperature_cools_toward_ambient():
	tire.tire_temp = 50.0

	var temperature : float = tire.update_tire_temp(
		Vector2.ZERO,
		1000.0,
		0.0,
		1.0,
		20.0,
		0.1
	)

	assert_lt(temperature, 50.0)
	assert_gt(temperature, 20.0)


func test_temperature_allows_zero_ambient_temperature():
	tire.tire_temp = 50.0

	var temperature : float = tire.update_tire_temp(
		Vector2.ZERO,
		1000.0,
		0.0,
		1.0,
		0.0,
		0.1
	)

	assert_true(is_finite(temperature))
	assert_lt(temperature, 50.0)
