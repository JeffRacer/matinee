@tool
class_name MatineeFadeAction
extends MatineeAction

enum FadeDirection {
	TO_BLACK,
	FROM_BLACK
}

@export_category("Fade")
@export var direction: FadeDirection = FadeDirection.FROM_BLACK

@export_range(-1.0, 5.0, 0.05)
var duration: float = -1.0


func _init() -> void:
	action_name = "Fade"


func play(director: Node) -> void:
	match direction:
		FadeDirection.TO_BLACK:
			await director.fade_to_black(duration)

		FadeDirection.FROM_BLACK:
			await director.fade_from_black(duration)

func get_duration_seconds() -> float:
	return 0.75 if duration < 0.0 else maxf(duration, 0.01)

