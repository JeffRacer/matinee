@tool
class_name MatineeSequenceEditor
extends RefCounted

signal tracks_applied(sequence: MatineeSequence, track_index: int, action_index: int)

var _undo_redo: EditorUndoRedoManager


func set_undo_redo(manager: EditorUndoRedoManager) -> void:
	_undo_redo = manager


func add_track(sequence: MatineeSequence, track: MatineeTrack, insert_index: int) -> bool:
	if not _is_editable_sequence(sequence) or track == null:
		return false
	var new_tracks := _copy_tracks(sequence)
	var safe_index := clampi(insert_index, 0, new_tracks.size())
	new_tracks.insert(safe_index, track)
	_commit_tracks(sequence, "Add Matinee Track", new_tracks, safe_index, -1, -1, -1)
	return true


func delete_track(sequence: MatineeSequence, track_index: int) -> bool:
	if not _is_valid_track_index(sequence, track_index):
		return false
	var new_tracks := _copy_tracks(sequence)
	new_tracks.remove_at(track_index)
	_commit_tracks(sequence, "Delete Matinee Track", new_tracks, mini(track_index, new_tracks.size() - 1), -1, track_index, -1)
	return true


func remove_track(sequence: MatineeSequence, track_index: int) -> bool:
	return delete_track(sequence, track_index)


func duplicate_track(sequence: MatineeSequence, track_index: int) -> bool:
	if not _is_valid_track_index(sequence, track_index):
		return false
	var new_tracks := _copy_tracks(sequence)
	var duplicated := _copy_track(sequence.tracks[track_index], true)
	duplicated.track_name = _get_unique_track_name(sequence, "%s Copy" % duplicated.track_name)
	new_tracks.insert(track_index + 1, duplicated)
	_commit_tracks(sequence, "Duplicate Matinee Track", new_tracks, track_index + 1, -1, track_index, -1)
	return true


func move_track(sequence: MatineeSequence, source_index: int, destination_index: int) -> bool:
	if not _is_valid_track_index(sequence, source_index):
		return false
	if destination_index < 0 or destination_index >= sequence.tracks.size() or source_index == destination_index:
		return false
	var new_tracks := _copy_tracks(sequence)
	var moved_track := new_tracks[source_index]
	new_tracks.remove_at(source_index)
	new_tracks.insert(destination_index, moved_track)
	_commit_tracks(sequence, "Move Matinee Track", new_tracks, destination_index, -1, source_index, -1)
	return true


func rename_track(sequence: MatineeSequence, track_index: int, track_name: String) -> bool:
	var normalized_name := track_name.strip_edges()
	if normalized_name.is_empty():
		return false
	return _set_track_property(sequence, track_index, &"track_name", normalized_name, "Rename Matinee Track")


func set_track_muted(sequence: MatineeSequence, track_index: int, muted: bool) -> bool:
	return _set_track_property(sequence, track_index, &"muted", muted, "Toggle Matinee Track Mute")


func set_track_locked(sequence: MatineeSequence, track_index: int, locked: bool) -> bool:
	return _set_track_property(sequence, track_index, &"locked", locked, "Toggle Matinee Track Lock")


func set_track_visible(sequence: MatineeSequence, track_index: int, visible: bool) -> bool:
	return _set_track_property(sequence, track_index, &"visible", visible, "Toggle Matinee Track Visibility")


func set_track_enabled(sequence: MatineeSequence, track_index: int, enabled: bool) -> bool:
	return _set_track_property(sequence, track_index, &"enabled", enabled, "Toggle Matinee Track Enabled")


func get_editable_track_index(sequence: MatineeSequence, preferred_index: int = -1) -> int:
	if not _is_editable_sequence(sequence):
		return -1
	if (
		preferred_index >= 0
		and preferred_index < sequence.tracks.size()
		and sequence.tracks[preferred_index] != null
		and not sequence.tracks[preferred_index].locked
	):
		return preferred_index
	for track_index in range(sequence.tracks.size()):
		var track := sequence.tracks[track_index]
		if track != null and not track.locked:
			return track_index
	return -1


