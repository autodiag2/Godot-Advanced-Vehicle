extends GutTest

var tire: BaseTireModel


func before_each():
	tire = BaseTireModel.new()


func test_initial_wear():
	assert_eq(tire.tire_wear, 0.0)


func test_rolling_resistance_at_rest():
	assert_eq(tire.get_rolling_resistance(1000.0, 0.0), 0.0)


func test_rolling_resistance_forward():
	assert_eq(tire.get_rolling_resistance(1000.0, 10.0), -10.0)


func test_rolling_resistance_backward():
	assert_eq(tire.get_rolling_resistance(1000.0, -10.0), 10.0)


func test_wear_increases():
	var wear : float = tire.update_tire_wear(
		1.0,
		Vector2(1.0, 0.0),
		1000.0,
		1.0
	)

	assert_gt(wear, 0.0)
