class_name EngineController extends Controller

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
	@warning_ignore("unused_parameter")
	func onCombustionSelfSustaining(engine: EngineController) -> void:
		pass

	@warning_ignore("unused_parameter")
	func onStall(engine: EngineController) -> void:
		pass

var listeners: Array[Listener] = []
var starter: EngineStarterController
var angular_velocity: float = 0.0 # rad/s
var output_torque: float = 0.0 # N.m positive
var limiter_torque: float = 0.0
var reaction_torque: float = 0.0
var combustion_running: bool = false
var drivetrain_connected: bool = false
var car_parameters: CarParameters
var parameters: EngineParameters
var audio_player: AudioStreamPlayer
var engine_sound: AudioStream
var starter_sound: AudioStream
var fuel_tank: FuelTank = FuelTank.new()

var rpm: float:
	get:
		return (
			angular_velocity *
			RPM_PER_RADIAN_PER_SECOND
		)
	set(value):
		assert(0.0 <= value)
		angular_velocity = (
			value /
			RPM_PER_RADIAN_PER_SECOND
		)

func add_listener(listener: Listener) -> void:
	assert(listener != null)

	if !listeners.has(listener):
		listeners.append(listener)


func remove_listener(listener: Listener) -> void:
	assert(listener != null)

	listeners.erase(listener)

func _init():
	controller_debug_print_enabled = true

func initialize(
	parameters_arg: CarParameters,
	car: RigidBody3D,
	starter_arg: EngineStarterController,
	audio_player_arg: AudioStreamPlayer
) -> void:
	assert(parameters_arg != null)
	assert(car != null)
	assert(audio_player_arg != null)
	assert(starter_arg != null)
	assert(parameters_arg.engine.moment > 0.0)
	assert(parameters_arg.engine.max_rpm > 0.0)
	assert(parameters_arg.engine.rpm_idle >= 0.0)
	assert(parameters_arg.engine.bsfc_map != null)

	parameters = parameters_arg.engine
	car_parameters = parameters_arg
	engine_sound = parameters.sound
	starter_sound = parameters.starter_sound
	
	audio_player = audio_player_arg
	angular_velocity = 0.0
	output_torque = 0.0
	starter = starter_arg
	limiter_torque = 0.0
	reaction_torque = 0.0
	combustion_running = false
	drivetrain_connected = false
	fuel_tank.initialise(parameters_arg, car)
	starter_initialise(1.0)

func starter_initialise(cranking_time: float):
	var t := calculate_starter_torque(cranking_time)
	starter.stop()
	starter.torque = t

func calculate_starter_torque(cranking_time: float) -> float:
	assert(cranking_time > 0.0)

	var idle_angular_velocity := (
		parameters.rpm_idle /
		RPM_PER_RADIAN_PER_SECOND
	)

	var angular_acceleration := (
		idle_angular_velocity /
		cranking_time
	)

	var acceleration_torque := (
		parameters.moment *
		angular_acceleration
	)

	var friction_torque := calculate_friction_torque(
		parameters.rpm_idle
	)

	return acceleration_torque + friction_torque

func set_drivetrain_connected(connected: bool) -> void:
	drivetrain_connected = connected

@warning_ignore("shadowed_variable")
func apply(
	throttle_input: float,
	delta: float,
	reaction_torque: float = self.reaction_torque
) -> float:
	assert(angular_velocity >= 0.0)
	assert(throttle_input >= 0.0)
	assert(throttle_input <= 1.0)
	assert(delta >= 0.0)
	starter.update(delta)
	
	var was_running_before_update: bool = angular_velocity > 0.0
	
	if fuel_tank.fuel_litres <= 0.0:
		combustion_running = false

	output_torque = calculate_torque(
		throttle_input,
		delta
	)

	limiter_torque = 0.0

	#print("starter.active=", starter.active, "fuel_tank.fuel_litres=", fuel_tank.fuel_litres, " rpm=", rpm)
	if (
		starter.active &&
		rpm >= parameters.rpm_idle
	):
		starter.stop()
		if ( 0.0 <= fuel_tank.fuel_litres ):
			combustion_running = true

			for listener in listeners:
				listener.onCombustionSelfSustaining(self)

	var net_torque := (
		output_torque - reaction_torque
	)
	print("output_torque=", output_torque, " reaction_torque=", reaction_torque)

	if (
		rpm > parameters.max_rpm &&
		net_torque > 0.0
	):
		limiter_torque = net_torque
		net_torque = 0.0
	
	if delta > 0.0:
		var next_angular_velocity := (
			angular_velocity +
			delta *
			net_torque /
			parameters.moment
		)

		var max_angular_velocity := (
			parameters.max_rpm /
			RPM_PER_RADIAN_PER_SECOND
		)

		if next_angular_velocity > max_angular_velocity:
			limiter_torque = (
				net_torque - 
				(
					max_angular_velocity -
					angular_velocity
				) *
				parameters.moment /
				delta
			)

			net_torque -= limiter_torque
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

	consume_fuel(
		throttle_input,
		delta
	)
	update_sound()
	
	return net_torque


