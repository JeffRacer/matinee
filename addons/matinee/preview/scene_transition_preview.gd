@tool
class_name MatineeSceneTransitionPreview
extends RefCounted

const DEFAULT_FADE_DURATION := 0.75
const DEFAULT_BURN_DURATION := 1.15
const DEFAULT_BURN_HOLD := 0.18
const DEFAULT_BURN_ORIGIN := Vector2(0.35, 0.55)

var _entries: Array[Dictionary] = []


func rebuild(sequence: MatineeSequence) -> void:
	_entries.clear()
	if not is_instance_valid(sequence):
		return
	for entry in sequence.get_timeline_entries(false):
		var action := entry.get("action") as MatineeAction
		if action is MatineeSceneAction:
			_entries.append(entry)
	_entries.sort_custom(_sort_timeline_entries)


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(false)


func get_state(time: float) -> Dictionary:
	var state: Dictionary = {}
	for entry in _entries:
		var start_time := float(entry.get("start", 0.0))
		if time < start_time and not is_equal_approx(time, start_time):
			break
		var end_time := float(entry.get("end", start_time))
		var duration := maxf(end_time - start_time, 0.0)
		var is_event := duration <= 0.0 and is_equal_approx(time, start_time)
		var is_active := duration > 0.0 and time >= start_time and time < end_time
		if not is_event and not is_active:
			continue
		var action := entry.get("action") as MatineeSceneAction
		if action == null or not action.enabled or action.scene_path.strip_edges().is_empty():
			continue
		state = _evaluate_entry(time, entry, action)
	return state


func _evaluate_entry(
	time: float,
	entry: Dictionary,
	action: MatineeSceneAction
) -> Dictionary:
	var start_time := float(entry.get("start", 0.0))
	var end_time := float(entry.get("end", start_time))
	var duration := maxf(end_time - start_time, 0.0)
	var state := _base_state(entry, action)
	if action.transition == MatineeSceneAction.SceneTransition.CUT:
		state["phase"] = &"cut" if is_equal_approx(time, start_time) else &"complete"
		return state
	if not action.wait_for_transition:
		state["phase"] = &"trigger" if is_equal_approx(time, start_time) else &"async"
		return state
	if duration <= 0.0:
		state["phase"] = &"trigger"
		return state
	var normalized_time := clampf((time - start_time) / duration, 0.0, 1.0)
	if action.transition == MatineeSceneAction.SceneTransition.FILM_BURN:
		_apply_burn_phase(state, action, normalized_time)
	else:
		_apply_fade_phase(state, action, normalized_time)
	return state


func _base_state(entry: Dictionary, action: MatineeSceneAction) -> Dictionary:
	var transition := &"fade"
	match action.transition:
		MatineeSceneAction.SceneTransition.FILM_BURN:
			transition = &"film_burn"
		MatineeSceneAction.SceneTransition.CUT:
			transition = &"cut"
	var scene_path := action.scene_path.strip_edges()
	return {
		"kind": &"scene_transition",
		"transition": transition,
		"phase": &"complete",
		"progress": 0.0,
		"opacity": 0.0,
		"scene_path": scene_path,
		"scene_label": scene_path.get_file().get_basename(),
		"burn_origin": _get_burn_origin(action.burn_origin),
		"track_index": int(entry.get("track_index", -1)),
		"action_index": int(entry.get("action_index", -1)),
	}


func _apply_fade_phase(
	state: Dictionary,
	action: MatineeSceneAction,
	normalized_time: float
) -> void:
	var fade_out := (
		DEFAULT_FADE_DURATION
		if action.fade_out_duration < 0.0
		else maxf(action.fade_out_duration, 0.01)
	)
	var hold := maxf(action.black_hold_duration, 0.0)
	var fade_in := (
		DEFAULT_FADE_DURATION
		if action.fade_in_duration < 0.0
		else maxf(action.fade_in_duration, 0.01)
	)
	var delay := maxf(action.delay_after_change, 0.0)
	var total := fade_out + hold + fade_in + delay
	var phase_time := normalized_time * total
	if phase_time < fade_out:
		var progress := phase_time / fade_out
		_set_phase(state, &"fade_out", progress, progress)
	elif phase_time < fade_out + hold:
		_set_phase(state, &"hold_after_change", 1.0, 1.0)
	elif phase_time < fade_out + hold + fade_in:
		var elapsed := phase_time - fade_out - hold
		var progress := 1.0 - elapsed / fade_in
		_set_phase(state, &"fade_in", progress, progress)
	else:
		_set_phase(state, &"complete", 0.0, 0.0)


func _apply_burn_phase(
	state: Dictionary,
	action: MatineeSceneAction,
	normalized_time: float
) -> void:
	var burn_out := (
		DEFAULT_BURN_DURATION
		if action.burn_out_duration < 0.0
		else maxf(action.burn_out_duration, 0.1)
	)
	var burn_in := (
		DEFAULT_BURN_DURATION
		if action.burn_in_duration < 0.0
		else maxf(action.burn_in_duration, 0.1)
	)
	var hold := (
		DEFAULT_BURN_HOLD
		if action.black_hold_duration < 0.0
		else maxf(action.black_hold_duration, 0.0)
	)
	var delay := maxf(action.delay_after_change, 0.0)
	var total := burn_out + hold + hold + burn_in + delay
	var phase_time := normalized_time * total
	if phase_time < burn_out:
		var progress := phase_time / burn_out
		_set_phase(state, &"burn_out", progress, progress)
	elif phase_time < burn_out + hold:
		_set_phase(state, &"hold_before_change", 1.0, 1.0)
	elif phase_time < burn_out + hold + hold:
		_set_phase(state, &"hold_after_change", 1.0, 1.0)
	elif phase_time < burn_out + hold + hold + burn_in:
		var elapsed := phase_time - burn_out - hold - hold
		var progress := 1.0 - elapsed / burn_in
		_set_phase(state, &"burn_in", progress, progress)
	else:
		_set_phase(state, &"complete", 0.0, 0.0)


func _set_phase(
	state: Dictionary,
	phase: StringName,
	progress: float,
	opacity: float
) -> void:
	state["phase"] = phase
	state["progress"] = clampf(progress, 0.0, 1.0)
	state["opacity"] = clampf(opacity, 0.0, 1.0)


func _get_burn_origin(configured: Vector2) -> Vector2:
	if configured.x < 0.0 or configured.y < 0.0:
		return DEFAULT_BURN_ORIGIN
	return Vector2(
		clampf(configured.x, 0.0, 1.0),
		clampf(configured.y, 0.0, 1.0)
	)


func _sort_timeline_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_start := float(left.get("start", 0.0))
	var right_start := float(right.get("start", 0.0))
	if not is_equal_approx(left_start, right_start):
		return left_start < right_start
	var left_track := int(left.get("track_index", -1))
	var right_track := int(right.get("track_index", -1))
	if left_track != right_track:
		return left_track < right_track
	return int(left.get("action_index", -1)) < int(right.get("action_index", -1))
