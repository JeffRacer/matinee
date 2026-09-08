class_name MatineeCameraRuntimeHandler
extends RefCounted

var _service := MatineeCameraRuntimeService.new()
var _context_root: Node


func begin_sequence(context_root: Node, warning_callback: Callable = Callable()) -> void:
	_context_root = context_root
	_service.begin(context_root, warning_callback)


func play_entry(
	entry: Dictionary,
	elapsed_provider: Callable,
	cancel_check: Callable
) -> void:
	var action := entry.get("action") as MatineeCameraAction
	if action == null:
		return
	var session := _service.enter(action, entry)
	if session.failed:
		return
	var start_time := float(entry.get("start", 0.0))
	var end_time := float(entry.get("end", start_time))
	while not bool(cancel_check.call()):
		var sequence_time := float(elapsed_provider.call())
		_service.update(session, maxf(sequence_time - start_time, 0.0))
		if sequence_time >= end_time:
			break
		if not is_instance_valid(_context_root) or _context_root.get_tree() == null:
			break
		await _context_root.get_tree().process_frame
	_service.exit(session, bool(cancel_check.call()))


func play_action(action: MatineeCameraAction, duration: float = -1.0) -> void:
	if action == null or not is_instance_valid(_context_root):
		return
	var actual_duration := maxf(duration, action.get_duration_seconds())
	var entry := {
		"action": action,
		"track_index": 0,
		"action_index": 0,
		"start": 0.0,
		"end": actual_duration,
	}
	var session := _service.enter(action, entry)
	if session.failed:
		return
	var elapsed := 0.0
	while elapsed < actual_duration and is_instance_valid(_context_root):
		_service.update(session, elapsed)
		await _context_root.get_tree().process_frame
		if not is_instance_valid(_context_root) or _context_root.get_tree() == null:
			break
		if not _context_root.get_tree().paused:
			elapsed += _context_root.get_process_delta_time()
	_service.exit(session)


func seek_sequence(sequence: MatineeSequence, time: float) -> void:
	if sequence == null or not is_instance_valid(_context_root):
		return
	_service.cleanup(true)
	_service.begin(_context_root)
	var sessions: Array[MatineeCameraRuntimeSession] = []
	for entry in sequence.get_timeline_entries(false):
		var action := entry.get("action") as MatineeCameraAction
		if action == null or not action.enabled:
			continue
		var start := float(entry.get("start", 0.0))
		var end := float(entry.get("end", start))
		if time < start or time >= end:
			continue
		var session := _service.enter(action, entry)
		if not session.failed:
			sessions.append(session)
	for session in sessions:
		_service.update(session, maxf(time - session.start_time, 0.0))


func finish_sequence(cancelled: bool = false) -> void:
	_service.cleanup(cancelled)
	_context_root = null


func cancel_sequence() -> void:
	_service.cleanup(true)


func get_service() -> MatineeCameraRuntimeService:
	return _service
