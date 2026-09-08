@tool
class_name MatineeTimelineInteraction
extends RefCounted

signal timeline_action_selected(action: MatineeAction, track_index: int, action_index: int)
signal track_selected(track: MatineeTrack, track_index: int)
signal timeline_action_move_requested(source_track_index: int, source_action_index: int, destination_track_index: int, start_time: float)
signal seek_requested(time: float)
signal zoom_requested(factor: float, canvas_x: float)
signal pan_requested(delta_x: float)
signal action_drag_started(canvas_position: Vector2)
signal action_drag_moved(canvas_position: Vector2)
signal action_drag_finished
signal cursor_shape_changed(cursor_shape: int)
signal redraw_requested

const WHEEL_ZOOM_FACTOR := 1.15
const DRAG_THRESHOLD := 6.0
const TRACK_SNAP_INTERVAL := 0.1

var _hovered_index := -1
var _is_panning := false
var _playhead_scrub_active := false
var _press_position := Vector2.ZERO
var _pressed_track_index := -1
var _pressed_track_action_index := -1
var _track_drag_active := false
var _track_drag_destination := -1
var _track_drag_start_time := 0.0
var _track_drag_pointer_position := Vector2.ZERO
var _cursor_shape := Control.CURSOR_ARROW


func reset() -> void:
	_hovered_index = -1
	_is_panning = false
	_playhead_scrub_active = false
	_press_position = Vector2.ZERO
	_pressed_track_index = -1
	_pressed_track_action_index = -1
	_track_drag_active = false
	_track_drag_destination = -1
	_track_drag_start_time = 0.0
	_track_drag_pointer_position = Vector2.ZERO
	_set_cursor(Control.CURSOR_ARROW)


func handle_gui_input(event: InputEvent, sequence: MatineeSequence, layout, total_duration: float) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if _playhead_scrub_active:
				_finish_playhead_scrub()
				return true
			if _track_drag_active:
				_reset_track_drag()
				return true
			if _is_panning:
				_cancel_pointer_gesture()
				return true
		return false

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _playhead_scrub_active:
			if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_finish_playhead_scrub()
				return false
			_seek_to_pointer(motion.position.x, layout, total_duration)
			_set_cursor(Control.CURSOR_HSIZE)
			return true
		if _is_panning:
			pan_requested.emit(motion.relative.x)
			return true
		if _pressed_track_index >= 0 and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if not _track_drag_active and motion.position.distance_to(_press_position) >= DRAG_THRESHOLD:
				_track_drag_active = true
				action_drag_started.emit(motion.position)
			if _track_drag_active:
				_update_track_drag(sequence, layout, motion.position)
				action_drag_moved.emit(motion.position)
				return true
		_update_hovered_row(sequence, layout, motion.position)
		_update_pointer_cursor(sequence, layout, motion.position)
		return false

	if not event is InputEventMouseButton:
		return false

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
		_is_panning = mouse_event.pressed
		_set_cursor(Control.CURSOR_DRAG if _is_panning else _cursor_shape_for(sequence, layout, mouse_event.position))
		return true

	if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
		if _playhead_scrub_active:
			_finish_playhead_scrub()
			_set_cursor(_cursor_shape_for(sequence, layout, mouse_event.position))
			return true
		if _track_drag_active:
			_commit_track_drag(sequence)
			return true
		_reset_track_drag()
		return false

	if mouse_event.pressed and mouse_event.ctrl_pressed:
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_requested.emit(WHEEL_ZOOM_FACTOR, mouse_event.position.x)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_requested.emit(1.0 / WHEEL_ZOOM_FACTOR, mouse_event.position.x)
			return true

	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false
	if not is_instance_valid(sequence):
		return false

	if mouse_event.position.y <= layout.ruler_height and mouse_event.position.x >= layout.label_width:
		_playhead_scrub_active = true
		_seek_to_pointer(mouse_event.position.x, layout, total_duration)
		_set_cursor(Control.CURSOR_HSIZE)
		return true

	var hit := _get_track_item_at(sequence, layout, mouse_event.position)
	if hit.is_empty():
		return false
	if int(hit["action_index"]) < 0:
		track_selected.emit(hit["track"], int(hit["track_index"]))
	else:
		var track := hit["track"] as MatineeTrack
		var clip := hit["clip"] as MatineeTimelineAction
		timeline_action_selected.emit(clip.action, int(hit["track_index"]), int(hit["action_index"]))
		if not track.locked:
			_pressed_track_index = int(hit["track_index"])
			_pressed_track_action_index = int(hit["action_index"])
			_press_position = mouse_event.position
	return true


func clear_hover() -> void:
	if _hovered_index == -1:
		return
	_hovered_index = -1
	_set_cursor(Control.CURSOR_ARROW)
	redraw_requested.emit()


