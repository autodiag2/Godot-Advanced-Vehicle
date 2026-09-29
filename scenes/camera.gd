extends Camera3D

# This script is taken from Bastiaan Olijs vehicle demo, available at https://github.com/BastiaanOlij/vehicle-demo

#MIT License
#
#Copyright (c) 2018 Bastiaan Olij
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#
#IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
#DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
#OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
#USE OR OTHER DEALINGS IN THE SOFTWARE.


@export var follow_this_path: NodePath

@export var target_distance := 5.0
@export var target_height := 0.8
@export var lerp_speed := 20.0
@export var touch_sensitivity := 0.08

var follow_this = null
var last_lookat = null

var camera_yaw := 0.0
var camera_pitch := 5.0


func _ready():
	follow_this = get_node(follow_this_path)
	last_lookat = follow_this.global_transform.origin
	set_as_top_level(true)


func _input(event):
	if event is InputEventScreenDrag:
		camera_yaw -= (
			event.relative.x *
			touch_sensitivity
		)

		camera_pitch -= (
			event.relative.y *
			touch_sensitivity
		)

		camera_pitch = clamp(
			camera_pitch,
			-10.0,
			75.0
		)


func _physics_process(delta):
	set_as_top_level(true)

	var target_origin: Vector3 = (
		follow_this.global_transform.origin
	)

	var yaw := deg_to_rad(camera_yaw)
	var pitch := deg_to_rad(camera_pitch)

	var horizontal_distance := (
		cos(pitch) *
		target_distance
	)

	var vertical_distance := (
		sin(pitch) *
		target_distance
	)

	var rotated_offset := Vector3(
		0.0,
		vertical_distance,
		horizontal_distance
	)

	rotated_offset = rotated_offset.rotated(
		Vector3.UP,
		yaw
	)

	var target_pos := (
		target_origin +
		rotated_offset
	)

	target_pos.y += target_height

	global_transform.origin = (
		global_transform.origin.lerp(
			target_pos,
			delta * lerp_speed
		)
	)

	var lookat_position := (
		target_origin +
		Vector3.UP *
		target_height
	)

	last_lookat = last_lookat.lerp(
		lookat_position,
		delta * lerp_speed
	)

	look_at(
		last_lookat,
		Vector3.UP
	)
