@tool
class_name MatineeChapterCardPreviewHandler
extends MatineePreviewHandler

const IntertitlePreviewUtils := preload(
	"res://addons/matinee/preview/handlers/intertitle_preview_utils.gd"
)


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeChapterAction"]


func evaluate_entry(
	_time: float,
	_entry: Dictionary,
	_action: MatineeAction,
	_context: MatineePreviewContext
) -> Dictionary:
	var chapter := _action as MatineeChapterAction
	if chapter == null:
		return {}
	var title := chapter.chapter_title.strip_edges()
	if title.is_empty():
		return {}
	var start_time := float(_entry.get("start", 0.0))
	var end_time := float(_entry.get("end", start_time))
	return {
		"kind": &"chapter_card",
		"kicker": chapter.chapter_number.strip_edges().to_upper(),
		"main_text": title.to_upper(),
		"subtitle": "",
		"opacity": IntertitlePreviewUtils.get_title_opacity(_time, start_time, end_time, chapter.fade_duration),
		"track_index": int(_entry.get("track_index", -1)),
		"action_index": int(_entry.get("action_index", -1)),
	}
