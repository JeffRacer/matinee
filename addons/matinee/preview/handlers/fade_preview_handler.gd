@tool
class_name MatineeFadePreviewHandler
extends MatineePreviewHandler

var _entries: Array[Dictionary] = []


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeFadeAction"]


func rebuild(sequence: MatineeSequence, _context: MatineePreviewContext) -> void:
	_entries.clear()
	if not is_instance_valid(sequence):
		return
	for entry in sequence.get_timeline_entries(false):
		if entry.get("action") is MatineeFadeAction:
			_entries.append(entry)
	_entries.sort_custom(_sort_timeline_entries)


func collect_persistent_states(
	_time: float,
	_context: MatineePreviewContext,
	_out_states: Array[Dictionary]
) -> void:
	var opacity := _get_fade_opacity(_time)
	if opacity > 0.0:
		_out_states.append({
			"kind": &"fade",
			"opacity": opacity,
		})


func _get_fade_opacity(time: float) -> float:
	var opacity := 0.0
	for entry in _entries:
		var start_time := float(entry.get("start", 0.0))
		if time < start_time:
			break
		var end_time := float(entry.get("end", start_time))
		var duration := maxf(end_time - start_time, 0.0)
		var fade := entry.get("action") as MatineeFadeAction
		if fade == null or not fade.enabled:
			continue
		var progress := 1.0 if duration <= 0.0 else clampf((time - start_time) / duration, 0.0, 1.0)
		if fade.direction == MatineeFadeAction.FadeDirection.TO_BLACK:
			opacity = progress
		else:
			opacity = 1.0 - progress
	return clampf(opacity, 0.0, 1.0)
