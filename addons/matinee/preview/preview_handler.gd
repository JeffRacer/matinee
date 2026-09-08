@tool
class_name MatineePreviewHandler
extends RefCounted


func get_supported_action_types() -> Array[StringName]:
	return []


func get_priority() -> int:
	return 0


func get_capabilities() -> Dictionary:
	return {}


func rebuild(_sequence: MatineeSequence, _context: MatineePreviewContext) -> void:
	pass


func on_preview_enabled(_context: MatineePreviewContext) -> void:
	pass


func on_preview_disabled(_context: MatineePreviewContext) -> void:
	pass


func enter_clip(_session: MatineePreviewClipSession, _context: MatineePreviewContext) -> void:
	pass


func update_clip(_session: MatineePreviewClipSession, _context: MatineePreviewContext) -> void:
	pass


func exit_clip(_session: MatineePreviewClipSession, _context: MatineePreviewContext) -> void:
	pass


func reset_clip(_session: MatineePreviewClipSession, _context: MatineePreviewContext) -> void:
	pass


func get_invalid_reason(_action: MatineeAction, _entry: Dictionary) -> String:
	return ""


func collect_persistent_states(
	_time: float,
	_context: MatineePreviewContext,
	_out_states: Array[Dictionary]
) -> void:
	pass


func evaluate_entry(
	_time: float,
	_entry: Dictionary,
	_action: MatineeAction,
	_context: MatineePreviewContext
) -> Dictionary:
	return {}


func _sort_timeline_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_start := float(left.get("start", 0.0))
	var right_start := float(right.get("start", 0.0))
	if not is_equal_approx(left_start, right_start):
		return left_start < right_start
	var left_track := int(left.get("track_index", -1))
	var right_track := int(right.get("track_index", -1))
	if left_track != right_track:
		return left_track < right_track
	return int(left.get("action_index", -1)) < int(right.get("action_index", -1))
