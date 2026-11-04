class_name EngineAudioSynthesizer
extends RefCounted

const SAMPLE_RATE: float = 22050.0
const CYCLE_DEGREES: float = 720.0

var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var audio_crank_angle_deg: float = 0.0
var cylinder_fire_envelopes := PackedFloat32Array()
var injector_envelopes := PackedFloat32Array()
var exhaust_envelopes := PackedFloat32Array()
var intake_envelopes := PackedFloat32Array()
var exhaust_noise_state: float = 0.0
var intake_noise_state: float = 0.0
var noise_state: float = 173.0
var initialized := false


func update(
	simulator: EngineSimulator,
	audio_player: AudioStreamPlayer,
	throttle: float
) -> void:
	if (
		simulator == null or
		simulator.parameters == null or
		simulator.rpm <= 0.0
	):
		stop(audio_player)
		return

	if not initialized:
		_start(simulator, audio_player)
	if playback == null:
		return

	var frames_available := playback.get_frames_available()
	if frames_available <= 0:
		return

	var parameters := simulator.parameters
	var cylinder_count := parameters.get_cylinder_count()
	if cylinder_fire_envelopes.size() != cylinder_count:
		cylinder_fire_envelopes.resize(cylinder_count)
		injector_envelopes.resize(cylinder_count)
		exhaust_envelopes.resize(cylinder_count)
		intake_envelopes.resize(cylinder_count)

	var rpm := maxf(simulator.rpm * Engine.time_scale, 0.0)
	var crank_step := rpm * 6.0 / SAMPLE_RATE
	var firing_angle := CYCLE_DEGREES - parameters.ignition_advance_deg
	if parameters.fuel_type == EngineParameters.FuelType.DIESEL:
		firing_angle = CYCLE_DEGREES - maxf(
			parameters.injection_advance_deg - parameters.diesel_ignition_delay_deg,
			0.0
		)
	var injection_angle := (
		CYCLE_DEGREES -
		parameters.injection_advance_deg -
		parameters.diesel_injection_duration_deg
	)
	var crank_degrees_per_second := maxf(rpm * 6.0, 1.0)
	var combustion_duration_seconds := (
		parameters.combustion_duration_deg /
		crank_degrees_per_second
	)
	var injection_duration_seconds := (
		parameters.diesel_injection_duration_deg /
		crank_degrees_per_second
	)
	var exhaust_duration_seconds := (
		maxf(
			parameters.exhaust_valve_close_deg -
			parameters.exhaust_valve_open_deg,
			1.0
		) /
		crank_degrees_per_second
	)
	var intake_duration_seconds := (
		maxf(
			parameters.intake_valve_close_deg -
			parameters.intake_valve_open_deg,
			1.0
		) /
		crank_degrees_per_second
	)
	var combustion_decay := exp(
		-1.0 / (SAMPLE_RATE * maxf(combustion_duration_seconds, 0.0007))
	)
	var injection_decay := exp(
		-1.0 / (SAMPLE_RATE * maxf(injection_duration_seconds, 0.0007))
	)
	var exhaust_decay := exp(
		-1.0 / (SAMPLE_RATE * maxf(exhaust_duration_seconds, 0.002))
	)
	var intake_decay := exp(
		-1.0 / (SAMPLE_RATE * maxf(intake_duration_seconds, 0.002))
	)
	var throttle_amount := clampf(throttle, 0.0, 1.0)
	var torque_load := clampf(
		maxf(simulator.mean_output_torque, 0.0) /
		maxf(parameters.max_torque_nm, 1.0),
		0.0,
		1.0
	)
	var load := maxf(throttle_amount * 0.65, torque_load)
	var crank_frequency := rpm / 60.0
	var firing_frequency := crank_frequency * float(cylinder_count) * 0.5
	var firing_increment := TAU * firing_frequency / SAMPLE_RATE
	var crank_increment := TAU * crank_frequency / SAMPLE_RATE
	var combustion_gain := 0.32 + load * 0.16
	var intake_gain := 0.018 + throttle_amount * 0.012
	var exhaust_gain := 0.024 + load * 0.012
	var firing_noise_gain := 0.12 + load * 0.06
	var diesel := parameters.fuel_type == EngineParameters.FuelType.DIESEL
	var crank_phase := TAU * audio_crank_angle_deg / 360.0
	var firing_phase := TAU * audio_crank_angle_deg * float(cylinder_count) / CYCLE_DEGREES

	for _frame_index in range(frames_available):
		var next_angle := fposmod(
			audio_crank_angle_deg + crank_step,
			CYCLE_DEGREES
		)
		var combustion_mix := 0.0
		var injector_mix := 0.0
		var exhaust_mix := 0.0
		var intake_mix := 0.0

		for cylinder_index in range(cylinder_count):
			var firing_offset: float = simulator.thermodynamics.cylinder_firing_offsets[cylinder_index]
			var previous_phase := fposmod(
				audio_crank_angle_deg - firing_offset,
				CYCLE_DEGREES
			)
			var next_phase := fposmod(
				next_angle - firing_offset,
				CYCLE_DEGREES
			)

			if (
				_crosses_angle(previous_phase, next_phase, firing_angle) and
				not simulator.has_cylinder_misfire_fault(cylinder_index)
			):
				cylinder_fire_envelopes[cylinder_index] = 1.0

			if (
				diesel and
				_crosses_angle(previous_phase, next_phase, injection_angle)
			):
				injector_envelopes[cylinder_index] = 1.0
			if _crosses_angle(
				previous_phase,
				next_phase,
				parameters.exhaust_valve_open_deg
			):
				var exhaust_pressure := simulator.get_cylinder_pressure_kpa(cylinder_index)
				exhaust_envelopes[cylinder_index] = clampf(
					exhaust_pressure / 8000.0,
					0.15,
					1.8
				)
			if _crosses_angle(
				previous_phase,
				next_phase,
				parameters.intake_valve_open_deg
			):
				intake_envelopes[cylinder_index] = 1.0

			var fire_envelope := cylinder_fire_envelopes[cylinder_index]
			var injector_envelope := injector_envelopes[cylinder_index]
			var exhaust_envelope := exhaust_envelopes[cylinder_index]
			var intake_envelope := intake_envelopes[cylinder_index]
			combustion_mix += fire_envelope
			injector_mix += injector_envelope
			exhaust_mix += exhaust_envelope
			intake_mix += intake_envelope
			cylinder_fire_envelopes[cylinder_index] = fire_envelope * combustion_decay
			injector_envelopes[cylinder_index] = injector_envelope * injection_decay
			exhaust_envelopes[cylinder_index] = exhaust_envelope * exhaust_decay
			intake_envelopes[cylinder_index] = intake_envelope * intake_decay

		var cylinder_scale := sqrt(float(cylinder_count))
		combustion_mix /= cylinder_scale
		injector_mix /= cylinder_scale
		exhaust_mix /= cylinder_scale
		intake_mix /= cylinder_scale

		var noise := _next_noise()
		intake_noise_state = lerpf(intake_noise_state, noise, 0.24)
		exhaust_noise_state = lerpf(exhaust_noise_state, noise, 0.075)
		var exhaust_tone := (
			sin(firing_phase) * 0.22 +
			sin(firing_phase * 2.0) * 0.11 +
			sin(firing_phase * 3.0) * 0.055 +
			sin(firing_phase * 4.0) * 0.025
		)
		var mechanical_tone := (
			sin(crank_phase) * 0.035 +
			sin(crank_phase * 2.0) * 0.045 +
			sin(crank_phase * 4.0) * 0.025 +
			sin(crank_phase * 8.0) * 0.012
		)
		var combustion_noise := (
			noise * combustion_mix * firing_noise_gain +
			exhaust_tone * combustion_mix * 0.18
		)
		var intake_noise := (
			intake_noise_state *
			intake_gain *
			(0.35 + intake_mix * 0.85)
		)
		var exhaust_noise := (
			exhaust_noise_state *
			exhaust_gain *
			(0.4 + exhaust_mix * 0.85)
		)
		var injector_click := noise * injector_mix * 0.04
		var diesel_clatter := 0.0
		if diesel:
			diesel_clatter = (
				sin(crank_phase * 8.0) * (0.014 + load * 0.014) +
				injector_click
			)
		var sample := (
			mechanical_tone * (0.5 + load * 0.12) +
			exhaust_tone * (0.08 + load * 0.04) +
			combustion_noise * combustion_gain +
			intake_noise +
			exhaust_noise +
			diesel_clatter
		)
		var throttle_volume := 0.88 + load * 0.12
		sample = clampf(sample * throttle_volume, -0.85, 0.85)
		playback.push_frame(Vector2(sample, sample))

		audio_crank_angle_deg = next_angle
		crank_phase = fposmod(crank_phase + crank_increment, TAU)
		firing_phase = fposmod(firing_phase + firing_increment, TAU)


func stop(audio_player: AudioStreamPlayer) -> void:
	if is_instance_valid(audio_player):
		audio_player.stop()
	playback = null
	generator = null
	initialized = false
	cylinder_fire_envelopes.clear()
	injector_envelopes.clear()
	exhaust_envelopes.clear()
	intake_envelopes.clear()
	exhaust_noise_state = 0.0
	intake_noise_state = 0.0


func _start(simulator: EngineSimulator, audio_player: AudioStreamPlayer) -> void:
	generator = AudioStreamGenerator.new()
	generator.mix_rate = int(SAMPLE_RATE)
	generator.buffer_length = 0.12
	audio_player.stream = generator
	audio_player.play()
	playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	audio_crank_angle_deg = simulator.crank_angle_deg
	initialized = playback != null


func _crosses_angle(previous: float, current: float, target: float) -> bool:
	var travel := fposmod(current - previous, CYCLE_DEGREES)
	var distance := fposmod(target - previous, CYCLE_DEGREES)
	return travel > 0.0 and distance > 0.0 and distance <= travel


func _next_noise() -> float:
	noise_state = fposmod(noise_state * 16807.0, 2147483647.0)
	return noise_state / 1073741823.5 - 1.0
