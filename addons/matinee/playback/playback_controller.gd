@tool
class_name MatineePlaybackController
extends RefCounted

enum State {
	STOPPED,
	PLAYING,
	PAUSED,
}

signal playback_started
signal playback_paused
signal playback_stopped
signal playback_finished
signal state_changed(state: int)
signal time_changed(time: float)
signal action_changed(action: MatineeAction, index: int)
signal timeline_action_changed(action: MatineeAction, track_index: int, action_index: int)
signal active_actions_changed(actions: Array[MatineeAction])

var playback_speed: float = 1.0
var loop_enabled: bool = false
var current_time: float = 0.0
var state: int = State.STOPPED
var sequence: MatineeSequence

var _entries: Array[Dictionary] = []
var _duration: float = 0.0
var _current_index: int = -1
var _current_track_index: int = -1
var _active_entries: Array[Dictionary] = []


func set_sequence(value: MatineeSequence) -> void:
	sequence = value
	_rebuild_entries()
	stop()


func rebuild() -> void:
	var old_time := current_time
	_rebuild_entries()
	seek(minf(old_time, _duration))


func play() -> void:
	if not is_instance_valid(sequence) or _duration <= 0.0:
		return
	if current_time >= _duration:
		seek(0.0)
	state = State.PLAYING
	state_changed.emit(state)
	playback_started.emit()


func pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	state_changed.emit(state)
	playback_paused.emit()


func toggle_play_pause() -> void:
	if state == State.PLAYING:
		pause()
	else:
		play()


func stop() -> void:
	var was_stopped := state == State.STOPPED and is_zero_approx(current_time)
	state = State.STOPPED
	current_time = 0.0
	_set_active_entries(_find_active_entries(current_time))
	time_changed.emit(current_time)
	state_changed.emit(state)
	if not was_stopped:
		playback_stopped.emit()


func rewind() -> void:
	seek(0.0)


func seek(time: float) -> void:
	current_time = clampf(time, 0.0, _duration)
	_set_active_entries(_find_active_entries(current_time))
	time_changed.emit(current_time)


func update(delta: float) -> void:
	if state != State.PLAYING or delta <= 0.0:
		return

	current_time += delta * maxf(playback_speed, 0.01)
	if current_time >= _duration:
		if loop_enabled and _duration > 0.0:
			current_time = fmod(current_time, _duration)
			_set_active_entries(_find_active_entries(current_time))
			time_changed.emit(current_time)
			return

		current_time = _duration
		_set_active_entries([])
		time_changed.emit(current_time)
		state = State.STOPPED
		state_changed.emit(state)
		playback_finished.emit()
		return

	_set_active_entries(_find_active_entries(current_time))
	time_changed.emit(current_time)


func get_duration() -> float:
	return _duration


func get_current_action_index() -> int:
	return _current_index


func get_current_track_index() -> int:
	return _current_track_index


func get_current_action() -> MatineeAction:
	if _active_entries.is_empty():
		return null
	return _active_entries[0]["action"] as MatineeAction


func get_current_actions() -> Array[MatineeAction]:
	var result: Array[MatineeAction] = []
	for entry in _active_entries:
		var action := entry["action"] as MatineeAction
		if action != null:
			result.append(action)
	return result


func get_active_entries() -> Array[Dictionary]:
	return _active_entries.duplicate()


func _rebuild_entries() -> void:
	_entries.clear()
	_duration = 0.0
	_current_index = -1
	_current_track_index = -1
	_active_entries.clear()
	if not is_instance_valid(sequence):
		return

	for entry in sequence.get_timeline_entries(false):
		var action := entry["action"] as MatineeAction
		if action == null or not action.enabled:
			continue
		if float(entry["end"]) <= float(entry["start"]):
			continue
		_entries.append(entry)
	_duration = sequence.get_duration_seconds()


func _find_active_entries(time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _entries.is_empty() or time < 0.0 or time >= _duration:
		return result
	for entry in _entries:
		if time >= float(entry["start"]) and time < float(entry["end"]):
			result.append(entry)
	return result


func _set_active_entries(entries: Array[Dictionary]) -> void:
	if _entries_match(_active_entries, entries):
		return
	_active_entries = entries.duplicate()
	var action: MatineeAction = null
	_current_track_index = -1
	_current_index = -1
	if not _active_entries.is_empty():
		var primary := _active_entries[0]
		action = primary["action"] as MatineeAction
		_current_track_index = int(primary["track_index"])
		_current_index = int(primary["action_index"])
	action_changed.emit(action, _current_index)
	timeline_action_changed.emit(action, _current_track_index, _current_index)
	active_actions_changed.emit(get_current_actions())


func _entries_match(left: Array[Dictionary], right: Array[Dictionary]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if (
			int(left[index]["track_index"]) != int(right[index]["track_index"])
			or int(left[index]["action_index"]) != int(right[index]["action_index"])
		):
			return false
	return true
