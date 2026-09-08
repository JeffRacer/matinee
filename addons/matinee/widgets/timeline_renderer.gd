@tool
class_name MatineeTimelineRenderer
extends RefCounted

const CLIP_TEXT_PADDING := 6.0
const CLIP_TEXT_GAP := 6.0
const TRACK_TITLE_BASELINE := 17.0
const TRACK_META_BASELINE := 37.0
const HEADER_SWATCH_SIZE := Vector2(10.0, 10.0)
const HEADER_BADGE_WIDTH := 16.0
const EMPTY_STATE_PADDING := Vector2(20.0, 16.0)


func draw(target: Control, layout, style, state: Dictionary) -> void:
	var font: Font = target.get_theme_default_font()
	var font_size: int = target.get_theme_default_font_size()
	var sequence := state.get("sequence") as MatineeSequence
	var playback_time: float = float(state.get("playback_time", 0.0))
	_draw_background(target, layout, style, sequence)
	_draw_ruler(target, layout, style, font, font_size, playback_time, sequence)
	if not is_instance_valid(sequence):
		_draw_empty_state(target, layout, style, font, font_size, "Select a MatineeSequence to begin.")
		return
	_draw_track_rows(target, layout, style, font, font_size, state, sequence)
	_draw_playhead(target, layout, style, playback_time)
	if bool(state.get("debug_enabled", false)):
		var overlay = state.get("debug_overlay")
		if overlay != null:
			overlay.draw(target, layout, style, font, maxi(font_size - 2, 8), state.get("debug_snapshot", []), sequence.tracks.size())


func _draw_background(target: Control, layout, style, sequence: MatineeSequence) -> void:
	target.draw_rect(Rect2(Vector2.ZERO, layout.canvas_size), style.panel_background)
	target.draw_rect(layout.ruler_rect(), style.ruler_background)
	_draw_grid(target, layout, style, sequence)
	target.draw_line(Vector2(layout.label_width, 0.0), Vector2(layout.label_width, layout.canvas_size.y), style.separator, 1.0)
	target.draw_line(Vector2(0.0, layout.ruler_height), Vector2(layout.canvas_size.x, layout.ruler_height), style.separator, 1.0)


func _draw_ruler(target: Control, layout, style, font: Font, font_size: int, playback_time: float, sequence: MatineeSequence) -> void:
	var major_step: float = _major_step(layout.pixels_per_second)
	var minor_step: float = major_step / 2.0
	var total_duration: float = maxf(_total_duration(sequence), float(layout.visible_time_range().get("end", 0.0)))
	target.draw_string(font, Vector2(8.0, 21.0), "TIME", HORIZONTAL_ALIGNMENT_LEFT, layout.label_width - 16.0, font_size, style.text_secondary)
	var current := 0.0
	while current <= total_duration + major_step:
		var x: float = layout.time_to_x(current)
		var is_major := is_equal_approx(fmod(current, major_step), 0.0)
		var tick_height := 12.0 if is_major else 6.0
		target.draw_line(Vector2(x, layout.ruler_height - tick_height), Vector2(x, layout.ruler_height), style.separator, 1.0)
		if is_major and absf(x - layout.time_to_x(playback_time)) > 28.0:
			target.draw_string(font, Vector2(x + 5.0, 18.0), _format_time(current), HORIZONTAL_ALIGNMENT_LEFT, 70.0, font_size, style.text_primary)
		current += minor_step


func _draw_grid(target: Control, layout, style, sequence: MatineeSequence) -> void:
	var major_step: float = _major_step(layout.pixels_per_second)
	var minor_step: float = major_step / 2.0
	var total_duration: float = maxf(_total_duration(sequence), float(layout.visible_time_range().get("end", 0.0)))
	var current := 0.0
	while current <= total_duration + minor_step:
		var x: float = layout.time_to_x(current)
		var is_major := is_equal_approx(fmod(current, major_step), 0.0)
		target.draw_line(Vector2(x, layout.ruler_height), Vector2(x, layout.canvas_size.y), style.grid_major if is_major else style.grid_minor, 1.0)
		current += minor_step


