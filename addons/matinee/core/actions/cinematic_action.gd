@tool
class_name MatineeCinematicAction
extends MatineeAction

enum CinematicMode {
	BEGIN,
	END
}


@export_category("Cinematic")
@export var mode: CinematicMode = CinematicMode.BEGIN


func _init() -> void:
	action_name = "Cinematic"


func play(director: Node) -> void:
	if director == null:
		return

	match mode:
		CinematicMode.BEGIN:
			if director.has_method("begin_cinematic"):
				director.call("begin_cinematic")

		CinematicMode.END:
			if director.has_method("end_cinematic"):
				director.call("end_cinematic")