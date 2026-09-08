@tool
class_name MatineeSceneAction
extends MatineeAction


enum SceneTransition {
	FADE,
	FILM_BURN,
	CUT
}


@export_category("Scene")

## Scene loaded when this action runs.
@export_file("*.tscn")
var scene_path: String = ""

## Optional marker ID passed to the host controller.
@export var destination_spawn_id: StringName = &""

@export var transition: SceneTransition = SceneTransition.FADE


@export_category("Fade Settings")

## Use -1 to use the Matinee defaults.
@export_range(-1.0, 5.0, 0.05)
var fade_out_duration: float = -1.0

## Use -1 to use the Matinee defaults.
@export_range(-1.0, 5.0, 0.05)
var fade_in_duration: float = -1.0

@export_range(0.0, 5.0, 0.05)
var black_hold_duration: float = 0.15


@export_category("Film Burn Settings")

## Use -1 to use the Matinee default burn duration.
@export_range(-1.0, 5.0, 0.05)
var burn_out_duration: float = -1.0

## Use -1 to use the Matinee default burn duration.
@export_range(-1.0, 5.0, 0.05)
var burn_in_duration: float = -1.0

## Negative coordinates use the Matinee's default origin.
@export var burn_origin: Vector2 = Vector2(-1.0, -1.0)


@export_category("Behavior")

## Wait for the complete transition before the next timeline action.
@export var wait_for_transition: bool = true

## Additional delay after the new scene has been revealed.
@export_range(0.0, 10.0, 0.05)
var delay_after_change: float = 0.0

## Show the common loading presentation while the scene is replaced.
@export var show_loading_card: bool = true


func _init() -> void:
	action_name = "Scene Change"


func play(director: Node) -> void:
	if scene_path.strip_edges().is_empty():
		push_warning("MatineeSceneAction cannot run without a scene path.")
		return

	if not ResourceLoader.exists(scene_path):
		push_error("MatineeSceneAction could not find scene: %s" % scene_path)
		return

	_stage_destination_spawn(director)

	if show_loading_card and director.has_method("show_loading_card"):
		director.call("show_loading_card")

	match transition:
		SceneTransition.FADE:
			await _play_fade_transition(director)
		SceneTransition.FILM_BURN:
			await _play_burn_transition(director)
		SceneTransition.CUT:
			await _play_cut_transition(director)

	if show_loading_card and director.has_method("hide_loading_card"):
		director.call("hide_loading_card")

	if delay_after_change > 0.0:
		await director.wait(delay_after_change)


func _stage_destination_spawn(director: Node) -> bool:
	if destination_spawn_id == &"":
		return false
	if not director.has_method("stage_destination_spawn"):
		push_warning("Scene Change requires stage_destination_spawn() for a destination marker.")
		return false
	director.call("stage_destination_spawn", destination_spawn_id)
	return true


func _play_fade_transition(director: Node) -> void:
	if wait_for_transition:
		await director.change_scene(
			scene_path,
			fade_out_duration,
			fade_in_duration,
			black_hold_duration
		)
	else:
		director.change_scene(
			scene_path,
			fade_out_duration,
			fade_in_duration,
			black_hold_duration
		)


func _play_burn_transition(director: Node) -> void:
	if wait_for_transition:
		await director.change_scene_with_burn(
			scene_path,
			burn_out_duration,
			burn_in_duration,
			black_hold_duration,
			burn_origin
		)
	else:
		director.change_scene_with_burn(
			scene_path,
			burn_out_duration,
			burn_in_duration,
			black_hold_duration,
			burn_origin
		)


func _play_cut_transition(director: Node) -> void:
	if director.has_method("prepare_for_scene_change"):
		director.call("prepare_for_scene_change")
	director.scene_change_started.emit(scene_path)

	if director.has_method("disable_movie_mode"):
		director.call("disable_movie_mode")

	var result := director.get_tree().change_scene_to_file(scene_path)

	if result != OK:
		push_error(
			"MatineeSceneAction failed to load scene: %s. Error code: %s"
			% [scene_path, result]
		)
		if director.has_method("complete_scene_change_cleanup"):
			director.call("complete_scene_change_cleanup")
		return

	await director.get_tree().process_frame
	await director.get_tree().process_frame

	if director.has_method("reset_presentation_to_clean_state"):
		director.call("reset_presentation_to_clean_state")

	director.scene_change_finished.emit(scene_path)
	if director.has_method("complete_scene_change_cleanup"):
		director.call("complete_scene_change_cleanup")


func get_duration_seconds() -> float:
	var transition_duration := 0.0

	if wait_for_transition:
		match transition:
			SceneTransition.FADE:
				var fade_out := 0.75 if fade_out_duration < 0.0 else maxf(fade_out_duration, 0.01)
				var fade_in := 0.75 if fade_in_duration < 0.0 else maxf(fade_in_duration, 0.01)
				transition_duration = fade_out + maxf(black_hold_duration, 0.0) + fade_in
			SceneTransition.FILM_BURN:
				var burn_out := 1.15 if burn_out_duration < 0.0 else maxf(burn_out_duration, 0.1)
				var burn_in := 1.15 if burn_in_duration < 0.0 else maxf(burn_in_duration, 0.1)
				var hold := 0.18 if black_hold_duration < 0.0 else maxf(black_hold_duration, 0.0)
				transition_duration = burn_out + hold + hold + burn_in
			SceneTransition.CUT:
				transition_duration = 0.0

	return transition_duration + maxf(delay_after_change, 0.0)
