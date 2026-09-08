class_name MatineeCameraRuntimeSession
extends RefCounted

var clip_id: StringName
var action: MatineeCameraAction
var track_index: int = -1
var action_index: int = -1
var start_time: float = 0.0
var end_time: float = 0.0
var local_time: float = 0.0
var blend_progress: float = 0.0
var previous_state: MatineeCameraState
var previous_session: MatineeCameraRuntimeSession
var target_state: MatineeCameraState
var target_camera: Camera2D
var follow_target: Node2D
var follow_was_resolved: bool = false
var last_follow_position: Vector2 = Vector2.ZERO
var follow_loss_reported: bool = false
var entered: bool = false
var controls_camera: bool = false
var cut_applied: bool = false
var target_activated: bool = false
var restored: bool = false
var failed: bool = false
var failure_message: String = ""


func configure(camera_action: MatineeCameraAction, entry: Dictionary) -> void:
	action = camera_action
	track_index = int(entry.get("track_index", -1))
	action_index = int(entry.get("action_index", -1))
	start_time = float(entry.get("start", 0.0))
	end_time = float(entry.get("end", start_time))
	clip_id = StringName("%d:%d:%d" % [track_index, action_index, camera_action.get_instance_id()])
	entered = true


func has_higher_priority_than(other: MatineeCameraRuntimeSession) -> bool:
	if other == null:
		return true
	if track_index != other.track_index:
		return track_index > other.track_index
	if not is_equal_approx(start_time, other.start_time):
		return start_time > other.start_time
	return action_index > other.action_index


func mark_failed(message: String) -> void:
	failed = true
	failure_message = message
	controls_camera = false
