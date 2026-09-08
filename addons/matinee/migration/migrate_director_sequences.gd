extends SceneTree

const Migration := preload("res://addons/matinee/migration/director_sequence_migration.gd")
const DEFAULT_ROOTS: Array[String] = ["res://"]


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var apply_changes := arguments.has("--apply")
	if apply_changes and not Engine.is_editor_hint():
		push_error("Apply mode requires --editor so Godot preserves resource UIDs.")
		quit(2)
		return
	var roots := _get_roots(arguments)
	var files := _find_tres_files(roots)
	var summary := {
		"scanned": 0,
		"sequences": 0,
		"legacy": 0,
		"ambiguous": 0,
		"current": 0,
		"invalid": 0,
		"migrated": 0,
		"failed": 0,
	}

	for path in files:
		summary.scanned += 1
		_process_file(path, apply_changes, summary)

	print("MatineeSequence migration %s: %d files scanned, %d sequences, %d legacy, %d ambiguous, %d current, %d invalid, %d changed, %d failed." % [
		"apply" if apply_changes else "dry-run",
		summary.scanned,
		summary.sequences,
		summary.legacy,
		summary.ambiguous,
		summary.current,
		summary.invalid,
		summary.migrated,
		summary.failed,
	])
	quit(1 if summary.failed > 0 or summary.invalid > 0 or summary.legacy > 0 or summary.ambiguous > 0 else 0)


func _process_file(path: String, apply_changes: bool, summary: Dictionary) -> void:
	var root_resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if root_resource == null:
		summary.failed += 1
		push_error("Could not load %s" % path)
		return

	var sequences: Array[MatineeSequence] = []
	_collect_sequences(root_resource, path, {}, sequences)
	if sequences.is_empty():
		return

	var file_changed := false
	for sequence in sequences:
		summary.sequences += 1
		var state := Migration.classify(sequence)
		summary[String(state)] += 1
		if not apply_changes:
			print("%s: %s" % [state, path])
			continue
		var result := Migration.migrate(sequence)
		if not bool(result.success):
			summary.failed += 1
			push_error("%s: %s" % [path, result.message])
			continue
		if bool(result.changed):
			file_changed = true
			summary.migrated += 1

	if file_changed:
		var save_error := ResourceSaver.save(root_resource, path)
		if save_error != OK:
			summary.failed += 1
			push_error("Could not save %s (error %d)." % [path, save_error])
		else:
			print("migrated: %s" % path)


func _collect_sequences(value: Variant, owner_path: String, visited: Dictionary, result: Array[MatineeSequence]) -> void:
	if not value is Resource:
		return

	var resource := value as Resource
	var identity := resource.get_instance_id()
	if visited.has(identity) or not _belongs_to_file(resource, owner_path):
		return
	visited[identity] = true
	if resource is MatineeSequence:
		var sequence := resource as MatineeSequence
		if not result.has(sequence):
			result.append(sequence)
		return

	for property in resource.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var child: Variant = resource.get(property.name)
		if child is Resource:
			_collect_sequences(child, owner_path, visited, result)
		elif child is Array:
			for item in child:
				if item is Resource:
					_collect_sequences(item, owner_path, visited, result)


func _belongs_to_file(resource: Resource, owner_path: String) -> bool:
	return (
		resource.resource_path.is_empty()
		or resource.resource_path == owner_path
		or resource.resource_path.begins_with(owner_path + "::")
	)


func _get_roots(arguments: PackedStringArray) -> Array[String]:
	var roots: Array[String] = []
	for argument in arguments:
		if argument.begins_with("--root="):
			roots.append(argument.trim_prefix("--root="))
	if roots.is_empty():
		roots.assign(DEFAULT_ROOTS)
	return roots


func _find_tres_files(roots: Array[String]) -> PackedStringArray:
	var result := PackedStringArray()
	for root_path in roots:
		_collect_tres_files(root_path, result)
	result.sort()
	return result


func _collect_tres_files(directory_path: String, result: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("Could not scan migration root: %s" % directory_path)
		return
	for child_name in directory.get_directories():
		_collect_tres_files(directory_path.path_join(child_name), result)
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "tres":
			result.append(directory_path.path_join(file_name))
