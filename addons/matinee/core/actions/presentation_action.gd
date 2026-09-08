@tool
class_name MatineePresentationAction
extends MatineeAction

enum PresentationMode {
	APPLY_PRESET,
	RESTORE_DEFAULT,
	ENABLE_MOVIE_MODE,
	DISABLE_MOVIE_MODE
}


@export_category("Presentation")
@export var mode: PresentationMode = PresentationMode.APPLY_PRESET

@export var preset: MatineePresentationPreset

@export var overlay_layer_override: int = -1


func _init() -> void:
	action_name = "Presentation"


func play(director: Node) -> void:
	if director == null:
		return

	if "overlay" in director:
		var overlay := director.get("overlay") as Node

		if overlay != null and overlay_layer_override >= 0:
			overlay.set("layer", overlay_layer_override)

	match mode:
		PresentationMode.APPLY_PRESET:
			if preset == null:
				push_warning(
					"MatineePresentationAction has no preset assigned."
				)
				return

			if director.has_method("apply_presentation_preset"):
				director.call(
					"apply_presentation_preset",
					preset
				)

		PresentationMode.RESTORE_DEFAULT:
			if director.has_method("reset_presentation_to_clean_state"):
				director.call("reset_presentation_to_clean_state")
				return

			if "overlay" not in director:
				return

			var overlay := director.get("overlay") as Node

			if overlay == null:
				return

			var default_preset := overlay.get("default_preset") as Resource
			if default_preset != null:
				director.call(
					"apply_presentation_preset",
					default_preset
				)
			else:
				director.call("disable_movie_mode")

		PresentationMode.ENABLE_MOVIE_MODE:
			if director.has_method("enable_movie_mode"):
				director.call("enable_movie_mode")

		PresentationMode.DISABLE_MOVIE_MODE:
			if director.has_method("disable_movie_mode"):
				director.call("disable_movie_mode")
