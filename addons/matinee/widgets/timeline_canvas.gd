@tool
class_name MatineeTimelineCanvas
extends Control

signal timeline_action_selected(action: MatineeAction, track_index: int, action_index: int)
signal track_selected(track: MatineeTrack, track_index: int)
signal timeline_action_move_requested(source_track_index: int, source_action_index: int, destination_track_index: int, start_time: float)
signal seek_requested(time: float)
signal zoom_requested(factor: float, canvas_x: float)
signal pan_requested(delta_x: float)
signal action_drag_started(canvas_position: Vector2)
signal action_drag_moved(canvas_position: Vector2)
signal action_drag_finished

const TimelineLayout := preload("res://addons/matinee/widgets/timeline_layout.gd")
const TimelineStyle := preload("res://addons/matinee/widgets/timeline_style.gd")
const TimelineRenderer := preload("res://addons/matinee/widgets/timeline_renderer.gd")
const TimelineInteraction := preload("res://addons/matinee/widgets/timeline_interaction.gd")
const TimelineDebugOverlay := preload("res://addons/matinee/widgets/timeline_debug_overlay.gd")

const LABEL_WIDTH := TimelineLayout.DEFAULT_LABEL_WIDTH
const RULER_HEIGHT := TimelineLayout.DEFAULT_RULER_HEIGHT
const ROW_HEIGHT := TimelineLayout.DEFAULT_ROW_HEIGHT
const BAR_MARGIN := TimelineLayout.DEFAULT_BAR_MARGIN
const MIN_BAR_WIDTH := TimelineLayout.DEFAULT_MIN_BAR_WIDTH
const MIN_CANVAS_WIDTH := TimelineLayout.DEFAULT_MIN_CANVAS_WIDTH

var _sequence: MatineeSequence
var _selection_state: MatineeSelectionState
var _layout: Variant = TimelineLayout.new()
var _renderer: Variant = TimelineRenderer.new()
var _interaction: Variant = TimelineInteraction.new()
var _debug_overlay: Variant = TimelineDebugOverlay.new()
var _selected_index := -1
var _active_index := -1
var _active_timeline_actions := {}
var _playback_time := 0.0
var _debug_enabled := false
var _debug_snapshot: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	mouse_exited.connect(_on_mouse_exited)
	focus_exited.connect(_on_focus_exited)
	_connect_interaction_signals()
	_update_layout_bounds()
	_update_minimum_size()
	_refresh_debug_snapshot()
	queue_redraw()


func set_sequence(sequence: MatineeSequence) -> void:
	_sequence = sequence
	_playback_time = 0.0
	_active_index = -1
	_interaction.reset()
	_update_layout_bounds()
	_update_minimum_size()
	_refresh_debug_snapshot()
	queue_redraw()


func clear_sequence() -> void:
	_sequence = null
	_selected_index = -1
	_active_index = -1
	_playback_time = 0.0
	_interaction.reset()
	_update_layout_bounds()
	_update_minimum_size()
	_refresh_debug_snapshot()
	queue_redraw()


func set_selection_state(selection_state: MatineeSelectionState) -> void:
	if _selection_state == selection_state:
		return

	if _selection_state != null:
		if _selection_state.action_changed.is_connected(_on_selection_changed):
			_selection_state.action_changed.disconnect(_on_selection_changed)
		if _selection_state.track_changed.is_connected(_on_track_selection_changed):
			_selection_state.track_changed.disconnect(_on_track_selection_changed)
		if _selection_state.selection_cleared.is_connected(_on_selection_cleared):
			_selection_state.selection_cleared.disconnect(_on_selection_cleared)

	_selection_state = selection_state
	_selected_index = -1

	if _selection_state != null:
		_selection_state.action_changed.connect(_on_selection_changed)
		_selection_state.track_changed.connect(_on_track_selection_changed)
		_selection_state.selection_cleared.connect(_on_selection_cleared)
		_selected_index = _selection_state.action_index

	_refresh_debug_snapshot()
	queue_redraw()


