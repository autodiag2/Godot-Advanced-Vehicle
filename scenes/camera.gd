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
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.


@export var follow_this_path: NodePath

@export var target_distance := 3.0
@export var target_height := 1.0
@export var lerp_speed := 20.0
@export var touch_sensitivity := 0.01

var follow_this = null
var last_lookat =  null

var camera_yaw := 0.0
var camera_pitch := -15.0


func _ready():
	follow_this = get_node(follow_this_path)
	last_lookat = follow_this.global_transform.origin
	set_as_top_level(true)


func _input(event):
	if event is InputEventScreenDrag:
		camera_yaw -= event.relative.x * touch_sensitivity
		camera_pitch -= event.relative.y * touch_sensitivity
		camera_pitch = clamp(
			camera_pitch,
			-60.0,
			20.0
		)


func _physics_process(delta):
	set_as_top_level(true)
	var delta_v = global_transform.origin - follow_this.global_transform.origin
	var target_pos = global_transform.origin

	# ignore y
	delta_v.y = 0.0

	if (delta_v.length() > target_distance):
		delta_v = delta_v.normalized() * target_distance
		delta_v.y = target_height
		target_pos = follow_this.global_transform.origin + delta_v
	else:
		target_pos.y = follow_this.global_transform.origin.y + target_height

	# Apply camera rotation from touch dragging
	var horizontal_distance := Vector2(
		delta_v.x,
		delta_v.z
	).length()

	var rotated_offset := Vector3(
		0.0,
		0.0,
		horizontal_distance
	)

	rotated_offset = rotated_offset.rotated(
		Vector3.UP,
		camera_yaw
	)

	var right_axis := Vector3(
		cos(camera_yaw),
		0.0,
		-sin(camera_yaw)
	)

	rotated_offset = rotated_offset.rotated(
		right_axis,
		deg_to_rad(camera_pitch)
	)

	target_pos = follow_this.global_transform.origin + rotated_offset
	target_pos.y += target_height

	global_transform.origin = global_transform.origin.lerp(
		target_pos,
		delta * lerp_speed
	)

	last_lookat = last_lookat.lerp(
		follow_this.global_transform.origin,
		delta * lerp_speed
	)

	look_at(
		last_lookat,
		Vector3(0.0, 1.0, 0.0)
	)
