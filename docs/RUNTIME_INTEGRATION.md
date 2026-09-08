# Runtime integration

The addon works immediately for authoring and editor preview. It does not bundle a game controller, dialogue UI, save system, inventory, objectives, or a runtime sequence scheduler.

For runtime playback, a host controller reads `sequence.get_timeline_entries(false)`, schedules clips using their explicit timing, and invokes `await action.play(controller)`. The host owns cancellation, scene lifetime, concurrency, and cleanup. Merely looping through this array sequentially will not reproduce overlapping tracks.

`MatineeAction.play(controller)` is the extension boundary. Custom actions extend `MatineeAction`, implement `play()`, `get_duration_seconds()`, and optionally validation and editor labels. Custom resources can be assigned to a clip through the Inspector; the Add menu contains built-in types.

Built-in actions retain their explicit controller interfaces. For example, Wait requires `wait(seconds)`, Title Card requires `show_title_card(text, hold, subtitle, fade)`, and Camera requires `play_camera_action(action)`. The camera runtime helpers under `core/camera/` implement camera resolution, interpolation, priority, and restoration for integration into that controller. Presentation, fade, film burn, and scene changes likewise require the methods called by their action scripts; they are not a universal renderer.

Audio actions expose `runtime_service_path`, resolved relative to the SceneTree root, such as `MyAudioService`. No particular autoload name is required. The assigned node must implement the methods used by that action: Play Music uses `play_track_by_id`, while SFX uses `play_stream`, `play_ui`, or `play_world` and optionally `is_playing`/`sound_finished`. Inspect the selected action's `play()` method for its complete interface. An unassigned service warns and returns. This setting is ignored by editor audio preview.

Dialogue resolves its configured UI path in the current scene. That UI supplies `is_open`, `show_actor_message`, `force_close_dialogue`, and `dialogue_closed`. Actor styling is optional.

Scene Change optionally calls `stage_destination_spawn(id)` on the controller for destination markers and `show_loading_card()` / `hide_loading_card()` for loading presentation. Matinee does not write to a global game manager.

The old game-specific action types are intentionally absent. Implement project-specific actions in the host project rather than adding gameplay dependencies to Matinee.
