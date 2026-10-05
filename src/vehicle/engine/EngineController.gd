class_name EngineController
extends RefCounted

const PETROL_KG_PER_LITRE: float = 0.7489
const RPM_PER_RADIAN_PER_SECOND: float = 60.0 / TAU
const NEWTON_METRE_RPM_TO_KW: int = 9549
const WATTS_PER_KILOWATT: float = 1000.0
const IDLE_CONTROL_GAIN: float = 1.0
const SECONDS_PER_HOUR: float = 3600.0
const NO_LOAD_BSFC_LOAD: float = 0.10
const FUEL_CUT_RPM_FACTOR: float = 1.10
const IDLE_BLEND_RPM_FACTOR: float = 0.10
const FRICTION_IDLE_FACTOR: float = 0.20

class Listener:
	func onCombustionSelfSustaining(engine: EngineController) -> void:
		pass

	func onStall(engine: EngineController) -> void:
		pass


var listeners: Array[Listener] = []
var starter: EngineStarterController
var angular_velocity: float = 0.0
var output_torque: float = 0.0
var net_torque: float = 0.0
var limiter_torque: float = 0.0
var reaction_torque: float = 0.0
var combustion_torque: float = 0.0
var fuel_litres: float = 0.0
var combustion_running: bool = false
var drivetrain_connected: bool = false
var parameters: CarParameters
var engine_audio_player: AudioStreamPlayer
var engine_sound: AudioStream
var was_running: bool = false

var rpm: float:
	get:
		return (
			angular_velocity *
			RPM_PER_RADIAN_PER_SECOND
		)
	set(value):
		assert(value >= 0.0)
		angular_velocity = (
			value /
			RPM_PER_RADIAN_PER_SECOND
		)

var max_engine_rpm: float = 8000.0


func add_listener(listener: Listener) -> void:
	assert(listener != null)

	if !listeners.has(listener):
		listeners.append(listener)


func remove_listener(listener: Listener) -> void:
	assert(listener != null)

	listeners.erase(listener)


func initialize(
	parameters_arg: CarParameters,
	car: RigidBody3D,
	starter_arg: EngineStarterController,
	audio_player: AudioStreamPlayer
) -> void:
	assert(parameters_arg != null)
	assert(car != null)
	assert(audio_player != null)
	assert(starter_arg != null)
	assert(parameters_arg.fuel_tank_size >= 0.0)
	assert(parameters_arg.fuel_percentage >= 0.0)
	assert(parameters_arg.fuel_percentage <= 100.0)
	assert(parameters_arg.engine.moment > 0.0)
	assert(parameters_arg.engine.max_rpm > 0.0)
	assert(parameters_arg.engine.rpm_idle >= 0.0)
	assert(parameters_arg.engine.bsfc_map != null)

	parameters = parameters_arg
	engine_sound = parameters.engine.sound
	max_engine_rpm = parameters.engine.max_rpm
	fuel_litres = (
		parameters.fuel_tank_size *
		parameters.fuel_percentage *
		0.01
	)
	engine_audio_player = audio_player
	angular_velocity = 0.0
	output_torque = 0.0
	combustion_torque = 0.0
	starter = starter_arg
	net_torque = 0.0
	limiter_torque = 0.0
	reaction_torque = 0.0
	was_running = false
	combustion_running = false
	drivetrain_connected = false

	car.mass += (
		fuel_litres *
		PETROL_KG_PER_LITRE
	)


func set_drivetrain_connected(connected: bool) -> void:
	drivetrain_connected = connected

func update(
	car: RigidBody3D,
	throttle_input: float,
	delta: float
) -> void:
	assert(car != null)
	assert(angular_velocity >= 0.0)
	assert(throttle_input >= 0.0)
	assert(throttle_input <= 1.0)
	assert(delta >= 0.0)

	var was_running_before_update: bool = angular_velocity > 0.0

	output_torque = calculate_torque(
		rpm,
		throttle_input,
		combustion_running || starter.get_torque() > 0.0
	)

	if fuel_litres <= 0.0:
		output_torque = calculate_torque(
			rpm,
			0.0,
			false
		)
		combustion_running = false

	limiter_torque = 0.0

	if (
		starter.get_torque() > 0.0 &&
		fuel_litres > 0.0 &&
		rpm >= parameters.engine.rpm_idle
	):
		combustion_running = true

		for listener in listeners:
			listener.onCombustionSelfSustaining(self)

	net_torque = (
		output_torque +
		starter.get_torque() +
		reaction_torque
	)

	if (
		rpm >= parameters.engine.max_rpm &&
		net_torque > 0.0
	):
		limiter_torque = -net_torque
		net_torque = 0.0

	if delta > 0.0:
		var next_angular_velocity := (
			angular_velocity +
			delta *
			net_torque /
			parameters.engine.moment
		)

		var max_angular_velocity := (
			parameters.engine.max_rpm /
			RPM_PER_RADIAN_PER_SECOND
		)

		if next_angular_velocity > max_angular_velocity:
			limiter_torque = (
				(
					max_angular_velocity -
					angular_velocity
				) *
				parameters.engine.moment /
				delta -
				net_torque
			)

			net_torque += limiter_torque
			angular_velocity = max_angular_velocity
		else:
			angular_velocity = maxf(
				next_angular_velocity,
				0.0
			)

			if angular_velocity == 0.0 and net_torque < 0.0:
				net_torque = 0.0

	angular_velocity = maxf(
		angular_velocity,
		0.0
	)

	if (
		was_running_before_update &&
		angular_velocity == 0.0
	):
		combustion_running = false

		for listener in listeners:
			listener.onStall(self)

	was_running = angular_velocity > 0.0

	consume_fuel(
		car,
		throttle_input,
		delta
	)