func _draw_track_rows(target: Control, layout, style, font: Font, font_size: int, state: Dictionary, sequence: MatineeSequence) -> void:
	if sequence.tracks.is_empty():
		_draw_empty_state(target, layout, style, font, font_size, "No tracks. Use + Track to create one.")
		return
	var selection_state := state.get("selection_state") as MatineeSelectionState
	var hovered_index: int = int(state.get("hovered_index", -1))
	var active_map := state.get("active_timeline_actions", {}) as Dictionary
	for track_index in range(sequence.tracks.size()):
		var track := sequence.tracks[track_index]
		var row_rect: Rect2 = layout.track_row_rect(track_index)
		var header_rect: Rect2 = layout.track_header_rect(track_index)
		var row_color: Color = style.row_alternate if track_index % 2 == 1 else style.row_primary
		target.draw_rect(row_rect, row_color)
		target.draw_rect(header_rect, style.track_header_background)
		if hovered_index == track_index:
			target.draw_rect(row_rect, style.hovered_track)
		if selection_state != null and selection_state.track_index == track_index:
			target.draw_rect(header_rect, style.selected_track)
			target.draw_rect(row_rect, Color(style.selected_track, 0.35))
		target.draw_line(Vector2(0.0, row_rect.end.y), Vector2(layout.canvas_size.x, row_rect.end.y), style.separator, 1.0)
		target.draw_line(Vector2(layout.label_width, row_rect.position.y), Vector2(layout.label_width, row_rect.end.y), style.separator, 1.0)
		if track == null:
			target.draw_string(font, Vector2(8.0, row_rect.position.y + 22.0), "Missing track", HORIZONTAL_ALIGNMENT_LEFT, layout.label_width - 16.0, font_size, style.warning_text)
			continue
		_draw_track_header(target, layout, style, font, font_size, track, track_index, header_rect)
		if track.actions.is_empty():
			_draw_track_empty_state(target, layout, style, font, maxi(font_size - 1, 10), track_index, selection_state != null and selection_state.track_index == track_index)
		if not track.visible:
			continue
		for action_index in range(track.actions.size()):
			var clip := track.actions[action_index]
			if clip == null:
				continue
			var selected := selection_state != null and selection_state.track_index == track_index and selection_state.action_index == action_index
			var active := active_map.has("%d:%d" % [track_index, action_index])
			_draw_track_clip(target, layout, style, font, font_size, track, clip, track_index, selected, active)
	_draw_track_drag_preview(target, layout, style, font, font_size, state, sequence)


func _draw_track_header(target: Control, layout, style, font: Font, font_size: int, track: MatineeTrack, track_index: int, header_rect: Rect2) -> void:
	var swatch_rect := Rect2(header_rect.position.x + 8.0, header_rect.position.y + 8.0, HEADER_SWATCH_SIZE.x, HEADER_SWATCH_SIZE.y)
	target.draw_rect(swatch_rect, track.color)
	target.draw_rect(swatch_rect, style.separator, false, 1.0)
	var badges: Array[String] = _track_badges(track)
	var badge_width: float = float(badges.size()) * (HEADER_BADGE_WIDTH + 3.0)
	var title_x: float = swatch_rect.end.x + 8.0
	var title_width: float = maxf(header_rect.size.x - title_x - 8.0 - badge_width, 0.0)
	var title_color: Color = style.text_primary if track.enabled and track.visible else style.text_secondary
	if _track_invalid_count(track) > 0:
		title_color = style.warning_text
	target.draw_string(font, Vector2(title_x, header_rect.position.y + TRACK_TITLE_BASELINE), _fit_text(font, track.track_name if not track.track_name.is_empty() else "Track %d" % (track_index + 1), title_width, font_size), HORIZONTAL_ALIGNMENT_LEFT, title_width, font_size, title_color)
	_draw_header_badges(target, style, font, maxi(font_size - 3, 8), header_rect, badges)
	var count_text := "%d clip%s" % [track.actions.size(), "" if track.actions.size() == 1 else "s"]
	if _track_invalid_count(track) > 0:
		count_text += " · %d invalid" % _track_invalid_count(track)
	if track.muted:
		count_text += " · muted"
	elif track.locked:
		count_text += " · locked"
	target.draw_string(font, Vector2(title_x, header_rect.position.y + TRACK_META_BASELINE), _fit_text(font, count_text, header_rect.size.x - title_x - 8.0, maxi(font_size - 2, 8)), HORIZONTAL_ALIGNMENT_LEFT, header_rect.size.x - title_x - 8.0, maxi(font_size - 2, 8), style.text_secondary)


