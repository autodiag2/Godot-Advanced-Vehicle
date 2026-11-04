class_name VirtualJoystick

extends Control

const REPOSITION_AREA_SCALE: float = 3.0
const REPOSITION_HOLD_DURATION: float = 0.24
const REPOSITION_DRAG_THRESHOLD: float = 8.0

## A simple virtual joystick for touchscreens, with useful options.
## Github: https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot

# EXPORTED VARIABLE

## The color of the button when the joystick is pressed.
@export var pressed_color := Color.GRAY

## If the input is inside this range, the output is zero.
@export_range(0, 200, 1) var deadzone_size : float = 10

## The max distance the tip can reach.
@export_range(0, 500, 1) var clampzone_size : float = 75

enum Joystick_mode {
	FIXED, ## The joystick doesn't move.
	DYNAMIC, ## Every time the joystick area is pressed, the joystick position is set on the touched position.
	FOLLOWING ## When the finger moves outside the joystick area, the joystick will follow it.
}

## If the joystick stays in the same position or appears on the touched position when touch is started
@export var joystick_mode := Joystick_mode.FIXED

enum Visibility_mode {
	ALWAYS, ## Always visible
	TOUCHSCREEN_ONLY, ## Visible on touch screens only
	WHEN_TOUCHED ## Visible only when touched
}

## If the joystick is always visible, or is shown only if there is a touchscreen
@export var visibility_mode := Visibility_mode.ALWAYS

## If true, the joystick uses Input Actions (Project -> Project Settings -> Input Map)
@export var use_input_actions := true

@export var action_left := "ui_left"
@export var action_right := "ui_right"
@export var action_up := "ui_up"
@export var action_down := "ui_down"

# PUBLIC VARIABLES

## If the joystick is receiving inputs.
var is_pressed := false

# The joystick output.
var output := Vector2.ZERO

# PRIVATE VARIABLES

var _touch_index : int = -1
var _reposition_touch_index: int = -1
var _reposition_touch_position := Vector2.ZERO
var _reposition_hold_elapsed: float = 0.0

@onready var _base := $Base
@onready var _tip := $Base/Tip

@onready var _base_default_position : Vector2 = _base.position
@onready var _tip_default_position : Vector2 = _tip.position

@onready var _default_color : Color = _tip.modulate

# FUNCTIONS

func _ready() -> void:
	if ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"):
		printerr("The Project Setting 'emulate_mouse_from_touch' should be set to False")
	if not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
		printerr("The Project Setting 'emulate_touch_from_mouse' should be set to True")
	
	if not DisplayServer.is_touchscreen_available() and visibility_mode == Visibility_mode.TOUCHSCREEN_ONLY :
		hide()
	
	if visibility_mode == Visibility_mode.WHEN_TOUCHED:
		hide()

func _process(delta: float) -> void:
	if _reposition_touch_index == -1:
		return
	_reposition_hold_elapsed += delta
	if _reposition_hold_elapsed >= REPOSITION_HOLD_DURATION:
		_activate_reposition(
			_reposition_touch_index,
			_reposition_touch_position
		)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if (
				_touch_index == -1 and
				_reposition_touch_index == -1 and
				_is_point_inside_joystick_area(event.position) and
				not _is_point_over_gui_button(event.position)
			):
				if joystick_mode == Joystick_mode.DYNAMIC or joystick_mode == Joystick_mode.FOLLOWING:
					_move_base(event.position)
					_begin_touch(event.index, event.position)
				elif _is_point_inside_base(event.position):
					_begin_touch(event.index, event.position)
				else:
					_reposition_touch_index = event.index
					_reposition_touch_position = event.position
					_reposition_hold_elapsed = 0.0
				get_viewport().set_input_as_handled()
		else:
			if event.index == _touch_index:
				_reset()
				if visibility_mode == Visibility_mode.WHEN_TOUCHED:
					hide()
				get_viewport().set_input_as_handled()
			elif event.index == _reposition_touch_index:
				_cancel_reposition()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == _reposition_touch_index:
			if event.position.distance_to(_reposition_touch_position) >= REPOSITION_DRAG_THRESHOLD:
				var origin := _reposition_touch_position
				_activate_reposition(event.index, origin)
				_update_joystick(event.position)
			else:
				_reposition_touch_position = event.position
			get_viewport().set_input_as_handled()


