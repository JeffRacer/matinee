extends SceneTree

var _failures: PackedStringArray = []


class WaitPreviewHandler extends MatineePreviewHandler:
	func get_supported_action_types() -> Array[StringName]:
		return [&"MatineeWaitAction"]

	func evaluate_entry(
		_time: float,
		_entry: Dictionary,
		_action: MatineeAction,
		_context: MatineePreviewContext
	) -> Dictionary:
		return {
			"kind": &"wait_preview",
			"track_index": int(_entry.get("track_index", -1)),
			"action_index": int(_entry.get("action_index", -1)),
		}


class TitleCardOverridePreviewHandler extends MatineePreviewHandler:
	func get_supported_action_types() -> Array[StringName]:
		return [&"MatineeTitleCardAction"]

	func evaluate_entry(
		_time: float,
		_entry: Dictionary,
		_action: MatineeAction,
		_context: MatineePreviewContext
	) -> Dictionary:
		return {
			"kind": &"title_card",
			"kicker": "",
			"main_text": "OVERRIDDEN",
			"subtitle": "",
			"opacity": 1.0,
			"track_index": int(_entry.get("track_index", -1)),
			"action_index": int(_entry.get("action_index", -1)),
		}


class LifecycleProbeHandler extends MatineePreviewHandler:
	var enabled_calls := 0
	var disabled_calls := 0
	var rebuild_calls := 0

	func rebuild(_sequence: MatineeSequence, _context: MatineePreviewContext) -> void:
		rebuild_calls += 1

	func on_preview_enabled(_context: MatineePreviewContext) -> void:
		enabled_calls += 1

	func on_preview_disabled(_context: MatineePreviewContext) -> void:
		disabled_calls += 1


class HighPriorityTitleCardPreviewHandler extends MatineePreviewHandler:
	func get_supported_action_types() -> Array[StringName]:
		return [&"MatineeTitleCardAction"]

	func get_priority() -> int:
		return 10

	func evaluate_entry(
		_time: float,
		_entry: Dictionary,
		_action: MatineeAction,
		_context: MatineePreviewContext
	) -> Dictionary:
		return {
			"kind": &"title_card",
			"kicker": "",
			"main_text": "HIGH PRIORITY",
			"subtitle": "",
			"opacity": 1.0,
			"track_index": int(_entry.get("track_index", -1)),
			"action_index": int(_entry.get("action_index", -1)),
		}


class MetadataProbeHandler extends MatineePreviewHandler:
	func get_supported_action_types() -> Array[StringName]:
		return [&"MatineeWaitAction"]

	func get_priority() -> int:
		return 7

	func get_capabilities() -> Dictionary:
		return {
			"kind": "probe",
			"persistent": true,
		}


class FailingWaitPreviewHandler extends MatineePreviewHandler:
	var enter_calls := 0

	func get_supported_action_types() -> Array[StringName]:
		return [&"MatineeWaitAction"]

	func enter_clip(session: MatineePreviewClipSession, _context: MatineePreviewContext) -> void:
		enter_calls += 1
		session.last_preview_error = "Intentional preview handler failure."


func _initialize() -> void:
	_test_title_card_preview_follows_timeline_time()
	_test_preview_ignores_unsupported_actions()
	_test_custom_handler_registration_extends_previewable_actions()
	_test_custom_handler_registration_overrides_existing_handler()
	_test_custom_handler_unregistration_removes_preview_support()
	_test_reset_default_handlers_removes_custom_handlers()
	_test_reset_default_handlers_restores_builtin_title_handler()
	_test_handler_lifecycle_hooks_follow_preview_toggle()
	_test_handler_priority_overrides_registration_order()
	_test_registered_handler_metadata_reports_priority_and_capabilities()
	_test_preview_registry_reports_supported_types()
	_test_clip_identity_and_lifecycle_sessions()
	_test_audio_registry_and_looping_player_reuse()
	_test_sfx_crossing_scrub_and_backward_rearm()
	_test_voice_and_ambience_preview()
	_test_audio_cleanup_and_muted_exclusion()
	_test_preview_diagnostics_and_failure_isolation()
	_test_addon_local_shader_and_grain_label()
	_test_preview_disable_and_clear_lifecycle()
	_test_preview_does_not_modify_resources()
	_test_fade_preview_scrubs_and_persists()
	_test_fade_preview_respects_muted_tracks()
	_test_concurrent_fade_actions_use_timeline_order()
	_test_preview_adapters_can_overlap()
	_test_dialogue_preview_uses_actor_style_and_timing()
	_test_dialogue_preview_uses_fallback_style()
	_test_dialogue_preview_ignores_empty_messages()
	_test_dialogue_preview_does_not_modify_resources()
	_test_chapter_card_preview_matches_runtime_text_and_fade()
	_test_location_card_preview_matches_runtime_text_and_fade()
	_test_intertitle_preview_ignores_empty_primary_text()
	_test_presentation_preview_reconstructs_persistent_preset()
	_test_presentation_preview_replays_mode_events()
	_test_presentation_preview_respects_muted_tracks()
	_test_presentation_preview_reconstructs_after_backward_seek()
	_test_persistent_preview_reads_live_enabled_state()
	_test_scene_fade_preview_evaluates_phases()
	_test_scene_burn_preview_evaluates_phases()
	_test_scene_cut_and_async_preview_are_event_based()
	_test_scene_preview_filters_invalid_and_muted_entries()
	_test_scene_change_resets_presentation_preview()
	_test_scene_without_path_does_not_reset_presentation_preview()

	if _failures.is_empty():
		print("Runtime preview tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_title_card_preview_follows_timeline_time() -> void:
	var fixture := _create_title_fixture()
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)

	playback.seek(0.225)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var states := preview.get_states()
	_expect(states.size() == 1, "An active Title Card should produce one preview state.")
	if states.size() == 1:
		_expect(states[0]["main_text"] == "BLACKRIDGE", "Preview should expose the authored title text.")
		_expect(states[0]["subtitle"] == "A DIRECTOR PREVIEW", "Preview should expose the authored subtitle.")
		_expect(is_equal_approx(float(states[0]["opacity"]), 0.5), "Preview should evaluate fade-in opacity from timeline time.")

	playback.seek(2.5)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	states = preview.get_states()
	_expect(states.size() == 1 and is_equal_approx(float(states[0]["opacity"]), 1.0), "Title Card should be fully visible during its hold interval.")

	playback.seek(4.775)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	states = preview.get_states()
	_expect(states.size() == 1 and is_equal_approx(float(states[0]["opacity"]), 0.5), "Preview should evaluate fade-out opacity before the clip end.")

	playback.seek(5.0)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(preview.get_states().is_empty(), "Title Card preview should clear at the exclusive clip end.")


