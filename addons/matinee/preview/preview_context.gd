@tool
class_name MatineePreviewContext
extends RefCounted

var sequence: MatineeSequence
var preview_root: Node
var current_time: float = 0.0
var previous_time: float = 0.0
var playback_state: int = 0
var seeking: bool = false
var scrub_direction: int = 0
var transport_mode: StringName = &"reset"
var enabled: bool = false
var active_entries: Array[Dictionary] = []
var audio_service: Variant
var mute_preview_audio: bool = false
var audio_while_scrubbing: bool = false
var active_clip_records := {}
var diagnostic_callback: Callable

var _persistent_states := {}
var _cleanup_callbacks: Array[Callable] = []


func reset_runtime_state() -> void:
	previous_time = 0.0
	current_time = 0.0
	playback_state = 0
	seeking = false
	scrub_direction = 0
	transport_mode = &"reset"
	active_entries.clear()
	active_clip_records.clear()
	_persistent_states.clear()


func register_cleanup(callback: Callable) -> void:
	if callback.is_valid() and not _cleanup_callbacks.has(callback):
		_cleanup_callbacks.append(callback)


func run_cleanup_callbacks() -> void:
	for callback in _cleanup_callbacks:
		if callback.is_valid():
			callback.call()
	_cleanup_callbacks.clear()


func report_warning(message: String) -> void:
	if diagnostic_callback.is_valid():
		diagnostic_callback.call(message)


func set_persistent_state(key: StringName, state: Variant) -> void:
	_persistent_states[key] = state


func get_persistent_state(key: StringName, default_value: Variant = null) -> Variant:
	return _persistent_states.get(key, default_value)


func clear_persistent_state(key: StringName) -> void:
	_persistent_states.erase(key)
