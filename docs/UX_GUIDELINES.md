# UX guidelines

Matinee should provide predictable, discoverable timeline authoring inside Godot.

- Keep selection synchronized across the tree, timeline, and Inspector.
- Respect the editor theme and scaling. Use readable labels and tooltips.
- Distinguish selection, hover, playback, and invalid-resource states through more than color.
- Keep the ruler, track rows, clip rendering, and hit testing on the same layout model.
- Empty states explain how to create or select a sequence and add tracks/actions.
- Respect text and numeric field focus; only consume shortcuts the dock handles.
- Clamp seek, pan, zoom, and clip timing. Keep cursor-centered zoom stable.
- Use a drag threshold, transient ghost, and one undoable edit on drop. Escape cancels without committing.
- Manual navigation suspends playback auto-follow until playback resumes.
- Track locks prevent edits; mute affects playback; visibility affects editor rendering.
- Never silently migrate unsupported resources. Show migration guidance and preserve their data.
- Preview is opt-in, read-only, and editor-owned. Stop and sequence changes clean up audio and visuals.
- Audio while scrubbing defaults off. One-shots use forward start crossings and re-arm after backward seeks.
- Camera preview displays diagnostics without changing the editor viewport.

## Navigation

| Input | Behavior |
| --- | --- |
| Ctrl + wheel | Zoom around cursor |
| Middle drag | Pan |
| Left click/drag ruler | Seek/scrub |
| Left click clip or track | Select |
| Drag clip | Move with preview |
| Space | Play/pause |
| Escape | Cancel gesture or stop |
| Home / End | Seek to start/end |

Keep toolbar controls and keyboard behavior consistent. Verify focus, pointer behavior, and layout interactively before release.