func set_pixels_per_second(value: float) -> void:
	_layout.set_pixels_per_second(value)
	_update_layout_bounds()
	_update_minimum_size()
	_refresh_debug_snapshot()
	queue_redraw()


func set_label_width(value: float) -> void:
	_layout.label_width = clampf(value, 96.0, 420.0)
	_update_layout_bounds()
	_update_minimum_size()
	_refresh_debug_snapshot()
	queue_redraw()


func get_pixels_per_second() -> float:
	return _layout.pixels_per_second


func get_label_width() -> float:
	return _layout.label_width


func set_playback_time(time: float) -> void:
	_playback_time = clampf(time, 0.0, get_total_duration())
	queue_redraw()


func set_active_action(index: int) -> void:
	_active_index = index
	queue_redraw()


func set_active_timeline_actions(entries: Array[Dictionary]) -> void:
	var next_active := {}
	for entry in entries:
		next_active["%d:%d" % [int(entry["track_index"]), int(entry["action_index"])]] = true
	if next_active == _active_timeline_actions:
		return
	_active_timeline_actions = next_active
	_refresh_debug_snapshot()
	queue_redraw()


func set_debug_enabled(enabled: bool) -> void:
	if _debug_enabled == enabled:
		return
	_debug_enabled = enabled
	if not enabled:
		_debug_overlay.reset()
	_update_layout_bounds()
	_update_minimum_size()
	_refresh_debug_snapshot()
	queue_redraw()


func get_track_debug_snapshot() -> Array[Dictionary]:
	_update_layout_bounds()
	return _debug_overlay.build_snapshot(_sequence, _selection_state, _active_timeline_actions, _layout).duplicate(true)


func get_playhead_x() -> float:
	return _layout.time_to_x(_playback_time)


func get_total_duration() -> float:
	if not is_instance_valid(_sequence):
		return 0.0
	return _sequence.get_duration_seconds()


func _fit_text_to_width(font: Font, value: String, width: float, font_size: int) -> String:
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


func _gui_input(event: InputEvent) -> void:
	_update_layout_bounds()
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		grab_focus()
	if _interaction.handle_gui_input(event, _sequence, _layout, get_total_duration()):
		accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	if not is_instance_valid(_sequence):
		return ""
	_update_layout_bounds()
	for track_index in range(_sequence.tracks.size()):
		var track := _sequence.tracks[track_index]
		if track == null:
			continue
		for timeline_action in track.actions:
			if timeline_action == null or timeline_action.action == null:
				continue
			var rect: Rect2 = _layout.clip_rect(
				track_index,
				timeline_action.start_time,
				timeline_action.duration
			)
			if rect.has_point(at_position):
				return _get_clip_tooltip(timeline_action)
	return ""


func _get_clip_tooltip(timeline_action: MatineeTimelineAction) -> String:
	var action := timeline_action.action
	var tooltip := "%s\nStart: %.2fs\nDuration: %.2fs" % [
		action.get_editor_name(),
		timeline_action.start_time,
		timeline_action.duration,
	]
	if action is MatineeCameraAction:
		var camera := action as MatineeCameraAction
		tooltip += "\nTarget camera: %s" % (str(camera.camera_path) if not camera.camera_path.is_empty() else "Missing")
		tooltip += "\nMode: %s" % ("Cut" if camera.is_cut() else "Blend %.2fs" % camera.blend_duration)
		tooltip += "\nFollow target: %s" % (str(camera.follow_target_path) if camera.use_follow_target else "Disabled")
		tooltip += "\nZoom override: %s" % (str(camera.zoom_override) if camera.use_zoom_override else "Disabled")
	return tooltip


func _draw() -> void:
	_update_layout_bounds()
	var style: Variant = TimelineStyle.capture(self)
	var state := {
		"sequence": _sequence,
		"selection_state": _selection_state,
		"selected_index": _selected_index,
		"active_index": _active_index,
		"active_timeline_actions": _active_timeline_actions,
		"hovered_index": _interaction.get_hovered_index(),
		"playback_time": _playback_time,
		"debug_enabled": _debug_enabled,
		"debug_snapshot": _debug_snapshot,
		"debug_overlay": _debug_overlay,
		"track_drag_active": _interaction.is_track_drag_active(),
		"pressed_track_index": _interaction.get_pressed_track_index(),
		"pressed_track_action_index": _interaction.get_pressed_track_action_index(),
		"track_drag_destination": _interaction.get_track_drag_destination(),
		"track_drag_start_time": _interaction.get_track_drag_start_time(),
		"interaction": _interaction,
	}
	_renderer.draw(self, _layout, style, state)


