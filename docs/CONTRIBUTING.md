# Contributing

Open `project.godot` in Godot 4.7+. Keep changes focused on the addon and add relevant regression coverage. All shipped dependencies must live inside `addons/matinee/`; never introduce a required project autoload or game asset.

Read `ARCHITECTURE.md`, `CODING_STANDARDS.md`, and `UX_GUIDELINES.md`. Preserve undo/redo, shared selection, read-only playback, and editor-owned preview cleanup. Global classes use the `Matinee` prefix.

Run `python tools/package.py --test --godot <executable>` before submitting. Include the Godot version, tests performed, and any manual checks still needed. Contributions are under the MIT license.
