@tool
class_name MatineeDialogueAction
extends MatineeAction

@export_category("Speaker")

## Preferred speaker source.
@export var actor: MatineeActorDefinition

## Fallback used when Actor is not assigned.
@export var fallback_speaker_name: String = "UNKNOWN"


@export_category("Dialogue")

@export_multiline
var message: String = "Hello there."


@export_category("Behavior")

## Wait until the player dismisses the dialogue before continuing.
@export var wait_until_closed: bool = true

## Brief pause after the line closes.
@export_range(0.0, 5.0, 0.05)
var delay_after_close: float = 0.10

## Close an existing dialogue before displaying this line.
@export var replace_open_dialogue: bool = false

## Request the actor's talk animation while the line is displayed.
@export var animate_speaker: bool = true

@export_category("Text Presentation")
## Opt-in so existing dialogue continues to display instantly.
@export var use_typewriter: bool = false
@export_range(1.0, 120.0, 1.0) var characters_per_second: float = 35.0
@export var allow_skip_to_end: bool = true
@export var pause_at_punctuation: bool = true
@export_range(0.0, 1.0, 0.01) var comma_pause: float = 0.08
@export_range(0.0, 2.0, 0.01) var sentence_pause: float = 0.20


@export_category("Lookup")

## Path relative to the current scene.
@export var dialogue_ui_path: NodePath = NodePath(
	"DialogueUI"
)


func _init() -> void:
	action_name = "Dialogue"


func play(director: Node) -> void:
	if message.strip_edges().is_empty():
		push_warning(
			"MatineeDialogueAction has an empty message."
		)
		return

	var current_scene := director.get_tree().current_scene

	if current_scene == null:
		push_warning(
			"MatineeDialogueAction could not find the current scene."
		)
		return

	var dialogue_ui := current_scene.get_node_or_null(
		dialogue_ui_path
	)

	if dialogue_ui == null:
		push_warning(
			"MatineeDialogueAction could not find DialogueUI at '%s' "
			+ "inside scene '%s'."
			% [
				dialogue_ui_path,
				current_scene.name
			]
		)
		return

	if bool(dialogue_ui.get("is_open")):
		if replace_open_dialogue:
			dialogue_ui.call("force_close_dialogue")
			await director.get_tree().process_frame
		else:
			push_warning(
				"MatineeDialogueAction cannot open because another "
				+ "dialogue is already active."
			)
			return

	var scene_actor := _find_scene_actor(
		current_scene
	)

	if animate_speaker:
		_play_actor_animation(
			scene_actor,
			_get_talk_animation()
		)

	dialogue_ui.call(
		"show_actor_message",
		message,
		actor,
		fallback_speaker_name,
		get_presentation_settings()
	)

	await director.get_tree().process_frame

	if not bool(dialogue_ui.get("is_open")):
		push_warning(
			"MatineeDialogueAction attempted to show a message, "
			+ "but DialogueUI did not open."
		)

		_play_actor_animation(
			scene_actor,
			_get_idle_animation()
		)
		return

	if wait_until_closed:
		await dialogue_ui.get("dialogue_closed")

		if animate_speaker:
			_play_actor_animation(
				scene_actor,
				_get_idle_animation()
			)

		if delay_after_close > 0.0:
			await director.wait(
				delay_after_close
			)


func _find_scene_actor(
	current_scene: Node
) -> Node:
	if actor == null:
		return null

	var target_id := actor.get_scene_actor_id()

	if target_id == &"":
		return null

	return _find_actor_recursive(
		current_scene,
		target_id
	)


func _find_actor_recursive(
	node: Node,
	target_id: StringName
) -> Node:
	if "actor_id" in node:
		var node_actor_id: StringName = node.get(
			"actor_id"
		)

		if node_actor_id == target_id:
			return node

	for child: Node in node.get_children():
		var result := _find_actor_recursive(
			child,
			target_id
		)

		if result != null:
			return result

	return null


func _play_actor_animation(
	scene_actor: Node,
	animation_name: StringName
) -> void:
	if scene_actor == null:
		return

	if animation_name == &"":
		return

	if scene_actor.has_method("play_actor_animation"):
		scene_actor.call(
			"play_actor_animation",
			animation_name
		)


func _get_talk_animation() -> StringName:
	if actor == null:
		return &""

	return actor.talk_animation


func _get_idle_animation() -> StringName:
	if actor == null:
		return &""

	return actor.idle_animation

func get_duration_seconds() -> float:
	return delay_after_close if wait_until_closed else 0.0


func has_exact_duration() -> bool:
	return not wait_until_closed


func get_presentation_settings() -> MatineeDialoguePresentationSettings:
	var settings := MatineeDialoguePresentationSettings.new()
	settings.use_typewriter = use_typewriter
	settings.characters_per_second = maxf(characters_per_second, 1.0)
	settings.allow_skip_to_end = allow_skip_to_end
	settings.pause_at_punctuation = pause_at_punctuation
	settings.comma_pause = maxf(comma_pause, 0.0)
	settings.sentence_pause = maxf(sentence_pause, 0.0)
	return settings