func get_new_timeline_action_start_time(
	sequence: MatineeSequence,
	track_index: int,
	selected_action_index: int,
	playhead_time: float
) -> float:
	if not _is_valid_track_index(sequence, track_index):
		return 0.0
	if (
		selected_action_index >= 0
		and selected_action_index < sequence.tracks[track_index].actions.size()
	):
		var selected_clip := sequence.tracks[track_index].actions[selected_action_index]
		if selected_clip != null:
			return selected_clip.get_end_time()
	if is_nan(playhead_time) or is_inf(playhead_time):
		return 0.0
	return maxf(playhead_time, 0.0)


func get_timeline_action_insert_index(
	sequence: MatineeSequence,
	track_index: int,
	selected_action_index: int,
	start_time: float
) -> int:
	if not _is_valid_track_index(sequence, track_index):
		return 0
	var actions := sequence.tracks[track_index].actions
	if selected_action_index >= 0 and selected_action_index < actions.size():
		return selected_action_index + 1
	for action_index in range(actions.size()):
		var clip := actions[action_index]
		if clip != null and clip.start_time > start_time:
			return action_index
	return actions.size()


func add_timeline_action(
	sequence: MatineeSequence,
	track_index: int,
	timeline_action: MatineeTimelineAction,
	insert_index: int
) -> bool:
	if not _is_valid_track_index(sequence, track_index) or timeline_action == null:
		return false
	var new_tracks := _copy_tracks(sequence)
	var track := new_tracks[track_index]
	if track.locked:
		return false
	var safe_index := clampi(insert_index, 0, track.actions.size())
	track.actions.insert(safe_index, timeline_action)
	_commit_tracks(sequence, "Add Timeline Action", new_tracks, track_index, safe_index, -1, -1)
	return true


func duplicate_timeline_action(sequence: MatineeSequence, track_index: int, action_index: int) -> bool:
	if not _is_valid_timeline_action_index(sequence, track_index, action_index):
		return false
	if sequence.tracks[track_index].locked:
		return false
	var source := sequence.tracks[track_index].actions[action_index]
	var duplicated_action := source.action.duplicate(true) as MatineeAction if source.action != null else null
	if duplicated_action == null:
		return false
	var duplicated := MatineeTimelineAction.new()
	duplicated.action = duplicated_action
	duplicated.start_time = source.start_time
	duplicated.duration = source.duration
	return add_timeline_action(sequence, track_index, duplicated, action_index + 1)


func delete_timeline_action(sequence: MatineeSequence, track_index: int, action_index: int) -> bool:
	if not _is_valid_timeline_action_index(sequence, track_index, action_index):
		return false
	var new_tracks := _copy_tracks(sequence)
	var track := new_tracks[track_index]
	if track.locked:
		return false
	track.actions.remove_at(action_index)
	_commit_tracks(sequence, "Delete Timeline Action", new_tracks, track_index, mini(action_index, track.actions.size() - 1), track_index, action_index)
	return true


func move_timeline_action(
	sequence: MatineeSequence,
	source_track_index: int,
	source_action_index: int,
	destination_track_index: int,
	destination_action_index: int
) -> bool:
	if not _is_valid_timeline_action_index(sequence, source_track_index, source_action_index):
		return false
	if not _is_valid_track_index(sequence, destination_track_index):
		return false
	var new_tracks := _copy_tracks(sequence)
	var source_track := new_tracks[source_track_index]
	var destination_track := new_tracks[destination_track_index]
	if source_track.locked or destination_track.locked:
		return false
	var moved := source_track.actions[source_action_index]
	source_track.actions.remove_at(source_action_index)
	var safe_index := clampi(destination_action_index, 0, destination_track.actions.size())
	destination_track.actions.insert(safe_index, moved)
	_commit_tracks(sequence, "Move Timeline Action", new_tracks, destination_track_index, safe_index, source_track_index, source_action_index)
	return true


func set_timeline_action_timing(
	sequence: MatineeSequence,
	track_index: int,
	action_index: int,
	start_time: float,
	duration: float
) -> bool:
	if not _is_valid_timeline_action_index(sequence, track_index, action_index):
		return false
	if start_time < 0.0 or duration < 0.0 or sequence.tracks[track_index].locked:
		return false
	var new_tracks := _copy_tracks(sequence)
	var timeline_action := new_tracks[track_index].actions[action_index]
	timeline_action.start_time = start_time
	timeline_action.duration = duration
	_commit_tracks(sequence, "Change Timeline Action Timing", new_tracks, track_index, action_index, track_index, action_index)
	return true