func calculate_torque(
	throttle_input: float,
	delta: float,
	engine_rpm: float = rpm,
	combustion_enabled: bool = combustion_running
) -> float:
	assert(engine_rpm >= 0.0)
	assert(throttle_input >= 0.0)
	assert(throttle_input <= 1.0)

	var combustion_torque := calculate_combusion_torque(throttle_input, engine_rpm)

	var engine_friction_torque := calculate_friction_torque(
		engine_rpm
	)

	var idle_torque := 0.0

	if (
		combustion_enabled &&
		throttle_input == 0.0 &&
		engine_rpm > 0.0 &&
		engine_rpm < parameters.rpm_idle
	):
		var idle_error := (
			parameters.rpm_idle -
			engine_rpm
		) / parameters.rpm_idle

		idle_torque = (
			parameters.max_torque *
			IDLE_CONTROL_GAIN *
			idle_error
		)

	var starter_torque := starter.get_torque(delta)
	print("combustion_torque=", combustion_torque, " starter_torque=", starter_torque, " idle_torque=", idle_torque, " engine_friction_torque=", engine_friction_torque)
	return (
		combustion_torque +
		starter_torque +
		idle_torque -
		engine_friction_torque
	)


func calculate_friction_torque(engine_rpm: float) -> float:
	assert(engine_rpm >= 0.0)

	var rpm_factor := clampf(
		engine_rpm /
		parameters.max_rpm,
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
		parameters.brake_torque *
		friction_factor
	)


func consume_fuel(
	throttle_input: float,
	delta: float
) -> void:
	assert(delta >= 0.0)

	if !combustion_running:
		return

	var fuel_consumed: float

	var idle_blend_start := parameters.rpm_idle
	var idle_blend_end := (
		parameters.rpm_idle *
		(1.0 + IDLE_BLEND_RPM_FACTOR)
	)

	var fuel_cut_rpm := (
		parameters.rpm_idle *
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
			throttle_input,
			delta
		)

		var idle_fuel_consumed := (
			parameters.idle_fuel_rate *
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
			throttle_input,
			delta
		)

	fuel_tank.consume(fuel_consumed)

	if fuel_tank.fuel_litres == 0.0:
		output_torque = 0.0
		rpm = 0.0
		combustion_running = false	
	update_sound()


func calculate_normal_fuel_consumption(throttle_input: float, delta: float) -> float:
	assert(0.0 <= delta)
	assert(0.0 <= throttle_input)
	assert(throttle_input <= 1.0)

	var mechanical_power_kw: float = (
		max(output_torque, 0.0) *
		angular_velocity /
		WATTS_PER_KILOWATT
	)

	var engine_load := calculate_engine_load(throttle_input)

	var bsfc: float = parameters.bsfc_map.sample(
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

func calculate_combusion_torque(
	throttle_input: float, 
	engine_rpm: float = rpm,
	fuel_litres: float = fuel_tank.fuel_litres
) -> float:
	assert(0.0 <= throttle_input)
	assert(throttle_input <= 1.0)
	
	if not combustion_running || 0.0 == fuel_litres:
		return 0.0

	var rpm_factor: float = clamp(
		engine_rpm /
		parameters.max_rpm,
		0.0,
		1.0
	)

	var torque_curve_factor: float = (
		parameters.torque_curve.sample_baked(
			rpm_factor
		)
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
		
	return maximum_torque * throttle_factor

func calculate_engine_load(throttle_input: float) -> float:
	assert(0.0 <= throttle_input)
	assert(throttle_input <= 1.0)
	var maximum_torque := (
		parameters.torque_curve.sample_baked(
			clampf(
				rpm /
				parameters.max_rpm,
				0.0,
				1.0
			)
		) *
		parameters.max_torque
	)
	
	assert(0.0 <= maximum_torque)
	
	if maximum_torque == 0.0:
		return 0.0

	var combustion_torque := calculate_combusion_torque(throttle_input)
	return clampf(
		combustion_torque /
		maximum_torque,
		0.0,
		1.0
	)

func update_sound() -> void:
	if not audio_player:
		return

	if starter.active:
		if audio_player.stream != starter_sound:
			audio_player.set_stream(starter_sound)
		if not audio_player.playing:
			audio_player.play()
		audio_player.pitch_scale = 1.0
	else:
		var pitch_scale: float = rpm / 1000.0
		if audio_player.stream != engine_sound:
			audio_player.set_stream(
				engine_sound
			)
		if not combustion_running:
			stop_sound()
			return
		if (
			rpm > 0.0 &&
			rpm <= parameters.max_rpm
		):
			if not audio_player.playing:
				audio_player.play()
			audio_player.pitch_scale = pitch_scale
		else:
			if audio_player.playing:
				audio_player.stop()

func start() -> void:
	starter.start()

func stop() -> void:
	combustion_running = false
	angular_velocity = 0.0
	output_torque = 0.0
	limiter_torque = 0.0
	reaction_torque = 0.0
	stop_sound()

func stop_sound() -> void:
	assert(audio_player != null)

	audio_player.stop()
