@tool
class_name MatineeWaitAction
extends MatineeAction

@export_range(0.0, 60.0, 0.05)
var duration: float = 1.0


func _init() -> void:
	action_name = "Wait"


func play(director: Node) -> void:
	if duration <= 0.0:
		await director.get_tree().process_frame
		return

	await director.wait(duration)

func get_duration_seconds() -> float:
	return maxf(duration, 0.0)

