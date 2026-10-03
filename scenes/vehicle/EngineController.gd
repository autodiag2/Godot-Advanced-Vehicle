class_name EngineController
extends RefCounted

const PETROL_KG_PER_LITRE: float = 0.7489
const RPM_PER_RADIAN_PER_SECOND: float = 60.0 / TAU
const NEWTON_METRE_RPM_TO_KW: int = 9549

var rpm: float = 0.0
var angular_velocity: float = 0.0
var output_torque: float = 0.0
var net_torque: float = 0.0
var reaction_torque: float = 0.0
var fuel_litres: float = 0.0
# View
var engine_audio_player: AudioStreamPlayer


func initialize(
	parameters: CarParameters,
	car: RigidBody3D,
	audio_player: AudioStreamPlayer
) -> void:
	assert(parameters != null)
	assert(car != null)
	assert(audio_player != null)
	assert(parameters.fuel_tank_size >= 0.0)
	assert(parameters.fuel_percentage >= 0.0)
	assert(parameters.fuel_percentage <= 100.0)
	assert(parameters.engine_moment > 0.0)
	assert(parameters.max_engine_rpm > 0.0)

	fuel_litres = (
		parameters.fuel_tank_size *
		parameters.fuel_percentage *
		0.01
	)
	engine_audio_player = audio_player
	car.mass += (
		fuel_litres *
		PETROL_KG_PER_LITRE
	)


func update(
	parameters: CarParameters,
	throttle_input: float,
	delta: float
) -> void:
	assert(parameters != null)
	assert(parameters.engine_moment > 0.0)
	assert(parameters.max_engine_rpm > 0.0)
	assert(parameters.rpm_idle >= 0.0)
	assert(rpm >= 0.0)
	assert(throttle_input >= 0.0)
	assert(throttle_input <= 1.0)
	assert(delta >= 0.0)

	output_torque = calculate_torque(
		rpm,
		throttle_input,
		parameters
	)

	net_torque = (
		output_torque +
		reaction_torque
	)

	rpm += (
		RPM_PER_RADIAN_PER_SECOND *
		delta *
		net_torque /
		parameters.engine_moment
	)

	if rpm < 0.0:
		rpm = 0.0

	if rpm >= parameters.max_engine_rpm:
		rpm = parameters.max_engine_rpm
		output_torque = 0.0

	angular_velocity = (
		rpm /
		RPM_PER_RADIAN_PER_SECOND
	)


func calculate_torque(
	engine_rpm: float,
	throttle_input: float,
	parameters: CarParameters
) -> float:
	assert(parameters != null)
	assert(parameters.max_engine_rpm > 0.0)
	assert(engine_rpm >= 0.0)
	assert(throttle_input >= 0.0)
	assert(throttle_input <= 1.0)

	var rpm_factor: float = clamp(
		engine_rpm /
		parameters.max_engine_rpm,
		0.0,
		1.0
	)

	var torque_curve_factor: float = (
		parameters.torque_curve.sample_baked(
			rpm_factor
		)
	)

	var engine_braking_torque: float = (
		-parameters.engine_brake *
		rpm_factor
	)

	var maximum_torque: float = (
		torque_curve_factor *
		parameters.max_torque
	)

	var throttle_factor := (
		parameters.throttle_model.sample_baked(
			throttle_input
		)
	)

	return lerpf(
		engine_braking_torque,
		maximum_torque,
		throttle_factor
	)


func clamp_to_idle(parameters: CarParameters) -> void:
	assert(parameters != null)
	assert(parameters.rpm_idle >= 0.0)

	rpm = max(
		rpm,
		parameters.rpm_idle
	)


func consume_fuel(
	parameters: CarParameters,
	car: RigidBody3D,
	delta: float
) -> void:
	assert(parameters != null)
	assert(car != null)
	assert(parameters.engine_bsfc >= 0.0)
	assert(delta >= 0.0)

	var fuel_consumed: float = (
		parameters.engine_bsfc *
		max(output_torque, 0.0) *
		rpm *
		delta /
		(
			3600.0 *
			PETROL_KG_PER_LITRE *
			NEWTON_METRE_RPM_TO_KW
		)
	)

	fuel_consumed = min(
		fuel_consumed,
		fuel_litres
	)

	fuel_consumed = max(
		fuel_consumed,
		0.0
	)

	fuel_litres -= fuel_consumed

	car.mass -= (
		fuel_consumed *
		PETROL_KG_PER_LITRE
	)


func update_sound(
	parameters: CarParameters
) -> void:
	assert(parameters != null)
	assert(parameters.max_engine_rpm > 0.0)
	assert(parameters.rpm_idle >= 0.0)
	assert(engine_audio_player != null)
	assert(rpm >= 0.0)

	var pitch_scale: float = rpm / 1000.0

	if (
		rpm >= parameters.rpm_idle &&
		rpm < parameters.max_engine_rpm
	):
		if engine_audio_player.stream != parameters.engine_sound:
			engine_audio_player.set_stream(
				parameters.engine_sound
			)

		if !engine_audio_player.playing:
			engine_audio_player.play()

		if pitch_scale > 0.1:
			engine_audio_player.pitch_scale = pitch_scale
	else:
		if engine_audio_player.playing:
			engine_audio_player.stop()


func stop_sound() -> void:
	assert(engine_audio_player != null)

	engine_audio_player.stop()
