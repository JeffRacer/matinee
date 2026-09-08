@tool
class_name MatineePreviewController
extends RefCounted

const PreviewCoordinator := preload(
	"res://addons/matinee/preview/preview_coordinator.gd"
)
const AudioPreviewService := preload(
	"res://addons/matinee/preview/audio_preview_service.gd"
)

signal preview_changed(states: Array[Dictionary])
signal preview_cleared
signal diagnostics_changed(diagnostics: Dictionary)

var enabled: bool = false
var _states: Array[Dictionary] = []
var _coordinator: MatineePreviewCoordinator = PreviewCoordinator.new()
var _audio_service: MatineeAudioPreviewService = AudioPreviewService.new()


func prepare(preview_root: Node) -> void:
	_audio_service.prepare(preview_root)
	_coordinator.prepare(preview_root, _audio_service)


func set_sequence(sequence: MatineeSequence) -> void:
	_coordinator.set_sequence(sequence)
	clear()


func rebuild(sequence: MatineeSequence) -> void:
	_coordinator.rebuild(sequence)


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_coordinator.set_enabled(value)
	if not enabled:
		clear()


func evaluate(
	time: float,
	active_entries: Array[Dictionary],
	playback_state: int = 0,
	seeking: bool = false
) -> void:
	if not enabled:
		clear()
		return

	_set_states(_coordinator.evaluate(time, active_entries, playback_state, seeking))
	diagnostics_changed.emit(get_preview_diagnostics())


func set_audio_muted(value: bool) -> void:
	_coordinator.set_audio_muted(value)
	diagnostics_changed.emit(get_preview_diagnostics())


func set_audio_while_scrubbing(value: bool) -> void:
	_coordinator.set_audio_while_scrubbing(value)
	diagnostics_changed.emit(get_preview_diagnostics())


func get_preview_diagnostics() -> Dictionary:
	return _coordinator.get_diagnostics()


func get_clip_session_snapshots() -> Array[Dictionary]:
	return _coordinator.get_clip_session_snapshots()


func get_audio_debug_snapshot() -> Dictionary:
	return _audio_service.get_debug_snapshot()


func cleanup() -> void:
	set_enabled(false)
	_coordinator.reset_all()
	_audio_service.cleanup()
	clear()


func is_action_previewable(action: MatineeAction) -> bool:
	return _coordinator.is_action_previewable(action)


func get_unsupported_reason(action: MatineeAction) -> String:
	return _coordinator.get_unsupported_reason(action)


func get_previewable_action_types() -> Array[StringName]:
	return _coordinator.get_previewable_action_types()


func get_registered_handler_metadata() -> Array[Dictionary]:
	return _coordinator.get_registered_handler_metadata()


func register_handler(handler: MatineePreviewHandler) -> void:
	_coordinator.register_handler(handler)


func unregister_handler(handler: MatineePreviewHandler) -> bool:
	return _coordinator.unregister_handler(handler)


func reset_default_handlers() -> void:
	_coordinator.reset_default_handlers()


func clear() -> void:
	_coordinator.clear_runtime_state()
	if _states.is_empty():
		return
	_states.clear()
	preview_changed.emit([])
	preview_cleared.emit()


func get_states() -> Array[Dictionary]:
	return _states.duplicate(true)


func _set_states(next_states: Array[Dictionary]) -> void:
	if _states == next_states:
		return
	_states = next_states.duplicate(true)
	preview_changed.emit(get_states())
