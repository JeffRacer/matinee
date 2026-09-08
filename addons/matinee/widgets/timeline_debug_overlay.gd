@tool
class_name MatineeTimelineDebugOverlay
extends RefCounted

var _reported_issue_keys := {}


func reset() -> void:
	_reported_issue_keys.clear()


func get_line_count(sequence: MatineeSequence) -> int:
	if not is_instance_valid(sequence) or not sequence.is_current_track_format():
		return 0
	var count := 0
	for track in sequence.tracks:
		count += 1 + (track.actions.size() if track != null else 0)
	return count


func build_snapshot(
	sequence: MatineeSequence,
	selection_state: MatineeSelectionState,
	active_timeline_actions: Dictionary,
	layout
) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	if not is_instance_valid(sequence) or not sequence.is_current_track_format():
		return snapshot
	for track_index in range(sequence.tracks.size()):
		var track := sequence.tracks[track_index]
		var track_data := {
			"track_index": track_index,
			"track_name": "<null>" if track == null else track.track_name,
			"track_type": "Invalid" if track == null else _track_type_name(track.track_type),
			"muted": false if track == null else track.muted,
			"locked": false if track == null else track.locked,
			"visible": false if track == null else track.visible,
			"enabled": false if track == null else track.enabled,
			"clip_count": 0 if track == null else track.actions.size(),
			"row_y": layout.row_y(track_index),
			"clips": [],
		}
		if track == null:
			snapshot.append(track_data)
			continue
		var clips: Array[Dictionary] = []
		for action_index in range(track.actions.size()):
			var clip := track.actions[action_index]
			var rect := Rect2()
			if clip != null:
				rect = layout.clip_rect(track_index, clip.start_time, clip.duration)
			var selected := (
				selection_state != null
				and selection_state.track_index == track_index
				and selection_state.action_index == action_index
			)
			var active := active_timeline_actions.has("%d:%d" % [track_index, action_index])
			var drawable := true
			var reason := ""
			if clip == null:
				drawable = false
				reason = "null timeline clip"
			elif clip.action == null:
				drawable = false
				reason = "null wrapped action"
			elif is_nan(clip.start_time) or is_inf(clip.start_time) or clip.start_time < 0.0:
				drawable = false
				reason = "invalid start time"
			elif is_nan(clip.duration) or is_inf(clip.duration) or clip.duration < 0.0:
				drawable = false
				reason = "invalid duration"
			elif not track.visible:
				drawable = false
				reason = "hidden track"
			elif rect.size.x <= 0.0:
				drawable = false
				reason = "zero-width clip"
			elif not layout.visible_rect.intersects(rect):
				drawable = false
				reason = "outside visible range"
			var stale_selection := selected and selection_state.timeline_action != clip
			if stale_selection:
				drawable = false
				reason = "stale selection reference"
			clips.append({
				"action_index": action_index,
				"action_name": "<null>" if clip == null or clip.action == null else clip.action.get_editor_name(),
				"action_is_null": clip == null or clip.action == null,
				"start_time": 0.0 if clip == null else clip.start_time,
				"duration": 0.0 if clip == null else clip.duration,
				"end_time": 0.0 if clip == null else clip.get_end_time(),
				"x": rect.position.x,
				"width": rect.size.x,
				"selected": selected,
				"active": active,
				"drawable": drawable,
				"reason": reason,
				"stale_selection": stale_selection,
			})
		track_data["clips"] = clips
		snapshot.append(track_data)
	return snapshot


func collect_issue_messages(snapshot: Array[Dictionary]) -> Array[String]:
	var messages: Array[String] = []
	for track_data in snapshot:
		var track_index := int(track_data["track_index"])
		if str(track_data["track_name"]) == "<null>":
			_append_issue_once(messages, "track:%d:null" % track_index, "Track %d is null." % track_index)
		for clip_data in track_data["clips"]:
			var reason := str(clip_data["reason"])
			if reason not in ["null timeline clip", "null wrapped action", "invalid start time", "invalid duration", "stale selection reference"]:
				continue
			var action_index := int(clip_data["action_index"])
			_append_issue_once(
				messages,
				"clip:%d:%d:%s" % [track_index, action_index, reason],
				"Track %d clip %d: %s." % [track_index, action_index, reason]
			)
	return messages


func draw(
	target: Control,
	layout,
	style,
	font: Font,
	font_size: int,
	snapshot: Array[Dictionary],
	track_count: int
) -> void:
	var overlay_rect: Rect2 = layout.debug_overlay_rect(track_count, _line_count_from_snapshot(snapshot))
	target.draw_rect(overlay_rect, style.panel_background.darkened(0.12))
	target.draw_line(overlay_rect.position, Vector2(overlay_rect.end.x, overlay_rect.position.y), style.separator, 2.0)
	var baseline: float = overlay_rect.position.y + 15.0
	for track_data in snapshot:
		var track_line := "T%d %s · %s · clips=%d · y=%.1f · enabled=%s muted=%s locked=%s visible=%s" % [
			int(track_data["track_index"]),
			str(track_data["track_name"]),
			str(track_data["track_type"]),
			int(track_data["clip_count"]),
			float(track_data["row_y"]),
			str(track_data["enabled"]),
			str(track_data["muted"]),
			str(track_data["locked"]),
			str(track_data["visible"]),
		]
		target.draw_string(font, Vector2(8.0, baseline), track_line, HORIZONTAL_ALIGNMENT_LEFT, overlay_rect.size.x - 16.0, font_size, style.text_primary)
		baseline += layout.debug_line_height
		for clip_data in track_data["clips"]:
			var reason_text := "" if bool(clip_data["drawable"]) else " · reason=" + str(clip_data["reason"])
			var clip_line := "  C%d %s · null=%s · start=%.2f duration=%.2f end=%.2f · x=%.1f width=%.1f · selected=%s active=%s drawable=%s%s" % [
				int(clip_data["action_index"]),
				str(clip_data["action_name"]),
				str(clip_data["action_is_null"]),
				float(clip_data["start_time"]),
				float(clip_data["duration"]),
				float(clip_data["end_time"]),
				float(clip_data["x"]),
				float(clip_data["width"]),
				str(clip_data["selected"]),
				str(clip_data["active"]),
				str(clip_data["drawable"]),
				reason_text,
			]
			target.draw_string(font, Vector2(8.0, baseline), clip_line, HORIZONTAL_ALIGNMENT_LEFT, overlay_rect.size.x - 16.0, font_size, style.text_primary if bool(clip_data["drawable"]) else style.text_secondary)
			baseline += layout.debug_line_height


func _append_issue_once(messages: Array[String], key: String, message: String) -> void:
	if _reported_issue_keys.has(key):
		return
	_reported_issue_keys[key] = true
	messages.append(message)


func _line_count_from_snapshot(snapshot: Array[Dictionary]) -> int:
	var count := 0
	for track_data in snapshot:
		count += 1 + (track_data["clips"] as Array).size()
	return count


func _track_type_name(track_type: int) -> String:
	match track_type:
		MatineeTrack.TrackType.VISUAL:
			return "Visual"
		MatineeTrack.TrackType.AUDIO:
			return "Audio"
		MatineeTrack.TrackType.CAMERA:
			return "Camera"
		MatineeTrack.TrackType.GAMEPLAY:
			return "Gameplay"
		_:
			return "General"
