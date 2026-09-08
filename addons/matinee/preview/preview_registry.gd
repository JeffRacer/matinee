@tool
extends RefCounted

var _handlers: Array = []
var _handlers_by_type := {}


func clear() -> void:
	_handlers.clear()
	_handlers_by_type.clear()


func register_handler(handler: Variant) -> void:
	if handler == null:
		return
	if not _handlers.has(handler):
		_handlers.append(handler)
	_rebuild_type_map()


func unregister_handler(handler: Variant) -> bool:
	if handler == null:
		return false
	var index := _handlers.find(handler)
	if index < 0:
		return false
	_handlers.remove_at(index)
	_rebuild_type_map()
	return true


func get_handlers() -> Array:
	return _handlers.duplicate()


func get_handler_for_action(action: MatineeAction) -> Variant:
	if action == null:
		return null
	var best_handler: Variant = null
	var best_priority: int = -2147483648
	var best_index: int = -1
	for index in range(_handlers.size()):
		var handler: Variant = _handlers[index]
		if not _handler_supports_action(handler, action):
			continue
		var priority: int = int(handler.get_priority())
		if priority > best_priority or (priority == best_priority and index > best_index):
			best_priority = priority
			best_index = index
			best_handler = handler
	return best_handler


func is_previewable(action: MatineeAction) -> bool:
	return get_handler_for_action(action) != null


func get_unsupported_reason(action: MatineeAction) -> String:
	if action == null:
		return "Preview action is missing."
	if is_previewable(action):
		return ""
	return "%s has no registered Runtime Preview handler." % action.get_editor_name()


func get_previewable_action_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for type_name in _handlers_by_type.keys():
		result.append(type_name)
	return result


func get_registered_handler_metadata() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(_handlers.size()):
		var handler: Variant = _handlers[index]
		var script: Script = handler.get_script()
		var handler_class_name: StringName = StringName(handler.get_class())
		if script != null:
			var global_name: StringName = script.get_global_name()
			if not global_name.is_empty():
				handler_class_name = global_name
		var types: Array[StringName] = []
		types.assign(handler.get_supported_action_types())
		result.append({
			"index": index,
			"class_name": handler_class_name,
			"priority": handler.get_priority(),
			"supported_action_types": types,
			"capabilities": handler.get_capabilities().duplicate(true),
		})
	return result


func _rebuild_type_map() -> void:
	_handlers_by_type.clear()
	for handler: Variant in _handlers:
		for type_name in handler.get_supported_action_types():
			_handlers_by_type[type_name] = handler


func _handler_supports_action(handler: Variant, action: MatineeAction) -> bool:
	if action == null:
		return false
	for type_name in handler.get_supported_action_types():
		if _action_matches_type(action, type_name):
			return true
	return false


func _action_matches_type(action: MatineeAction, type_name: StringName) -> bool:
	var expected_name := String(type_name)
	if expected_name.is_empty():
		return false
	if action.is_class(expected_name):
		return true
	var script: Script = action.get_script()
	if script == null:
		return false
	var current_script: Script = script
	while current_script != null:
		var global_name: StringName = current_script.get_global_name()
		if String(global_name) == expected_name:
			return true
		current_script = current_script.get_base_script()
	return false
