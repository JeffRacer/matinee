@tool
class_name MatineePreviewCoordinator
extends RefCounted

const PreviewContext := preload("res://addons/matinee/preview/preview_context.gd")
const FadePreviewHandler := preload("res://addons/matinee/preview/handlers/fade_preview_handler.gd")
const PresentationPreviewHandler := preload("res://addons/matinee/preview/handlers/presentation_preview_handler.gd")
const ScenePreviewHandler := preload("res://addons/matinee/preview/handlers/scene_preview_handler.gd")
const TitleCardPreviewHandler := preload("res://addons/matinee/preview/handlers/title_card_preview_handler.gd")
const ChapterCardPreviewHandler := preload("res://addons/matinee/preview/handlers/chapter_card_preview_handler.gd")
const LocationCardPreviewHandler := preload("res://addons/matinee/preview/handlers/location_card_preview_handler.gd")
const DialoguePreviewHandler := preload("res://addons/matinee/preview/handlers/dialogue_preview_handler.gd")
const MusicPreviewHandler := preload("res://addons/matinee/preview/handlers/music_preview_handler.gd")
const AmbiencePreviewHandler := preload("res://addons/matinee/preview/handlers/ambience_preview_handler.gd")
const SFXPreviewHandler := preload("res://addons/matinee/preview/handlers/sfx_preview_handler.gd")
const VoicePreviewHandler := preload("res://addons/matinee/preview/handlers/voice_preview_handler.gd")
const CameraPreviewHandler := preload("res://addons/matinee/preview/handlers/camera_preview_handler.gd")
const ClipSession := preload("res://addons/matinee/preview/preview_clip_session.gd")

var _context: MatineePreviewContext = PreviewContext.new()
var _registry: Variant = null
var _timeline_entries: Array[Dictionary] = []
var _sessions := {}
var _diagnostics := {}
var _last_warning := ""


func _init() -> void:
	_registry = load("res://addons/matinee/preview/preview_registry.gd").new()
	_register_default_handlers()


func set_sequence(sequence: MatineeSequence) -> void:
	_context.sequence = sequence
	rebuild(sequence)


func rebuild(sequence: MatineeSequence) -> void:
	reset_all()
	_context.sequence = sequence
	_timeline_entries.clear()
	if is_instance_valid(sequence):
		_timeline_entries = sequence.get_timeline_entries(false)
	for handler: Variant in _registry.get_handlers():
		var preview_handler: Variant = handler
		preview_handler.rebuild(sequence, _context)


func evaluate(
	time: float,
	active_entries: Array[Dictionary],
	playback_state: int = 0,
	seeking: bool = false
) -> Array[Dictionary]:
	_classify_transport(time, playback_state, seeking)
	_context.current_time = time
	_context.playback_state = playback_state
	_context.seeking = seeking
	_context.active_entries = active_entries.duplicate()
	var next_states: Array[Dictionary] = []
	var previewed_count := 0
	var unsupported_count := 0
	var invalid_count := 0
	var event_active_count := 0

	for entry in _timeline_entries:
		var action := entry.get("action") as MatineeAction
		if action == null or not action.enabled:
			continue
		var handler: Variant = _registry.get_handler_for_action(action)
		var is_active := _entry_is_active(entry, time)
		var is_event_crossing := _entry_is_event_crossing(entry)
		if is_event_crossing:
			event_active_count += 1
		if handler == null:
			if is_active or is_event_crossing:
				unsupported_count += 1
				_set_warning_once(_registry.get_unsupported_reason(action))
			continue
		var invalid_reason: String = handler.get_invalid_reason(action, entry)
		if not invalid_reason.is_empty():
			if is_active or is_event_crossing:
				invalid_count += 1
				_set_warning_once(invalid_reason)
			continue
		var session := _get_or_create_session(entry, handler)
		if session.failed:
			if is_active or is_event_crossing:
				invalid_count += 1
			continue
		var capabilities: Dictionary = handler.get_capabilities()
		if is_active or is_event_crossing:
			if not session.entered:
				enter_clip(session, entry)
			else:
				update_clip(session, entry)
			previewed_count += 1
		elif bool(capabilities.get("tracks_inactive", false)):
			_call_session_handler(session, &"update_clip")
		if not is_active and not is_event_crossing and session.entered:
			exit_clip(session)

	for handler: Variant in _registry.get_handlers():
		var preview_handler: Variant = handler
		preview_handler.collect_persistent_states(time, _context, next_states)

	for entry in active_entries:
		var action := entry.get("action") as MatineeAction
		if action == null or not action.enabled:
			continue
		var handler: Variant = _registry.get_handler_for_action(action)
		if handler == null:
			continue
		var preview_handler: Variant = handler
		var state: Dictionary = preview_handler.evaluate_entry(time, entry, action, _context)
		if not state.is_empty():
			next_states.append(state)

	_context.active_clip_records = _sessions.duplicate()
	_diagnostics = {
		"active_clips": active_entries.size() + event_active_count,
		"previewed_clips": previewed_count,
		"unsupported_clips": unsupported_count,
		"invalid_clips": invalid_count,
		"audio_muted": _context.mute_preview_audio,
		"audio_while_scrubbing": _context.audio_while_scrubbing,
		"last_warning": _last_warning,
	}
	_context.previous_time = time

	return next_states