func cancel_pointer_gesture() -> void:
	_cancel_pointer_gesture()


func offset_action_drag(sequence: MatineeSequence, layout, scroll_delta: Vector2) -> void:
	if not _track_drag_active or scroll_delta.is_zero_approx():
		return
	_update_track_drag(sequence, layout, _track_drag_pointer_position + scroll_delta)


func is_pointer_busy() -> bool:
	return _is_panning or _playhead_scrub_active or _track_drag_active


func is_panning() -> bool:
	return _is_panning


func is_playhead_scrub_active() -> bool:
	return _playhead_scrub_active


func get_hovered_index() -> int:
	return _hovered_index


func is_track_drag_active() -> bool:
	return _track_drag_active


func get_pressed_track_index() -> int:
	return _pressed_track_index


func get_pressed_track_action_index() -> int:
	return _pressed_track_action_index


func get_track_drag_destination() -> int:
	return _track_drag_destination


func get_track_drag_start_time() -> float:
	return _track_drag_start_time


func _update_hovered_row(sequence: MatineeSequence, layout, position: Vector2) -> void:
	var next_index: int = layout.row_index_at(position.y)
	if not is_instance_valid(sequence):
		next_index = -1
	elif next_index < 0 or next_index >= sequence.tracks.size():
			next_index = -1
	if next_index == _hovered_index:
		return
	_hovered_index = next_index
	redraw_requested.emit()


func _update_pointer_cursor(sequence: MatineeSequence, layout, position: Vector2) -> void:
	_set_cursor(_cursor_shape_for(sequence, layout, position))


func _cursor_shape_for(sequence: MatineeSequence, layout, position: Vector2) -> int:
	if _is_panning or _track_drag_active:
		return Control.CURSOR_DRAG
	if position.y <= layout.ruler_height and position.x >= layout.label_width:
		return Control.CURSOR_HSIZE
	if is_instance_valid(sequence):
		var hit := _get_track_item_at(sequence, layout, position)
		if not hit.is_empty():
			return Control.CURSOR_MOVE if int(hit["action_index"]) >= 0 else Control.CURSOR_POINTING_HAND
	return Control.CURSOR_ARROW


func _set_cursor(shape: int) -> void:
	if _cursor_shape == shape:
		return
	_cursor_shape = shape
	cursor_shape_changed.emit(shape)


func _seek_to_pointer(position_x: float, layout, total_duration: float) -> void:
	seek_requested.emit(clampf(layout.x_to_time(position_x), 0.0, total_duration))


func _finish_playhead_scrub() -> void:
	_playhead_scrub_active = false
	_set_cursor(Control.CURSOR_ARROW)


func _get_track_item_at(sequence: MatineeSequence, layout, position: Vector2) -> Dictionary:
	var track_index: int = layout.row_index_at(position.y)
	if track_index < 0 or track_index >= sequence.tracks.size():
		return {}
	var track := sequence.tracks[track_index]
	if track == null:
		return {}
	if position.x < layout.label_width:
		return {"track": track, "track_index": track_index, "action_index": -1}
	if not track.visible:
		return {}
	for action_index in range(track.actions.size()):
		var clip := track.actions[action_index]
		if clip == null or clip.action == null:
			continue
		if layout.clip_rect(track_index, clip.start_time, clip.duration).has_point(position):
			return {"track": track, "clip": clip, "track_index": track_index, "action_index": action_index}
	return {}


func _update_track_drag(sequence: MatineeSequence, layout, position: Vector2) -> void:
	_track_drag_pointer_position = position
	_track_drag_destination = layout.drag_destination_row(position.y, sequence.tracks.size())
	_track_drag_start_time = maxf(layout.snapped_time_for_x(position.x, TRACK_SNAP_INTERVAL), 0.0)
	redraw_requested.emit()


func _commit_track_drag(sequence: MatineeSequence) -> void:
	var destination := _track_drag_destination
	var source_track := _pressed_track_index
	var source_action := _pressed_track_action_index
	var destination_track := sequence.tracks[destination] if destination >= 0 and destination < sequence.tracks.size() else null
	if destination_track != null and not destination_track.locked:
		timeline_action_move_requested.emit(source_track, source_action, destination, _track_drag_start_time)
	_reset_track_drag()


func _reset_track_drag() -> void:
	var was_dragging := _track_drag_active
	_pressed_track_index = -1
	_pressed_track_action_index = -1
	_track_drag_active = false
	_track_drag_destination = -1
	_track_drag_start_time = 0.0
	_track_drag_pointer_position = Vector2.ZERO
	if was_dragging:
		action_drag_finished.emit()
	redraw_requested.emit()


func _cancel_pointer_gesture() -> void:
	_is_panning = false
	_finish_playhead_scrub()
	_reset_track_drag()
	_set_cursor(Control.CURSOR_ARROW)
