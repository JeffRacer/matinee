@tool
class_name MatineeAmbiencePreviewHandler
extends MatineePreviewHandler


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeAmbienceAction"]


func get_capabilities() -> Dictionary:
	return {"audio": true, "stateful": true, "looping": true}


func get_invalid_reason(action: MatineeAction, entry: Dictionary) -> String:
	var ambience := action as MatineeAmbienceAction
	if ambience == null or ambience.mode != MatineeAmbienceAction.AmbienceMode.PLAY:
		return "Ambience control actions do not produce editor audio."
	if ambience.track == null:
		return "Ambience preview is missing an AudioStream."
	if float(entry.get("end", 0.0)) <= float(entry.get("start", 0.0)):
		return "Ambience preview requires a positive timeline clip duration."
	return ""


func enter_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	update_clip(session, context)


func update_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	var ambience := session.action as MatineeAmbienceAction
	if ambience == null or context.audio_service == null:
		return
	if context.playback_state == 1 or (context.seeking and context.audio_while_scrubbing):
		context.audio_service.play_clip(session.clip_id, ambience.track, session.local_time, 0.0, 1.0, ambience.loop_stream)
	context.audio_service.update_clip(session.clip_id, session.local_time, context.playback_state == 2)


func exit_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	if context.audio_service != null:
		context.audio_service.stop_clip(session.clip_id)


func reset_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	exit_clip(session, context)
