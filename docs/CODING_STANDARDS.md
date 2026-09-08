# Coding Standards

## Scope

These standards apply to the Matinee Godot plugin, especially editor-facing `@tool` GDScript.

## General Style

- Prefer small, focused classes with one clear responsibility.
- Use descriptive names over clever abbreviations.
- Keep control flow easy to scan.
- Favor guard clauses over deeply nested blocks.
- Add comments for intent, constraints, or non-obvious Godot behavior—not for obvious syntax.
- Preserve the existing local style unless a deliberate cleanup is part of the task.

## Script Size

A typical script should stay near 200–400 lines. A file approaching 600 lines should be reviewed for separable responsibilities.

Do not split files solely to satisfy a line count. Split when a coherent responsibility can move behind a clear interface.

## Naming

Use the `Matinee` prefix for all global addon classes.

Examples:

- `MatineeTimeline`
- `MatineeTimelineCanvas`
- `MatineePlaybackController`
- `MatineeSelectionState`
- `MatineeSequenceEditor`

Use Godot conventions for members and methods:

```gdscript
var current_time: float
var selected_action_index: int

func seek_to_time(time_seconds: float) -> void:
    pass
```

Signals should describe an event that already occurred or an intent emitted by a widget:

```gdscript
signal selection_changed(action_index: int)
signal play_requested
signal seek_requested(time_seconds: float)
```

## Type Safety

Use typed GDScript where practical:

- Type parameters and return values.
- Type important members.
- Use explicit casts only when necessary.
- Avoid broad `Variant` usage when a stable type is known.

Editor code frequently encounters missing or temporarily invalid nodes/resources, so type safety must be paired with defensive checks.

## `@tool` Safety

Editor scripts must tolerate partial lifecycle states.

Before using editor nodes or resources:

- Check `is_instance_valid()` where appropriate.
- Guard optional references.
- Avoid assuming `_ready()` has completed for every collaborator.
- Avoid persistent side effects during scene import or editor startup.
- Disconnect signals when replacing observed objects if duplicate connections are possible.
- Do not continuously process when idle unless required.

## Signals and Coupling

Prefer signal-driven coordination over direct widget-to-widget calls.

Good:

```text
Timeline emits selection intent
SelectionState updates
Inspector observes selection change
```

Avoid making the timeline aware of inspector implementation details or the inspector aware of canvas drawing details.

## Resource Editing

UI widgets must not directly modify `MatineeSequence` or action resources.

All persistent edits must pass through `MatineeSequenceEditor` so that:

- Undo/redo is consistently applied.
- Refresh signals are centralized.
- Validation and cache invalidation can be added in one place.
- Editing rules remain consistent across tree, inspector, and timeline.

### Canonical Sequence Format

- Author and evaluate `MatineeSequence.tracks` and `MatineeTimelineAction` wrappers only.
- Use `MatineeSequence.CURRENT_TRACK_MODEL_VERSION`; do not duplicate numeric version literals.
- Do not read or mutate deprecated `MatineeSequence.actions` outside the migration helper and focused migration tests.
- Never migrate resources implicitly from loading, editor commands, validation, playback, preview, or gameplay runtime.
- Reject unsupported legacy-only and dual-populated resources with a clear migration-tool instruction.
- Preserve original `MatineeAction` identity and action-specific properties during format migrations.

## Undo/Redo

Every persistent editing operation must support Godot `UndoRedo`.

An edit should define:

- A clear action name.
- Do methods/properties.
- Undo methods/properties.
- Any required selection restoration.
- Any required redraw, validation, or playback-cache refresh.

Playback, hover, temporary drag previews, and scrolling are transient UI state and do not belong in undo history.

## Preview Audio

- Audio preview nodes are editor-owned and must never reuse runtime managers or
  permanently modify the project audio-bus layout.
- Key stateful preview work by runtime-only clip identity, never array order
  alone and never by serializing instance IDs.
- One-shot audio requires an explicit time-crossing policy and re-arm rule.
- All owned players, callbacks, session records, diagnostics, and UI state must
  share an idempotent cleanup path.
- Missing streams and unsupported handlers are preview warnings; they do not
  invalidate otherwise valid sequence timing.

## Playback

Playback is read-only simulation.

The playback controller may:

- Advance time.
- Seek.
- Calculate active actions.
- Emit state changes.
- Request UI synchronization.

It must not:

- Reorder actions.
- Change durations.
- Modify sequence properties.
- Commit preview state to resources.

## Runtime Integration

Runtime controllers belong to the host project. Keep all host dependencies explicit through action interfaces or configured service paths. Never add compile-time references to host singletons.

## Rendering

Keep `_draw()` deterministic and side-effect free.

- Do not edit resources from `_draw()`.
- Avoid unnecessary allocations in frequent draw paths.
- Cache layout calculations when they are expensive and stable.
- Queue redraws only when visual state changes.
- Keep hit-testing geometry consistent with rendered geometry.

## Input Handling

- Respect focused text fields and controls before applying global shortcuts.
- Consume input only when the timeline or dock actually handles it.
- Keep mouse gestures consistent with `docs/UX_GUIDELINES.md`.
- Clamp zoom, pan, and seek values to valid ranges.
- Distinguish click, drag, and pan thresholds to prevent accidental edits.

## Error Handling

Prefer graceful no-op behavior for temporary editor states and explicit errors for invalid persistent data.

Use warnings or validation UI when users can correct the condition. Avoid flooding the output panel during normal editor interaction.

## Commit Discipline

Keep commits focused and working where possible. Separate broad refactors from behavior changes unless they cannot be safely divided.

Recommended commit prefixes:

- `feat:` new behavior
- `fix:` bug fix
- `refactor:` structural change without intended behavior change
- `docs:` documentation
- `test:` test or validation coverage
- `chore:` maintenance

## Runtime Camera Rules

- Keep Camera Action resources free of direct Node references and editor types.
- Resolve Camera2D and follow NodePaths against the current runtime scene.
- Keep per-clip state in `MatineeCameraRuntimeSession`; never serialize runtime state.
- Use deterministic local clip time for interpolation and seeking.
- Route all camera writes through `MatineeCameraRuntimeService` so overlapping clips
  cannot fight for control.
- Make cleanup and restoration idempotent, including cancellation and scene exit.
- Never use the main editor viewport for Camera Action preview.

## Before Finishing a Change

- Review signal connections.
- Verify undo and redo.
- Verify selection synchronization.
- Verify playback still behaves as read-only.
- Test empty, short, and long sequences.
- Check the Godot output for parser errors and repeated warnings.
- Update documentation when architecture, behavior, or shortcuts change.
