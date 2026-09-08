# Architecture

`addons/matinee/plugin.gd` owns the editor dock and its lifecycle. The dock coordinates the toolbar, timeline, action tree, inspector, summary, and preview.

- `core/timeline/`: `MatineeSequence` contains `MatineeTrack` resources whose `MatineeTimelineAction` clips reference `MatineeAction` resources and explicit timing.
- `services/`: `MatineeSequenceEditor` commits persistent changes through Godot undo/redo.
- `models/`: `MatineeSelectionState` synchronizes tree, timeline, and inspector selection.
- `playback/`: read-only transport and active-clip evaluation.
- `preview/` and `widgets/`: editor-owned visual/audio preview; no action `play()` calls or host services.
- `core/actions/`: cinematic resources and optional host-runtime integration methods.
- `core/camera/`: Camera2D runtime services and per-session restoration.
- `resources/`: actor styling and presentation presets, with no game assets.
- `migration/`: explicit conversion of legacy flat timing to canonical tracks.

Track model version 1 is canonical. Unsupported legacy or dual-populated sequences are never migrated implicitly. Use `MatineeSequence.CURRENT_TRACK_MODEL_VERSION` for version checks.

All addon resource paths must stay under `res://addons/matinee/`. All global classes use the `Matinee` prefix to avoid collisions with common host-project names.

Playback, dragging previews, hover, and audio sessions are transient. Preview cleanup must be idempotent across stop, sequence replacement, dock closure, and plugin shutdown. Host runtime controllers are separate from editor playback.
