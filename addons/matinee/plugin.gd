@tool
extends EditorPlugin

const DirectorDockScene := preload("res://addons/matinee/director_dock.tscn")

var _dock: Control


func _enter_tree() -> void:
	_dock = DirectorDockScene.instantiate() as Control
	_dock.name = "Matinee"
	_dock.set_undo_redo(get_undo_redo())
	_dock.set_scene_context_provider(func() -> Node: return get_editor_interface().get_edited_scene_root())
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)


func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null


func _handles(object: Object) -> bool:
	return object is MatineeSequence


func _edit(object: Object) -> void:
	if is_instance_valid(_dock) and object is MatineeSequence:
		_dock.set_sequence(object as MatineeSequence)


func _make_visible(_visible: bool) -> void:
	# Keep the dock available while other resources or scene nodes are selected.
	# The last opened MatineeSequence remains visible for convenient authoring.
	pass
