@tool
class_name MatineeChapterAction
extends MatineeAction

@export_category("Chapter")
@export var chapter_number: String = "ACT I"

@export_multiline
var chapter_title: String = "THE STRANGE SUBSTANCE"

@export_range(-1.0, 10.0, 0.1)
var hold_duration: float = -1.0

@export_range(-1.0, 3.0, 0.05)
var fade_duration: float = -1.0

@export var lock_controls: bool = false


func _init() -> void:
	action_name = "Chapter Card"


func play(director: Node) -> void:
	if chapter_title.strip_edges().is_empty():
		push_warning(
			"MatineeChapterAction has an empty chapter title."
		)
		return

	await director.show_chapter_card(
		chapter_number,
		chapter_title,
		hold_duration,
		fade_duration,
		lock_controls
	)

func get_duration_seconds() -> float:
	var actual_hold := 2.8 if hold_duration < 0.0 else maxf(hold_duration, 0.1)
	var actual_fade := 0.45 if fade_duration < 0.0 else maxf(fade_duration, 0.05)
	return actual_fade + actual_hold + actual_fade

