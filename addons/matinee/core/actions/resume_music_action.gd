@tool
class_name MatineeResumeMusicAction
extends MatineeAction


func _init() -> void:
	action_name = "Resume Music"


func play(_director: Node) -> void:
	var music_manager := _get_runtime_service()
	if music_manager != null:
		music_manager.call("resume_music")


func get_editor_color() -> Color:
	return Color(0.63, 0.53, 0.95) if enabled else super.get_editor_color()
