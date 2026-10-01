extends GutTest

var tire: CurveTireModel
const MIN_PEAK_SA_START_DEG = 3.0
const MAX_PEAK_SA_START_DEG = 12.0
const MIN_DELTA_SA_DEG = 1.0
const MAX_DELTA_SA_DEG = 4.0

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


func test_surface_mu_scales_force():
	var forces1 := tire.update_tire_forces(Vector2(0.01, 0.0), 1000.0, 1.0)
	var forces2 := tire.update_tire_forces(Vector2(0.01, 0.0), 1000.0, 0.5)

	assert_gt(forces1.x, forces2.x)
	assert_almost_eq(forces2.x / forces1.x, 0.5, 0.001)


func test_zero_surface_mu_produces_zero_force():
	var forces := tire.update_tire_forces(
		Vector2(0.1, 0.1),
		1000.0,
		0.0
	)

	assert_almost_eq(forces.x, 0.0, 0.000001)
	assert_almost_eq(forces.y, 0.0, 0.000001)


func test_pure_longitudinal_slip_produces_no_lateral_force():
	var forces := tire.update_tire_forces(
		Vector2(0.1, 0.0),
		1000.0
	)

	assert_almost_eq(forces.y, 0.0, 0.000001)


func test_pure_lateral_slip_produces_no_longitudinal_force():
	var forces := tire.update_tire_forces(
		Vector2(0.0, 0.1),
		1000.0
	)

	assert_almost_eq(forces.x, 0.0, 0.000001)


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


func test_combined_slip_reduces_longitudinal_force():
	var longitudinal := tire.update_tire_forces(
		Vector2(0.03, 0.0),
		1000.0
	)

	var combined := tire.update_tire_forces(
		Vector2(0.03, 0.03),
		1000.0
	)

	assert_lte(abs(combined.x), abs(longitudinal.x))


func test_combined_slip_reduces_lateral_force():
	var lateral := tire.update_tire_forces(
		Vector2(0.0, 0.03),
		1000.0
	)

	var combined := tire.update_tire_forces(
		Vector2(0.03, 0.03),
		1000.0
	)

	assert_lte(abs(combined.y), abs(lateral.y))


func test_force_symmetry_for_longitudinal_slip():
	var positive := tire.update_tire_forces(
		Vector2(0.05, 0.0),
		1000.0
	)

	var negative := tire.update_tire_forces(
		Vector2(-0.05, 0.0),
		1000.0
	)

	assert_almost_eq(positive.x, -negative.x, 0.000001)


func test_force_symmetry_for_lateral_slip():
	var positive := tire.update_tire_forces(
		Vector2(0.0, 0.05),
		1000.0
	)

	var negative := tire.update_tire_forces(
		Vector2(0.0, -0.05),
		1000.0
	)

	assert_almost_eq(positive.y, -negative.y, 0.000001)


func test_force_is_odd_function_of_slip():
	var slip := Vector2(0.03, 0.02)

	var positive := tire.update_tire_forces(slip, 1000.0)
	var negative := tire.update_tire_forces(-slip, 1000.0)

	assert_almost_eq(positive.x, -negative.x, 0.000001)
	assert_almost_eq(positive.y, -negative.y, 0.000001)

func test_force_magnitude_does_not_exceed_available_friction():
	var normal_load := 1000.0
	var surface_mu := 1.0

	var forces := tire.update_tire_forces(
		Vector2(100.0, 100.0),
		normal_load,
		surface_mu
	)

	var maximum_force := (
		normal_load *
		surface_mu *
		tire.load_sensitivity
	)

	assert_lte(forces.length(), maximum_force + 0.001)

func test_combined_slip_force_is_bounded_by_model_friction():
	var normal_load := 1000.0
	var surface_mu := 1.0

	var forces := tire.update_tire_forces(
		Vector2(0.1, 0.1),
		normal_load,
		surface_mu
	)

	var maximum_force := (
		normal_load *
		surface_mu *
		tire.load_sensitivity
	)

	assert_lte(forces.length(), maximum_force + 0.001)

func test_force_is_finite_for_zero_slip():
	var forces := tire.update_tire_forces(
		Vector2.ZERO,
		1000.0
	)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_force_is_finite_for_large_slip():
	var forces := tire.update_tire_forces(
		Vector2(1000.0, 1000.0),
		1000.0
	)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))

