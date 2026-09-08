@tool
class_name MatineeVoicePreviewHandler
extends MatineePreviewHandler


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeVoiceAction"]


func get_capabilities() -> Dictionary:
	return {"audio": true, "stateful": true, "one_shot": true, "tracks_inactive": true}


func get_invalid_reason(action: MatineeAction, _entry: Dictionary) -> String:
	var voice := action as MatineeVoiceAction
	if voice == null or voice.mode != MatineeVoiceAction.VoiceMode.PLAY:
		return "Voice control actions do not produce editor audio."
	return "Voice preview is missing an AudioStream." if voice.stream == null else ""


func enter_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	var voice := session.action as MatineeVoiceAction
	if voice == null or context.audio_service == null:
		return
	if voice.wait_for_completion and session.timeline_action != null and session.timeline_action.duration > 0.0:
		if context.playback_state == 1 or (context.seeking and context.audio_while_scrubbing):
			context.audio_service.play_clip(session.clip_id, voice.stream, session.local_time)


func update_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	var voice := session.action as MatineeVoiceAction
	if voice == null or context.audio_service == null:
		return
	if voice.wait_for_completion and session.timeline_action != null and session.timeline_action.duration > 0.0:
		if context.playback_state == 1 or (context.seeking and context.audio_while_scrubbing):
			context.audio_service.play_clip(session.clip_id, voice.stream, session.local_time)
		context.audio_service.update_clip(session.clip_id, session.local_time, context.playback_state == 2)
		return
	var start_time := session.timeline_action.start_time if session.timeline_action != null else 0.0
	if context.current_time < start_time:
		context.audio_service.stop_clip(session.clip_id)
		session.one_shot_fired = false
		return
	var crossed := (
		context.transport_mode == &"forward_playback"
		and context.previous_time <= start_time
		and context.current_time >= start_time
	) or (
		context.seeking
		and context.audio_while_scrubbing
		and context.previous_time < start_time
		and context.current_time >= start_time
	)
	if crossed and not session.one_shot_fired:
		session.one_shot_fired = context.audio_service.play_one_shot(session.clip_id, voice.stream)


func exit_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	var voice := session.action as MatineeVoiceAction
	if voice != null and voice.wait_for_completion and context.audio_service != null:
		context.audio_service.stop_clip(session.clip_id)


func reset_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	if context.audio_service != null:
		context.audio_service.stop_clip(session.clip_id)
	session.one_shot_fired = false