func _test_preview_ignores_unsupported_actions() -> void:
	var sequence := MatineeSequence.new()
	var track := MatineeTrack.new()
	var clip := MatineeTimelineAction.new()
	clip.action = MatineeWaitAction.new()
	clip.duration = 2.0
	track.actions.append(clip)
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	var playback := MatineePlaybackController.new()
	playback.set_sequence(sequence)
	playback.seek(1.0)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(preview.get_states().is_empty(), "Unsupported actions should not produce a false preview.")


func _test_custom_handler_registration_extends_previewable_actions() -> void:
	var sequence := MatineeSequence.new()
	var track := MatineeTrack.new()
	var clip := MatineeTimelineAction.new()
	clip.action = MatineeWaitAction.new()
	clip.start_time = 0.0
	clip.duration = 2.0
	track.actions.append(clip)
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION

	var playback := MatineePlaybackController.new()
	playback.set_sequence(sequence)
	playback.seek(1.0)

	var preview := MatineePreviewController.new()
	preview.set_sequence(sequence)
	preview.set_enabled(true)

	_expect(not preview.is_action_previewable(MatineeWaitAction.new()), "MatineeWaitAction should be unsupported before custom handler registration.")
	preview.register_handler(WaitPreviewHandler.new())
	_expect(preview.is_action_previewable(MatineeWaitAction.new()), "Custom handler registration should expose MatineeWaitAction as previewable.")

	preview.evaluate(playback.current_time, playback.get_active_entries())
	var state := _find_preview_state(preview.get_states(), &"wait_preview")
	_expect(not state.is_empty(), "Custom registered handlers should contribute preview state during evaluate().")


func _test_custom_handler_registration_overrides_existing_handler() -> void:
	var fixture := _create_title_fixture()
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)

	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	preview.register_handler(TitleCardOverridePreviewHandler.new())
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var state := _find_preview_state(preview.get_states(), &"title_card")
	_expect(str(state.get("main_text", "")) == "OVERRIDDEN", "Later custom handlers should override existing handlers for the same action type.")


func _test_custom_handler_unregistration_removes_preview_support() -> void:
	var sequence := MatineeSequence.new()
	var track := MatineeTrack.new()
	var clip := MatineeTimelineAction.new()
	clip.action = MatineeWaitAction.new()
	clip.start_time = 0.0
	clip.duration = 2.0
	track.actions.append(clip)
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION

	var playback := MatineePlaybackController.new()
	playback.set_sequence(sequence)
	playback.seek(1.0)

	var preview := MatineePreviewController.new()
	preview.set_sequence(sequence)
	preview.set_enabled(true)
	var handler := WaitPreviewHandler.new()
	preview.register_handler(handler)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(not _find_preview_state(preview.get_states(), &"wait_preview").is_empty(), "Registered handlers should contribute preview state before unregistration.")

	_expect(preview.unregister_handler(handler), "Unregister should report success for a registered handler.")
	_expect(not preview.unregister_handler(handler), "Unregister should report false when handler is already removed.")
	_expect(not preview.is_action_previewable(MatineeWaitAction.new()), "Unregistering custom handler should remove its previewable action support.")
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(_find_preview_state(preview.get_states(), &"wait_preview").is_empty(), "Unregistered handlers should stop contributing preview state.")


func _test_reset_default_handlers_removes_custom_handlers() -> void:
	var preview := MatineePreviewController.new()
	preview.register_handler(WaitPreviewHandler.new())
	_expect(preview.is_action_previewable(MatineeWaitAction.new()), "Custom handlers should mark their action types as previewable before reset.")
	preview.reset_default_handlers()
	_expect(not preview.is_action_previewable(MatineeWaitAction.new()), "Resetting to default handlers should remove custom previewable action types.")


func _test_reset_default_handlers_restores_builtin_title_handler() -> void:
	var fixture := _create_title_fixture()
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)

	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	preview.register_handler(TitleCardOverridePreviewHandler.new())
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var overridden := _find_preview_state(preview.get_states(), &"title_card")
	_expect(str(overridden.get("main_text", "")) == "OVERRIDDEN", "Custom title handler should override before reset.")

	preview.reset_default_handlers()
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var restored := _find_preview_state(preview.get_states(), &"title_card")
	_expect(str(restored.get("main_text", "")) == "BLACKRIDGE", "Resetting default handlers should restore built-in TitleCard preview behavior.")


func _test_handler_lifecycle_hooks_follow_preview_toggle() -> void:
	var preview := MatineePreviewController.new()
	var probe := LifecycleProbeHandler.new()
	preview.register_handler(probe)
	_expect(probe.rebuild_calls == 1, "Registering a handler should trigger an initial rebuild callback.")
	preview.set_enabled(true)
	preview.set_enabled(true)
	_expect(probe.enabled_calls == 1, "Handlers should receive one enable callback per enable transition.")
	preview.set_enabled(false)
	preview.set_enabled(false)
	_expect(probe.disabled_calls == 1, "Handlers should receive one disable callback per disable transition.")


func _test_handler_priority_overrides_registration_order() -> void:
	var fixture := _create_title_fixture()
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)

	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	preview.register_handler(HighPriorityTitleCardPreviewHandler.new())
	preview.register_handler(TitleCardOverridePreviewHandler.new())

	preview.evaluate(playback.current_time, playback.get_active_entries())
	var state := _find_preview_state(preview.get_states(), &"title_card")
	_expect(str(state.get("main_text", "")) == "HIGH PRIORITY", "Higher-priority handlers should override later registrations with lower priority.")


func _test_registered_handler_metadata_reports_priority_and_capabilities() -> void:
	var preview := MatineePreviewController.new()
	preview.register_handler(MetadataProbeHandler.new())
	var metadata := preview.get_registered_handler_metadata()
	var found := false
	for entry in metadata:
		var types := entry.get("supported_action_types", []) as Array
		if int(entry.get("priority", 0)) != 7 or not types.has(&"MatineeWaitAction"):
			continue
		var capabilities := entry.get("capabilities", {}) as Dictionary
		found = str(capabilities.get("kind", "")) == "probe" and bool(capabilities.get("persistent", false))
		if found:
			break
	_expect(found, "Registered handler metadata should expose priority, supported action types, and capabilities.")


