# Matinee

Native multi-track cinematic authoring for Godot 4.7+.

Copy this entire folder to `addons/matinee/` and enable **Matinee** in Project Settings > Plugins. Create and select a `MatineeSequence` resource, add tracks and actions, and enable Runtime Preview for supported visual and audio clips.

All dependencies are included in this folder. No autoloads or game assets are needed for authoring or preview. Resource classes use the `Matinee` prefix.

Runtime action execution requires a host playback controller. The editor transport is a read-only timeline simulation; it does not call action `play()` methods. Optional audio services are configured through each action's `runtime_service_path`; no fixed singleton name is required. See the source repository's runtime integration guide for details.

Licensed under MIT; see LICENSE.
