@tool
class_name MatineeTitleCardPreviewHandler
extends MatineePreviewHandler

const IntertitlePreviewUtils := preload(
	"res://addons/matinee/preview/handlers/intertitle_preview_utils.gd"
)


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeTitleCardAction"]


func evaluate_entry(
	_time: float,
	_entry: Dictionary,
	_action: MatineeAction,
	_context: MatineePreviewContext
) -> Dictionary:
	var title := _action as MatineeTitleCardAction
	if title == null or title.main_text.strip_edges().is_empty():
		return {}

	var start_time := float(_entry.get("start", 0.0))
	var end_time := float(_entry.get("end", start_time))

	return {
		"kind": &"title_card",
		"kicker": "",
		"main_text": title.main_text,
		"subtitle": title.subtitle,
		"opacity": IntertitlePreviewUtils.get_title_opacity(
			_time,
			start_time,
			end_time,
			title.fade_duration
		),
		"use_custom_text_colors": title.use_custom_text_colors,
		"main_font_color": title.main_font_color,
		"subtitle_font_color": title.subtitle_font_color,
		"use_outline": title.use_outline,
		"outline_color": title.outline_color,
		"main_outline_size": title.main_outline_size,
		"outline_subtitle": title.outline_subtitle,
		"subtitle_outline_size": title.subtitle_outline_size,
		"track_index": int(_entry.get("track_index", -1)),
		"action_index": int(_entry.get("action_index", -1)),
	}
