class_name MatineeActorDefinition
extends Resource


@export_category("Appearance")

@export var top_down_sprite: Texture2D


@export_category("Identity")

## Stable internal identifier used by story and cinematic systems.
## Examples: narrator, traveller.
@export var actor_id: StringName = &"actor"

## Name displayed in the dialogue box.
@export var display_name: String = "ACTOR"


@export_category("Dialogue Style")

## Color used by DialogueUI for the speaker's name.
@export var name_color: Color = Color(
	0.88,
	0.86,
	0.76,
	1.0
)

## Color used for this actor's dialogue text.
@export var text_color: Color = Color(
	0.92,
	0.91,
	0.84,
	1.0
)

## Characters displayed per second.
## Set to 0 for instant text.
@export_range(0.0, 120.0, 1.0)
var typing_speed: float = 0.0

## Additional pause after punctuation when typewriter text is enabled.
@export_range(0.0, 1.0, 0.01)
var punctuation_pause: float = 0.12

## Whether names should be forced to uppercase.
@export var uppercase_name: bool = true


@export_category("Scene Actor")

## Finds an NPC or character node placed in the current scene.
## The node should expose the same value through an actor_id property.
@export var scene_actor_id: StringName = &""

## Optional default animations used by timeline actions later.
@export var idle_animation: StringName = &"idle"
@export var talk_animation: StringName = &"talk"
@export var walk_animation: StringName = &"walk"


func get_formatted_name() -> String:
	if uppercase_name:
		return display_name.to_upper()

	return display_name


func get_scene_actor_id() -> StringName:
	if scene_actor_id != &"":
		return scene_actor_id

	return actor_id
