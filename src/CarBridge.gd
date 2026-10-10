extends Node

var bridge = null


func _ready():

	var wrapper = Engine.get_singleton(
		"JavaClassWrapper"
	)

	if wrapper == null:
		push_warning("JavaClassWrapper not found")
		return

	bridge = wrapper.wrap(
		"com.github.autodiag2.elm327emu.sim.CarBridge"
	)

	if bridge == null:
		push_warning("Failed to wrap Kotlin CarBridge")
		return


func _process(_delta):

	if bridge == null:
		return

	var vehicle := get_tree().get_first_node_in_group(
		"player_car"
	) as Vehicle

	if vehicle == null:
		return

	bridge.setSignal(
		"SAEJ1979.engine_speed",
		vehicle.engine.rpm
	)

	bridge.setSignal(
		"SAEJ1979.vehicle_speed",
		vehicle.getSpeedKmH()
	)

	bridge.setSignal(
		"SAEJ1979.fuel_tank_level_input",
		vehicle.engine.fuel_tank.fuel_litres /
		vehicle.parameters.fuel_tank_size
	)

	bridge.setSignal(
		"SAEJ1979.relative_accelerator_pedal_position",
		vehicle.input_controller.throttle
	)

	bridge.setSignal(
		"SAEJ1979.actual_engine_percent_torque",
		vehicle.engine.output_torque /
		vehicle.parameters.engine.max_torque *
		100
	)
