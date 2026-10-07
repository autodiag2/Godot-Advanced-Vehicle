class_name WorldSim
extends Node

const WORLD_PATH := "res://assets/world/"
const VEHICLE_PATH := "res://assets/vehicle/"
const VEHICLE_SPAWN := "VehicleSpawn"

@export var default_world: PackedScene
@export var default_vehicle: PackedScene
@export var hud_scene: PackedScene
@export var setup_scene: PackedScene

@onready var world_root := $WorldRoot
@onready var vehicle_root := $VehicleRoot
@onready var ui_root := $UIRoot

var current_world: Node
var current_vehicle_container: Node
var current_vehicle: BaseCar
var hud: Control
var setup_screen: Control
var world_scenes: Array[PackedScene] = []
var vehicle_scenes: Array[PackedScene] = []

func _ready() -> void:
	_load_world_scenes()
	_load_vehicle_scenes()
	if hud_scene != null:
		hud = hud_scene.instantiate()
		ui_root.add_child(hud)

	if default_world != null:
		load_world(default_world)

	if default_vehicle != null:
		load_vehicle(default_vehicle)

	if setup_scene != null:
		show_setup_screen()


func _load_world_scenes() -> void:
	world_scenes.clear()

	var dir := DirAccess.open(WORLD_PATH)
	assert(dir != null)

	for folder_name in dir.get_directories():
		var path := "%s/%s/world.tscn" % [WORLD_PATH, folder_name]
		var scene := load(path) as PackedScene
		if scene != null:
			world_scenes.append(scene)


func _load_vehicle_scenes() -> void:
	vehicle_scenes.clear()

	var dir := DirAccess.open(VEHICLE_PATH)
	assert(dir != null)

	for folder_name in dir.get_directories():
		var path := "%s/%s/vehicle.tscn" % [VEHICLE_PATH, folder_name]
		var scene := load(path) as PackedScene
		if scene != null:
			vehicle_scenes.append(scene)


func load_world(world: Variant) -> void:
	var scene: PackedScene
	if world is String:
		var path: String
		if world.begins_with(WORLD_PATH):
			path = world
		else:
			path = "%s/%s/world.tscn" % [WORLD_PATH, world]

		scene = load(path) as PackedScene
	elif world is PackedScene:
		scene = world
	else:
		assert(false, "Invalid world type")
	
	assert(scene != null)

	if current_world != null:
		current_world.queue_free()
		current_world = null

	current_world = scene.instantiate()
	world_root.add_child(current_world)

	_position_vehicle_on_world()

func load_vehicle(vehicle: Variant) -> void:
	var scene: PackedScene

	if vehicle is String:
		var path: String
		if vehicle.begins_with(VEHICLE_PATH):
			path = vehicle
		else:
			path = "%s/%s/vehicle.tscn" % [VEHICLE_PATH, vehicle]

		scene = load(path) as PackedScene
	elif vehicle is PackedScene:
		scene = vehicle
	else:
		assert(false, "Invalid vehicle type")

	assert(scene != null)

	var parameters_path := scene.resource_path.get_base_dir() + "/parameters.tres"
	var car_parameters := load(parameters_path) as CarParameters
	assert(car_parameters != null, "Vehicle must contain parameters.tres")

	if current_vehicle != null:
		current_vehicle.queue_free()
		current_vehicle = null

	if current_vehicle_container != null:
		current_vehicle_container.queue_free()
		current_vehicle_container = null

	current_vehicle_container = scene.instantiate()
	vehicle_root.add_child(current_vehicle_container)

	var car := current_vehicle_container as BaseCar
	if car == null:
		car = current_vehicle_container.find_child("Vehicle", true, false) as BaseCar

	assert(car != null)
	current_vehicle = car
	current_vehicle.set_parameters(car_parameters)

	if hud != null:
		var joystick := hud.find_child("Joystick", true, false) as Control
		assert(joystick != null)
		car.set_joystick(joystick)

		if hud.has_method("set_vehicle"):
			hud.set_vehicle(car)

	_position_vehicle_on_world()

func _position_vehicle_on_world() -> void:
	if current_world == null:
		return

	if current_vehicle == null:
		return

	var vehicle_spawn := current_world.find_child(
		VEHICLE_SPAWN,
		true,
		false
	) as Node3D

	assert(vehicle_spawn != null, "World must contain a " + VEHICLE_SPAWN + " Node3D")

	current_vehicle.global_position = vehicle_spawn.global_position
	current_vehicle.linear_velocity = Vector3.ZERO
	current_vehicle.angular_velocity = Vector3.ZERO
	current_vehicle.sleeping = false
	current_vehicle.spawn()


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


func setup_world(world: Variant) -> void:
	load_world(world)


func setup(world: Variant, vehicle_scene: PackedScene) -> void:
	load_world(world)
	load_vehicle(vehicle_scene)
	hide_setup_screen()