func _test_preview_registry_reports_supported_types() -> void:
	var preview := MatineePreviewController.new()
	var types := preview.get_previewable_action_types()
	_expect(types.has(&"MatineeTitleCardAction"), "Preview registry should include MatineeTitleCardAction handlers.")
	_expect(types.has(&"MatineeChapterAction"), "Preview registry should include MatineeChapterAction handlers.")
	_expect(types.has(&"MatineeLocationAction"), "Preview registry should include MatineeLocationAction handlers.")
	_expect(types.has(&"MatineeDialogueAction"), "Preview registry should include MatineeDialogueAction handlers.")
	_expect(types.has(&"MatineeFadeAction"), "Preview registry should include MatineeFadeAction handlers.")
	_expect(types.has(&"MatineePresentationAction"), "Preview registry should include MatineePresentationAction handlers.")
	_expect(types.has(&"MatineeSceneAction"), "Preview registry should include MatineeSceneAction handlers.")
	_expect(types.has(&"MatineeMusicAction"), "Preview registry should include MatineeMusicAction handlers.")
	_expect(types.has(&"MatineeAmbienceAction"), "Preview registry should include MatineeAmbienceAction handlers.")
	_expect(types.has(&"MatineeSFXAction"), "Preview registry should include MatineeSFXAction handlers.")
	_expect(types.has(&"MatineeVoiceAction"), "Preview registry should include MatineeVoiceAction handlers.")
	_expect(not preview.is_action_previewable(MatineeWaitAction.new()), "Unsupported action types should remain unpreviewable.")


func _test_clip_identity_and_lifecycle_sessions() -> void:
	var fixture := _create_title_fixture()
	var entry := fixture.get_timeline_entries(false)[0]
	var clip_id := MatineePreviewClipIdentity.from_entry(entry)
	_expect(clip_id == MatineePreviewClipIdentity.from_entry(entry), "Clip identity should be stable across reevaluation.")
	var other_fixture := _create_title_fixture()
	_expect(clip_id != MatineePreviewClipIdentity.from_entry(other_fixture.get_timeline_entries(false)[0]), "Distinct clip resources should have distinct runtime identities.")
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	preview.evaluate(1.0, playback.get_active_entries(), MatineePlaybackController.State.PLAYING)
	var sessions := preview.get_clip_session_snapshots()
	_expect(sessions.size() == 1 and sessions[0]["state"] == MatineePreviewClipSession.State.ENTERED, "An active clip should enter one lifecycle session.")
	preview.evaluate(1.1, playback.get_active_entries(), MatineePlaybackController.State.PLAYING)
	sessions = preview.get_clip_session_snapshots()
	_expect(sessions[0]["state"] == MatineePreviewClipSession.State.ACTIVE, "A retained clip should advance to active lifecycle state.")
	preview.evaluate(5.0, [], MatineePlaybackController.State.PLAYING)
	sessions = preview.get_clip_session_snapshots()
	_expect(sessions[0]["state"] == MatineePreviewClipSession.State.EXITED, "Leaving a clip interval should exit its lifecycle session.")
	preview.clear()
	_expect(preview.get_clip_session_snapshots().is_empty(), "Reset should clear lifecycle session records.")


func _test_audio_registry_and_looping_player_reuse() -> void:
	var music := MatineeMusicAction.new()
	music.track = AudioStreamGenerator.new()
	var fixture := _create_action_fixture(music, 0.0, 8.0)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.prepare(root)
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	playback.seek(0.1)
	preview.evaluate(0.1, playback.get_active_entries(), MatineePlaybackController.State.PLAYING)
	var entry := fixture.get_timeline_entries(false)[0]
	_expect(_audio_play_count(preview, entry) == 1, "Music should create and start one editor-owned player.")
	playback.seek(0.2)
	preview.evaluate(0.2, playback.get_active_entries(), MatineePlaybackController.State.PLAYING)
	_expect(_audio_play_count(preview, entry) == 1, "Music updates should reuse the existing player without restarting.")
	preview.evaluate(0.2, playback.get_active_entries(), MatineePlaybackController.State.PAUSED)
	preview.evaluate(0.2, playback.get_active_entries(), MatineePlaybackController.State.PLAYING)
	_expect(_audio_play_count(preview, entry) == 1, "Pause and resume should not duplicate the music player.")
	preview.cleanup()


func _test_sfx_crossing_scrub_and_backward_rearm() -> void:
	var sfx := MatineeSFXAction.new()
	sfx.stream = AudioStreamGenerator.new()
	var fixture := _create_action_fixture(sfx, 2.0, 0.0)
	var entry := fixture.get_timeline_entries(false)[0]
	var preview := MatineePreviewController.new()
	preview.prepare(root)
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	preview.evaluate(1.0, [], MatineePlaybackController.State.PLAYING)
	preview.evaluate(2.1, [], MatineePlaybackController.State.PLAYING)
	preview.evaluate(2.2, [], MatineePlaybackController.State.PLAYING)
	_expect(_audio_play_count(preview, entry) == 1, "SFX should fire once on a normal forward start crossing.")
	preview.evaluate(1.0, [], MatineePlaybackController.State.PAUSED, true)
	preview.evaluate(2.1, [], MatineePlaybackController.State.PAUSED, true)
	_expect(_audio_play_count(preview, entry) == 1, "SFX should remain silent during scrubbing by default.")
	preview.set_audio_while_scrubbing(true)
	preview.evaluate(1.0, [], MatineePlaybackController.State.PAUSED, true)
	preview.evaluate(2.1, [], MatineePlaybackController.State.PAUSED, true)
	preview.evaluate(2.2, [], MatineePlaybackController.State.PAUSED, true)
	_expect(_audio_play_count(preview, entry) == 2, "Enabled scrub audio should fire once per controlled forward crossing.")
	preview.evaluate(1.0, [], MatineePlaybackController.State.PAUSED, true)
	preview.evaluate(2.1, [], MatineePlaybackController.State.PLAYING)
	_expect(_audio_play_count(preview, entry) == 3, "Backward movement before the event should re-arm SFX playback.")
	preview.cleanup()


func _test_voice_and_ambience_preview() -> void:
	var ambience := MatineeAmbienceAction.new()
	ambience.track = AudioStreamGenerator.new()
	ambience.loop_stream = true
	var voice := MatineeVoiceAction.new()
	voice.stream = AudioStreamGenerator.new()
	voice.wait_for_completion = true
	var sequence := _create_action_fixture(ambience, 0.0, 5.0)
	var voice_clip := MatineeTimelineAction.new()
	voice_clip.action = voice
	voice_clip.start_time = 0.0
	voice_clip.duration = 2.0
	sequence.tracks[0].actions.append(voice_clip)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(sequence)
	playback.seek(0.25)
	var preview := MatineePreviewController.new()
	preview.prepare(root)
	preview.set_sequence(sequence)
	preview.set_enabled(true)
	preview.evaluate(0.25, playback.get_active_entries(), MatineePlaybackController.State.PLAYING)
	_expect(int(preview.get_audio_debug_snapshot()["player_count"]) == 2, "Concurrent Ambience and Voice clips should own separate preview players.")
	preview.cleanup()


