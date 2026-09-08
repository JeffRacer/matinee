@tool
class_name MatineeLocationCardPreviewHandler
extends MatineePreviewHandler

const IntertitlePreviewUtils := preload(
	"res://addons/matinee/preview/handlers/intertitle_preview_utils.gd"
)


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeLocationAction"]


func evaluate_entry(
	_time: float,
	_entry: Dictionary,
	_action: MatineeAction,
	_context: MatineePreviewContext
) -> Dictionary:
	var location := _action as MatineeLocationAction
	if location == null:
		return {}
	var name := location.location_name.strip_edges()
	if name.is_empty():
		return {}
	var start_time := float(_entry.get("start", 0.0))
	var end_time := float(_entry.get("end", start_time))
	return {
		"kind": &"location_card",
		"kicker": "",
		"main_text": name.to_upper(),
		"subtitle": location.location_subtitle.strip_edges().to_upper(),
		"opacity": IntertitlePreviewUtils.get_title_opacity(_time, start_time, end_time, 0.28),
		"track_index": int(_entry.get("track_index", -1)),
		"action_index": int(_entry.get("action_index", -1)),
	}
