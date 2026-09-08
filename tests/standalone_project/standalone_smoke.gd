extends SceneTree


class SpawnProbe extends Node:
	var marker: StringName

	func stage_destination_spawn(value: StringName) -> void:
		marker = value


func _initialize() -> void:
	if not _load_scripts("res://addons/matinee"):
		return
	var example := load("res://examples/welcome.tres") as MatineeSequence
	if example == null or not is_equal_approx(example.get_duration_seconds(), 3.0):
		_fail("Welcome example is not a valid three-second sequence.")
		return
	var service := Node.new()
	service.name = "CustomHostService"
	root.add_child(service)
	var service_action := MatineeAction.new()
	if service_action._get_runtime_service() != null:
		_fail("An unconfigured action should not resolve a host singleton.")
		return
	service_action.runtime_service_path = NodePath("CustomHostService")
	if service_action._get_runtime_service() != service:
		_fail("The configured host service path did not resolve.")
		return
	service.free()
	var spawn_probe := SpawnProbe.new()
	var scene_action := MatineeSceneAction.new()
	scene_action.destination_spawn_id = &"entrance"
	if not scene_action._stage_destination_spawn(spawn_probe) or spawn_probe.marker != &"entrance":
		_fail("Scene Change did not delegate its marker to the host controller.")
		return
	spawn_probe.free()
	var factory_script := load(
		"res://addons/matinee/action_factory.gd"
	) as Script
	if factory_script == null:
		_fail("Could not load MatineeActionFactory.")
		return

	for entry: Dictionary in factory_script.call("get_types"):
		var action_id := entry.get("id", &"") as StringName
		var action := factory_script.call("create", action_id) as MatineeAction
		if action == null:
			_fail("Could not instantiate action type: %s" % action_id)
			return

	var camera_action := factory_script.call("create", &"camera") as MatineeCameraAction
	if camera_action == null or not camera_action.restore_previous_camera:
		_fail("Camera Action defaults are unavailable in the standalone package.")
		return
	var camera_service := MatineeCameraRuntimeService.new()
	if camera_service == null:
		_fail("Camera runtime service is unavailable in the standalone package.")
		return

	var sequence := MatineeSequence.new()
	var track := MatineeTrack.new()
	var clip := MatineeTimelineAction.new()
	clip.action = factory_script.call("create", &"wait") as MatineeAction
	clip.duration = 1.0
	track.actions.append(clip)
	sequence.tracks.append(track)
	sequence.track_model_version = MatineeSequence.CURRENT_TRACK_MODEL_VERSION

	if not is_equal_approx(sequence.get_duration_seconds(), 1.0):
		_fail("Timeline resource smoke test returned the wrong duration.")
		return

	var save_path := "user://matinee_smoke.tres"
	if ResourceSaver.save(sequence, save_path) != OK:
		_fail("Could not save a standalone sequence.")
		return
	var restored := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MatineeSequence
	if restored == null or not is_equal_approx(restored.get_duration_seconds(), 1.0):
		_fail("Standalone sequence did not survive save/reload.")
		return
	print("Matinee standalone package smoke test passed.")
	quit(0)


func _load_scripts(folder: String) -> bool:
	for filename in DirAccess.get_files_at(folder):
		if filename.ends_with(".gd"):
			var script := load(folder.path_join(filename)) as Script
			if script == null or not script.can_instantiate():
				_fail("Addon script cannot load: " + folder.path_join(filename))
				return false
	for directory in DirAccess.get_directories_at(folder):
		if not _load_scripts(folder.path_join(directory)):
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
