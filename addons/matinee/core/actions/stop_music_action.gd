@tool
class_name MatineeStopMusicAction
extends MatineeAction


@export_category("Music")
@export_range(0.0, 10.0, 0.1) var fade_duration: float = 1.0
@export var wait_for_fade: bool = false


func _init() -> void:
	action_name = "Stop Music"


func play(_director: Node) -> void:
	var music_manager := _get_runtime_service()
	if music_manager == null:
		push_warning("Stop Music requires a configured host audio service (runtime_service_path).")
		return
	if wait_for_fade:
		await music_manager.call("stop_music", maxf(fade_duration, 0.0))
	else:
		music_manager.call("stop_music", maxf(fade_duration, 0.0))


func get_duration_seconds() -> float:
	return maxf(fade_duration, 0.0) if wait_for_fade else 0.0


func get_validation_issues(_scene_context: Node = null) -> PackedStringArray:
	return PackedStringArray(["Stop Music fade duration cannot be negative."]) if fade_duration < 0.0 else PackedStringArray()


func get_editor_summary() -> String:
	return "Fade %.1fs" % maxf(fade_duration, 0.0)


func get_editor_color() -> Color:
	return Color(0.63, 0.53, 0.95) if enabled else super.get_editor_color()