func move_timeline_action_to_time(
	sequence: MatineeSequence,
	source_track_index: int,
	source_action_index: int,
	destination_track_index: int,
	start_time: float
) -> bool:
	if not _is_valid_timeline_action_index(sequence, source_track_index, source_action_index):
		return false
	if not _is_valid_track_index(sequence, destination_track_index) or start_time < 0.0:
		return false
	if sequence.tracks[source_track_index].locked or sequence.tracks[destination_track_index].locked:
		return false
	if source_track_index == destination_track_index:
		return ripple_move_timeline_action(
			sequence,
			source_track_index,
			source_action_index,
			start_time
		)
	var new_tracks := _copy_tracks(sequence)
	var clip := new_tracks[source_track_index].actions[source_action_index]
	var destination_action_index := source_action_index
	if source_track_index != destination_track_index:
		new_tracks[source_track_index].actions.remove_at(source_action_index)
		destination_action_index = new_tracks[destination_track_index].actions.size()
		new_tracks[destination_track_index].actions.append(clip)
	clip.start_time = start_time
	_commit_tracks(sequence, "Move Timeline Action", new_tracks, destination_track_index, destination_action_index, source_track_index, source_action_index)
	return true


func ripple_move_timeline_action(
	sequence: MatineeSequence,
	track_index: int,
	action_index: int,
	target_time: float
) -> bool:
	if not _is_valid_timeline_action_index(sequence, track_index, action_index):
		return false
	if target_time < 0.0 or sequence.tracks[track_index].locked:
		return false

	var new_tracks := _copy_tracks(sequence)
	var track := new_tracks[track_index]
	var moved := track.actions[action_index]
	if moved == null:
		return false
	track.actions.remove_at(action_index)

	var moved_end := moved.get_end_time()
	for clip in track.actions:
		if clip != null and clip.start_time >= moved_end:
			clip.start_time = maxf(clip.start_time - moved.duration, 0.0)
	_sort_timeline_actions_by_time(track.actions)

	var insertion_index := _get_ripple_insertion_index(track.actions, target_time)
	var insertion_time := _get_ripple_insertion_time(
		track.actions,
		insertion_index,
		target_time
	)
	for index in range(insertion_index, track.actions.size()):
		var clip := track.actions[index]
		if clip != null:
			clip.start_time += moved.duration
	moved.start_time = insertion_time
	track.actions.insert(insertion_index, moved)
	_commit_tracks(
		sequence,
		"Ripple Move Timeline Action",
		new_tracks,
		track_index,
		insertion_index,
		track_index,
		action_index
	)
	return true


func _get_ripple_insertion_index(
	actions: Array[MatineeTimelineAction],
	target_time: float
) -> int:
	for index in range(actions.size()):
		var clip := actions[index]
		if clip == null:
			continue
		var midpoint := clip.start_time + maxf(clip.duration, 0.0) * 0.5
		if target_time < midpoint:
			return index
	return actions.size()


func _get_ripple_insertion_time(
	actions: Array[MatineeTimelineAction],
	insertion_index: int,
	target_time: float
) -> float:
	if insertion_index < actions.size():
		var next_clip := actions[insertion_index]
		if next_clip != null:
			return minf(target_time, next_clip.start_time)
	if actions.is_empty():
		return target_time
	var previous_clip := actions.back()
	return maxf(target_time, previous_clip.get_end_time()) if previous_clip != null else target_time


func _sort_timeline_actions_by_time(actions: Array[MatineeTimelineAction]) -> void:
	actions.sort_custom(
		func(left: MatineeTimelineAction, right: MatineeTimelineAction) -> bool:
			if left == null:
				return false
			if right == null:
				return true
			return left.start_time < right.start_time
	)


func _commit_tracks(
	sequence: MatineeSequence,
	action_name: String,
	new_tracks: Array[MatineeTrack],
	new_track_selection: int,
	new_action_selection: int,
	old_track_selection: int,
	old_action_selection: int
) -> void:
	var old_tracks := _copy_tracks(sequence)
	var old_track_model_version := sequence.track_model_version
	if _undo_redo == null:
		_apply_tracks(sequence, new_tracks, MatineeSequence.CURRENT_TRACK_MODEL_VERSION, new_track_selection, new_action_selection)
		return
	_undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, sequence)
	_undo_redo.add_do_method(self, "_apply_tracks", sequence, new_tracks, MatineeSequence.CURRENT_TRACK_MODEL_VERSION, new_track_selection, new_action_selection)
	_undo_redo.add_undo_method(self, "_apply_tracks", sequence, old_tracks, old_track_model_version, old_track_selection, old_action_selection)
	_undo_redo.commit_action()