func set_enabled(value: bool) -> void:
	if _context.enabled == value:
		return
	if value:
		for handler: Variant in _registry.get_handlers():
			var preview_handler: Variant = handler
			preview_handler.on_preview_enabled(_context)
	else:
		for handler: Variant in _registry.get_handlers():
			var preview_handler: Variant = handler
			preview_handler.on_preview_disabled(_context)
		reset_all()
	_context.enabled = value


func clear_runtime_state() -> void:
	reset_all()
	_context.reset_runtime_state()
	_last_warning = ""
	_diagnostics.clear()


func prepare(preview_root: Node, audio_service: Variant) -> void:
	_context.preview_root = preview_root
	_context.audio_service = audio_service


func set_audio_muted(value: bool) -> void:
	_context.mute_preview_audio = value
	_diagnostics["audio_muted"] = value
	if _context.audio_service != null:
		_context.audio_service.set_muted(value)


func set_audio_while_scrubbing(value: bool) -> void:
	_context.audio_while_scrubbing = value
	_diagnostics["audio_while_scrubbing"] = value
	if _context.audio_service != null:
		_context.audio_service.set_audio_while_scrubbing(value)


func get_diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)


func get_clip_session_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for session: MatineePreviewClipSession in _sessions.values():
		result.append({
			"clip_id": session.clip_id,
			"track_index": session.track_index,
			"action_index": session.action_index,
			"state": session.state,
			"entered": session.entered,
			"one_shot_fired": session.one_shot_fired,
			"local_time": session.local_time,
			"previous_local_time": session.previous_local_time,
			"last_preview_error": session.last_preview_error,
			"failed": session.failed,
		})
	return result


func enter_clip(session: MatineePreviewClipSession, entry: Dictionary) -> void:
	session.update_time(_context.current_time, float(entry.get("start", 0.0)))
	session.entered = true
	session.state = MatineePreviewClipSession.State.ENTERED
	_call_session_handler(session, &"enter_clip")
	if session.last_preview_error.is_empty():
		_call_session_handler(session, &"update_clip")


func update_clip(session: MatineePreviewClipSession, entry: Dictionary) -> void:
	session.update_time(_context.current_time, float(entry.get("start", 0.0)))
	session.state = MatineePreviewClipSession.State.ACTIVE
	_call_session_handler(session, &"update_clip")


func exit_clip(session: MatineePreviewClipSession) -> void:
	_call_session_handler(session, &"exit_clip")
	session.entered = false
	session.state = MatineePreviewClipSession.State.EXITED


func reset_clip(session: MatineePreviewClipSession) -> void:
	if session.entered:
		exit_clip(session)
	_call_session_handler(session, &"reset_clip")
	session.entered = false
	session.state = MatineePreviewClipSession.State.RESET


func reset_all() -> void:
	for session: MatineePreviewClipSession in _sessions.values():
		reset_clip(session)
	_sessions.clear()
	_context.active_clip_records.clear()
	_context.run_cleanup_callbacks()
	if _context.audio_service != null:
		_context.audio_service.stop_all()


func is_action_previewable(action: MatineeAction) -> bool:
	return _registry.is_previewable(action)


