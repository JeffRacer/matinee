@tool
class_name MatineeInspectorPanel
extends VBoxContainer

signal property_edited(property: StringName)


const PREVIEW_TEXT_PROPERTIES: Array[StringName] = [
	&"message",
	&"main_text",
	&"subtitle",
]


var _editor_inspector: EditorInspector
var _inspected_object: Object


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_editor_inspector = EditorInspector.new()
	_editor_inspector.custom_minimum_size = Vector2(0.0, 220.0)
	_editor_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_inspector.property_edited.connect(_on_inspector_property_edited)
	add_child(_editor_inspector)


func inspect_sequence(sequence: MatineeSequence) -> void:
	_inspect_object(sequence)


func inspect_action(action: MatineeAction) -> void:
	_inspect_object(action)


func inspect_timeline_action(timeline_action: MatineeTimelineAction) -> void:
	_inspect_object(timeline_action)


func inspect_track(track: MatineeTrack) -> void:
	_inspect_object(track)


func clear() -> void:
	_inspect_object(null)


func is_inspecting(object: Object) -> bool:
	return _inspected_object == object


func has_keyboard_focus() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false

	var focus_owner := viewport.gui_get_focus_owner()
	return (
		focus_owner != null
		and (
			focus_owner == self
			or is_ancestor_of(focus_owner)
		)
	)


func _inspect_object(object: Object) -> void:
	if _editor_inspector == null:
		return

	# Calling EditorInspector.edit() again for the same resource rebuilds its
	# property controls and destroys the LineEdit/TextEdit currently in use.
	if _inspected_object == object:
		return

	_inspected_object = object
	_editor_inspector.edit(object)


func _on_inspector_property_edited(property: StringName) -> void:
	# The Matinee dock already refreshes its action tree and runtime preview
	# when the generic `action` property changes. Preview text fields are nested
	# action properties, so route them through that existing refresh path while
	# leaving the EditorInspector focused on the active text control.
	if PREVIEW_TEXT_PROPERTIES.has(property):
		property_edited.emit(&"action")
		return

	property_edited.emit(property)