func _draw_track_clip(target: Control, layout, style, font: Font, font_size: int, track: MatineeTrack, clip: MatineeTimelineAction, track_index: int, selected: bool, active: bool) -> void:
	var invalid := clip.action == null or clip.duration < 0.0
	var action_enabled := clip.action != null and clip.action.enabled
	var base_color: Color = track.color
	if clip.action != null:
		base_color = track.color.lerp(clip.action.get_editor_color(), 0.45)
	var fill: Color = style.clip_fill(base_color, track.muted, track.enabled, action_enabled, invalid)
	var rect: Rect2 = layout.clip_rect(track_index, clip.start_time, clip.duration)
	if layout.is_event_marker(clip.duration):
		_draw_event_marker(target, style, rect, fill, selected, active, invalid)
	else:
		target.draw_rect(rect, fill, true)
		if track.muted:
			target.draw_rect(rect, style.muted_clip_overlay, true)
		if not track.enabled or not action_enabled:
			target.draw_rect(rect, style.disabled_clip_overlay, true)
	var border_color: Color = style.clip_outline(selected, active, invalid, fill)
	target.draw_rect(rect, border_color, false, 2.0 if selected or active or invalid else 1.0)
	if active:
		target.draw_line(Vector2(rect.position.x + 1.0, rect.position.y + 2.0), Vector2(rect.end.x - 1.0, rect.position.y + 2.0), style.active_clip_outline, 2.0)
	_draw_clip_text(target, layout, style, font, font_size, rect, clip, fill, invalid)


func _draw_event_marker(target: Control, style, rect: Rect2, fill: Color, selected: bool, active: bool, invalid: bool) -> void:
	var center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	var radius: float = minf(rect.size.x, rect.size.y) * 0.35
	var marker := PackedVector2Array([
		Vector2(center.x, center.y - radius),
		Vector2(center.x + radius, center.y),
		Vector2(center.x, center.y + radius),
		Vector2(center.x - radius, center.y),
	])
	target.draw_colored_polygon(marker, fill)
	var outline: Color = style.clip_outline(selected, active, invalid, fill)
	target.draw_polyline(marker + PackedVector2Array([marker[0]]), outline, 2.0)


func _draw_clip_text(target: Control, layout, style, font: Font, font_size: int, rect: Rect2, clip: MatineeTimelineAction, fill: Color, invalid: bool) -> void:
	if rect.size.x < 28.0:
		return
	var action_name := _clip_label(clip)
	if clip.action != null and not clip.action.enabled:
		action_name = "Disabled · " + action_name
	var text_color: Color = style.warning_text if invalid else style.clip_text(fill)
	var text_rect: Rect2 = layout.clip_text_rect(rect, CLIP_TEXT_PADDING)
	var baseline: float = rect.position.y + (rect.size.y + float(font_size)) * 0.5 - 1.0
	var timing_text := ""
	var timing_width := 0.0
	var timing_font_size := maxi(font_size - 2, 8)
	if rect.size.x >= 146.0:
		timing_text = "%.1fs · %.1fs" % [clip.start_time, clip.duration]
		timing_width = font.get_string_size(timing_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, timing_font_size).x
	var name_width: float = text_rect.size.x
	if not timing_text.is_empty():
		name_width = maxf(name_width - timing_width - CLIP_TEXT_GAP, 0.0)
	var fitted_name := _fit_text(font, action_name, name_width, font_size)
	if not fitted_name.is_empty():
		target.draw_string(font, Vector2(text_rect.position.x, baseline), fitted_name, HORIZONTAL_ALIGNMENT_LEFT, name_width, font_size, text_color)
	if not timing_text.is_empty() and rect.size.x >= 182.0:
		target.draw_string(font, Vector2(rect.end.x - CLIP_TEXT_PADDING - timing_width, baseline), timing_text, HORIZONTAL_ALIGNMENT_LEFT, timing_width, timing_font_size, style.text_secondary)


