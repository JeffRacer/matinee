@tool
class_name MatineeValidator
extends RefCounted


static func validate(
	sequence: MatineeSequence,
	previewable_action_types: Array[StringName] = [],
	scene_context: Node = null
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if sequence == null:
		results.append(_issue("error", -1, "No MatineeSequence is selected."))
		return results

	if sequence.get_enabled_action_count() == 0:
		results.append(_issue("warning", -1, "The sequence contains no actions."))

	for structural_issue in sequence.get_validation_issues():
		results.append(_issue(
			"error",
			int(structural_issue.get("action_index", -1)),
			str(structural_issue["message"]),
			int(structural_issue.get("track_index", -1))
		))

	for entry in sequence.get_timeline_entries():
		var action := entry["action"] as MatineeAction
		_validate_action(action, int(entry["action_index"]), results, int(entry["track_index"]), scene_context)
		if not previewable_action_types.is_empty() and not _matches_preview_type(action, previewable_action_types):
			results.append(_issue(
				"warning",
				int(entry["action_index"]),
				"%s has no Runtime Preview handler." % action.get_editor_name(),
				int(entry["track_index"])
			))
		elif action is MatineeCameraAction:
			results.append(_issue(
				"preview_warning",
				int(entry["action_index"]),
				"Camera preview is diagnostic-only; live framing is unavailable without an isolated game viewport.",
				int(entry["track_index"])
			))

	_validate_camera_overlaps(sequence, results)

	return results


static func _validate_action(
	action: MatineeAction,
	index: int,
	results: Array[Dictionary],
	track_index: int = -1,
	scene_context: Node = null
) -> void:
	if action == null:
		results.append(_issue("error", index, "Timeline clip has no action resource.", track_index))
		return
	if action.get_duration_seconds() < 0.0:
		results.append(_issue("error", index, "Duration cannot be negative.", track_index))
	for message in action.get_validation_issues(scene_context):
		results.append(_issue("error", index, message, track_index))

	var editor_name := action.get_editor_name()
	match editor_name:
		"Scene Change":
			var scene_path := str(action.get("scene_path")).strip_edges()
			if scene_path.is_empty():
				results.append(_issue("error", index, "Scene Change has no scene path.", track_index))
			elif not ResourceLoader.exists(scene_path):
				results.append(_issue("error", index, "Scene does not exist: %s" % scene_path, track_index))
		"Dialogue":
			if str(action.get("message")).strip_edges().is_empty():
				results.append(_issue("warning", index, "Dialogue has no message.", track_index))
		"Title Card":
			if str(action.get("main_text")).strip_edges().is_empty():
				results.append(_issue("warning", index, "Title Card has no title.", track_index))
		"Chapter Card":
			if str(action.get("chapter_title")).strip_edges().is_empty():
				results.append(_issue("warning", index, "Chapter Card has no title.", track_index))
		"Location Card":
			if str(action.get("location_name")).strip_edges().is_empty():
				results.append(_issue("warning", index, "Location Card has no location name.", track_index))


static func _validate_camera_overlaps(sequence: MatineeSequence, results: Array[Dictionary]) -> void:
	var camera_entries: Array[Dictionary] = []
	for entry in sequence.get_timeline_entries():
		if entry.get("action") is MatineeCameraAction:
			camera_entries.append(entry)
	for left_index in range(camera_entries.size()):
		var left := camera_entries[left_index]
		for right_index in range(left_index + 1, camera_entries.size()):
			var right := camera_entries[right_index]
			if float(left["start"]) >= float(right["end"]) or float(right["start"]) >= float(left["end"]):
				continue
			var winner := _higher_camera_priority(left, right)
			results.append(_issue(
				"warning",
				int(right["action_index"]),
				"Camera clips overlap; track %d action %d wins by deterministic camera priority."
				% [int(winner["track_index"]), int(winner["action_index"])],
				int(right["track_index"])
			))


static func _higher_camera_priority(left: Dictionary, right: Dictionary) -> Dictionary:
	var left_track := int(left.get("track_index", -1))
	var right_track := int(right.get("track_index", -1))
	if left_track != right_track:
		return left if left_track > right_track else right
	var left_start := float(left.get("start", 0.0))
	var right_start := float(right.get("start", 0.0))
	if not is_equal_approx(left_start, right_start):
		return left if left_start > right_start else right
	return left if int(left.get("action_index", -1)) > int(right.get("action_index", -1)) else right


static func _issue(severity: String, action_index: int, message: String, track_index: int = -1) -> Dictionary:
	return {
		"severity": severity,
		"track_index": track_index,
		"action_index": action_index,
		"message": message,
	}


static func _matches_preview_type(
	action: MatineeAction,
	previewable_action_types: Array[StringName]
) -> bool:
	if action == null:
		return false
	for type_name in previewable_action_types:
		if action.is_class(String(type_name)):
			return true
		var script := action.get_script() as Script
		while script != null:
			if script.get_global_name() == type_name:
				return true
			script = script.get_base_script()
	return false
