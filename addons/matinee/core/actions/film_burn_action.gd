@tool
class_name MatineeFilmBurnAction
extends MatineeAction


enum Direction {
	TO_BLACK,
	FROM_BLACK,
}


@export_category("Film Burn")

@export var direction: Direction = Direction.TO_BLACK

## Use -1 to use the Matinee default burn duration.
@export_range(-1.0, 5.0, 0.05)
var duration: float = -1.0

## Negative coordinates use the Matinee's default burn origin.
@export var burn_origin: Vector2 = Vector2(-1.0, -1.0)


func _init() -> void:
	action_name = "Film Burn"


func play(director: Node) -> void:
	if director == null:
		push_warning("MatineeFilmBurnAction requires a Matinee instance.")
		return

	_raise_burn_overlay(director)

	match direction:
		Direction.TO_BLACK:
			if not director.has_method("burn_to_black"):
				push_warning("Matinee does not support burn_to_black().")
				return
			await director.call("burn_to_black", duration, burn_origin)

		Direction.FROM_BLACK:
			if not director.has_method("burn_from_black"):
				push_warning("Matinee does not support burn_from_black().")
				return
			await director.call("burn_from_black", duration, burn_origin)


func get_duration_seconds() -> float:
	return 1.15 if duration < 0.0 else maxf(duration, 0.05)


func get_validation_issues(
	_scene_context: Node = null
) -> PackedStringArray:
	var issues := PackedStringArray()
	if duration == 0.0:
		issues.append("Film Burn duration should be greater than zero or -1 for the Matinee default.")
	return issues


func get_editor_summary() -> String:
	var direction_name := "To black" if direction == Direction.TO_BLACK else "From black"
	var burn_duration := 1.15 if duration < 0.0 else duration
	return "%s · %.2fs" % [
		direction_name,
		burn_duration,
	]


func _raise_burn_overlay(director: Node) -> void:
	var burn_rect := director.get_node_or_null(
		"CinematicLayer/FilmBurnRect"
	) as Control
	if burn_rect == null:
		return

	# Persistent BackgroundImageAction stages are created dynamically and can
	# otherwise end up later in the CanvasLayer child order than FilmBurnRect.
	# A high z-index guarantees the burn shader renders over the background,
	# title text, and any other ordinary cinematic presentation content.
	burn_rect.z_index = 1000
