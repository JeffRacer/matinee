@tool
class_name MatineeStatusBar
extends Label


func set_info(message: String) -> void:
	text = message


func set_warning(message: String) -> void:
	text = message


func set_error(message: String) -> void:
	text = message


func set_playback(
	state_name: String,
	current_time: float,
	duration: float,
	action_name: String,
	index: int,
	action_count: int,
	speed: float,
	loop_enabled: bool
) -> void:
	var action_text := action_name
	if index >= 0:
		action_text += " · Action %d/%d" % [index + 1, action_count]
	var loop_text := "  ·  Loop" if loop_enabled else ""
	text = "%s  %s / %s  ·  %s  ·  %.2fx%s" % [
		state_name,
		_format_time(current_time),
		_format_time(duration),
		action_text,
		speed,
		loop_text,
	]


func show_empty_state() -> void:
	text = "Select a .tres MatineeSequence in the FileSystem dock to open it here."


func show_empty_sequence() -> void:
	text = "This sequence has no actions. Use + Add to begin authoring."


func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var whole_seconds := int(seconds) % 60
	var tenths := int(floor(fmod(seconds, 1.0) * 10.0 + 0.0001))
	return "%02d:%02d.%d" % [minutes, whole_seconds, tenths]
