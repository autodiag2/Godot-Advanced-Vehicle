extends GutTest

var tire: CurveTireModel


func before_each():
	tire = CurveTireModel.new()


func test_zero_slip_produces_zero_force():
	var forces := tire.update_tire_forces(Vector2.ZERO, 1000.0)

	assert_almost_eq(forces.x, 0.0, 0.000001)
	assert_almost_eq(forces.y, 0.0, 0.000001)


func test_positive_longitudinal_slip_produces_positive_force():
	var forces := tire.update_tire_forces(Vector2(0.01, 0.0), 1000.0)

	assert_gt(forces.x, 0.0)


func test_negative_longitudinal_slip_produces_negative_force():
	var forces := tire.update_tire_forces(Vector2(-0.01, 0.0), 1000.0)

	assert_lt(forces.x, 0.0)


func test_positive_lateral_slip_produces_positive_force():
	var forces := tire.update_tire_forces(Vector2(0.0, 0.01), 1000.0)

	assert_gt(forces.y, 0.0)


func test_negative_lateral_slip_produces_negative_force():
	var forces := tire.update_tire_forces(Vector2(0.0, -0.01), 1000.0)

	assert_lt(forces.y, 0.0)


func test_zero_normal_load_produces_zero_force():
	var forces := tire.update_tire_forces(Vector2(0.1, 0.1), 0.0)

	assert_almost_eq(forces.x, 0.0, 0.000001)
	assert_almost_eq(forces.y, 0.0, 0.000001)


func test_force_scales_with_normal_load():
	var forces1 := tire.update_tire_forces(Vector2(0.01, 0.0), 1000.0)
	var forces2 := tire.update_tire_forces(Vector2(0.01, 0.0), 2000.0)

	assert_gt(forces1.x, 0.0)
	assert_gt(forces2.x, forces1.x)


func test_surface_mu_scales_force():
	var forces1 := tire.update_tire_forces(Vector2(0.01, 0.0), 1000.0, 1.0)
	var forces2 := tire.update_tire_forces(Vector2(0.01, 0.0), 1000.0, 0.5)

	assert_gt(forces1.x, forces2.x)
	assert_almost_eq(forces2.x / forces1.x, 0.5, 0.001)


func test_zero_surface_mu_produces_zero_force():
	var forces := tire.update_tire_forces(Vector2(0.1, 0.1), 1000.0, 0.0)

	assert_almost_eq(forces.x, 0.0, 0.000001)
	assert_almost_eq(forces.y, 0.0, 0.000001)


func test_longitudinal_force_has_correct_sign_after_peak():
	var peak_sa := deg_to_rad(7.5)
	var slip := Vector2(peak_sa * 2.0, 0.0)

	var forces := tire.update_tire_forces(slip, 1000.0)

	assert_gt(forces.x, 0.0)


func test_lateral_force_has_correct_sign_after_peak():
	var peak_sa := deg_to_rad(7.5)
	var peak_sr := peak_sa * 0.65
	var slip := Vector2(0.0, peak_sr * 2.0)

	var forces := tire.update_tire_forces(slip, 1000.0)

	assert_gt(forces.y, 0.0)


func test_stiffness_changes_peak_slip_angle():
	tire.tire_stiffness = 0.0
	var low_stiffness_force := tire.update_tire_forces(
		Vector2(deg_to_rad(5.0), 0.0),
		1000.0
	)

	tire.tire_stiffness = 1.0
	var high_stiffness_force := tire.update_tire_forces(
		Vector2(deg_to_rad(5.0), 0.0),
		1000.0
	)

	assert_ne(low_stiffness_force.x, high_stiffness_force.x)


func test_combined_slip_produces_both_force_components():
	var forces := tire.update_tire_forces(
		Vector2(0.01, 0.01),
		1000.0
	)

	assert_ne(forces.x, 0.0)
	assert_ne(forces.y, 0.0)


func test_combined_slip_force_direction_matches_slip():
	var slip := Vector2(0.01, 0.01)
	var forces := tire.update_tire_forces(slip, 1000.0)

	assert_gt(forces.x, 0.0)
	assert_gt(forces.y, 0.0)


func test_wear_reduces_force():
	var slip := Vector2(0.01, 0.0)

	tire.tire_wear = 0.0
	var new_tire_force := tire.update_tire_forces(slip, 1000.0)

	tire.tire_wear = 1.0
	var worn_tire_force := tire.update_tire_forces(slip, 1000.0)

	assert_lt(worn_tire_force.x, new_tire_force.x)


func test_temperature_affects_force():
	var slip := Vector2(0.01, 0.0)

	tire.tire_temp = tire.opt_tire_temp
	var optimal_temp_force := tire.update_tire_forces(slip, 1000.0)

	tire.tire_temp = tire.max_tire_temp
	var hot_tire_force := tire.update_tire_forces(slip, 1000.0)

	assert_ne(optimal_temp_force.x, hot_tire_force.x)


