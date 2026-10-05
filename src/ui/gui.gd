extends Control

@onready var speedlabel = $Essentials/VBoxContainer/Speedlabel
@onready var gearlabel = $Essentials/VBoxContainer/GearLabel
@onready var rpmlabel = $Essentials/VBoxContainer/RpmLabel
@onready var fuellabel = $Essentials/VBoxContainer/FuelLabel
@onready var BreakPadsUsageLabel = $Essentials/VBoxContainer/BreakPadsUsageLabel
@onready var TireInfoApp = $TireInfoApp

var vehicle: BaseCar

func set_vehicle(vehicle_arg: BaseCar) -> void:
	vehicle = vehicle_arg
	TireInfoApp.onSetVehicle(vehicle)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if ( vehicle == null ):
		return

	speedlabel.text = "Speed = %d" % vehicle.getSpeedKmH()
	
	gearlabel.text = "gear = %d" % vehicle.powertrain_controller.drivetrain.gearbox.selected_gear
	rpmlabel.text = "RPM = %d" % int(vehicle.engine_controller.rpm)
	fuellabel.text = "Fuel = %3.2f" % vehicle.engine_controller.fuel_litres
	
	var usage : Array = vehicle.getBrakePadsUsagePercent()
	BreakPadsUsageLabel.text = (
		"BP FL FR BL BR = %.2f%% %.2f%% %.2f%% %.2f%%"
		% usage
	)
