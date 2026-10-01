class_name TireModel
extends Resource

const WEAR_CURVE = preload("res://resources/tire_wear_curve.tres")
const TEMPERATURE_MU = preload("res://scenes/vehicle/tire_models/temp_mu.tres")

@export var radius := 0.3
@export var width := 0.205
@export var rated_load := 5500.0
@export var load_sensitivity_at_zero_load := 1.7
@export var load_sensitivity_at_rated_load := 0.9
@export var max_temperature := 150.0
@export var opt_temperature := 90.0
@export var heating_multiplier := 0.0015
@export var cooling_multiplier := -0.25
@export var rolling_resistance_coefficient := 0.01

var wear := 0.0
var load_sensitivity := 1.0
var temperature := 20.0
var temperature_mu: Curve

func _init() -> void:
	temperature_mu = TEMPERATURE_MU.duplicate()
	temperature_mu.set_point_offset(
		1,
		opt_temperature / max_temperature
	)

# Override this
func update_tire_forces(_slip: Vector2, _normal_load: float, _surface_mu: float) -> Vector3:
	return Vector3.ZERO


func get_rolling_resistance(
	normal_load: float,
	longitudinal_velocity: float
) -> float:
	assert(normal_load >= 0.0)
	if abs(longitudinal_velocity) < 0.01:
		return 0.0

	return (
		-rolling_resistance_coefficient *
		normal_load *
		sign(longitudinal_velocity)
	)


func update_wear(delta: float, slip: Vector2, normal_load: float, mu: float):
	assert(normal_load >= 0.0)
	assert(mu >= 0.0)
	assert(delta >= 0.0)

	wear += slip.length() * mu * delta * normal_load / 7000000.0
	wear = clampf(wear, 0, 1)
	return wear

func update_load_sensitivity(normal_load: float) -> float:
	var load_factor := normal_load / rated_load
	load_sensitivity = clampf(lerpf(load_sensitivity_at_zero_load, load_sensitivity_at_rated_load, load_factor), 0.2, load_sensitivity_at_zero_load)

	return load_sensitivity

func update_temperature(slip, normal_load, speed, mu, ambient_temp, delta):
	assert(normal_load >= 0.0)
	assert(mu >= 0.0)
	assert(delta >= 0.0)

	var delta_temp := 0.0
	# Heating
	if abs(speed) > 1.0:
		delta_temp += slip.length() * normal_load * mu * heating_multiplier * delta
	# Cooling
	var cooling: float = cooling_multiplier * (temperature - ambient_temp)
	delta_temp += cooling * delta
	# Clamp the temps
	var max_temperature_rate := 6.0
	var max_delta_temp : float = max_temperature_rate * delta
	delta_temp = clamp(delta_temp, -max_delta_temp, max_delta_temp)
	temperature = clampf(temperature + delta_temp, ambient_temp, max_temperature)
	return temperature