func test_force_is_finite_for_zero_load():
	var forces := tire.update_tire_forces(
		Vector2(0.1, 0.1),
		0.0
	)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_above_rated_load_has_finite_force():
	var forces := tire.update_tire_forces(
		Vector2(0.1, 0.1),
		tire.tire_rated_load * 10.0
	)

	assert_false(is_nan(forces.x))
	assert_false(is_nan(forces.y))
	assert_false(is_inf(forces.x))
	assert_false(is_inf(forces.y))


func test_tiny_slip_does_not_produce_large_force():
	var forces := tire.update_tire_forces(
		Vector2(0.000001, 0.000001),
		1000.0
	)

	assert_lt(abs(forces.x), 10.0)
	assert_lt(abs(forces.y), 10.0)


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


func test_extreme_stiffness_remains_finite():
	tire.tire_stiffness = 0.0
	var low := tire.update_tire_forces(
		Vector2(0.1, 0.1),
		1000.0
	)

	tire.tire_stiffness = 1.0
	var high := tire.update_tire_forces(
		Vector2(0.1, 0.1),
		1000.0
	)

	assert_false(is_nan(low.x))
	assert_false(is_nan(low.y))
	assert_false(is_inf(low.x))
	assert_false(is_inf(low.y))
	assert_false(is_nan(high.x))
	assert_false(is_nan(high.y))
	assert_false(is_inf(high.x))
	assert_false(is_inf(high.y))


func test_longitudinal_force_is_continuous_at_actual_peak():
	var normal_load := 1000.0
	var load_factor := normal_load / tire.tire_rated_load

	var peak_sa_deg : float = lerp(
		MAX_PEAK_SA_START_DEG,
		MIN_PEAK_SA_START_DEG,
		tire.tire_stiffness
	)

	var delta_sa_deg : float = lerp(
		MAX_DELTA_SA_DEG,
		MIN_DELTA_SA_DEG,
		tire.tire_stiffness
	)

	var sa0 := peak_sa_deg + 0.5 * delta_sa_deg
	var sa1 := peak_sa_deg - 0.5 * delta_sa_deg
	var peak_sa := deg_to_rad(lerp(sa1, sa0, load_factor))

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


func test_lateral_force_is_continuous_at_actual_peak():
	var normal_load := 1000.0
	var load_factor := normal_load / tire.tire_rated_load

	var peak_sa_deg : float = lerp(
		MAX_PEAK_SA_START_DEG,
		MIN_PEAK_SA_START_DEG,
		tire.tire_stiffness
	)

	var delta_sa_deg : float = lerp(
		MAX_DELTA_SA_DEG,
		MIN_DELTA_SA_DEG,
		tire.tire_stiffness
	)

	var sa0 : float = peak_sa_deg + 0.5 * delta_sa_deg
	var sa1 : float = peak_sa_deg - 0.5 * delta_sa_deg
	var peak_sa := deg_to_rad(lerp(sa1, sa0, load_factor))
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


func test_force_does_not_reverse_before_peak():
	var previous := 0.0

	for i in range(1, 20):
		var slip := float(i) * 0.001
		var forces := tire.update_tire_forces(
			Vector2(slip, 0.0),
			1000.0
		)

		assert_gte(forces.x, previous)

		previous = forces.x


func test_force_remains_non_negative_after_peak():
	for i in range(1, 100):
		var slip := float(i) * 0.01
		var forces := tire.update_tire_forces(
			Vector2(slip, 0.0),
			1000.0
		)

		assert_gte(forces.x, 0.0)


func test_wear_reduces_force():
	var slip := Vector2(0.01, 0.0)

	tire.tire_wear = 0.0
	var new_tire_force := tire.update_tire_forces(slip, 1000.0)

	tire.tire_wear = 1.0
	var worn_tire_force := tire.update_tire_forces(slip, 1000.0)

	assert_lte(abs(worn_tire_force.x), abs(new_tire_force.x))


func test_temperature_affects_force():
	var slip := Vector2(0.01, 0.0)

	tire.tire_temp = tire.opt_tire_temp
	var optimal_temp_force := tire.update_tire_forces(slip, 1000.0)

	tire.tire_temp = tire.max_tire_temp
	var hot_tire_force := tire.update_tire_forces(slip, 1000.0)

	assert_ne(optimal_temp_force.x, hot_tire_force.x)


func test_load_sensitivity_is_updated():
	tire.update_tire_forces(
		Vector2.ZERO,
		tire.tire_rated_load
	)

	assert_almost_eq(tire.load_sensitivity, tire.load_sens1, 0.000001)
