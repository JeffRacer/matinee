class_name MatineeCameraRuntimeService
extends RefCounted

const TRANSITION_CAMERA_NAME := "BRCameraTransition"

var _context_root: Node
var _viewport: Viewport
var _base_state: MatineeCameraState
var _sessions: Dictionary = {}
var _winner: MatineeCameraRuntimeSession
var _transition_camera: Camera2D
var _last_warning: String = ""
var _warning_callback: Callable


func begin(context_root: Node, warning_callback: Callable = Callable()) -> void:
	cleanup(true)
	_context_root = context_root
	_viewport = context_root.get_viewport() if is_instance_valid(context_root) else null
	_warning_callback = warning_callback
	_base_state = MatineeCameraState.capture(_get_current_camera())


func enter(action: MatineeCameraAction, entry: Dictionary) -> MatineeCameraRuntimeSession:
	var session := MatineeCameraRuntimeSession.new()
	session.configure(action, entry)
	if not is_instance_valid(_context_root):
		_fail_session(session, "Camera Action has no runtime scene context.")
		return session
	if action.camera_path.is_empty():
		_fail_session(session, "Camera Action requires a target Camera2D path.")
		return session
	if action.blend_duration < 0.0:
		_fail_session(session, "Camera Action blend duration cannot be negative.")
		return session
	if action.use_zoom_override and (action.zoom_override.x <= 0.0 or action.zoom_override.y <= 0.0):
		_fail_session(session, "Camera Action zoom override must be positive.")
		return session
	var target := _context_root.get_node_or_null(action.camera_path)
	if target == null:
		_fail_session(session, "Camera Action could not resolve target: %s" % action.camera_path)
		return session
	if not target is Camera2D:
		_fail_session(session, "Camera Action target is not Camera2D: %s" % action.camera_path)
		return session

	session.target_camera = target as Camera2D
	session.target_state = MatineeCameraState.capture(session.target_camera)
	if action.use_follow_target and not action.follow_target_path.is_empty():
		var follow := _context_root.get_node_or_null(action.follow_target_path)
		if follow is Node2D:
			session.follow_target = follow as Node2D
			session.follow_was_resolved = true
			session.last_follow_position = session.follow_target.global_position
		else:
			_warn("Camera Action could not resolve Node2D follow target: %s" % action.follow_target_path)
	elif action.use_follow_target:
		_warn("Camera Action follow is enabled without a follow target path.")

	_sessions[session.clip_id] = session
	_recompute_winner()
	return session


func update(session: MatineeCameraRuntimeSession, local_time: float) -> void:
	if session == null or session.failed or not _sessions.has(session.clip_id):
		return
	session.local_time = maxf(local_time, 0.0)
	if not is_instance_valid(session.target_camera):
		_handle_lost_target(session)
		return
	if session == _winner:
		_apply_winner(session)


func exit(session: MatineeCameraRuntimeSession, force_restore: bool = false) -> void:
	if session == null or session.restored:
		return
	var was_winner := session == _winner
	_sessions.erase(session.clip_id)
	session.entered = false
	session.controls_camera = false
	if was_winner:
		_winner = null
		_disable_transition_camera()
		if force_restore or session.action.restore_previous_camera:
			_restore_session(session)
		else:
			_activate_target_final(session)
	else:
		_retire_suspended_session(session)
		session.restored = true
	_recompute_winner()


func reset_session(session: MatineeCameraRuntimeSession) -> void:
	exit(session, true)


func cleanup(force_restore: bool = true) -> void:
	for session: MatineeCameraRuntimeSession in _sessions.values():
		session.controls_camera = false
		session.restored = true
	_sessions.clear()
	_winner = null
	_disable_transition_camera()
	if force_restore:
		if _base_state != null:
			_restore_state_or_fallback(_base_state)
	_free_transition_camera()
	_context_root = null
	_viewport = null
	_base_state = null
	_warning_callback = Callable()


func get_winner() -> MatineeCameraRuntimeSession:
	return _winner


func get_session_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for session: MatineeCameraRuntimeSession in _sessions.values():
		snapshots.append({
			"clip_id": session.clip_id,
			"track_index": session.track_index,
			"action_index": session.action_index,
			"local_time": session.local_time,
			"blend_progress": session.blend_progress,
			"controls_camera": session.controls_camera,
			"failed": session.failed,
			"failure_message": session.failure_message,
		})
	return snapshots


