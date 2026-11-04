class_name EngineAudioSynthesizer
extends RefCounted

const SAMPLE_RATE: float = 22050.0
const CYCLE_DEGREES: float = 720.0

var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var audio_crank_angle_deg: float = 0.0
var cylinder_fire_envelopes := PackedFloat32Array()
var injector_envelopes := PackedFloat32Array()
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

	var rpm := maxf(simulator.rpm, 0.0)
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
	var combustion_decay := exp(-1.0 / (SAMPLE_RATE * 0.045))
	var injection_decay := exp(-1.0 / (SAMPLE_RATE * 0.008))
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
	var combustion_gain := 0.2 + load * 0.7
	var intake_gain := 0.012 + throttle_amount * 0.045
	var exhaust_gain := 0.018 + load * 0.04
	var firing_noise_gain := 0.15 + load * 0.15
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

			var fire_envelope := cylinder_fire_envelopes[cylinder_index]
			var injector_envelope := injector_envelopes[cylinder_index]
			combustion_mix += fire_envelope
			injector_mix += injector_envelope
			cylinder_fire_envelopes[cylinder_index] = fire_envelope * combustion_decay
			injector_envelopes[cylinder_index] = injector_envelope * injection_decay

		combustion_mix /= sqrt(float(cylinder_count))
		injector_mix /= sqrt(float(cylinder_count))

		var noise := _next_noise()
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
		var intake_noise := noise * intake_gain
		var exhaust_noise := noise * exhaust_gain
		var injector_click := noise * injector_mix * 0.045
		var diesel_clatter := 0.0
		if diesel:
			diesel_clatter = (
				sin(crank_phase * 8.0) * (0.018 + load * 0.035) +
				injector_click
			)
		var sample := (
			mechanical_tone * (0.45 + load * 0.4) +
			exhaust_tone * (0.08 + load * 0.15) +
			combustion_noise * combustion_gain +
			intake_noise +
			exhaust_noise +
			diesel_clatter
		)
		sample = clampf(sample, -0.85, 0.85)
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
