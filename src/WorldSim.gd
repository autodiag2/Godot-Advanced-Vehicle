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
var current_world_scene: PackedScene
var current_vehicle_scene: PackedScene
var hud: Control
var setup_screen: Control
var world_scenes: Array[PackedScene] = []
var vehicle_scenes: Array[PackedScene] = []
var load_generation := 0

func reload() -> void:
	_replace_world(current_world_scene)
	_replace_vehicle(current_vehicle_scene)

func _ready() -> void:
	_load_world_scenes()
	_load_vehicle_scenes()

	if hud_scene != null:
		hud = hud_scene.instantiate()
		ui_root.add_child(hud)
		var restart_sim = hud.find_child("restart_sim", true, false)
		restart_sim.onInitWorldSim(self)

	if default_world != null:
		current_world_scene = default_world
		_replace_world(default_world)

	if default_vehicle != null:
		current_vehicle_scene = default_vehicle
		_replace_vehicle(default_vehicle)

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

	current_world_scene = scene
	load_generation += 1
	_replace_world(scene)

	if current_vehicle_scene != null:
		_replace_vehicle(current_vehicle_scene)


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

	current_vehicle_scene = scene
	load_generation += 1
	_replace_vehicle(scene)


func _replace_world(scene: PackedScene) -> void:
	if current_world != null:
		current_world.queue_free()
		current_world = null

	current_world = scene.instantiate()
	world_root.add_child(current_world)


func _replace_vehicle(scene: PackedScene) -> void:
	load_generation += 1
	var generation := load_generation

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

	var parameters_path := scene.resource_path.get_base_dir() + "/parameters.tres"
	var car_parameters := load(parameters_path) as CarParameters

	if car_parameters == null:
		push_warning("Vehicle should contain parameters.tres")
		car_parameters = CarParameters.new()

	car.set_parameters(car_parameters)

	if hud != null:
		var joystick := hud.find_child("Joystick", true, false) as Control
		assert(joystick != null)
		car.set_joystick(joystick)

		if hud.has_method("set_vehicle"):
			hud.set_vehicle(car)

	_position_vehicle_on_world(generation)


func _position_vehicle_on_world(generation: int) -> void:
	if current_world == null or current_vehicle == null:
		return

	var vehicle := current_vehicle
	var world := current_world
	var vehicle_spawn := world.find_child(
		VEHICLE_SPAWN,
		true,
		false
	) as Node3D

	vehicle.freeze = true

	if vehicle_spawn == null:
		vehicle.global_position = Vector3(0.0, 10.0, 0.0)
		push_warning("World must contain a " + VEHICLE_SPAWN + " Node3D")
	else:
		vehicle.global_transform = vehicle_spawn.global_transform

	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.reset_physics_interpolation()

	await get_tree().physics_frame

	if generation != load_generation:
		return

	if not is_instance_valid(vehicle) or not is_instance_valid(world):
		return

	if vehicle_spawn != null and is_instance_valid(vehicle_spawn):
		vehicle.global_transform = vehicle_spawn.global_transform
	else:
		vehicle.global_position = Vector3(0.0, 10.0, 0.0)

	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.reset_physics_interpolation()
	vehicle.freeze = false
	vehicle.spawn()


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

	assert(scene != null)

	current_world_scene = scene
	current_vehicle_scene = vehicle_scene
	load_generation += 1
	_replace_world(scene)
	_replace_vehicle(vehicle_scene)
	hide_setup_screen()