func offset_action_drag(scroll_delta: Vector2) -> void:
	_interaction.offset_action_drag(_sequence, _layout, scroll_delta)


func _connect_interaction_signals() -> void:
	_interaction.timeline_action_selected.connect(func(action: MatineeAction, track_index: int, action_index: int) -> void: timeline_action_selected.emit(action, track_index, action_index))
	_interaction.track_selected.connect(func(track: MatineeTrack, track_index: int) -> void: track_selected.emit(track, track_index))
	_interaction.timeline_action_move_requested.connect(func(source_track_index: int, source_action_index: int, destination_track_index: int, start_time: float) -> void: timeline_action_move_requested.emit(source_track_index, source_action_index, destination_track_index, start_time))
	_interaction.seek_requested.connect(func(time: float) -> void: seek_requested.emit(time))
	_interaction.zoom_requested.connect(func(factor: float, canvas_x: float) -> void: zoom_requested.emit(factor, canvas_x))
	_interaction.pan_requested.connect(func(delta_x: float) -> void: pan_requested.emit(delta_x))
	_interaction.action_drag_started.connect(func(canvas_position: Vector2) -> void: action_drag_started.emit(canvas_position))
	_interaction.action_drag_moved.connect(func(canvas_position: Vector2) -> void: action_drag_moved.emit(canvas_position))
	_interaction.action_drag_finished.connect(func() -> void: action_drag_finished.emit())
	_interaction.cursor_shape_changed.connect(func(cursor_shape: int) -> void: mouse_default_cursor_shape = cursor_shape)
	_interaction.redraw_requested.connect(queue_redraw)


func _update_layout_bounds() -> void:
	_layout.set_canvas_size(size)
	_layout.set_visible_rect(_get_visible_canvas_rect())


func _update_minimum_size() -> void:
	var row_count := 1
	if is_instance_valid(_sequence):
		row_count = _sequence.tracks.size()
	var debug_line_count: int = _debug_overlay.get_line_count(_sequence) if _debug_enabled else 0
	custom_minimum_size = _layout.canvas_minimum_size(get_total_duration(), row_count, debug_line_count, _debug_enabled)


func _get_visible_canvas_rect() -> Rect2:
	var scroll_container := get_parent() as ScrollContainer
	if scroll_container == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical), scroll_container.size)


func _refresh_debug_snapshot() -> void:
	if not _debug_enabled:
		_debug_snapshot.clear()
		return
	_update_layout_bounds()
	_debug_snapshot = _debug_overlay.build_snapshot(_sequence, _selection_state, _active_timeline_actions, _layout)
	for message in _debug_overlay.collect_issue_messages(_debug_snapshot):
		push_warning("Matinee Track Debug: " + message)


func _on_mouse_exited() -> void:
	if _interaction.is_pointer_busy():
		return
	_interaction.clear_hover()


func _on_focus_exited() -> void:
	_interaction.cancel_pointer_gesture()


func _on_selection_changed(_action: MatineeAction, index: int) -> void:
	_selected_index = index
	_refresh_debug_snapshot()
	queue_redraw()


func _on_selection_cleared() -> void:
	_selected_index = -1
	_refresh_debug_snapshot()
	queue_redraw()


func _on_track_selection_changed(_track: MatineeTrack, _track_index: int) -> void:
	_selected_index = -1
	_refresh_debug_snapshot()
	queue_redraw()


func refresh_from_sequence() -> void:
	if not is_instance_valid(_sequence):
		return
	_update_layout_bounds()
	_update_minimum_size()
	_refresh_debug_snapshot()
	queue_redraw()