func _clip_label(clip: MatineeTimelineAction) -> String:
	if clip == null or clip.action == null:
		return "Missing action"
	var action := clip.action
	var base_name := action.get_editor_name()
	var preview_text := _action_preview_text(action, base_name)
	if preview_text.is_empty():
		return base_name
	return "%s: %s" % [base_name, preview_text]


func _action_preview_text(action: MatineeAction, editor_name: String) -> String:
	var raw := ""
	match editor_name:
		"Dialogue":
			raw = str(action.get("message"))
		"Title Card":
			raw = str(action.get("main_text"))
			if raw.strip_edges().is_empty():
				raw = str(action.get("subtitle"))
		"Camera":
			raw = action.get_editor_summary()
		_:
			return ""
	return _single_line_text(raw)


func _single_line_text(value: String) -> String:
	var result := value.replace("\r", " ").replace("\n", " ").strip_edges()
	while result.find("  ") >= 0:
		result = result.replace("  ", " ")
	return result


func _draw_track_empty_state(target: Control, layout, style, font: Font, font_size: int, track_index: int, selected: bool) -> void:
	var row_rect: Rect2 = layout.track_row_rect(track_index)
	var panel_rect := Rect2(layout.label_width + 12.0, row_rect.position.y + 8.0, maxf(layout.canvas_size.x - layout.label_width - 24.0, 120.0), row_rect.size.y - 16.0)
	target.draw_rect(panel_rect, Color(style.warning_panel, 0.24), true)
	target.draw_rect(panel_rect, style.separator if not selected else style.selected_clip_outline, false, 1.0)
	target.draw_string(font, Vector2(panel_rect.position.x + 10.0, panel_rect.position.y + panel_rect.size.y * 0.5 + font_size * 0.35), _fit_text(font, "This track is empty. Select it and use + Add.", panel_rect.size.x - 20.0, font_size), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 20.0, font_size, style.text_secondary)


func _draw_track_drag_preview(target: Control, layout, style, font: Font, font_size: int, state: Dictionary, sequence: MatineeSequence) -> void:
	if not bool(state.get("track_drag_active", false)):
		return
	var source_track_index: int = int(state.get("pressed_track_index", -1))
	var source_action_index: int = int(state.get("pressed_track_action_index", -1))
	var destination_index: int = int(state.get("track_drag_destination", -1))
	if source_track_index < 0 or source_action_index < 0 or destination_index < 0:
		return
	var clip := sequence.tracks[source_track_index].actions[source_action_index]
	if clip == null:
		return
	var destination_row: Rect2 = layout.track_row_rect(destination_index)
	target.draw_rect(destination_row, style.drop_destination)
	var rect: Rect2 = layout.clip_rect(destination_index, float(state.get("track_drag_start_time", 0.0)), clip.duration)
	target.draw_rect(rect, style.drag_ghost, true)
	target.draw_rect(rect, style.selected_clip_outline, false, 2.0)
	target.draw_line(Vector2(rect.position.x, layout.ruler_height), Vector2(rect.position.x, layout.canvas_size.y), style.snap_guide, 1.0)
	if rect.size.x >= 64.0:
		target.draw_string(font, Vector2(rect.position.x + 6.0, rect.position.y + 18.0), _fit_text(font, "%.1fs" % float(state.get("track_drag_start_time", 0.0)), rect.size.x - 12.0, font_size), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, font_size, style.text_primary)