func _test_audio_cleanup_and_muted_exclusion() -> void:
	var music := MatineeMusicAction.new()
	music.track = AudioStreamGenerator.new()
	var fixture := _create_action_fixture(music, 0.0, 4.0)
	fixture.tracks[0].muted = true
	var preview := MatineePreviewController.new()
	preview.prepare(root)
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	preview.evaluate(1.0, [], MatineePlaybackController.State.PLAYING)
	_expect(int(preview.get_audio_debug_snapshot()["player_count"]) == 0, "Muted tracks should not create preview audio players.")
	fixture.tracks[0].muted = false
	preview.rebuild(fixture)
	preview.evaluate(1.0, fixture.get_timeline_entries(false), MatineePlaybackController.State.PLAYING)
	_expect(int(preview.get_audio_debug_snapshot()["player_count"]) == 1, "Unmuted audio should be reevaluated after rebuild.")
	preview.cleanup()
	preview.cleanup()
	_expect(int(preview.get_audio_debug_snapshot()["player_count"]) == 0, "Repeated cleanup should be safe and leave no players.")


func _test_preview_diagnostics_and_failure_isolation() -> void:
	var wait_fixture := _create_action_fixture(MatineeWaitAction.new(), 0.0, 2.0)
	var preview := MatineePreviewController.new()
	preview.set_sequence(wait_fixture)
	preview.set_enabled(true)
	preview.evaluate(1.0, wait_fixture.get_timeline_entries(false), MatineePlaybackController.State.PLAYING)
	var diagnostics := preview.get_preview_diagnostics()
	_expect(int(diagnostics.get("unsupported_clips", 0)) == 1, "Unsupported active actions should appear in preview diagnostics.")
	var failing_handler := FailingWaitPreviewHandler.new()
	preview.register_handler(failing_handler)
	preview.rebuild(wait_fixture)
	preview.evaluate(1.0, wait_fixture.get_timeline_entries(false), MatineePlaybackController.State.PLAYING)
	preview.evaluate(1.1, wait_fixture.get_timeline_entries(false), MatineePlaybackController.State.PLAYING)
	var sessions := preview.get_clip_session_snapshots()
	_expect(sessions.size() == 1 and not str(sessions[0]["last_preview_error"]).is_empty(), "A reported handler failure should be isolated to its clip session.")
	_expect(failing_handler.enter_calls == 1, "A failed clip handler should be disabled instead of retried every frame.")
	var music := MatineeMusicAction.new()
	var invalid_fixture := _create_action_fixture(music, 0.0, 2.0)
	preview.reset_default_handlers()
	preview.set_sequence(invalid_fixture)
	preview.evaluate(1.0, invalid_fixture.get_timeline_entries(false), MatineePlaybackController.State.PLAYING)
	diagnostics = preview.get_preview_diagnostics()
	_expect(int(diagnostics.get("invalid_clips", 0)) == 1, "Missing audio streams should be classified as invalid preview data.")


func _test_addon_local_shader_and_grain_label() -> void:
	_expect(ResourceLoader.exists("res://addons/matinee/preview/shaders/film_burn.gdshader"), "Film Burn preview shader should be addon-local.")
	var scene_text := FileAccess.get_file_as_string("res://addons/matinee/director_dock.tscn")
	_expect(not scene_text.contains("res://engine/presentation/film/shaders/film_burn.gdshader"), "Matinee dock should not hard-depend on the project Film Burn shader.")
	var widget_text := FileAccess.get_file_as_string("res://addons/matinee/widgets/runtime_preview.gd")
	_expect(widget_text.count('effects.append("Grain")') == 1, "Presentation diagnostics should append Grain exactly once.")


func _test_preview_disable_and_clear_lifecycle() -> void:
	var fixture := _create_title_fixture()
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(not preview.get_states().is_empty(), "Enabled preview should retain active states.")
	preview.clear()
	_expect(preview.get_states().is_empty(), "Lifecycle clear should remove transient preview state.")
	preview.evaluate(playback.current_time, playback.get_active_entries())
	preview.set_enabled(false)
	_expect(preview.get_states().is_empty(), "Disabling preview should clear transient state.")
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(preview.get_states().is_empty(), "Disabled preview should ignore active playback entries.")


func _test_preview_does_not_modify_resources() -> void:
	var fixture := _create_title_fixture()
	var clip := fixture.tracks[0].actions[0] as MatineeTimelineAction
	var action := clip.action as MatineeTitleCardAction
	var original_start := clip.start_time
	var original_duration := clip.duration
	var original_text := action.main_text
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(2.0)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	preview.clear()
	_expect(is_equal_approx(clip.start_time, original_start), "Preview must not change clip start time.")
	_expect(is_equal_approx(clip.duration, original_duration), "Preview must not change clip duration.")
	_expect(action.main_text == original_text, "Preview must not change action content.")


func _test_fade_preview_scrubs_and_persists() -> void:
	var fixture := _create_fade_fixture()
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	_assert_fade_opacity(preview, playback, 0.5, 0.0, "Fade preview should begin clear before the first fade.")
	_assert_fade_opacity(preview, playback, 2.0, 0.5, "Fade-to-black should be half opaque halfway through its clip.")
	_assert_fade_opacity(preview, playback, 4.0, 1.0, "Fade-to-black should persist after its clip ends.")
	_assert_fade_opacity(preview, playback, 5.0, 1.0, "Fade-from-black should begin fully black.")
	_assert_fade_opacity(preview, playback, 6.0, 0.5, "Fade-from-black should be half opaque halfway through its clip.")
	_assert_fade_opacity(preview, playback, 7.0, 0.0, "Fade-from-black should finish clear at the sequence end.")


func _test_fade_preview_respects_muted_tracks() -> void:
	var fixture := _create_fade_fixture()
	fixture.tracks[0].muted = true
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	_assert_fade_opacity(preview, playback, 4.0, 0.0, "Muted tracks should not contribute persistent fade preview state.")


func _test_concurrent_fade_actions_use_timeline_order() -> void:
	var to_black := MatineeFadeAction.new()
	to_black.direction = MatineeFadeAction.FadeDirection.TO_BLACK
	var to_black_clip := MatineeTimelineAction.new()
	to_black_clip.action = to_black
	to_black_clip.start_time = 0.0
	to_black_clip.duration = 4.0

	var from_black := MatineeFadeAction.new()
	from_black.direction = MatineeFadeAction.FadeDirection.FROM_BLACK
	var from_black_clip := MatineeTimelineAction.new()
	from_black_clip.action = from_black
	from_black_clip.start_time = 1.0
	from_black_clip.duration = 4.0

	var track := MatineeTrack.new()
	track.actions.assign([to_black_clip, from_black_clip])
	var sequence := MatineeSequence.new()
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION

	var playback := MatineePlaybackController.new()
	playback.set_sequence(sequence)
	var preview := MatineePreviewController.new()
	preview.set_sequence(sequence)
	preview.set_enabled(true)

	_assert_fade_opacity(preview, playback, 2.0, 0.75, "Later fade events should deterministically drive overlapping fade opacity.")


