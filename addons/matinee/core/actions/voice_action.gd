@tool
class_name MatineeVoiceAction
extends MatineeAction

enum VoiceMode { PLAY, STOP, PAUSE, RESUME }

@export_category("Voice")
@export var mode: VoiceMode = VoiceMode.PLAY
@export var stream: AudioStream
@export_range(0.0, 10.0, 0.1) var fade_duration: float = 0.25
@export var restart: bool = true
@export var wait_for_completion: bool = true


func _init() -> void:
	action_name = "Voice"


func play(_director: Node) -> void:
	var voice_manager := _get_runtime_service()
	if voice_manager == null:
		push_warning("MatineeVoiceAction requires a configured host audio service (runtime_service_path).")
		return

	match mode:
		VoiceMode.PLAY:
			if stream == null:
				push_warning("MatineeVoiceAction has no stream assigned.")
				return
			voice_manager.call("play_voice", stream, fade_duration, restart)
			if wait_for_completion:
				await voice_manager.get("voice_finished")
		VoiceMode.STOP:
			await voice_manager.call("stop_voice", fade_duration)
		VoiceMode.PAUSE:
			voice_manager.call("pause_voice")
		VoiceMode.RESUME:
			voice_manager.call("resume_voice")

func get_duration_seconds() -> float:
	match mode:
		VoiceMode.PLAY:
			if not wait_for_completion or stream == null:
				return 0.0
			return maxf(stream.get_length(), 0.0)
		VoiceMode.STOP:
			return maxf(fade_duration, 0.0)
		_:
			return 0.0
