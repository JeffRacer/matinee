class_name MatineeCameraState
extends RefCounted

var camera: Camera2D
var global_position: Vector2 = Vector2.ZERO
var global_rotation: float = 0.0
var rendered_position: Vector2 = Vector2.ZERO
var rendered_rotation: float = 0.0
var zoom: Vector2 = Vector2.ONE
var offset: Vector2 = Vector2.ZERO
var enabled: bool = false
var was_current: bool = false
var follow_target: Node2D


static func capture(source: Camera2D) -> MatineeCameraState:
	var state := MatineeCameraState.new()
	state.camera = source
	if not is_instance_valid(source):
		return state
	state.global_position = source.global_position
	state.global_rotation = source.global_rotation
	state.rendered_position = source.global_position
	state.rendered_rotation = source.global_rotation
	state.zoom = source.zoom
	state.offset = source.offset
	state.enabled = source.enabled
	state.was_current = source.is_current()
	if source.is_inside_tree() and state.was_current:
		state.rendered_position = source.get_screen_center_position()
		state.rendered_rotation = source.get_screen_rotation()
	return state


func restore(make_current: bool = true) -> bool:
	if not is_instance_valid(camera):
		return false
	camera.global_position = global_position
	camera.global_rotation = global_rotation
	camera.zoom = zoom
	camera.offset = offset
	camera.enabled = enabled or (make_current and was_current)
	if make_current and was_current and camera.enabled and camera.is_inside_tree():
		camera.make_current()
	return true