func _test_preview_adapters_can_overlap() -> void:
	var fixture := _create_fade_fixture()
	var title := MatineeTitleCardAction.new()
	title.main_text = "OVERLAP"
	var title_clip := MatineeTimelineAction.new()
	title_clip.action = title
	title_clip.start_time = 1.0
	title_clip.duration = 3.0
	var title_track := MatineeTrack.new()
	title_track.track_name = "Titles"
	title_track.actions.append(title_clip)
	fixture.tracks.append(title_track)
	var dialogue_fixture := _create_dialogue_fixture()
	fixture.tracks.append(dialogue_fixture.tracks[0])
	var presentation := MatineePresentationAction.new()
	presentation.preset = MatineePresentationPreset.new()
	var presentation_clip := MatineeTimelineAction.new()
	presentation_clip.action = presentation
	presentation_clip.start_time = 0.0
	presentation_clip.duration = 0.0
	var presentation_track := MatineeTrack.new()
	presentation_track.track_name = "Film"
	presentation_track.actions.append(presentation_clip)
	fixture.tracks.append(presentation_track)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(2.0)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var states := preview.get_states()
	_expect(states.any(func(state: Dictionary) -> bool: return state.get("kind") == &"fade"), "Fade state should coexist with other preview adapters.")
	_expect(states.any(func(state: Dictionary) -> bool: return state.get("kind") == &"title_card"), "Title Card state should coexist with a fade.")
	_expect(states.any(func(state: Dictionary) -> bool: return state.get("kind") == &"dialogue"), "Dialogue state should coexist with visual preview adapters.")
	_expect(states.any(func(state: Dictionary) -> bool: return state.get("kind") == &"presentation"), "Persistent Presentation state should coexist with interval preview adapters.")


func _test_dialogue_preview_uses_actor_style_and_timing() -> void:
	var fixture := _create_dialogue_fixture()
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)

	playback.seek(1.0)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var states := preview.get_states()
	_expect(states.size() == 1, "An active Dialogue clip should produce one preview state.")
	if states.size() == 1:
		_expect(states[0]["kind"] == &"dialogue", "Dialogue preview should expose its renderer-neutral kind.")
		_expect(states[0]["speaker"] == "DEPUTY MERCER", "Dialogue preview should use the actor's formatted name.")
		_expect(states[0]["message"] == "“Morning, Sheriff.”", "Dialogue preview should match runtime quote formatting.")
		_expect(states[0]["name_color"] == Color(0.4, 0.7, 0.9), "Dialogue preview should expose the actor's name color.")
		_expect(states[0]["text_color"] == Color(0.8, 0.7, 0.6), "Dialogue preview should expose the actor's text color.")

	playback.seek(3.0)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(preview.get_states().is_empty(), "Dialogue preview should clear at the exclusive clip end.")


func _test_dialogue_preview_uses_fallback_style() -> void:
	var fixture := _create_dialogue_fixture()
	var action := (fixture.tracks[0].actions[0] as MatineeTimelineAction).action as MatineeDialogueAction
	action.actor = null
	action.fallback_speaker_name = "NARRATOR"
	action.message = "\"Already quoted.\""
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var states := preview.get_states()
	_expect(states.size() == 1 and states[0]["speaker"] == "NARRATOR", "Dialogue preview should use the fallback speaker without an actor.")
	_expect(states.size() == 1 and states[0]["message"] == "\"Already quoted.\"", "Dialogue preview should preserve explicitly quoted text.")
	_expect(states.size() == 1 and states[0]["name_color"] == Color(0.88, 0.86, 0.76), "Dialogue preview should use the runtime fallback name color.")
	_expect(states.size() == 1 and states[0]["text_color"] == Color(0.92, 0.91, 0.84), "Dialogue preview should use the runtime fallback text color.")


func _test_dialogue_preview_ignores_empty_messages() -> void:
	var fixture := _create_dialogue_fixture()
	var action := (fixture.tracks[0].actions[0] as MatineeTimelineAction).action as MatineeDialogueAction
	action.message = "   "
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(preview.get_states().is_empty(), "Empty Dialogue messages should not produce preview state.")


func _test_dialogue_preview_does_not_modify_resources() -> void:
	var fixture := _create_dialogue_fixture()
	var clip := fixture.tracks[0].actions[0] as MatineeTimelineAction
	var action := clip.action as MatineeDialogueAction
	var original_message := action.message
	var original_speaker := action.actor.display_name
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.0)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	preview.clear()
	_expect(action.message == original_message, "Dialogue preview must not change action content.")
	_expect(action.actor.display_name == original_speaker, "Dialogue preview must not change actor content.")


func _test_chapter_card_preview_matches_runtime_text_and_fade() -> void:
	var action := MatineeChapterAction.new()
	action.chapter_number = "Act II"
	action.chapter_title = "A Dark Road"
	action.fade_duration = 0.5
	var fixture := _create_action_fixture(action, 1.0, 4.0)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(1.25)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var states := preview.get_states()
	_expect(states.size() == 1 and states[0]["kind"] == &"chapter_card", "An active Chapter Card should produce chapter preview state.")
	_expect(states.size() == 1 and states[0]["kicker"] == "ACT II", "Chapter preview should uppercase the authored chapter number.")
	_expect(states.size() == 1 and states[0]["main_text"] == "A DARK ROAD", "Chapter preview should uppercase the authored title.")
	_expect(states.size() == 1 and is_equal_approx(float(states[0]["opacity"]), 0.5), "Chapter preview should use clip time for deterministic fade opacity.")


func _test_location_card_preview_matches_runtime_text_and_fade() -> void:
	var action := MatineeLocationAction.new()
	action.location_name = "Holloway Farm"
	action.location_subtitle = "Four miles north of town"
	var fixture := _create_action_fixture(action, 2.0, 3.0)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	playback.seek(2.14)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var states := preview.get_states()
	_expect(states.size() == 1 and states[0]["kind"] == &"location_card", "An active Location Card should produce location preview state.")
	_expect(states.size() == 1 and states[0]["main_text"] == "HOLLOWAY FARM", "Location preview should uppercase the authored name.")
	_expect(states.size() == 1 and states[0]["subtitle"] == "FOUR MILES NORTH OF TOWN", "Location preview should uppercase the authored subtitle.")
	_expect(states.size() == 1 and is_equal_approx(float(states[0]["opacity"]), 0.5), "Location preview should match the runtime's fixed fade duration.")
	playback.seek(5.0)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(preview.get_states().is_empty(), "Location preview should clear at the exclusive clip end.")
	_expect(action.location_name == "Holloway Farm", "Location preview must not modify authored text.")


