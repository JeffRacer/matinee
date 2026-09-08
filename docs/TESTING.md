# Testing

Run `python tools/package.py --test --godot <Godot executable>` to build the ZIP and test its actual contents in a temporary clean project without autoloads or game assets. Godot processes have bounded timeouts, and script/resource errors fail the command even if Godot exits with code zero.

Automated coverage includes all addon scripts, all registered action types, canonical timeline duration, serialization, preview handlers and cleanup, and explicit legacy timing migration.

Before a release, also check interactively:

- Enable/disable the plugin and reload the project.
- Create empty and populated sequences; save and reopen them.
- Add, move, duplicate, and delete clips and tracks; undo and redo each edit.
- Confirm selection remains synchronized across timeline, tree, and Inspector.
- Play, pause, seek, zoom, and pan; check shortcuts while typing in fields.
- Preview visual and audio actions, then stop or change the selected sequence.
- Check camera diagnostics, editor scaling, and the Output panel.

Headless checks do not certify pointer interaction, visual layout, or host runtime behavior.
