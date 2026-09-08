@tool
class_name MatineeSFXPreviewHandler
extends MatineePreviewHandler


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeSFXAction"]


func get_capabilities() -> Dictionary:
	return {"audio": true, "one_shot": true, "tracks_inactive": true}


func get_invalid_reason(action: MatineeAction, _entry: Dictionary) -> String:
	var sfx := action as MatineeSFXAction
	return "Sound Effect preview is missing an AudioStream." if sfx == null or sfx.stream == null else ""


func update_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	var start_time := session.timeline_action.start_time if session.timeline_action != null else 0.0
	if context.current_time < start_time:
		if session.one_shot_fired and context.audio_service != null:
			context.audio_service.stop_clip(session.clip_id)
		session.one_shot_fired = false
		return
	var normal_crossing := (
		context.transport_mode == &"forward_playback"
		and context.previous_time <= start_time
		and context.current_time >= start_time
	)
	var scrub_crossing := (
		context.seeking
		and context.audio_while_scrubbing
		and context.previous_time < start_time
		and context.current_time >= start_time
	)
	if session.one_shot_fired or (not normal_crossing and not scrub_crossing):
		return
	var sfx := session.action as MatineeSFXAction
	if sfx != null and context.audio_service != null:
		session.one_shot_fired = context.audio_service.play_one_shot(
			session.clip_id, sfx.stream, sfx.volume_db, sfx.pitch_scale
		)


func reset_clip(session: MatineePreviewClipSession, context: MatineePreviewContext) -> void:
	if context.audio_service != null:
		context.audio_service.stop_clip(session.clip_id)
	session.one_shot_fired = false
