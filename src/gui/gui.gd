extends Control

const ENGINE_BUBBLE_SCENE: PackedScene = preload("res://assets/ui/engine_bubble.tscn")

@onready var speedlabel = $Essentials/VBoxContainer/Speedlabel
@onready var gearlabel = $Essentials/VBoxContainer/GearLabel
@onready var rpmlabel = $Essentials/VBoxContainer/RpmLabel
@onready var fuellabel = $Essentials/VBoxContainer/FuelLabel
@onready var TireInfoApp = $TireInfoApp
@onready var automatic_transmission = $Menu/VBoxContainer/MarginContainer/VBoxContainer/automatic_transmission
@onready var essentials_panel: Panel = $Essentials
@onready var essentials_container: VBoxContainer = $Essentials/VBoxContainer

var vehicle: BaseCar
var engine_button: Button
var engine_popup: EngineVisualizer


func _ready() -> void:
	essentials_panel.offset_top = -171.0
	essentials_panel.custom_minimum_size = Vector2(200.0, 171.0)
	engine_button = Button.new()
	engine_button.text = "Engine"
	engine_button.custom_minimum_size = Vector2(120.0, 30.0)
	essentials_container.add_child(engine_button)
	engine_popup = ENGINE_BUBBLE_SCENE.instantiate() as EngineVisualizer
	add_child(engine_popup)
	engine_button.pressed.connect(_show_engine_popup)


func _show_engine_popup() -> void:
	if vehicle == null:
		return
	engine_popup.set_vehicle(vehicle)
	engine_popup.popup_centered()



@warning_ignore("shadowed_variable")
func set_vehicle(vehicle: BaseCar) -> void:
	assert(vehicle != null)
	self.vehicle = vehicle
	TireInfoApp.onSetVehicle(vehicle)
	automatic_transmission.onSetVehicle(vehicle)
	engine_popup.set_vehicle(vehicle)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if vehicle == null:
		return
	engine_button.text = "Engine (%.2fx)" % Engine.time_scale
	speedlabel.text = "Speed = %d" % vehicle.getSpeedKmH()
	
	gearlabel.text = "gear = %d" % vehicle.powertrain_controller.drivetrain.selected_gear
	rpmlabel.text = "RPM = %d" % int(vehicle.engine_controller.rpm)
	fuellabel.text = "Fuel = %3.2f" % vehicle.engine_controller.fuel_litres
