@tool
class_name MatineeLocationAction
extends MatineeAction

@export_category("Location")
@export var location_name: String = "HOLLOWAY COUNTY"

@export_multiline
var location_subtitle: String = "JULY 14, 1957"

@export_range(-1.0, 10.0, 0.1)
var hold_duration: float = -1.0

@export var block_controls: bool = false


func _init() -> void:
	action_name = "Location Card"


func play(director: Node) -> void:
	if location_name.strip_edges().is_empty():
		push_warning(
			"MatineeLocationAction has an empty location name."
		)
		return

	await director.show_location_card(
		location_name,
		location_subtitle,
		hold_duration,
		block_controls
	)

func get_duration_seconds() -> float:
	var actual_hold := 3.0 if hold_duration < 0.0 else maxf(hold_duration, 0.1)
	return 0.28 + actual_hold + 0.28
