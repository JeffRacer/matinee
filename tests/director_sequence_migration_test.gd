extends SceneTree

const Migration := preload("res://addons/matinee/migration/director_sequence_migration.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_deterministic_legacy_migration()
	_test_ambiguous_cleanup_requires_identity_match()
	_test_current_and_invalid_detection()

	if _failures.is_empty():
		print("MatineeSequence migration tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_deterministic_legacy_migration() -> void:
	var first := MatineeWaitAction.new()
	first.duration = 2.0
	first.action_name = "First"
	var disabled := MatineeWaitAction.new()
	disabled.duration = 3.0
	disabled.enabled = false
	disabled.action_name = "Disabled"
	var event := MatineeWaitAction.new()
	event.duration = 0.0
	event.action_name = "Event"
	var sequence := MatineeSequence.new()
	sequence.track_model_version = 0
	sequence.actions.assign([first, disabled, event])
	var legacy_duration := 2.0

	_expect(Migration.classify(sequence) == Migration.STATE_LEGACY, "Populated flat actions should be detected as legacy.")
	var result := Migration.migrate(sequence)
	_expect(bool(result.success) and bool(result.changed), "Legacy migration should report one successful change.")
	_expect(sequence.track_model_version == MatineeSequence.CURRENT_TRACK_MODEL_VERSION, "Migration should assign the current model version.")
	_expect(sequence.actions.is_empty(), "Migration should clear deprecated flat storage.")
	_expect(sequence.tracks.size() == 1 and sequence.tracks[0].track_name == "Main", "Migration should create one Main track.")
	if sequence.tracks.size() != 1 or sequence.tracks[0].actions.size() != 3:
		_expect(false, "Migration should wrap every legacy action.")
		return
	var clips := sequence.tracks[0].actions
	_expect(clips[0].action == first and clips[1].action == disabled and clips[2].action == event, "Migration must preserve action identity and order.")
	_expect(first.action_name == "First" and disabled.action_name == "Disabled", "Migration must preserve action properties.")
	_expect(is_equal_approx(clips[0].start_time, 0.0) and is_equal_approx(clips[0].duration, 2.0), "First clip timing should begin at zero.")
	_expect(is_equal_approx(clips[1].start_time, 2.0) and is_equal_approx(clips[1].duration, 3.0), "Disabled actions should retain duration at the accumulated time.")
	_expect(is_equal_approx(clips[2].start_time, 2.0) and is_zero_approx(clips[2].duration), "Disabled actions must not advance time and zero-duration clips must remain zero.")
	_expect(is_equal_approx(sequence.get_duration_seconds(), legacy_duration), "Migration should preserve the legacy sequence duration.")

	var second_result := Migration.migrate(sequence)
	_expect(bool(second_result.success) and not bool(second_result.changed), "A second migration run should be idempotent.")


func _test_ambiguous_cleanup_requires_identity_match() -> void:
	var action := MatineeWaitAction.new()
	var clip := MatineeTimelineAction.new()
	clip.action = action
	var track := MatineeTrack.new()
	track.actions.append(clip)
	var sequence := MatineeSequence.new()
	sequence.actions.append(action)
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION

	_expect(Migration.classify(sequence) == Migration.STATE_AMBIGUOUS, "Dual-populated storage should be detected as ambiguous.")
	var result := Migration.migrate(sequence)
	_expect(bool(result.success) and sequence.actions.is_empty(), "Matching track identities should allow redundant legacy storage cleanup.")

	var mismatched := MatineeSequence.new()
	mismatched.actions.append(MatineeWaitAction.new())
	mismatched.tracks.append(track)
	mismatched.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	var mismatch_result := Migration.migrate(mismatched)
	_expect(not bool(mismatch_result.success) and not bool(mismatch_result.changed), "Ambiguous mismatched actions must fail without mutation.")
	_expect(mismatched.actions.size() == 1, "Failed ambiguous cleanup must retain legacy data.")


func _test_current_and_invalid_detection() -> void:
	var current := MatineeSequence.new()
	current.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	_expect(Migration.classify(current) == Migration.STATE_CURRENT, "Versioned track storage should be current even when empty.")

	var invalid := MatineeSequence.new()
	invalid.track_model_version = 0
	_expect(Migration.classify(invalid) == Migration.STATE_INVALID, "Unversioned empty storage should be invalid for migration.")
	var null_result := Migration.migrate(null)
	_expect(not bool(null_result.success), "Null resources should fail safely.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
