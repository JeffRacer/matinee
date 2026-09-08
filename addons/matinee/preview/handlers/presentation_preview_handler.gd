@tool
class_name MatineePresentationPreviewHandler
extends MatineePreviewHandler

var _events: Array[Dictionary] = []


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineePresentationAction"]


func rebuild(sequence: MatineeSequence, _context: MatineePreviewContext) -> void:
	_events.clear()
	if not is_instance_valid(sequence):
		return
	for entry in sequence.get_timeline_entries(false):
		var action := entry.get("action") as MatineeAction
		if action is MatineePresentationAction or action is MatineeSceneAction:
			_events.append(entry)
	_events.sort_custom(_sort_timeline_entries)


func collect_persistent_states(
	_time: float,
	_context: MatineePreviewContext,
	_out_states: Array[Dictionary]
) -> void:
	var state := _get_presentation_state(_time)
	if not state.is_empty():
		_out_states.append(state)


func _get_presentation_state(time: float) -> Dictionary:
	var state: Dictionary = {}
	for entry in _events:
		if time < float(entry.get("start", 0.0)):
			break
		var director_action := entry.get("action") as MatineeAction
		if director_action == null or not director_action.enabled:
			continue
		if director_action is MatineeSceneAction:
			var scene_action := director_action as MatineeSceneAction
			if not scene_action.scene_path.strip_edges().is_empty():
				state.clear()
			continue
		var action := director_action as MatineePresentationAction
		if action == null:
			continue
		match action.mode:
			MatineePresentationAction.PresentationMode.APPLY_PRESET:
				if action.preset == null:
					continue
				if not action.preset.movie_mode_enabled:
					state.clear()
				else:
					state = _get_preset_state(action.preset, entry)
			MatineePresentationAction.PresentationMode.RESTORE_DEFAULT, \
			MatineePresentationAction.PresentationMode.DISABLE_MOVIE_MODE:
				state.clear()
			MatineePresentationAction.PresentationMode.ENABLE_MOVIE_MODE:
				if state.is_empty():
					state = _get_clean_movie_mode_state(entry)
				else:
					state["track_index"] = int(entry.get("track_index", -1))
					state["action_index"] = int(entry.get("action_index", -1))
	return state


func _get_preset_state(
	preset: MatineePresentationPreset,
	entry: Dictionary
) -> Dictionary:
	var preset_name := preset.preset_name.strip_edges()
	if preset_name.is_empty():
		preset_name = "Unnamed Preset"
	return {
		"kind": &"presentation",
		"preset_name": preset_name,
		"master_opacity": clampf(preset.master_opacity, 0.0, 1.0),
		"grain_strength": preset.grain_strength if preset.grain_enabled else 0.0,
		"flicker_strength": preset.flicker_strength if preset.flicker_enabled else 0.0,
		"dust_opacity": preset.dust_opacity if preset.dust_enabled else 0.0,
		"scratches_opacity": preset.scratches_opacity if preset.scratches_enabled else 0.0,
		"vignette_strength": preset.vignette_strength if preset.vignette_enabled else 0.0,
		"gate_weave_amount": preset.gate_weave_amount if preset.gate_weave_enabled else 0.0,
		"track_index": int(entry.get("track_index", -1)),
		"action_index": int(entry.get("action_index", -1)),
	}


func _get_clean_movie_mode_state(entry: Dictionary) -> Dictionary:
	return {
		"kind": &"presentation",
		"preset_name": "Movie Mode",
		"master_opacity": 1.0,
		"grain_strength": 0.0,
		"flicker_strength": 0.0,
		"dust_opacity": 0.0,
		"scratches_opacity": 0.0,
		"vignette_strength": 0.0,
		"gate_weave_amount": 0.0,
		"track_index": int(entry.get("track_index", -1)),
		"action_index": int(entry.get("action_index", -1)),
	}
