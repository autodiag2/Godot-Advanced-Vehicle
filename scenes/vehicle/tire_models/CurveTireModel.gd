class_name CurveTireModel
extends TireModel

const buildup = preload("res://scenes/vehicle/tire_models/buildup_curve.tres")
const falloff = preload("res://scenes/vehicle/tire_models/falloff_curve.tres")

const MIN_PEAK_SA_START_DEG = 3.0
const MAX_PEAK_SA_START_DEG = 12.0

const MIN_DELTA_SA_DEG = 1.0
const MAX_DELTA_SA_DEG = 4.0

@export_range(0.0, 1.0) var tire_stiffness := 0.5

func update_tire_forces(slip: Vector2, normal_load: float, surface_mu: float = 1.0) -> Vector3:
	assert(surface_mu >= 0.0)
	assert(normal_load >= 0.0)

	var wear_mu := TIRE_WEAR_CURVE.sample_baked(wear)
	var temp_mu := temperature_mu.sample_baked(tire_temp / max_tire_temp)
	load_sensitivity = update_load_sensitivity(normal_load)
	var mu := surface_mu * wear_mu * temp_mu * load_sensitivity

	var load_factor := normal_load / rated_load
	var peak_sa_deg: float = lerp(MAX_PEAK_SA_START_DEG, MIN_PEAK_SA_START_DEG, tire_stiffness)
	var delta_sa_deg: float = lerp(MAX_DELTA_SA_DEG, MIN_DELTA_SA_DEG, tire_stiffness)

	var sa0 := peak_sa_deg + 0.5 * delta_sa_deg
	var sa1 := peak_sa_deg - 0.5 * delta_sa_deg
	var peak_sa := deg_to_rad(lerp(sa1, sa0, load_factor))

	var peak_sr_ratio := 0.65
	var peak_sr := peak_sa * peak_sr_ratio

	var normalised_sr := slip.y / peak_sr
	var normalised_sa := slip.x / peak_sa
	var resultant_slip := sqrt(pow(normalised_sr, 2) + pow(normalised_sa, 2))

	var tire_forces := Vector3.ZERO

	if resultant_slip != 0:
		var force_magnitude: float

		if resultant_slip < 1.0:
			force_magnitude = buildup.sample_baked(resultant_slip)
		else:
			force_magnitude = falloff.sample_baked(resultant_slip - 1.0)

		tire_forces.x = (
			force_magnitude *
			abs(normalised_sa / resultant_slip) *
			sign(slip.x)
		)

		tire_forces.y = (
			force_magnitude *
			abs(normalised_sr / resultant_slip) *
			sign(slip.y)
		)

	tire_forces *= mu * normal_load

	return tire_forces
