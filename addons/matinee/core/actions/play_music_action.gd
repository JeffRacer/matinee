@tool
class_name MatineePlayMusicAction
extends MatineeAction


@export_category("Music")
@export var music: AudioStream
@export var music_id: StringName = &""
@export_range(0.0, 10.0, 0.1) var fade_duration: float = 1.0
@export var restart_if_already_playing: bool = false
@export var wait_for_fade: bool = false


func _init() -> void:
	action_name = "Play Music"


func play(_director: Node) -> void:
	if music == null or music_id.is_empty():
		return
	var music_manager := _get_runtime_service()
	if music_manager == null:
		push_warning("Play Music requires a configured host audio service (runtime_service_path).")
		return
	if wait_for_fade:
		await music_manager.call("play_track_by_id", music_id, music, maxf(fade_duration, 0.0), restart_if_already_playing)
	else:
		music_manager.call("play_track_by_id", music_id, music, maxf(fade_duration, 0.0), restart_if_already_playing)


func get_duration_seconds() -> float:
	return maxf(fade_duration, 0.0) if wait_for_fade else 0.0


func get_validation_issues(_scene_context: Node = null) -> PackedStringArray:
	var issues := PackedStringArray()
	if music == null:
		issues.append("Play Music requires an AudioStream.")
	if music_id.is_empty():
		issues.append("Play Music requires a music ID.")
	if fade_duration < 0.0:
		issues.append("Play Music fade duration cannot be negative.")
	return issues


func get_editor_summary() -> String:
	var music_name: String = String(music_id) if not music_id.is_empty() else "Unassigned"
	return "%s · Fade %.1fs" % [music_name, maxf(fade_duration, 0.0)]


func get_editor_color() -> Color:
	return Color(0.63, 0.53, 0.95) if enabled else super.get_editor_color()