func _test_intertitle_preview_ignores_empty_primary_text() -> void:
	var chapter := MatineeChapterAction.new()
	chapter.chapter_title = "   "
	var location := MatineeLocationAction.new()
	location.location_name = "   "
	var chapter_fixture := _create_action_fixture(chapter, 0.0, 2.0)
	var location_clip := (_create_action_fixture(location, 0.0, 2.0).tracks[0] as MatineeTrack).actions[0]
	chapter_fixture.tracks[0].actions.append(location_clip)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(chapter_fixture)
	playback.seek(1.0)
	var preview := MatineePreviewController.new()
	preview.set_enabled(true)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(preview.get_states().is_empty(), "Intertitle actions with empty primary text should not produce preview state.")


func _test_presentation_preview_reconstructs_persistent_preset() -> void:
	var preset := MatineePresentationPreset.new()
	preset.preset_name = "Noir Test"
	preset.master_opacity = 0.75
	preset.grain_enabled = true
	preset.grain_strength = 0.08
	preset.flicker_enabled = false
	preset.vignette_enabled = true
	preset.vignette_strength = 0.3
	var action := MatineePresentationAction.new()
	action.preset = preset
	var invalid_apply := MatineePresentationAction.new()
	invalid_apply.preset = null
	var fixture := _create_presentation_fixture([action, invalid_apply])
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	_assert_presentation_state(preview, playback, 0.5, "", "Presentation should be clean before the preset event.")
	_assert_presentation_state(preview, playback, 1.0, "Noir Test", "Presentation preset should apply at its zero-duration event time.")
	_assert_presentation_state(preview, playback, 2.5, "Noir Test", "A null preset event should leave the current presentation state unchanged.")
	preset.grain_strength = 0.1
	_assert_presentation_state(preview, playback, 4.0, "Noir Test", "Presentation preset should persist after its event clip.")
	var states := preview.get_states()
	if states.size() == 1:
		_expect(is_equal_approx(float(states[0]["master_opacity"]), 0.75), "Presentation preview should expose master opacity.")
		_expect(is_equal_approx(float(states[0]["grain_strength"]), 0.1), "Presentation preview should reflect current preset values without mutating them.")
		_expect(is_zero_approx(float(states[0]["flicker_strength"])), "Disabled effects should be zero in preview state.")
		_expect(is_equal_approx(float(states[0]["vignette_strength"]), 0.3), "Presentation preview should expose enabled vignette strength.")
	_expect(preset.preset_name == "Noir Test", "Presentation preview must not modify preset resources.")


func _test_presentation_preview_replays_mode_events() -> void:
	var preset := MatineePresentationPreset.new()
	preset.preset_name = "Active Preset"
	var apply := MatineePresentationAction.new()
	apply.mode = MatineePresentationAction.PresentationMode.APPLY_PRESET
	apply.preset = preset
	var disable := MatineePresentationAction.new()
	disable.mode = MatineePresentationAction.PresentationMode.DISABLE_MOVIE_MODE
	var enable := MatineePresentationAction.new()
	enable.mode = MatineePresentationAction.PresentationMode.ENABLE_MOVIE_MODE
	var restore := MatineePresentationAction.new()
	restore.mode = MatineePresentationAction.PresentationMode.RESTORE_DEFAULT
	var fixture := _create_presentation_fixture([apply, disable, enable, restore])
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	_assert_presentation_state(preview, playback, 1.5, "Active Preset", "Apply should activate the authored preset.")
	_assert_presentation_state(preview, playback, 2.5, "", "Disable should reset presentation preview to clean state.")
	_assert_presentation_state(preview, playback, 3.5, "Movie Mode", "Enable should show clean movie mode without inventing a preset.")
	_assert_presentation_state(preview, playback, 4.5, "", "Restore should return presentation preview to clean state.")


func _test_presentation_preview_respects_muted_tracks() -> void:
	var action := MatineePresentationAction.new()
	action.preset = MatineePresentationPreset.new()
	var fixture := _create_action_fixture(action, 0.0, 0.0)
	fixture.tracks[0].muted = true
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	_assert_presentation_state(preview, playback, 1.0, "", "Muted tracks should not contribute persistent presentation state.")


func _test_presentation_preview_reconstructs_after_backward_seek() -> void:
	var preset := MatineePresentationPreset.new()
	preset.preset_name = "Seek Preset"
	var apply := MatineePresentationAction.new()
	apply.mode = MatineePresentationAction.PresentationMode.APPLY_PRESET
	apply.preset = preset
	var restore := MatineePresentationAction.new()
	restore.mode = MatineePresentationAction.PresentationMode.RESTORE_DEFAULT
	var fixture := _create_presentation_fixture([apply, restore])
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	_assert_presentation_state(preview, playback, 4.5, "", "Presentation should be clean after restore events.")
	_assert_presentation_state(preview, playback, 1.5, "Seek Preset", "Backward seeks should reconstruct presentation state from timeline events.")


func _test_persistent_preview_reads_live_enabled_state() -> void:
	var fade := MatineeFadeAction.new()
	var fade_fixture := _create_action_fixture(fade, 0.0, 2.0)
	var fade_playback := MatineePlaybackController.new()
	fade_playback.set_sequence(fade_fixture)
	var fade_preview := MatineePreviewController.new()
	fade_preview.set_sequence(fade_fixture)
	fade_preview.set_enabled(true)
	_assert_fade_opacity(fade_preview, fade_playback, 1.0, 0.5, "Enabled Fade actions should contribute cached preview state.")
	fade.enabled = false
	_assert_fade_opacity(fade_preview, fade_playback, 1.0, 0.0, "Disabling a cached Fade action should take effect without a rebuild.")
	fade.enabled = true
	_assert_fade_opacity(fade_preview, fade_playback, 1.0, 0.5, "Re-enabling a cached Fade action should take effect without a rebuild.")

	var presentation := MatineePresentationAction.new()
	presentation.preset = MatineePresentationPreset.new()
	presentation.preset.preset_name = "Live Preset"
	var presentation_fixture := _create_action_fixture(presentation, 0.0, 0.0)
	var presentation_playback := MatineePlaybackController.new()
	presentation_playback.set_sequence(presentation_fixture)
	var presentation_preview := MatineePreviewController.new()
	presentation_preview.set_sequence(presentation_fixture)
	presentation_preview.set_enabled(true)
	_assert_presentation_state(presentation_preview, presentation_playback, 1.0, "Live Preset", "Enabled Presentation actions should contribute cached preview state.")
	presentation.enabled = false
	_assert_presentation_state(presentation_preview, presentation_playback, 1.0, "", "Disabling a cached Presentation action should take effect without a rebuild.")
	presentation.enabled = true
	_assert_presentation_state(presentation_preview, presentation_playback, 1.0, "Live Preset", "Re-enabling a cached Presentation action should take effect without a rebuild.")

	var scene := MatineeSceneAction.new()
	scene.scene_path = "res://tests/fixtures/preview_scene.tscn"
	scene.fade_out_duration = 1.0
	scene.black_hold_duration = 0.5
	scene.fade_in_duration = 1.0
	scene.delay_after_change = 0.5
	var scene_fixture := _create_action_fixture(scene, 0.0, 3.0)
	var scene_playback := MatineePlaybackController.new()
	scene_playback.set_sequence(scene_fixture)
	var scene_preview := MatineePreviewController.new()
	scene_preview.set_sequence(scene_fixture)
	scene_preview.set_enabled(true)
	_assert_scene_state(scene_preview, scene_playback, 0.5, &"fade_out", 0.5, "Enabled Scene actions should contribute cached preview state.")
	scene.enabled = false
	_assert_scene_state(scene_preview, scene_playback, 0.5, &"", 0.0, "Disabling a cached Scene action should take effect without a rebuild.")
	scene.enabled = true
	_assert_scene_state(scene_preview, scene_playback, 0.5, &"fade_out", 0.5, "Re-enabling a cached Scene action should take effect without a rebuild.")


