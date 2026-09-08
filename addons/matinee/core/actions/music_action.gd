@tool
class_name MatineeMusicAction
extends MatineeAction


enum MusicMode {
	PLAY,
	STOP,
	PAUSE,
	RESUME,
	RESTART_CURRENT
}


@export_category("Music")
@export var mode: MusicMode = MusicMode.PLAY

## Audio stream used by PLAY mode.
@export var track: AudioStream

## Stable identifier used to avoid restarting the same track unnecessarily.
@export var track_id: StringName = &""

## Use -1 to use host audio service.default_fade_duration.
@export_range(-1.0, 10.0, 0.1)
var fade_duration: float = -1.0

## Only applies to PLAY mode.
@export var restart: bool = false

## When enabled, the Matinee waits for a crossfade or fade-out before
## advancing to the next action. Disable this when title cards or dialogue
## should begin while the music is fading in.
@export var wait_for_fade: bool = false


func _init() -> void:
	action_name = "Music"


func play(director: Node) -> void:
	if director == null:
		push_warning(
			"MatineeMusicAction cannot run without a Matinee."
		)
		return

	match mode:
		MusicMode.PLAY:
			await _play_track(director)

		MusicMode.STOP:
			await _stop_track(director)

		MusicMode.PAUSE:
			if director.has_method("pause_music"):
				director.call("pause_music")

		MusicMode.RESUME:
			if director.has_method("resume_music"):
				director.call("resume_music")

		MusicMode.RESTART_CURRENT:
			if not director.has_method("restart_music"):
				push_warning(
					"Matinee does not expose restart_music()."
				)
				return

			if wait_for_fade:
				await director.call(
					"restart_music",
					fade_duration,
					true
				)
			else:
				director.call(
					"restart_music",
					fade_duration,
					false
				)


func _play_track(director: Node) -> void:
	if track == null:
		push_warning(
			"MatineeMusicAction PLAY has no track assigned."
		)
		return

	if not director.has_method("play_music"):
		push_warning(
			"Matinee does not expose play_music()."
		)
		return

	if wait_for_fade:
		await director.call(
			"play_music",
			track,
			track_id,
			fade_duration,
			restart,
			true
		)
	else:
		director.call(
			"play_music",
			track,
			track_id,
			fade_duration,
			restart,
			false
		)


func _stop_track(director: Node) -> void:
	if not director.has_method("stop_music"):
		push_warning(
			"Matinee does not expose stop_music()."
		)
		return

	if wait_for_fade:
		await director.call(
			"stop_music",
			fade_duration,
			true
		)
	else:
		director.call(
			"stop_music",
			fade_duration,
			false
		)

func get_duration_seconds() -> float:
	if not wait_for_fade:
		return 0.0
	return 1.5 if fade_duration < 0.0 else maxf(fade_duration, 0.0)

