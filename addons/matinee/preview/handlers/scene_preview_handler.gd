@tool
class_name MatineeScenePreviewHandler
extends MatineePreviewHandler

const SceneTransitionPreview := preload(
	"res://addons/matinee/preview/scene_transition_preview.gd"
)

var _scene_preview := SceneTransitionPreview.new()


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeSceneAction"]


func rebuild(sequence: MatineeSequence, _context: MatineePreviewContext) -> void:
	_scene_preview.rebuild(sequence)


func collect_persistent_states(
	_time: float,
	_context: MatineePreviewContext,
	_out_states: Array[Dictionary]
) -> void:
	var scene_state := _scene_preview.get_state(_time)
	if not scene_state.is_empty():
		_out_states.append(scene_state)