func _test_scene_fade_preview_evaluates_phases() -> void:
	var action := MatineeSceneAction.new()
	action.scene_path = "res://tests/fixtures/preview_scene.tscn"
	action.transition = MatineeSceneAction.SceneTransition.FADE
	action.fade_out_duration = 1.0
	action.black_hold_duration = 0.5
	action.fade_in_duration = 1.0
	action.delay_after_change = 0.5
	var fixture := _create_action_fixture(action, 1.0, 3.0)
	var clip := fixture.tracks[0].actions[0] as MatineeTimelineAction
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	_assert_scene_state(preview, playback, 1.5, &"fade_out", 0.5, "Fade transition should interpolate its fade-out phase.")
	_assert_scene_state(preview, playback, 2.25, &"hold_after_change", 1.0, "Fade transition should remain black during its hold.")
	_assert_scene_state(preview, playback, 3.0, &"fade_in", 0.5, "Fade transition should interpolate its fade-in phase.")
	_assert_scene_state(preview, playback, 3.75, &"complete", 0.0, "Post-change delay should remain visible as a completed transition state.")
	_assert_scene_state(preview, playback, 4.0, &"", 0.0, "Scene transition preview should clear at the exclusive clip end.")
	_expect(is_equal_approx(clip.start_time, 1.0), "Scene preview must not modify clip timing.")
	_expect(action.scene_path == "res://tests/fixtures/preview_scene.tscn", "Scene preview must not modify the destination path.")


func _test_scene_burn_preview_evaluates_phases() -> void:
	var action := MatineeSceneAction.new()
	action.scene_path = "res://tests/fixtures/preview_scene.tscn"
	action.transition = MatineeSceneAction.SceneTransition.FILM_BURN
	action.burn_out_duration = 1.0
	action.black_hold_duration = 0.5
	action.burn_in_duration = 1.0
	action.burn_origin = Vector2(1.2, -0.1)
	var fixture := _create_action_fixture(action, 0.0, 3.0)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	_assert_scene_state(preview, playback, 0.5, &"burn_out", 0.5, "Film Burn should interpolate its burn-out phase.")
	_assert_scene_state(preview, playback, 1.25, &"hold_before_change", 1.0, "Film Burn should expose the pre-change black hold.")
	_assert_scene_state(preview, playback, 1.75, &"hold_after_change", 1.0, "Film Burn should expose the post-change black hold.")
	_assert_scene_state(preview, playback, 2.5, &"burn_in", 0.5, "Film Burn should interpolate its burn-in phase.")
	var state := _find_preview_state(preview.get_states(), &"scene_transition")
	_expect(state.get("burn_origin") == Vector2(0.35, 0.55), "Partially negative burn origins should use the runtime default.")


func _test_scene_cut_and_async_preview_are_event_based() -> void:
	var cut := MatineeSceneAction.new()
	cut.scene_path = "res://tests/fixtures/preview_scene.tscn"
	cut.transition = MatineeSceneAction.SceneTransition.CUT
	cut.delay_after_change = 1.0
	var cut_fixture := _create_action_fixture(cut, 1.0, 1.0)
	var cut_playback := MatineePlaybackController.new()
	cut_playback.set_sequence(cut_fixture)
	var cut_preview := MatineePreviewController.new()
	cut_preview.set_sequence(cut_fixture)
	cut_preview.set_enabled(true)
	_assert_scene_state(cut_preview, cut_playback, 1.0, &"cut", 0.0, "Cut should appear as an exact timeline event.")
	_assert_scene_state(cut_preview, cut_playback, 1.5, &"complete", 0.0, "Cut delay should not invent a visual transition.")

	var async_fade := MatineeSceneAction.new()
	async_fade.scene_path = "res://tests/fixtures/preview_scene.tscn"
	async_fade.wait_for_transition = false
	async_fade.delay_after_change = 2.0
	var async_fixture := _create_action_fixture(async_fade, 1.0, 2.0)
	var async_playback := MatineePlaybackController.new()
	async_playback.set_sequence(async_fixture)
	var async_preview := MatineePreviewController.new()
	async_preview.set_sequence(async_fixture)
	async_preview.set_enabled(true)
	_assert_scene_state(async_preview, async_playback, 1.0, &"trigger", 0.0, "Non-waiting transitions should expose their trigger event.")
	_assert_scene_state(async_preview, async_playback, 1.5, &"async", 0.0, "Non-waiting transitions should not invent interval animation.")


func _test_scene_preview_filters_invalid_and_muted_entries() -> void:
	var empty := MatineeSceneAction.new()
	empty.scene_path = "   "
	var empty_fixture := _create_action_fixture(empty, 0.0, 2.0)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(empty_fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(empty_fixture)
	preview.set_enabled(true)
	_assert_scene_state(preview, playback, 1.0, &"", 0.0, "Scene actions with empty paths should not produce preview state.")

	var valid := MatineeSceneAction.new()
	valid.scene_path = "res://tests/fixtures/preview_scene.tscn"
	var muted_fixture := _create_action_fixture(valid, 0.0, 2.0)
	muted_fixture.tracks[0].muted = true
	playback.set_sequence(muted_fixture)
	preview.set_sequence(muted_fixture)
	_assert_scene_state(preview, playback, 1.0, &"", 0.0, "Muted tracks should not contribute Scene transition preview.")


func _test_scene_change_resets_presentation_preview() -> void:
	var preset_action := MatineePresentationAction.new()
	preset_action.preset = MatineePresentationPreset.new()
	var fixture := _create_action_fixture(preset_action, 0.0, 0.0)
	var scene := MatineeSceneAction.new()
	scene.scene_path = "res://tests/fixtures/preview_scene.tscn"
	var scene_clip := MatineeTimelineAction.new()
	scene_clip.action = scene
	scene_clip.start_time = 2.0
	scene_clip.duration = 2.0
	fixture.tracks[0].actions.append(scene_clip)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)
	playback.seek(1.0)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(not _find_preview_state(preview.get_states(), &"presentation").is_empty(), "Presentation should be active before the Scene event.")
	playback.seek(2.0)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	_expect(_find_preview_state(preview.get_states(), &"presentation").is_empty(), "Scene changes should reset reconstructed Presentation state.")


