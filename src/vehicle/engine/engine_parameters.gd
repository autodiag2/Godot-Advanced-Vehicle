class_name EngineParameters
extends Resource

enum FuelType {
	PETROL,
	DIESEL,
}

@export_category("Engine layout")
@export_range(1, 12, 1) var cylinder_count: int = 4
@export var firing_order: PackedInt32Array = PackedInt32Array([1, 3, 4, 2])
@export_range(40.0, 150.0, 0.1) var bore_mm: float = 86.0
@export_range(40.0, 150.0, 0.1) var stroke_mm: float = 86.0
@export_range(2.0, 5.0, 0.1) var connecting_rod_ratio: float = 3.5
@export_range(5.0, 25.0, 0.1) var compression_ratio: float = 10.5

@export_category("Fuel and combustion")
@export var fuel_type: FuelType = FuelType.PETROL
@export var bsfc_map: EngineBSFCMap
@export_range(0.1, 1.0, 0.01) var volumetric_efficiency: float = 0.88
@export_range(0.1, 1.0, 0.01) var combustion_efficiency: float = 0.34
@export_range(10.0, 100.0, 0.5) var combustion_duration_deg: float = 42.0
@export_range(0.0, 40.0, 0.5) var ignition_advance_deg: float = 15.0
@export_range(0.0, 40.0, 0.5) var injection_advance_deg: float = 8.0
@export_range(250.0, 450.0, 1.0) var intake_temperature_k: float = 300.0
@export_range(0.5, 1.5, 0.01) var specific_heat_ratio: float = 1.34
@export_range(0.0, 200.0, 0.5) var exhaust_pressure_kpa: float = 105.0
@export_range(0.0, 1.0, 0.01) var torque_pulse_strength: float = 0.45
@export_range(0.1, 1.5, 0.01) var fuel_density_kg_per_litre: float = 0.745
@export_range(20.0, 50.0, 0.1) var lower_heating_value_mj_per_kg: float = 43.0
@export_range(10.0, 20.0, 0.1) var stoichiometric_afr: float = 14.7
@export_range(12.0, 30.0, 0.1) var diesel_full_load_afr: float = 18.0

@export_category("Performance")
@export_range(10.0, 2000.0, 1.0) var max_torque_nm: float = 260.0
@export_range(1000.0, 15000.0, 50.0) var max_rpm: float = 8000.0
@export_range(300.0, 2500.0, 25.0) var idle_rpm: float = 900.0
@export_range(0.01, 2.0, 0.01) var inertia_kg_m2: float = 0.14
@export_range(0.0, 100.0, 0.1) var friction_torque_nm: float = 12.0
@export var torque_curve: Curve
@export var throttle_model: Curve