func get_last_warning() -> String:
	return _last_warning


func _recompute_winner() -> void:
	var next_winner: MatineeCameraRuntimeSession
	for session: MatineeCameraRuntimeSession in _sessions.values():
		if session.failed or not is_instance_valid(session.target_camera):
			continue
		if session.has_higher_priority_than(next_winner):
			next_winner = session
	if next_winner == _winner:
		if _winner != null:
			_apply_winner(_winner)
		return
	if next_winner != null and next_winner.previous_state == null:
		# A suspended clip must capture the camera it actually replaces, not the
		# higher-priority camera that happened to be active when the clip entered.
		next_winner.previous_state = _capture_current_rendered_state()
		next_winner.previous_session = _winner
	if _winner != null:
		_winner.controls_camera = false
		_winner.cut_applied = false
		_winner.target_activated = false
	_winner = next_winner
	if _winner != null:
		_winner.controls_camera = true
		_apply_winner(_winner)


func _apply_winner(session: MatineeCameraRuntimeSession) -> void:
	if session.action.is_cut():
		session.blend_progress = 1.0
		if not session.cut_applied:
			_activate_target_final(session)
			session.cut_applied = true
		_update_follow(session)
		return

	var duration := maxf(session.action.blend_duration, 0.0001)
	var raw_progress := clampf(session.local_time / duration, 0.0, 1.0)
	var eased_progress := float(Tween.interpolate_value(
		0.0,
		1.0,
		raw_progress,
		1.0,
		session.action.transition_type,
		session.action.ease_type
	))
	session.blend_progress = clampf(eased_progress, 0.0, 1.0)
	if raw_progress >= 1.0:
		_activate_target_final(session)
		_update_follow(session)
		return
	_apply_transition_state(session, session.blend_progress)


func _apply_transition_state(session: MatineeCameraRuntimeSession, progress: float) -> void:
	var transition := _ensure_transition_camera()
	if transition == null or session.previous_state == null or session.target_state == null:
		_fail_session(session, "Camera Action could not create a transition camera.")
		return
	var destination_position := _get_destination_position(session)
	var destination_rotation := session.target_state.global_rotation
	var destination_zoom := _get_destination_zoom(session)
	transition.enabled = false
	transition.global_position = session.previous_state.rendered_position.lerp(destination_position, progress)
	transition.global_rotation = lerp_angle(session.previous_state.rendered_rotation, destination_rotation, progress)
	transition.zoom = session.previous_state.zoom.lerp(destination_zoom, progress)
	transition.offset = session.previous_state.offset.lerp(session.target_state.offset, progress)
	transition.enabled = true
	transition.make_current()


func _activate_target_final(session: MatineeCameraRuntimeSession) -> void:
	if not is_instance_valid(session.target_camera):
		_handle_lost_target(session)
		return
	if not session.target_activated:
		session.target_camera.global_position = _get_destination_position(session)
		session.target_camera.global_rotation = session.target_state.global_rotation
		session.target_camera.zoom = _get_destination_zoom(session)
		session.target_camera.offset = session.target_state.offset
		session.target_camera.enabled = true
		session.target_camera.make_current()
		session.target_activated = true
	_disable_transition_camera()


func _update_follow(session: MatineeCameraRuntimeSession) -> void:
	if not session.action.use_follow_target:
		return
	if not is_instance_valid(session.target_camera):
		_handle_lost_target(session)
		return
	if is_instance_valid(session.follow_target):
		session.last_follow_position = session.follow_target.global_position
		session.target_camera.global_position = session.last_follow_position
	elif session.follow_was_resolved:
		_warn_follow_loss_once(session)
		session.target_camera.global_position = session.last_follow_position


func _get_destination_position(session: MatineeCameraRuntimeSession) -> Vector2:
	if session.action.use_follow_target and is_instance_valid(session.follow_target):
		session.last_follow_position = session.follow_target.global_position
		return session.last_follow_position
	if session.action.use_follow_target and session.follow_was_resolved:
		_warn_follow_loss_once(session)
		return session.last_follow_position
	if session.action.preserve_camera_position_on_enter and session.previous_state != null:
		return session.previous_state.rendered_position
	return session.target_state.global_position


func _warn_follow_loss_once(session: MatineeCameraRuntimeSession) -> void:
	if session.follow_loss_reported:
		return
	session.follow_loss_reported = true
	_warn("Camera Action follow target was freed; continuing from its last position.")


