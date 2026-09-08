@tool
class_name MatineeAmbienceAction
extends MatineeAction

enum AmbienceMode { PLAY, STOP, PAUSE, RESUME, RESTART_CURRENT }

@export_category("Ambience")
@export var mode: AmbienceMode = AmbienceMode.PLAY
@export var track: AudioStream
@export var track_id: StringName = &""
@export_range(0.0, 10.0, 0.1) var fade_duration: float = 1.5
@export var restart: bool = false
@export var loop_stream: bool = true
@export var wait_for_fade: bool = false


func _init() -> void:
	action_name = "Ambience"


func play(_director: Node) -> void:
	var ambience_manager := _get_runtime_service()
	if ambience_manager == null:
		push_warning("MatineeAmbienceAction requires a configured host audio service (runtime_service_path).")
		return

	match mode:
		AmbienceMode.PLAY:
			if track == null:
				push_warning("MatineeAmbienceAction has no track assigned.")
				return
			if wait_for_fade:
				await ambience_manager.call("play_track_by_id", track_id, track, fade_duration, restart, loop_stream)
			else:
				ambience_manager.call("play_track_by_id", track_id, track, fade_duration, restart, loop_stream)
		AmbienceMode.STOP:
			if wait_for_fade:
				await ambience_manager.call("stop_ambience", fade_duration)
			else:
				ambience_manager.call("stop_ambience", fade_duration)
		AmbienceMode.PAUSE:
			ambience_manager.call("pause_ambience")
		AmbienceMode.RESUME:
			ambience_manager.call("resume_ambience")
		AmbienceMode.RESTART_CURRENT:
			if wait_for_fade:
				await ambience_manager.call("restart_current_track", fade_duration)
			else:
				ambience_manager.call("restart_current_track", fade_duration)

func get_duration_seconds() -> float:
	return maxf(fade_duration, 0.0) if wait_for_fade else 0.0