func _draw_empty_state(target: Control, layout, style, font: Font, font_size: int, message: String) -> void:
	var available_rect := Rect2(8.0, layout.ruler_height + 8.0, maxf(layout.canvas_size.x - 16.0, 120.0), maxf(layout.canvas_size.y - layout.ruler_height - 16.0, 44.0))
	var message_size := font.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_CENTER, available_rect.size.x - EMPTY_STATE_PADDING.x * 2.0, font_size)
	var panel_size := Vector2(minf(message_size.x + EMPTY_STATE_PADDING.x * 2.0, available_rect.size.x), message_size.y + EMPTY_STATE_PADDING.y * 2.0)
	var panel_rect := Rect2(Vector2(available_rect.position.x + (available_rect.size.x - panel_size.x) * 0.5, available_rect.position.y + (available_rect.size.y - panel_size.y) * 0.5), panel_size)
	target.draw_rect(panel_rect, style.warning_panel, true)
	target.draw_rect(panel_rect, Color(style.text_secondary, 0.18), false, 1.0)
	target.draw_multiline_string(font, Vector2(panel_rect.position.x + EMPTY_STATE_PADDING.x, panel_rect.position.y + EMPTY_STATE_PADDING.y + font.get_ascent(font_size)), message, HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x - EMPTY_STATE_PADDING.x * 2.0, font_size, -1, style.text_secondary)


func _draw_playhead(target: Control, layout, style, playback_time: float) -> void:
	var x: float = layout.time_to_x(playback_time)
	target.draw_line(Vector2(x, 0.0), Vector2(x, layout.canvas_size.y), style.playhead_glow, 6.0)
	target.draw_line(Vector2(x, 0.0), Vector2(x, layout.canvas_size.y), style.playhead, 2.0)
	var marker := PackedVector2Array([
		Vector2(x - 7.0, 0.0),
		Vector2(x + 7.0, 0.0),
		Vector2(x, 10.0),
	])
	target.draw_colored_polygon(marker, style.playhead)


func _track_invalid_count(track: MatineeTrack) -> int:
	var invalid_count := 0
	for clip in track.actions:
		if clip == null or clip.action == null or clip.duration < 0.0:
			invalid_count += 1
	return invalid_count


func _track_badges(track: MatineeTrack) -> Array[String]:
	var result: Array[String] = []
	if track.muted:
		result.append("M")
	if track.locked:
		result.append("L")
	if not track.visible:
		result.append("H")
	if not track.enabled:
		result.append("D")
	if _track_invalid_count(track) > 0:
		result.append("!")
	return result


func _draw_header_badges(target: Control, style, font: Font, font_size: int, header_rect: Rect2, badges: Array[String]) -> void:
	var x := header_rect.end.x - 8.0
	for badge_text in badges:
		x -= HEADER_BADGE_WIDTH
		var badge_rect := Rect2(x, header_rect.position.y + 7.0, HEADER_BADGE_WIDTH, 14.0)
		target.draw_rect(badge_rect, style.badge_background, true)
		target.draw_rect(badge_rect, style.separator, false, 1.0)
		target.draw_string(font, Vector2(badge_rect.position.x + 4.0, badge_rect.position.y + 11.0), badge_text, HORIZONTAL_ALIGNMENT_LEFT, badge_rect.size.x - 4.0, font_size, style.warning_text if badge_text == "!" else style.text_secondary)
		x -= 3.0


func _fit_text(font: Font, value: String, width: float, font_size: int) -> String:
	if width <= 0.0:
		return ""
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
		return value
	var ellipsis := "..."
	if font.get_string_size(ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width:
		return ""
	var low := 0
	var high := value.length()
	while low < high:
		var middle := int(ceil(float(low + high) * 0.5))
		var candidate := value.left(middle) + ellipsis
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
			low = middle
		else:
			high = middle - 1
	return value.left(low) + ellipsis


func _major_step(pixels_per_second: float) -> float:
	if pixels_per_second >= 120.0:
		return 1.0
	if pixels_per_second >= 60.0:
		return 2.0
	if pixels_per_second >= 28.0:
		return 5.0
	return 10.0


func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var whole_seconds := int(seconds) % 60
	return "%02d:%02d" % [minutes, whole_seconds]


func _total_duration(sequence: MatineeSequence) -> float:
	return sequence.get_duration_seconds() if is_instance_valid(sequence) else 0.0