func calculate_torque(
	engine_rpm: float,
	throttle_input: float,
	combustion_enabled: bool = true
) -> float:
	assert(engine_rpm >= 0.0)
	assert(throttle_input >= 0.0)
	assert(throttle_input <= 1.0)

	var rpm_factor: float = clamp(
		engine_rpm /
		parameters.engine.max_rpm,
		0.0,
		1.0
	)

	var torque_curve_factor: float = (
		parameters.engine.torque_curve.sample_baked(
			rpm_factor
		)
	)

	var maximum_torque: float = (
		torque_curve_factor *
		parameters.engine.max_torque
	)

	var throttle_factor := (
		parameters.engine.throttle_model.sample_baked(
			throttle_input
		)
	)

	combustion_torque = 0.0

	if combustion_enabled:
		combustion_torque = (
			maximum_torque *
			throttle_factor
		)

	var engine_friction_torque := calculate_friction_torque(
		engine_rpm
	)

	var idle_torque := 0.0

	if (
		combustion_enabled &&
		throttle_input == 0.0 &&
		engine_rpm > 0.0 &&
		engine_rpm < parameters.engine.rpm_idle
	):
		var idle_error := (
			parameters.engine.rpm_idle -
			engine_rpm
		) / parameters.engine.rpm_idle

		idle_torque = (
			parameters.engine.max_torque *
			IDLE_CONTROL_GAIN *
			idle_error
		)

	return (
		combustion_torque +
		idle_torque -
		engine_friction_torque
	)


func calculate_friction_torque(engine_rpm: float) -> float:
	assert(engine_rpm >= 0.0)

	var rpm_factor := clampf(
		engine_rpm /
		parameters.engine.max_rpm,
		0.0,
		1.0
	)

	var friction_factor := (
		FRICTION_IDLE_FACTOR +
		(1.0 - FRICTION_IDLE_FACTOR) *
		rpm_factor *
		rpm_factor
	)

	return (
		parameters.engine.brake_torque *
		friction_factor
	)


func consume_fuel(
	car: RigidBody3D,
	throttle_input: float,
	delta: float
) -> void:
	assert(car != null)
	assert(delta >= 0.0)

	if !combustion_running:
		return

	var fuel_consumed: float

	var idle_blend_start := parameters.engine.rpm_idle
	var idle_blend_end := (
		parameters.engine.rpm_idle *
		(1.0 + IDLE_BLEND_RPM_FACTOR)
	)

	var fuel_cut_rpm := (
		parameters.engine.rpm_idle *
		FUEL_CUT_RPM_FACTOR
	)

	var is_fuel_cut := (
		drivetrain_connected &&
		throttle_input == 0.0 &&
		rpm >= fuel_cut_rpm
	)

	if is_fuel_cut:
		fuel_consumed = 0.0
	elif (
		throttle_input == 0.0 &&
		rpm > 0.0 &&
		rpm <= idle_blend_end
	):
		var normal_fuel_consumed := calculate_normal_fuel_consumption(
			delta
		)

		var idle_fuel_consumed := (
			parameters.engine.idle_fuel_rate *
			delta /
			SECONDS_PER_HOUR
		)

		var idle_factor := inverse_lerp(
			idle_blend_end,
			idle_blend_start,
			rpm
		)

		idle_factor = clampf(
			idle_factor,
			0.0,
			1.0
		)

		fuel_consumed = lerpf(
			normal_fuel_consumed,
			idle_fuel_consumed,
			idle_factor
		)
	else:
		fuel_consumed = calculate_normal_fuel_consumption(
			delta
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

	if fuel_litres <= 0.0:
		fuel_litres = 0.0
		output_torque = 0.0
		rpm = 0.0
		combustion_running = false
		stop_sound()
	else:
		update_sound()


func calculate_normal_fuel_consumption(delta: float) -> float:
	assert(delta >= 0.0)

	var mechanical_power_kw: float = (
		max(output_torque, 0.0) *
		angular_velocity /
		WATTS_PER_KILOWATT
	)

	var engine_load := calculate_engine_load()

	var bsfc: float = parameters.engine.bsfc_map.sample(
		rpm,
		maxf(
			engine_load,
			NO_LOAD_BSFC_LOAD
		)
	)

	var friction_torque := calculate_friction_torque(
		rpm
	)

	var friction_power_kw: float = (
		friction_torque *
		angular_velocity /
		WATTS_PER_KILOWATT
	)

	var fuel_power_kw := (
		mechanical_power_kw +
		friction_power_kw
	)

	return (
		bsfc *
		fuel_power_kw *
		delta /
		(
			SECONDS_PER_HOUR *
			1000.0 *
			PETROL_KG_PER_LITRE
		)
	)

func calculate_engine_load() -> float:
	var maximum_torque := (
		parameters.engine.torque_curve.sample_baked(
			clampf(
				rpm /
				parameters.engine.max_rpm,
				0.0,
				1.0
			)
		) *
		parameters.engine.max_torque
	)

	if maximum_torque <= 0.0:
		return 0.0

	return clampf(
		combustion_torque /
		maximum_torque,
		0.0,
		1.0
	)

func update_sound() -> void:
	assert(engine_audio_player != null)
	assert(angular_velocity >= 0.0)

	var pitch_scale: float = rpm / 1000.0

	if (
		rpm > 0.0 &&
		rpm < max_engine_rpm
	):
		if engine_audio_player.stream != engine_sound:
			engine_audio_player.set_stream(
				engine_sound
			)

		if !engine_audio_player.playing:
			engine_audio_player.play()

		engine_audio_player.pitch_scale = pitch_scale
	else:
		if engine_audio_player.playing:
			engine_audio_player.stop()


func stop_sound() -> void:
	assert(engine_audio_player != null)

	engine_audio_player.stop()
