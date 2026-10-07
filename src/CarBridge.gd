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

	var car = get_tree().get_first_node_in_group(
		"player_car"
	)

	if car == null:
		return

	bridge.setSignal(
		"SAEJ1979.engine_speed",
		car.engine_controller.rpm
	)

	bridge.setSignal(
		"SAEJ1979.vehicle_speed",
		car.getSpeedKmH()
	)

	bridge.setSignal(
		"SAEJ1979.fuel_tank_level_input",
		car.engine_controller.fuel_litres /
		car.parameters.fuel_tank_size
	)

	bridge.setSignal(
		"SAEJ1979.relative_accelerator_pedal_position",
		car.input_controller.throttle
	)

	bridge.setSignal(
		"SAEJ1979.actual_engine_percent_torque",
		car.engine_controller.output_torque /
		car.parameters.engine.max_torque *
		100
	)