func test_load_sensitivity_is_updated():
	tire.update_tire_forces(Vector2.ZERO, tire.tire_rated_load)

	assert_almost_eq(tire.load_sensitivity, tire.load_sens1, 0.000001)

func test_zero_slip_has_no_nan_or_inf():
	var forces := tire.update_tire_forces(Vector2.ZERO, 1000.0)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_force_is_finite_for_large_slip():
	var forces := tire.update_tire_forces(Vector2(1000.0, 1000.0), 1000.0)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_force_is_finite_for_negative_load():
	var forces := tire.update_tire_forces(Vector2(0.1, 0.1), -1000.0)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_force_is_finite_for_zero_load():
	var forces := tire.update_tire_forces(Vector2(0.1, 0.1), 0.0)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_force_symmetry_for_longitudinal_slip():
	var positive := tire.update_tire_forces(Vector2(0.05, 0.0), 1000.0)
	var negative := tire.update_tire_forces(Vector2(-0.05, 0.0), 1000.0)

	assert_almost_eq(positive.x, -negative.x, 0.000001)


func test_force_symmetry_for_lateral_slip():
	var positive := tire.update_tire_forces(Vector2(0.0, 0.05), 1000.0)
	var negative := tire.update_tire_forces(Vector2(0.0, -0.05), 1000.0)

	assert_almost_eq(positive.y, -negative.y, 0.000001)


func test_force_does_not_jump_at_longitudinal_peak():
	var normal_load := 1000.0
	var peak_sa := deg_to_rad(7.5)
	var epsilon := 0.000001

	var before := tire.update_tire_forces(
		Vector2(peak_sa - epsilon, 0.0),
		normal_load
	)

	var after := tire.update_tire_forces(
		Vector2(peak_sa + epsilon, 0.0),
		normal_load
	)

	var jump : float = abs(after.x - before.x)

	assert_lt(jump, normal_load * 0.1)


func test_force_does_not_jump_at_lateral_peak():
	var normal_load := 1000.0
	var peak_sa := deg_to_rad(7.5)
	var peak_sr := peak_sa * 0.65
	var epsilon := 0.000001

	var before := tire.update_tire_forces(
		Vector2(0.0, peak_sr - epsilon),
		normal_load
	)

	var after := tire.update_tire_forces(
		Vector2(0.0, peak_sr + epsilon),
		normal_load
	)

	var jump : float = abs(after.y - before.y)

	assert_lt(jump, normal_load * 0.1)


func test_tiny_slip_does_not_produce_large_force():
	var forces := tire.update_tire_forces(
		Vector2(0.000001, 0.000001),
		1000.0
	)

	assert_lt(abs(forces.x), 10.0)
	assert_lt(abs(forces.y), 10.0)


func test_force_does_not_increase_when_wear_is_maximum():
	var slip := Vector2(0.02, 0.0)

	tire.tire_wear = 0.0
	var fresh := tire.update_tire_forces(slip, 1000.0)

	tire.tire_wear = 1.0
	var worn := tire.update_tire_forces(slip, 1000.0)

	assert_lte(abs(worn.x), abs(fresh.x))


func test_force_does_not_increase_with_zero_friction():
	var forces := tire.update_tire_forces(
		Vector2(1.0, 1.0),
		1000.0,
		0.0
	)

	assert_almost_eq(forces.length(), 0.0, 0.000001)


func test_zero_load_does_not_create_force_from_load_sensitivity():
	var forces := tire.update_tire_forces(
		Vector2(1.0, 1.0),
		0.0,
		1.0
	)

	assert_almost_eq(forces.length(), 0.0, 0.000001)


func test_above_rated_load_has_finite_force():
	var forces := tire.update_tire_forces(
		Vector2(0.1, 0.1),
		tire.tire_rated_load * 10.0
	)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_negative_slip_does_not_change_force_magnitude():
	var positive := tire.update_tire_forces(
		Vector2(0.1, 0.05),
		1000.0
	)

	var negative := tire.update_tire_forces(
		Vector2(-0.1, -0.05),
		1000.0
	)

	assert_almost_eq(positive.length(), negative.length(), 0.000001)


func test_extreme_stiffness_remains_finite():
	tire.tire_stiffness = 0.0
	var low := tire.update_tire_forces(Vector2(0.1, 0.1), 1000.0)

	tire.tire_stiffness = 1.0
	var high := tire.update_tire_forces(Vector2(0.1, 0.1), 1000.0)

	assert_false(is_nan(low.x))
	assert_false(is_nan(low.y))
	assert_false(is_nan(high.x))
	assert_false(is_nan(high.y))
