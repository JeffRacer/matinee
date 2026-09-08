@tool
class_name MatineeSelectionState
extends RefCounted

signal sequence_changed(sequence: MatineeSequence)
signal action_changed(action: MatineeAction, index: int)
signal timeline_action_changed(action: MatineeAction, track_index: int, action_index: int)
signal timeline_clip_changed(timeline_action: MatineeTimelineAction, track_index: int, action_index: int)
signal track_changed(track: MatineeTrack, track_index: int)
signal selection_cleared()

var sequence: MatineeSequence = null
var action: MatineeAction = null
var action_index: int = -1
var track_index: int = -1
var track: MatineeTrack = null
var timeline_action: MatineeTimelineAction = null


func set_sequence(new_sequence: MatineeSequence) -> void:
	if sequence == new_sequence:
		return

	sequence = new_sequence
	clear_selection()
	sequence_changed.emit(sequence)


func select_action(new_action: MatineeAction, index: int, new_track_index: int = 0) -> void:
	var new_timeline_action := _get_timeline_action(new_track_index, index)
	if action == new_action and timeline_action == new_timeline_action and action_index == index and track_index == new_track_index:
		return

	action = new_action
	action_index = index
	track_index = new_track_index
	track = sequence.tracks[track_index] if sequence != null and track_index >= 0 and track_index < sequence.tracks.size() else null
	timeline_action = new_timeline_action
	action_changed.emit(action, action_index)
	timeline_action_changed.emit(action, track_index, action_index)
	timeline_clip_changed.emit(timeline_action, track_index, action_index)


func select_track(new_track: MatineeTrack, new_track_index: int) -> void:
	if track == new_track and track_index == new_track_index and action == null:
		return
	track = new_track
	track_index = new_track_index
	action = null
	action_index = -1
	timeline_action = null
	track_changed.emit(track, track_index)


func clear_selection() -> void:
	var had_selection := action != null or action_index != -1 or track_index != -1
	action = null
	action_index = -1
	track_index = -1
	track = null
	timeline_action = null

	if had_selection:
		selection_cleared.emit()


func has_selection() -> bool:
	return action != null and track_index >= 0 and action_index >= 0


func _get_timeline_action(target_track_index: int, target_action_index: int) -> MatineeTimelineAction:
	if sequence == null or not sequence.is_current_track_format():
		return null
	if target_track_index < 0 or target_track_index >= sequence.tracks.size():
		return null
	var target_track := sequence.tracks[target_track_index]
	if target_track == null or target_action_index < 0 or target_action_index >= target_track.actions.size():
		return null
	return target_track.actions[target_action_index]