func _get_destination_zoom(session: MatineeCameraRuntimeSession) -> Vector2:
	if session.action.use_zoom_override:
		return session.action.zoom_override
	return session.target_state.zoom


func _restore_session(session: MatineeCameraRuntimeSession) -> void:
	if session.restored:
		return
	session.restored = true
	if is_instance_valid(session.target_camera) and session.target_state != null:
		session.target_state.restore(false)
	_restore_state_or_fallback(session.previous_state)


func _retire_suspended_session(session: MatineeCameraRuntimeSession) -> void:
	if session.previous_state == null or not session.action.restore_previous_camera:
		return
	if is_instance_valid(session.target_camera) and session.target_state != null:
		session.target_state.restore(false)
	for active_session: MatineeCameraRuntimeSession in _sessions.values():
		if active_session.previous_session != session:
			continue
		active_session.previous_session = session.previous_session
		active_session.previous_state = session.previous_state


func _restore_state_or_fallback(state: MatineeCameraState) -> void:
	if state != null and state.restore(true):
		return
	var fallback := _find_fallback_camera()
	if fallback == null:
		_warn("Camera restoration failed and no fallback Camera2D was found.")
		return
	fallback.enabled = true
	fallback.make_current()
	_warn("Camera restoration used fallback camera: %s" % fallback.get_path())


func _handle_lost_target(session: MatineeCameraRuntimeSession) -> void:
	var message := "Camera Action target was freed during playback."
	_fail_session(session, message)
	var was_winner := session == _winner
	_sessions.erase(session.clip_id)
	if was_winner:
		_winner = null
		_disable_transition_camera()
		if session.action.restore_previous_camera:
			_restore_state_or_fallback(session.previous_state)
		session.restored = true
	else:
		_retire_suspended_session(session)
		session.restored = true
	_recompute_winner()


func _fail_session(session: MatineeCameraRuntimeSession, message: String) -> void:
	session.mark_failed(message)
	_warn(message)


func _capture_current_rendered_state() -> MatineeCameraState:
	var current := _get_current_camera()
	if current == _transition_camera and _winner != null:
		var authoritative := _winner.target_camera
		var state := MatineeCameraState.capture(authoritative)
		state.was_current = true
		state.enabled = true
		state.rendered_position = _transition_camera.global_position
		state.rendered_rotation = _transition_camera.global_rotation
		state.zoom = _transition_camera.zoom
		state.offset = _transition_camera.offset
		return state
	return MatineeCameraState.capture(current)


func _get_current_camera() -> Camera2D:
	if is_instance_valid(_viewport):
		return _viewport.get_camera_2d()
	if is_instance_valid(_context_root):
		return _context_root.get_viewport().get_camera_2d()
	return null


func _ensure_transition_camera() -> Camera2D:
	if is_instance_valid(_transition_camera):
		return _transition_camera
	if not is_instance_valid(_context_root):
		return null
	_transition_camera = Camera2D.new()
	_transition_camera.name = TRANSITION_CAMERA_NAME
	_transition_camera.enabled = false
	_transition_camera.ignore_rotation = false
	_transition_camera.position_smoothing_enabled = false
	_transition_camera.rotation_smoothing_enabled = false
	_transition_camera.limit_enabled = false
	_context_root.add_child(_transition_camera)
	return _transition_camera


func _disable_transition_camera() -> void:
	if is_instance_valid(_transition_camera):
		_transition_camera.enabled = false


func _free_transition_camera() -> void:
	if not is_instance_valid(_transition_camera):
		_transition_camera = null
		return
	if _transition_camera.get_parent() != null:
		_transition_camera.get_parent().remove_child(_transition_camera)
	_transition_camera.queue_free()
	_transition_camera = null


func _find_fallback_camera() -> Camera2D:
	var current := _get_current_camera()
	if is_instance_valid(current) and current != _transition_camera:
		return current
	if not is_instance_valid(_context_root):
		return null
	var first_camera: Camera2D
	for node in _context_root.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		if camera == null or camera == _transition_camera:
			continue
		if first_camera == null:
			first_camera = camera
		if camera.enabled:
			return camera
	return first_camera


func _warn(message: String) -> void:
	if message.is_empty() or message == _last_warning:
		return
	_last_warning = message
	if _warning_callback.is_valid():
		_warning_callback.call(message)
	else:
		push_warning(message)
