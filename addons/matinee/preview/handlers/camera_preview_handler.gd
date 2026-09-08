@tool
class_name MatineeCameraPreviewHandler
extends MatineePreviewHandler

const PREVIEW_LIMITATION := "Diagnostic preview only; live Camera2D framing requires an isolated game viewport."

var _camera_entries: Array[Dictionary] = []


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeCameraAction"]


func get_capabilities() -> Dictionary:
	return {
		"diagnostic_only": true,
		"live_framing": false,
		"seeking": true,
		"overlap_priority": true,
	}


func rebuild(sequence: MatineeSequence, _context: MatineePreviewContext) -> void:
	_camera_entries.clear()
	if sequence == null:
		return
	for entry in sequence.get_timeline_entries(false):
		if entry.get("action") is MatineeCameraAction:
			_camera_entries.append(entry)


func get_invalid_reason(action: MatineeAction, _entry: Dictionary) -> String:
	var camera_action := action as MatineeCameraAction
	if camera_action == null:
		return "Camera preview received an incompatible action."
	var issues := camera_action.get_validation_issues()
	return "" if issues.is_empty() else issues[0]


func evaluate_entry(
	time: float,
	entry: Dictionary,
	action: MatineeAction,
	_context: MatineePreviewContext
) -> Dictionary:
	var camera_action := action as MatineeCameraAction
	if camera_action == null:
		return {}
	var winner := _get_winner_at(time)
	if winner.is_empty() or not _is_same_entry(entry, winner):
		return {}
	var start := float(entry.get("start", 0.0))
	var local_time := maxf(time - start, 0.0)
	var raw_progress := 1.0
	if not camera_action.is_cut():
		raw_progress = clampf(local_time / maxf(camera_action.blend_duration, 0.0001), 0.0, 1.0)
	var eased_progress := float(Tween.interpolate_value(
		0.0,
		1.0,
		raw_progress,
		1.0,
		camera_action.transition_type,
		camera_action.ease_type
	))
	return {
		"kind": &"camera",
		"target_camera": str(camera_action.camera_path),
		"follow_target": str(camera_action.follow_target_path) if camera_action.use_follow_target else "Disabled",
		"mode": "Cut" if camera_action.is_cut() else "Blend",
		"blend_duration": maxf(camera_action.blend_duration, 0.0),
		"transition": camera_action.get_transition_label(),
		"ease": camera_action.get_ease_label(),
		"zoom_override": camera_action.zoom_override if camera_action.use_zoom_override else Vector2.ZERO,
		"uses_zoom_override": camera_action.use_zoom_override,
		"blend_progress": clampf(eased_progress, 0.0, 1.0),
		"wins_priority": true,
		"track_index": int(entry.get("track_index", -1)),
		"action_index": int(entry.get("action_index", -1)),
		"preview_limitation": PREVIEW_LIMITATION,
	}


func _get_winner_at(time: float) -> Dictionary:
	var winner: Dictionary = {}
	for entry in _camera_entries:
		var action := entry.get("action") as MatineeCameraAction
		if action == null or not action.enabled:
			continue
		var start := float(entry.get("start", 0.0))
		var end := float(entry.get("end", start))
		if end <= start or time < start or time >= end:
			continue
		if winner.is_empty() or _entry_has_higher_priority(entry, winner):
			winner = entry
	return winner


func _entry_has_higher_priority(candidate: Dictionary, current: Dictionary) -> bool:
	var candidate_track := int(candidate.get("track_index", -1))
	var current_track := int(current.get("track_index", -1))
	if candidate_track != current_track:
		return candidate_track > current_track
	var candidate_start := float(candidate.get("start", 0.0))
	var current_start := float(current.get("start", 0.0))
	if not is_equal_approx(candidate_start, current_start):
		return candidate_start > current_start
	return int(candidate.get("action_index", -1)) > int(current.get("action_index", -1))


func _is_same_entry(left: Dictionary, right: Dictionary) -> bool:
	return (
		left.get("timeline_action") == right.get("timeline_action")
		and int(left.get("track_index", -1)) == int(right.get("track_index", -1))
		and int(left.get("action_index", -1)) == int(right.get("action_index", -1))
	)
