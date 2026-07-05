extends Node

var bridge = null

func _ready():

	var wrapper = Engine.get_singleton(
		"JavaClassWrapper"
	)

	if wrapper == null:
		print("JavaClassWrapper not found")
		return

	bridge = wrapper.wrap(
		"com.github.autodiag2.elm327emu.sim.CarBridge"
	)

	if bridge == null:
		print("Failed to wrap Kotlin CarBridge")
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
		car.rpm
	)

	bridge.setSignal(
		"SAEJ1979.vehicle_speed",
		car.speedo
	)

	bridge.setSignal(
		"SAEJ1979.fuel_tank_level_input",
		car.fuel / car.car_params.fuel_tank_size
	)

	bridge.setSignal(
		"SAEJ1979.relative_accelerator_pedal_position",
		car.throttle_input
	)

	bridge.setSignal(
		"SAEJ1979.actual_engine_percent_torque",
		car.torque_out / car.max_torque * 100
	)