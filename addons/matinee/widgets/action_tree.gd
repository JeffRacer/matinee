@tool
class_name MatineeActionTree
extends Tree

signal timeline_action_selected(action: MatineeAction, track_index: int, action_index: int)
signal track_selected(track: MatineeTrack, track_index: int)
signal timeline_action_move_requested(source_track_index: int, source_action_index: int, destination_track_index: int, destination_action_index: int)
signal track_move_requested(source_track_index: int, destination_track_index: int)

var _sequence: MatineeSequence
var _selection_state: MatineeSelectionState
var action_count: int = 0


func _ready() -> void:
	drop_mode_flags = Tree.DROP_MODE_INBETWEEN
	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)


func set_sequence(sequence: MatineeSequence) -> void:
	_sequence = sequence
	refresh()


func set_selection_state(selection_state: MatineeSelectionState) -> void:
	if _selection_state == selection_state:
		return

	if _selection_state != null:
		if _selection_state.action_changed.is_connected(_on_selection_state_changed):
			_selection_state.action_changed.disconnect(_on_selection_state_changed)
		if _selection_state.track_changed.is_connected(_on_selection_track_changed):
			_selection_state.track_changed.disconnect(_on_selection_track_changed)
		if _selection_state.selection_cleared.is_connected(_on_selection_state_cleared):
			_selection_state.selection_cleared.disconnect(_on_selection_state_cleared)

	_selection_state = selection_state

	if _selection_state != null:
		_selection_state.action_changed.connect(_on_selection_state_changed)
		_selection_state.track_changed.connect(_on_selection_track_changed)
		_selection_state.selection_cleared.connect(_on_selection_state_cleared)
		_restore_selection()


func refresh() -> void:
	clear()

	if not is_instance_valid(_sequence):
		action_count = 0
		return
	_refresh_tracks()


func clear_sequence() -> void:
	_sequence = null
	action_count = 0
	clear()


func select_timeline_action(track_index: int, action_index: int) -> void:
	var root := get_root()
	if root == null:
		return
	var track_item := root.get_first_child()
	var current_track := 0
	while track_item != null:
		if current_track == track_index:
			var action_item := track_item.get_first_child()
			var current_action := 0
			while action_item != null:
				if current_action == action_index:
					action_item.select(0)
					return
				current_action += 1
				action_item = action_item.get_next()
			return
		current_track += 1
		track_item = track_item.get_next()


func select_track(track_index: int) -> void:
	var root := get_root()
	if root == null:
		return
	var track_item := root.get_first_child()
	var current_track := 0
	while track_item != null:
		if current_track == track_index:
			track_item.select(0)
			return
		current_track += 1
		track_item = track_item.get_next()


func _on_item_selected() -> void:
	if not is_instance_valid(_sequence):
		return

	var item := get_selected()
	if item == null:
		return
	var metadata := item.get_metadata(0)
	if not metadata is Dictionary:
		return
	var track_index := int(metadata.get("track_index", -1))
	var action_index := int(metadata.get("action_index", -1))
	if track_index < 0 or track_index >= _sequence.tracks.size():
		return
	if action_index < 0:
		if _sequence.tracks[track_index] != null:
			track_selected.emit(_sequence.tracks[track_index], track_index)
		return
	var track := _sequence.tracks[track_index]
	var clip := track.actions[action_index]
	if clip != null and clip.action != null:
		timeline_action_selected.emit(clip.action, track_index, action_index)


func _on_selection_state_changed(_action: MatineeAction, index: int) -> void:
	if _selection_state != null and _sequence != null:
		select_timeline_action(_selection_state.track_index, index)


func _on_selection_track_changed(_track: MatineeTrack, track_index: int) -> void:
	select_track(track_index)


