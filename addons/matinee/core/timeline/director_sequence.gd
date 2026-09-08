@tool
class_name MatineeSequence
extends Resource

const CURRENT_TRACK_MODEL_VERSION := 1

@export_category("Sequence")
@export var sequence_name: String = "New Sequence"

@export_multiline
var description: String = ""

@export var lock_controls: bool = true
@export var stop_on_error: bool = true

## Deprecated storage retained only so unsupported pre-v0.4 resources can load
## without losing data before the explicit migration tool processes them.
@export_storage var actions: Array[MatineeAction] = []

@export_category("Tracks")
@export var tracks: Array[MatineeTrack] = []
@export_storage var track_model_version: int = CURRENT_TRACK_MODEL_VERSION


func is_current_track_format() -> bool:
	return actions.is_empty() and track_model_version == CURRENT_TRACK_MODEL_VERSION


func has_legacy_actions() -> bool:
	return not actions.is_empty()


func has_ambiguous_storage() -> bool:
	return not actions.is_empty() and not tracks.is_empty()


func get_timeline_entries(include_muted: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not is_current_track_format():
		return entries
	for track_index in range(tracks.size()):
		var track := tracks[track_index]
		if track == null or not track.enabled or (track.muted and not include_muted):
			continue
		for action_index in range(track.actions.size()):
			var timeline_action := track.actions[action_index]
			if timeline_action == null or timeline_action.action == null:
				continue
			entries.append({
				"track": track,
				"track_index": track_index,
				"timeline_action": timeline_action,
				"action": timeline_action.action,
				"action_index": action_index,
				"start": timeline_action.start_time,
				"end": timeline_action.get_end_time(),
			})
	return entries


func get_duration_seconds() -> float:
	var total := 0.0
	if not is_current_track_format():
		return 0.0
	for track in tracks:
		if track != null and track.enabled:
			total = maxf(total, track.get_duration_seconds())
	return total


func has_exact_duration() -> bool:
	for entry in get_timeline_entries():
		var action := entry["action"] as MatineeAction
		if action == null or not action.enabled:
			continue

		if not action.has_exact_duration():
			return false

	return true


func get_enabled_action_count() -> int:
	var count := 0

	if not is_current_track_format():
		return 0
	for track in tracks:
		if track != null and track.enabled:
			count += track.get_enabled_action_count()

	return count


func get_all_actions() -> Array[MatineeAction]:
	var result: Array[MatineeAction] = []
	for entry in get_timeline_entries():
		var action := entry["action"] as MatineeAction
		if action != null and not result.has(action):
			result.append(action)
	return result


func get_all_timeline_actions() -> Array[MatineeTimelineAction]:
	var result: Array[MatineeTimelineAction] = []
	for track in tracks:
		if track == null:
			continue
		for timeline_action in track.actions:
			if timeline_action != null:
				result.append(timeline_action)
	return result


func get_validation_issues() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if has_ambiguous_storage():
		issues.append({"track_index": -1, "action_index": -1, "message": "Sequence contains both tracks and deprecated flat actions. Run the MatineeSequence migration tool."})
	elif has_legacy_actions():
		issues.append({"track_index": -1, "action_index": -1, "message": "Unsupported legacy MatineeSequence format. Run tools/migrate_director_sequences.gd."})
	if track_model_version != CURRENT_TRACK_MODEL_VERSION:
		issues.append({"track_index": -1, "action_index": -1, "message": "Unsupported track-model version %d (current: %d)." % [track_model_version, CURRENT_TRACK_MODEL_VERSION]})

	var track_names := {}
	for track_index in range(tracks.size()):
		var track := tracks[track_index]
		if track == null:
			issues.append({"track_index": track_index, "action_index": -1, "message": "Track entry is empty."})
			continue
		var normalized_name := track.track_name.strip_edges().to_lower()
		if not normalized_name.is_empty():
			if track_names.has(normalized_name):
				issues.append({"track_index": track_index, "action_index": -1, "message": "Track name duplicates another track: %s" % track.track_name})
			else:
				track_names[normalized_name] = track_index
		for issue in track.get_validation_issues():
			var sequence_issue: Dictionary = issue.duplicate()
			sequence_issue["track_index"] = track_index
			issues.append(sequence_issue)
	return issues


func get_formatted_duration() -> String:
	var total_seconds := get_duration_seconds()
	var minutes := int(total_seconds) / 60
	var seconds := int(total_seconds) % 60
	var tenths := int(floor(fmod(total_seconds, 1.0) * 10.0 + 0.0001))
	var suffix := "" if has_exact_duration() else "+"

	return "%02d:%02d.%d%s" % [
		minutes,
		seconds,
		tenths,
		suffix
	]


func get_timing_label() -> String:
	return "Exact" if has_exact_duration() else "Minimum / dynamic"


func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "Sequence Information",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY
		},
		{
			"name": "sequence_length",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "sequence_timing",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "enabled_action_count",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		}
	]


func _get(property: StringName) -> Variant:
	match property:
		&"sequence_length":
			return get_formatted_duration()
		&"sequence_timing":
			return get_timing_label()
		&"enabled_action_count":
			return get_enabled_action_count()

	return null
