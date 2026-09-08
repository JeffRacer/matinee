@tool
class_name MatineeDialoguePreviewHandler
extends MatineePreviewHandler


func get_supported_action_types() -> Array[StringName]:
	return [&"MatineeDialogueAction"]


func evaluate_entry(
	_time: float,
	_entry: Dictionary,
	_action: MatineeAction,
	_context: MatineePreviewContext
) -> Dictionary:
	var dialogue := _action as MatineeDialogueAction
	if dialogue == null:
		return {}
	var message := dialogue.message.strip_edges()
	if message.is_empty():
		return {}
	var speaker := dialogue.fallback_speaker_name
	var name_color := Color(0.88, 0.86, 0.76, 1.0)
	var text_color := Color(0.92, 0.91, 0.84, 1.0)
	if dialogue.actor != null:
		speaker = dialogue.actor.get_formatted_name()
		name_color = dialogue.actor.name_color
		text_color = dialogue.actor.text_color
	return {
		"kind": &"dialogue",
		"speaker": speaker,
		"message": _format_dialogue_message(message),
		"name_color": name_color,
		"text_color": text_color,
		"track_index": int(_entry.get("track_index", -1)),
		"action_index": int(_entry.get("action_index", -1)),
	}


func _format_dialogue_message(message: String) -> String:
	if message.begins_with("“") or message.begins_with("\""):
		return message
	return "“%s”" % message