func _refresh_tracks() -> void:
	var root := create_item()
	action_count = 0
	for track_index in range(_sequence.tracks.size()):
		var track := _sequence.tracks[track_index]
		var track_item := create_item(root)
		track_item.set_metadata(0, {"item_type": &"track", "track_index": track_index, "action_index": -1})
		if track == null:
			track_item.set_text(1, "⚠ Missing track")
			track_item.set_text(2, "—")
			continue
		var states: Array[String] = []
		if track.muted:
			states.append("Muted")
		if track.locked:
			states.append("Locked")
		if not track.visible:
			states.append("Hidden")
		if not track.enabled:
			states.append("Disabled")
		track_item.set_text(1, track.track_name)
		track_item.set_text(2, _get_track_summary(track.actions.size(), states))
		track_item.set_tooltip_text(1, _get_track_tooltip(track, states))
		track_item.set_tooltip_text(2, _get_track_tooltip(track, states))
		track_item.set_custom_color(1, track.color)
		for action_index in range(track.actions.size()):
			var clip := track.actions[action_index]
			var item := create_item(track_item)
			item.set_metadata(0, {"item_type": &"timeline_action", "track_index": track_index, "action_index": action_index})
			item.set_text(0, _format_time(0.0 if clip == null else clip.start_time))
			if clip == null or clip.action == null:
				item.set_text(1, "⚠ Missing action")
				item.set_text(2, "—" if clip == null else _format_duration(clip.duration))
				item.set_tooltip_text(1, "This timeline clip has no valid MatineeAction resource.")
				continue
			item.set_text(1, _get_action_label(clip.action))
			item.set_text(2, _format_duration(clip.duration))
			item.set_custom_color(1, clip.action.get_editor_color())
			item.set_tooltip_text(1, _get_action_tooltip(clip.action, clip.start_time, clip.duration))
			item.set_tooltip_text(2, _get_action_tooltip(clip.action, clip.start_time, clip.duration))
			action_count += 1
		track_item.collapsed = false
	if action_count == 0 and _sequence.tracks.is_empty():
		var empty_item := create_item(root)
		empty_item.set_text(1, "No tracks.")
	_restore_selection()


func _get_track_summary(clip_count: int, states: Array[String]) -> String:
	var summary := "%d clip%s" % [clip_count, "" if clip_count == 1 else "s"]
	if not states.is_empty():
		summary += " · " + ", ".join(states)
	return summary


func _get_track_tooltip(track: MatineeTrack, states: Array[String]) -> String:
	var lines := [
		"Track: %s" % track.track_name,
		"Clips: %d" % track.actions.size(),
	]
	if not states.is_empty():
		lines.append("State: %s" % ", ".join(states))
	return "\n".join(lines)


func _restore_selection() -> void:
	if _selection_state == null:
		return
	if _selection_state.action_index >= 0:
		select_timeline_action(_selection_state.track_index, _selection_state.action_index)
	elif _selection_state.track_index >= 0:
		select_track(_selection_state.track_index)
	else:
		deselect_all()


func _on_selection_state_cleared() -> void:
	deselect_all()


func _get_drag_data(at_position: Vector2) -> Variant:
	var item := get_item_at_position(at_position)
	if item == null or not is_instance_valid(_sequence) or not _sequence.is_current_track_format():
		return null
	var metadata := item.get_metadata(0)
	if not metadata is Dictionary:
		return null
	var track_index := int(metadata["track_index"])
	if track_index < 0 or track_index >= _sequence.tracks.size() or _sequence.tracks[track_index] == null:
		return null
	if _sequence.tracks[track_index].locked:
		return null
	var preview := Label.new()
	preview.text = item.get_text(1)
	set_drag_preview(preview)
	if metadata.get("item_type", &"") == &"track":
		return {"item_type": &"track", "source_track_index": track_index}
	return {"item_type": &"timeline_action", "source_track_index": track_index, "source_action_index": int(metadata["action_index"])}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.get("item_type", &"") in [&"timeline_action", &"track"]
		and is_instance_valid(_sequence)
		and _sequence.is_current_track_format()
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var item_type: StringName = data.get("item_type", &"")
	var target := get_item_at_position(at_position)
	if target == null:
		return
	var metadata := target.get_metadata(0)
	if not metadata is Dictionary:
		return
	var destination_track_index := int(metadata.get("track_index", -1))
	if destination_track_index < 0 or destination_track_index >= _sequence.tracks.size():
		return
	if _sequence.tracks[destination_track_index] == null or _sequence.tracks[destination_track_index].locked:
		return
	if item_type == &"track":
		var source_track_index := int(data.get("source_track_index", -1))
		if source_track_index != destination_track_index:
			track_move_requested.emit(source_track_index, destination_track_index)
		return
	var destination_action_index := int(metadata.get("action_index", -1))
	if destination_action_index < 0:
		destination_action_index = _sequence.tracks[destination_track_index].actions.size()
	elif get_drop_section_at_position(at_position) > 0:
		destination_action_index += 1
	var source_track_index := int(data["source_track_index"])
	var source_action_index := int(data["source_action_index"])
	if source_track_index == destination_track_index and source_action_index < destination_action_index:
		destination_action_index -= 1
	if source_track_index == destination_track_index and source_action_index == destination_action_index:
		return
	timeline_action_move_requested.emit(source_track_index, source_action_index, destination_track_index, destination_action_index)