func get_unsupported_reason(action: MatineeAction) -> String:
	return _registry.get_unsupported_reason(action)


func get_previewable_action_types() -> Array[StringName]:
	return _registry.get_previewable_action_types()


func get_registered_handler_metadata() -> Array[Dictionary]:
	return _registry.get_registered_handler_metadata()


func register_handler(handler: Variant) -> void:
	if handler == null:
		return
	_registry.register_handler(handler)
	handler.rebuild(_context.sequence, _context)
	if _context.enabled:
		handler.on_preview_enabled(_context)


func unregister_handler(handler: Variant) -> bool:
	if handler == null:
		return false
	if _context.enabled:
		handler.on_preview_disabled(_context)
	return _registry.unregister_handler(handler)


func reset_default_handlers() -> void:
	if _context.enabled:
		for handler: Variant in _registry.get_handlers():
			var preview_handler: Variant = handler
			preview_handler.on_preview_disabled(_context)
	_register_default_handlers()
	rebuild(_context.sequence)
	if _context.enabled:
		for handler: Variant in _registry.get_handlers():
			var preview_handler: Variant = handler
			preview_handler.on_preview_enabled(_context)


func _register_default_handlers() -> void:
	_registry.clear()
	_registry.register_handler(FadePreviewHandler.new())
	_registry.register_handler(PresentationPreviewHandler.new())
	_registry.register_handler(ScenePreviewHandler.new())
	_registry.register_handler(TitleCardPreviewHandler.new())
	_registry.register_handler(ChapterCardPreviewHandler.new())
	_registry.register_handler(LocationCardPreviewHandler.new())
	_registry.register_handler(DialoguePreviewHandler.new())
	_registry.register_handler(MusicPreviewHandler.new())
	_registry.register_handler(AmbiencePreviewHandler.new())
	_registry.register_handler(SFXPreviewHandler.new())
	_registry.register_handler(VoicePreviewHandler.new())
	_registry.register_handler(CameraPreviewHandler.new())


func _classify_transport(time: float, playback_state: int, seeking: bool) -> void:
	var previous := _context.current_time
	_context.scrub_direction = signf(time - previous) as int
	if seeking:
		_context.transport_mode = &"backward_seek" if time < previous else &"forward_seek"
	elif playback_state == 1:
		_context.transport_mode = &"forward_playback" if time >= previous else &"backward_seek"
	elif playback_state == 2:
		_context.transport_mode = &"paused_update"
	else:
		_context.transport_mode = &"stop_reset"


func _entry_is_active(entry: Dictionary, time: float) -> bool:
	var start := float(entry.get("start", 0.0))
	var end := float(entry.get("end", start))
	return end > start and time >= start and time < end


func _entry_is_event_crossing(entry: Dictionary) -> bool:
	var start := float(entry.get("start", 0.0))
	var end := float(entry.get("end", start))
	if end > start:
		return false
	if _context.transport_mode == &"forward_playback":
		return _context.previous_time <= start and _context.current_time >= start
	return _context.seeking and _context.audio_while_scrubbing and _context.previous_time < start and _context.current_time >= start


func _get_or_create_session(entry: Dictionary, handler: Variant) -> MatineePreviewClipSession:
	var clip_id := MatineePreviewClipIdentity.from_entry(entry)
	var session := _sessions.get(clip_id) as MatineePreviewClipSession
	if session == null:
		session = ClipSession.new()
		session.configure(entry, handler)
		_sessions[clip_id] = session
	return session


func _set_warning_once(message: String) -> void:
	if message.is_empty() or message == _last_warning:
		return
	_last_warning = message
	_context.report_warning(message)


func _call_session_handler(session: MatineePreviewClipSession, method: StringName) -> void:
	if session.handler == null or not session.handler.has_method(method):
		session.last_preview_error = "Preview handler is missing %s()." % method
		_set_warning_once(session.last_preview_error)
		return
	session.handler.call(method, session, _context)
	if not session.last_preview_error.is_empty() and method not in [&"exit_clip", &"reset_clip"]:
		session.failed = true
		_set_warning_once(session.last_preview_error)
		if _context.audio_service != null:
			_context.audio_service.stop_clip(session.clip_id)
		session.entered = false
		session.state = MatineePreviewClipSession.State.EXITED
