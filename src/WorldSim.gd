class_name WorldSim
extends Node

@export var default_world: PackedScene = preload("res://assets/world/grass_loop.tscn")
@export var default_vehicle: PackedScene = preload("res://assets/vehicle/sport_car.tscn")
@export var hud_scene: PackedScene = preload("res://assets/ui/gui.tscn")
@export var setup_scene: PackedScene

@onready var world_root := $WorldRoot
@onready var vehicle_root := $VehicleRoot
@onready var ui_root := $UIRoot

var current_world: Node
var current_vehicle: Node
var hud: Control
var setup_screen: Control

func _ready() -> void:
	if hud_scene != null:
		hud = hud_scene.instantiate()
		ui_root.add_child(hud)

	if default_world != null:
		load_world(default_world)

	if default_vehicle != null:
		load_vehicle(default_vehicle)

	if setup_scene != null:
		show_setup_screen()


func load_world(scene: PackedScene) -> void:
	assert(scene != null)

	if current_world != null:
		current_world.queue_free()
		current_world = null

	current_world = scene.instantiate()
	world_root.add_child(current_world)


func load_vehicle(scene: PackedScene) -> void:
	assert(scene != null)

	if current_vehicle != null:
		current_vehicle.queue_free()
		current_vehicle = null

	current_vehicle = scene.instantiate()
	vehicle_root.add_child(current_vehicle)

	var car := current_vehicle.find_child("RigidBodyCar", true, false) as BaseCar
	assert(car != null)

	if hud != null:
		var joystick := hud.find_child("Joystick", true, false) as Control
		assert(joystick != null)
		car.set_joystick(joystick)
		if hud.has_method("set_vehicle"):
			hud.set_vehicle(car)

func show_setup_screen() -> void:
	if setup_screen != null:
		return

	setup_screen = setup_scene.instantiate()
	ui_root.add_child(setup_screen)

	if setup_screen.has_method("setup"):
		setup_screen.setup(self)


func hide_setup_screen() -> void:
	if setup_screen == null:
		return

	setup_screen.queue_free()
	setup_screen = null


func setup_vehicle(scene: PackedScene) -> void:
	load_vehicle(scene)
	hide_setup_screen()


func setup_world(scene: PackedScene) -> void:
	load_world(scene)


func setup(world_scene: PackedScene, vehicle_scene: PackedScene) -> void:
	load_world(world_scene)
	load_vehicle(vehicle_scene)
	hide_setup_screen()