func _test_scene_without_path_does_not_reset_presentation_preview() -> void:
	var preset := MatineePresentationPreset.new()
	preset.preset_name = "Persistent"
	var presentation_action := MatineePresentationAction.new()
	presentation_action.preset = preset
	var fixture := _create_action_fixture(presentation_action, 0.0, 0.0)
	var scene := MatineeSceneAction.new()
	scene.scene_path = "   "
	var scene_clip := MatineeTimelineAction.new()
	scene_clip.action = scene
	scene_clip.start_time = 2.0
	scene_clip.duration = 1.0
	fixture.tracks[0].actions.append(scene_clip)
	var playback := MatineePlaybackController.new()
	playback.set_sequence(fixture)
	var preview := MatineePreviewController.new()
	preview.set_sequence(fixture)
	preview.set_enabled(true)

	_assert_presentation_state(preview, playback, 1.0, "Persistent", "Presentation should activate before an empty scene-path event.")
	_assert_presentation_state(preview, playback, 2.5, "Persistent", "Scene events without a destination path should not clear presentation state.")


func _assert_presentation_state(
	preview: MatineePreviewController,
	playback: MatineePlaybackController,
	time: float,
	expected_name: String,
	message: String
) -> void:
	playback.seek(time)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var actual_name := ""
	for state in preview.get_states():
		if state.get("kind") == &"presentation":
			actual_name = str(state.get("preset_name", ""))
			break
	_expect(actual_name == expected_name, message)


func _assert_scene_state(
	preview: MatineePreviewController,
	playback: MatineePlaybackController,
	time: float,
	expected_phase: StringName,
	expected_progress: float,
	message: String
) -> void:
	playback.seek(time)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var state := _find_preview_state(preview.get_states(), &"scene_transition")
	var actual_phase: StringName = state.get("phase", &"")
	var actual_progress := float(state.get("progress", 0.0))
	_expect(
		actual_phase == expected_phase and is_equal_approx(actual_progress, expected_progress),
		message
	)


func _find_preview_state(
	states: Array[Dictionary],
	kind: StringName
) -> Dictionary:
	for state in states:
		if state.get("kind") == kind:
			return state
	return {}


func _assert_fade_opacity(preview: MatineePreviewController, playback: MatineePlaybackController, time: float, expected: float, message: String) -> void:
	playback.seek(time)
	preview.evaluate(playback.current_time, playback.get_active_entries())
	var opacity := 0.0
	for state in preview.get_states():
		if state.get("kind") == &"fade":
			opacity = float(state.get("opacity", 0.0))
			break
	_expect(is_equal_approx(opacity, expected), message)


func _create_title_fixture() -> MatineeSequence:
	var action := MatineeTitleCardAction.new()
	action.main_text = "BLACKRIDGE"
	action.subtitle = "A DIRECTOR PREVIEW"
	action.fade_duration = 0.45
	var clip := MatineeTimelineAction.new()
	clip.action = action
	clip.start_time = 0.0
	clip.duration = 5.0
	var track := MatineeTrack.new()
	track.track_name = "Presentation"
	track.track_type = MatineeTrack.TrackType.VISUAL
	track.actions.append(clip)
	var sequence := MatineeSequence.new()
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	return sequence


func _create_fade_fixture() -> MatineeSequence:
	var to_black := MatineeFadeAction.new()
	to_black.direction = MatineeFadeAction.FadeDirection.TO_BLACK
	var to_black_clip := MatineeTimelineAction.new()
	to_black_clip.action = to_black
	to_black_clip.start_time = 1.0
	to_black_clip.duration = 2.0

	var from_black := MatineeFadeAction.new()
	from_black.direction = MatineeFadeAction.FadeDirection.FROM_BLACK
	var from_black_clip := MatineeTimelineAction.new()
	from_black_clip.action = from_black
	from_black_clip.start_time = 5.0
	from_black_clip.duration = 2.0

	var track := MatineeTrack.new()
	track.track_name = "FX"
	track.track_type = MatineeTrack.TrackType.VISUAL
	track.actions.assign([to_black_clip, from_black_clip])
	var sequence := MatineeSequence.new()
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	return sequence


func _create_dialogue_fixture() -> MatineeSequence:
	var actor := MatineeActorDefinition.new()
	actor.display_name = "Deputy Mercer"
	actor.uppercase_name = true
	actor.name_color = Color(0.4, 0.7, 0.9)
	actor.text_color = Color(0.8, 0.7, 0.6)
	var action := MatineeDialogueAction.new()
	action.actor = actor
	action.message = "Morning, Sheriff."
	var clip := MatineeTimelineAction.new()
	clip.action = action
	clip.start_time = 0.5
	clip.duration = 2.5
	var track := MatineeTrack.new()
	track.track_name = "Dialogue"
	track.actions.append(clip)
	var sequence := MatineeSequence.new()
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	return sequence


func _create_action_fixture(
	action: MatineeAction,
	start_time: float,
	duration: float
) -> MatineeSequence:
	var clip := MatineeTimelineAction.new()
	clip.action = action
	clip.start_time = start_time
	clip.duration = duration
	var track := MatineeTrack.new()
	track.track_name = "Presentation"
	track.track_type = MatineeTrack.TrackType.VISUAL
	track.actions.append(clip)
	var sequence := MatineeSequence.new()
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	return sequence


func _create_presentation_fixture(
	actions: Array[MatineePresentationAction]
) -> MatineeSequence:
	var track := MatineeTrack.new()
	track.track_name = "Presentation"
	track.track_type = MatineeTrack.TrackType.VISUAL
	for index in range(actions.size()):
		var clip := MatineeTimelineAction.new()
		clip.action = actions[index]
		clip.start_time = float(index + 1)
		clip.duration = 0.0
		track.actions.append(clip)
	var duration_clip := MatineeTimelineAction.new()
	duration_clip.action = MatineeWaitAction.new()
	duration_clip.start_time = 0.0
	duration_clip.duration = 6.0
	track.actions.append(duration_clip)
	var sequence := MatineeSequence.new()
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION
	return sequence


func _audio_play_count(preview: MatineePreviewController, entry: Dictionary) -> int:
	var counts := preview.get_audio_debug_snapshot().get("play_counts", {}) as Dictionary
	return int(counts.get(MatineePreviewClipIdentity.from_entry(entry), 0))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