func _apply_tracks(
	sequence: MatineeSequence,
	tracks_value: Array[MatineeTrack],
	track_model_version: int,
	track_selection: int,
	action_selection: int
) -> void:
	if not is_instance_valid(sequence):
		return
	var applied_tracks: Array[MatineeTrack] = []
	applied_tracks.assign(tracks_value)
	sequence.tracks = applied_tracks
	sequence.track_model_version = track_model_version
	sequence.emit_changed()
	tracks_applied.emit(sequence, track_selection, action_selection)


func _copy_tracks(sequence: MatineeSequence) -> Array[MatineeTrack]:
	var result: Array[MatineeTrack] = []
	if not is_instance_valid(sequence):
		return result
	for source_track in sequence.tracks:
		if source_track == null:
			result.append(null)
			continue
		var track := MatineeTrack.new()
		track.track_name = source_track.track_name
		track.track_type = source_track.track_type
		track.enabled = source_track.enabled
		track.muted = source_track.muted
		track.locked = source_track.locked
		track.visible = source_track.visible
		track.color = source_track.color
		track.allows_overlap = source_track.allows_overlap
		for source_timeline_action in source_track.actions:
			if source_timeline_action == null:
				track.actions.append(null)
				continue
			var timeline_action := MatineeTimelineAction.new()
			timeline_action.action = source_timeline_action.action
			timeline_action.start_time = source_timeline_action.start_time
			timeline_action.duration = source_timeline_action.duration
			track.actions.append(timeline_action)
		result.append(track)
	return result


func _copy_track(source_track: MatineeTrack, duplicate_actions: bool) -> MatineeTrack:
	var track := MatineeTrack.new()
	track.track_name = source_track.track_name
	track.track_type = source_track.track_type
	track.enabled = source_track.enabled
	track.muted = source_track.muted
	track.locked = source_track.locked
	track.visible = source_track.visible
	track.color = source_track.color
	track.allows_overlap = source_track.allows_overlap
	for source_clip in source_track.actions:
		if source_clip == null:
			track.actions.append(null)
			continue
		var clip := MatineeTimelineAction.new()
		clip.action = source_clip.action.duplicate(true) as MatineeAction if duplicate_actions and source_clip.action != null else source_clip.action
		clip.start_time = source_clip.start_time
		clip.duration = source_clip.duration
		track.actions.append(clip)
	return track


func _set_track_property(
	sequence: MatineeSequence,
	track_index: int,
	property: StringName,
	value: Variant,
	action_name: String
) -> bool:
	if not _is_valid_track_index(sequence, track_index):
		return false
	var new_tracks := _copy_tracks(sequence)
	var track := new_tracks[track_index]
	if track.get(property) == value:
		return false
	track.set(property, value)
	_commit_tracks(sequence, action_name, new_tracks, track_index, -1, track_index, -1)
	return true


func _get_unique_track_name(sequence: MatineeSequence, requested_name: String) -> String:
	var candidate := requested_name
	var suffix := 2
	var names := {}
	for track in sequence.tracks:
		if track != null:
			names[track.track_name.to_lower()] = true
	while names.has(candidate.to_lower()):
		candidate = "%s %d" % [requested_name, suffix]
		suffix += 1
	return candidate


func _is_valid_track_index(sequence: MatineeSequence, track_index: int) -> bool:
	return (
		_is_editable_sequence(sequence)
		and track_index >= 0
		and track_index < sequence.tracks.size()
		and sequence.tracks[track_index] != null
	)


func _is_editable_sequence(sequence: MatineeSequence) -> bool:
	return is_instance_valid(sequence) and sequence.is_current_track_format()


func _is_valid_timeline_action_index(sequence: MatineeSequence, track_index: int, action_index: int) -> bool:
	return (
		_is_valid_track_index(sequence, track_index)
		and action_index >= 0
		and action_index < sequence.tracks[track_index].actions.size()
		and sequence.tracks[track_index].actions[action_index] != null
	)
