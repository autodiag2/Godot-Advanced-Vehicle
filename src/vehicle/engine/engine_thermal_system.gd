class_name EngineThermalSystem
extends RefCounted

enum CoolantMixture {
	WATER,
	GLYCOL_30,
	GLYCOL_50,
	GLYCOL_60,
}

enum OilGrade {
	SAE_0W20,
	SAE_5W30,
	SAE_5W40,
	SAE_10W60,
}

const COOLANT_NAMES := [
	"Water (0% glycol)",
	"30% ethylene glycol",
	"50% ethylene glycol",
	"60% ethylene glycol",
]
const COOLANT_DENSITIES := [0.998, 1.035, 1.075, 1.09]
const COOLANT_HEAT_CAPACITIES := [4180.0, 3900.0, 3600.0, 3400.0]
const COOLANT_VISCOSITY_FACTORS := [1.0, 1.08, 1.18, 1.3]
const OIL_NAMES := ["SAE 0W-20", "SAE 5W-30", "SAE 5W-40", "SAE 10W-60"]
const OIL_VISCOSITY_AT_100C := [8.5, 10.5, 14.0, 24.0]

var parameters: EngineParameters
var coolant_mixture: int = CoolantMixture.GLYCOL_50
var oil_grade: int = OilGrade.SAE_5W30
var ambient_temperature_c: float = 20.0
var block_temperature_c: float = 20.0
var coolant_temperature_c: float = 20.0
var oil_temperature_c: float = 20.0
var coolant_pressure_kpa: float = 0.0
var oil_pressure_kpa: float = 0.0
var thermostat_opening: float = 0.0
var coolant_pump_flow_l_min: float = 0.0
var radiator_heat_rejection_kw: float = 0.0
var oil_heat_rejection_kw: float = 0.0


func initialize(engine_parameters: EngineParameters) -> void:
	parameters = engine_parameters
	coolant_mixture = clampi(parameters.coolant_mixture, 0, CoolantMixture.GLYCOL_60)
	oil_grade = clampi(parameters.oil_grade, 0, OilGrade.SAE_10W60)
	block_temperature_c = ambient_temperature_c
	coolant_temperature_c = ambient_temperature_c
	oil_temperature_c = ambient_temperature_c
	_update_pressures(0.0)


func set_coolant_mixture(value: int) -> void:
	coolant_mixture = clampi(value, 0, CoolantMixture.GLYCOL_60)
	if parameters != null:
		parameters.coolant_mixture = coolant_mixture


func set_oil_grade(value: int) -> void:
	oil_grade = clampi(value, 0, OilGrade.SAE_10W60)
	if parameters != null:
		parameters.oil_grade = oil_grade


func get_coolant_mixture_name() -> String:
	return COOLANT_NAMES[coolant_mixture]


func get_oil_grade_name() -> String:
	return OIL_NAMES[oil_grade]


func get_oil_viscosity_cst() -> float:
	var temperature_factor := exp(clampf((100.0 - oil_temperature_c) * 0.025, -1.5, 2.5))
	return OIL_VISCOSITY_AT_100C[oil_grade] * temperature_factor


func get_wall_temperature_k() -> float:
	return maxf(block_temperature_c + 273.15, 180.0)


func advance(
	delta: float,
	engine_rpm: float,
	throttle: float,
	wall_heat_input_w: float,
	friction_power_w: float
) -> void:
	if delta <= 0.0 or parameters == null:
		return

	var coolant_density := COOLANT_DENSITIES[coolant_mixture]
	var coolant_heat_capacity := COOLANT_HEAT_CAPACITIES[coolant_mixture]
	var coolant_capacity_j_k := maxf(
		parameters.coolant_capacity_litres * coolant_density * coolant_heat_capacity,
		1000.0
	)
	var oil_density := 0.86
	var oil_heat_capacity := 1950.0
	var oil_capacity_j_k := maxf(
		parameters.oil_capacity_litres * oil_density * oil_heat_capacity,
		1000.0
	)
	var block_capacity_j_k := 28000.0
	var pump_factor := clampf(0.22 + engine_rpm / 5200.0, 0.22, 1.25)
	coolant_pump_flow_l_min = clampf(engine_rpm * 0.018, 0.0, 90.0)
	var thermostat_position := clampf((coolant_temperature_c - 76.0) / 18.0, 0.0, 1.0)
	thermostat_opening = thermostat_position * thermostat_position * (3.0 - 2.0 * thermostat_position)
	var fan_factor := 1.0 if coolant_temperature_c >= 96.0 else 0.0
	var airflow_factor := clampf(0.22 + throttle * 0.18 + fan_factor * 0.6, 0.2, 1.0)
	var radiator_ua := (60.0 + 280.0 * airflow_factor) / COOLANT_VISCOSITY_FACTORS[coolant_mixture]
	var oil_cooler_ua := 18.0 + 38.0 * airflow_factor
	var block_to_coolant_w := (block_temperature_c - coolant_temperature_c) * 390.0 * pump_factor
	var block_to_oil_w := (block_temperature_c - oil_temperature_c) * 115.0
	var oil_to_coolant_w := (oil_temperature_c - coolant_temperature_c) * 55.0
	var block_to_ambient_w := (block_temperature_c - ambient_temperature_c) * 12.0
	var coolant_to_radiator_w := maxf(coolant_temperature_c - ambient_temperature_c, 0.0) * radiator_ua * thermostat_opening * pump_factor
	var coolant_to_ambient_w := (coolant_temperature_c - ambient_temperature_c) * 12.0
	var oil_to_cooler_w := maxf(oil_temperature_c - ambient_temperature_c, 0.0) * oil_cooler_ua
	var oil_to_ambient_w := (oil_temperature_c - ambient_temperature_c) * 7.0
	var block_input_w := maxf(wall_heat_input_w, 0.0) * 0.78 + maxf(friction_power_w, 0.0) * 0.15
	var oil_input_w := maxf(wall_heat_input_w, 0.0) * 0.22 + maxf(friction_power_w, 0.0) * 0.85
	var block_net_w := block_input_w - block_to_coolant_w - block_to_oil_w - block_to_ambient_w
	var coolant_net_w := block_to_coolant_w + oil_to_coolant_w - coolant_to_radiator_w - coolant_to_ambient_w
	var oil_net_w := oil_input_w + block_to_oil_w - oil_to_coolant_w - oil_to_cooler_w - oil_to_ambient_w

	block_temperature_c = clampf(block_temperature_c + block_net_w * delta / block_capacity_j_k, ambient_temperature_c, 220.0)
	coolant_temperature_c = clampf(coolant_temperature_c + coolant_net_w * delta / coolant_capacity_j_k, ambient_temperature_c - 5.0, 150.0)
	oil_temperature_c = clampf(oil_temperature_c + oil_net_w * delta / oil_capacity_j_k, ambient_temperature_c - 5.0, 190.0)
	radiator_heat_rejection_kw = maxf(coolant_to_radiator_w, 0.0) / 1000.0
	oil_heat_rejection_kw = maxf(oil_to_cooler_w, 0.0) / 1000.0
	_update_pressures(engine_rpm)


func _update_pressures(engine_rpm: float) -> void:
	coolant_pressure_kpa = clampf(
		maxf(coolant_temperature_c - ambient_temperature_c, 0.0) * 1.3,
		0.0,
		145.0
	)
	var viscosity_factor := clampf(get_oil_viscosity_cst() / 10.5, 0.35, 2.0)
	oil_pressure_kpa = clampf((115.0 + engine_rpm * 0.095) * viscosity_factor, 0.0, 700.0)