func _get_action_icon(action: MatineeAction) -> Texture2D:
	var icon_name := &"Resource"

	match action.get_editor_name():
		"Dialogue":
			icon_name = &"RichTextLabel"
		"Music", "Ambience", "Sound Effect", "Voice":
			icon_name = &"AudioStreamPlayer"
		"Fade", "Presentation", "Title Card", "Chapter Card", "Location Card":
			icon_name = &"Animation"
		"Scene Change":
			icon_name = &"PackedScene"
		"Wait":
			icon_name = &"Timer"
		"Cinematic", "Camera":
			icon_name = &"Camera2D"

	if has_theme_icon(icon_name, &"EditorIcons"):
		return get_theme_icon(icon_name, &"EditorIcons")
	if has_theme_icon(&"Resource", &"EditorIcons"):
		return get_theme_icon(&"Resource", &"EditorIcons")
	return null


func _get_action_tooltip(action: MatineeAction, start_time: float, duration: float) -> String:
	var timing := "Exact" if action.has_exact_duration() else "Minimum / dynamic"
	var tooltip := "Start: %s\nDuration: %s\nTiming: %s" % [
		_format_time(start_time),
		_format_duration(duration),
		timing
	]
	var preview := _get_action_preview_text(action)
	if not preview.is_empty():
		tooltip += "\nPreview: %s" % preview
	if action is MatineeCameraAction:
		var camera := action as MatineeCameraAction
		tooltip += "\nTarget: %s" % (str(camera.camera_path) if not camera.camera_path.is_empty() else "Missing")
		tooltip += "\nTransition: %s" % ("Cut" if camera.is_cut() else "Blend %.2fs" % camera.blend_duration)
		tooltip += "\nFollow: %s" % (str(camera.follow_target_path) if camera.use_follow_target else "Disabled")
		tooltip += "\nZoom: %s" % (str(camera.zoom_override) if camera.use_zoom_override else "Configured camera zoom")
	tooltip += "\nResource: %s" % (action.resource_path if not action.resource_path.is_empty() else "Built into sequence")
	return tooltip


func _get_action_label(action: MatineeAction) -> String:
	if action == null:
		return "Missing action"
	var base_name := action.get_editor_name()
	var preview := _get_action_preview_text(action)
	if preview.is_empty():
		return base_name
	return "%s: %s" % [base_name, preview]


func _get_action_preview_text(action: MatineeAction) -> String:
	if action == null:
		return ""
	var text := ""
	match action.get_editor_name():
		"Dialogue":
			text = str(action.get("message"))
		"Title Card":
			text = str(action.get("main_text"))
			if text.strip_edges().is_empty():
				text = str(action.get("subtitle"))
		"Camera":
			text = action.get_editor_summary()
		_:
			return ""
	return _compact_single_line(text)


func _compact_single_line(value: String) -> String:
	var compact := value.replace("\r", " ").replace("\n", " ").strip_edges()
	while compact.find("  ") >= 0:
		compact = compact.replace("  ", " ")
	return compact


func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var whole_seconds := int(seconds) % 60
	var tenths := int(floor(fmod(seconds, 1.0) * 10.0 + 0.0001))
	return "%02d:%02d.%d" % [minutes, whole_seconds, tenths]


func _format_duration(seconds: float) -> String:
	return "%.1fs" % seconds