func _begin_touch(touch_index: int, touch_position: Vector2) -> void:
	if visibility_mode == Visibility_mode.WHEN_TOUCHED:
		show()
	_touch_index = touch_index
	_tip.modulate = pressed_color
	_update_joystick(touch_position)


func _activate_reposition(touch_index: int, touch_position: Vector2) -> void:
	_move_base(touch_position)
	_base_default_position = _base.position
	_reposition_touch_index = -1
	_reposition_hold_elapsed = 0.0
	_begin_touch(touch_index, touch_position)


func _cancel_reposition() -> void:
	_reposition_touch_index = -1
	_reposition_touch_position = Vector2.ZERO
	_reposition_hold_elapsed = 0.0

func _move_base(new_position: Vector2) -> void:
	_base.global_position = new_position - _base.pivot_offset * get_global_transform_with_canvas().get_scale()

func _move_tip(new_position: Vector2) -> void:
	_tip.global_position = new_position - _tip.pivot_offset * _base.get_global_transform_with_canvas().get_scale()

func _is_point_inside_joystick_area(point: Vector2) -> bool:
	var base_radius := _get_base_radius()
	var center := _base.global_position + base_radius
	var half_extent := base_radius * REPOSITION_AREA_SCALE
	return (
		absf(point.x - center.x) <= half_extent.x and
		absf(point.y - center.y) <= half_extent.y
	)

func _is_point_over_gui_button(point: Vector2) -> bool:
	var gui_root := get_parent().get_parent()
	for node in gui_root.find_children("*", "TouchScreenButton", true, false):
		var button := node as TouchScreenButton
		var texture := button.texture_normal
		if texture == null:
			texture = button.texture_pressed
		if not button.is_visible_in_tree() or texture == null:
			continue
		var local_point := button.get_global_transform_with_canvas().affine_inverse() * point
		var texture_size := Vector2(texture.get_size())
		if Rect2(-texture_size * 0.5, texture_size).has_point(local_point):
			return true

	for node in gui_root.find_children("*", "BaseButton", true, false):
		var button := node as Control
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return true
	return false


func _get_base_radius() -> Vector2:
	return _base.size * _base.get_global_transform_with_canvas().get_scale() / 2

func _is_point_inside_base(point: Vector2) -> bool:
	var _base_radius = _get_base_radius()
	var center : Vector2 = _base.global_position + _base_radius
	var vector : Vector2 = point - center
	if vector.length_squared() <= _base_radius.x * _base_radius.x:
		return true
	else:
		return false

func _update_joystick(touch_position: Vector2) -> void:
	var _base_radius = _get_base_radius()
	var center : Vector2 = _base.global_position + _base_radius
	var vector : Vector2 = touch_position - center
	vector = vector.limit_length(clampzone_size)
	
	if joystick_mode == Joystick_mode.FOLLOWING and touch_position.distance_to(center) > clampzone_size:
		_move_base(touch_position - vector)
	
	_move_tip(center + vector)
	
	if vector.length_squared() > deadzone_size * deadzone_size:
		is_pressed = true
		output = (vector - (vector.normalized() * deadzone_size)) / (clampzone_size - deadzone_size)
	else:
		is_pressed = false
		output = Vector2.ZERO
	
	if use_input_actions:
		# Release actions
		if output.x >= 0 and Input.is_action_pressed(action_left):
			Input.action_release(action_left)
		if output.x <= 0 and Input.is_action_pressed(action_right):
			Input.action_release(action_right)
		if output.y >= 0 and Input.is_action_pressed(action_up):
			Input.action_release(action_up)
		if output.y <= 0 and Input.is_action_pressed(action_down):
			Input.action_release(action_down)
		# Press actions
		if output.x < 0:
			Input.action_press(action_left, -output.x)
		if output.x > 0:
			Input.action_press(action_right, output.x)
		if output.y < 0:
			Input.action_press(action_up, -output.y)
		if output.y > 0:
			Input.action_press(action_down, output.y)

func _reset():
	is_pressed = false
	output = Vector2.ZERO
	_touch_index = -1
	_tip.modulate = _default_color
	_base.position = _base_default_position
	_tip.position = _tip_default_position
	# Release actions
	if use_input_actions:
		for action in [action_left, action_right, action_down, action_up]:
			if Input.is_action_pressed(action):
				Input.action_release(action)
