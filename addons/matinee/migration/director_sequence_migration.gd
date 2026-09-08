@tool
class_name MatineeSequenceMigration
extends RefCounted

const STATE_CURRENT := &"current"
const STATE_LEGACY := &"legacy"
const STATE_AMBIGUOUS := &"ambiguous"
const STATE_INVALID := &"invalid"


static func classify(sequence: MatineeSequence) -> StringName:
	if not is_instance_valid(sequence):
		return STATE_INVALID
	if not sequence.actions.is_empty() and not sequence.tracks.is_empty():
		return STATE_AMBIGUOUS
	if not sequence.actions.is_empty():
		return STATE_LEGACY
	if sequence.track_model_version == MatineeSequence.CURRENT_TRACK_MODEL_VERSION:
		return STATE_CURRENT
	return STATE_INVALID


static func migrate(sequence: MatineeSequence) -> Dictionary:
	var state := classify(sequence)
	match state:
		STATE_CURRENT:
			return _result(true, false, state, "Sequence already uses the current track format.")
		STATE_LEGACY:
			return _migrate_legacy(sequence)
		STATE_AMBIGUOUS:
			return _remove_redundant_legacy_storage(sequence)
		_:
			return _result(false, false, state, "Sequence format is empty, malformed, or uses an unsupported version.")


static func _migrate_legacy(sequence: MatineeSequence) -> Dictionary:
	for action in sequence.actions:
		if action == null:
			return _result(false, false, STATE_LEGACY, "Legacy sequence contains a null action.")

	var main_track := MatineeTrack.from_legacy_actions(sequence.actions)
	main_track.track_name = "Main"
	main_track.track_type = MatineeTrack.TrackType.GENERAL
	main_track.enabled = true
	main_track.muted = false
	main_track.locked = false
	main_track.visible = true

	sequence.tracks.assign([main_track])
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	sequence.actions.clear()
	sequence.emit_changed()
	return _result(true, true, STATE_LEGACY, "Migrated legacy actions to Main.")


static func _remove_redundant_legacy_storage(sequence: MatineeSequence) -> Dictionary:
	if sequence.track_model_version != MatineeSequence.CURRENT_TRACK_MODEL_VERSION:
		return _result(false, false, STATE_AMBIGUOUS, "Ambiguous sequence does not use the current track-model version.")
	if not _tracks_reference_exact_actions(sequence):
		return _result(false, false, STATE_AMBIGUOUS, "Track clips do not reference exactly the same actions as legacy storage.")

	sequence.actions.clear()
	sequence.emit_changed()
	return _result(true, true, STATE_AMBIGUOUS, "Removed redundant legacy action storage.")


static func _tracks_reference_exact_actions(sequence: MatineeSequence) -> bool:
	var legacy_counts := _action_identity_counts(sequence.actions)
	var track_actions: Array[MatineeAction] = []
	for track in sequence.tracks:
		if track == null:
			return false
		for clip in track.actions:
			if clip == null or clip.action == null:
				return false
			track_actions.append(clip.action)
	return legacy_counts == _action_identity_counts(track_actions)


static func _action_identity_counts(actions: Array[MatineeAction]) -> Dictionary:
	var counts := {}
	for action in actions:
		if action == null:
			counts[0] = int(counts.get(0, 0)) + 1
			continue
		var identity := action.get_instance_id()
		counts[identity] = int(counts.get(identity, 0)) + 1
	return counts


static func _result(success: bool, changed: bool, state: StringName, message: String) -> Dictionary:
	return {
		"success": success,
		"changed": changed,
		"state": state,
		"message": message,
	}
