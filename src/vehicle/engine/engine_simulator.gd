class_name EngineSimulator
extends RefCounted

const RPM_PER_RADIAN_PER_SECOND: float = 60.0 / TAU

var parameters: EngineParameters
var thermodynamics := EngineThermodynamics.new()
var crank_angle_deg: float = 0.0
var rpm: float = 0.0
var angular_velocity: float = 0.0
var output_torque: float = 0.0
var mean_output_torque: float = 0.0


func initialize(engine_parameters: EngineParameters, initial_rpm: float) -> void:
	parameters = engine_parameters
	thermodynamics.initialize(engine_parameters, initial_rpm)
	_sync_state()


func advance(delta: float, throttle_input: float, reaction_torque: float) -> float:
	output_torque = thermodynamics.advance(
		delta,
		throttle_input,
		reaction_torque
	)
	_sync_state()
	return output_torque


func set_rpm(value: float) -> void:
	thermodynamics.set_rpm(value)
	_sync_state()


func stop() -> void:
	set_rpm(0.0)
	output_torque = 0.0
	mean_output_torque = 0.0
	thermodynamics.output_torque = 0.0
	thermodynamics.mean_output_torque = 0.0


func get_cylinder_phase(cylinder_index: int) -> float:
	return thermodynamics.get_cylinder_phase(cylinder_index)


func get_cylinder_pressure_kpa(cylinder_index: int) -> float:
	return thermodynamics.get_cylinder_pressure_kpa(cylinder_index)


func get_cylinder_temperature_k(cylinder_index: int) -> float:
	return thermodynamics.get_cylinder_temperature_k(cylinder_index)


func get_cylinder_combustion_intensity(cylinder_index: int) -> float:
	return thermodynamics.get_cylinder_combustion_intensity(cylinder_index)


func get_cylinder_smoke_intensity(cylinder_index: int) -> float:
	return thermodynamics.get_cylinder_smoke_intensity(cylinder_index)


func get_cylinder_burned_fraction(cylinder_index: int) -> float:
	return thermodynamics.get_cylinder_burned_fraction(cylinder_index)


func get_cylinder_heat_release_kw(cylinder_index: int) -> float:
	return thermodynamics.get_cylinder_heat_release_kw(cylinder_index)


func get_cylinder_stage(cylinder_index: int) -> String:
	return thermodynamics.get_cylinder_stage(cylinder_index)


func get_piston_displacement(phase_deg: float) -> float:
	return thermodynamics.get_piston_displacement(phase_deg)


func _sync_state() -> void:
	crank_angle_deg = thermodynamics.crank_angle_deg
	rpm = thermodynamics.rpm
	angular_velocity = thermodynamics.angular_velocity
	output_torque = thermodynamics.output_torque
	mean_output_torque = thermodynamics.mean_output_torque
