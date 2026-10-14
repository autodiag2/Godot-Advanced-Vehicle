extends Control


@onready var speedlabel = $Essentials/VBoxContainer/Speedlabel
@onready var gearlabel = $Essentials/VBoxContainer/GearLabel
@onready var rpmlabel = $Essentials/VBoxContainer/RpmLabel
@onready var fuellabel = $Essentials/VBoxContainer/FuelLabel
@onready var TireInfoApp = $TireInfoApp

var vehicle: BaseCar

@warning_ignore("shadowed_variable")
func set_vehicle(vehicle: BaseCar) -> void:
	assert(vehicle != null)
	self.vehicle = vehicle
	TireInfoApp.onSetVehicle(vehicle)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	speedlabel.text = "Speed = %d" % vehicle.getSpeedKmH()
	
	gearlabel.text = "gear = %d" % vehicle.powertrain_controller.drivetrain.selected_gear
	rpmlabel.text = "RPM = %d" % int(vehicle.engine_controller.rpm)
	fuellabel.text = "Fuel = %3.2f" % vehicle.engine_controller.fuel_litres
