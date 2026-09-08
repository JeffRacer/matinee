@tool
class_name MatineeTimeline
extends VBoxContainer

signal timeline_action_selected(action: MatineeAction, track_index: int, action_index: int)
signal track_selected(track: MatineeTrack, track_index: int)
signal timeline_action_move_requested(source_track_index: int, source_action_index: int, destination_track_index: int, start_time: float)
signal seek_requested(time: float)

const TimelineLayout := preload("res://addons/matinee/widgets/timeline_layout.gd")

const MIN_ZOOM := TimelineLayout.MIN_PIXELS_PER_SECOND
const MAX_ZOOM := TimelineLayout.MAX_PIXELS_PER_SECOND
const ZOOM_FACTOR := 1.25
const LABEL_WIDTH_COMPACT := 132.0
const LABEL_WIDTH_EXPANDED := 300.0
const AUTO_SCROLL_EDGE := 40.0
const AUTO_SCROLL_MAX_SPEED := 520.0

var _sequence: MatineeSequence
var _auto_follow_enabled := true
var _playback_active := false
var _follow_suspended := false
var _action_drag_active := false
var _action_drag_canvas_position := Vector2.ZERO
var _scroll_clamp_pending := false

@onready var _zoom_out_button: Button = $TimelineToolbar/ZoomOutButton
@onready var _zoom_label: Label = $TimelineToolbar/ZoomLabel
@onready var _zoom_in_button: Button = $TimelineToolbar/ZoomInButton
@onready var _fit_button: Button = $TimelineToolbar/FitButton
@onready var _debug_button: CheckButton = $TimelineToolbar/DebugButton
@onready var _track_names_button: CheckButton = $TimelineToolbar/TrackNamesButton
@onready var _scroll_container: ScrollContainer = $ScrollContainer
@onready var _canvas = $ScrollContainer/TimelineCanvas


func _ready() -> void:
	_zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	_zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	_fit_button.pressed.connect(_on_fit_pressed)
	_debug_button.toggled.connect(_on_debug_toggled)
	_track_names_button.toggled.connect(_on_track_names_toggled)
	_canvas.timeline_action_selected.connect(func(action: MatineeAction, track_index: int, action_index: int) -> void: timeline_action_selected.emit(action, track_index, action_index))
	_canvas.track_selected.connect(func(track: MatineeTrack, track_index: int) -> void: track_selected.emit(track, track_index))
	_canvas.timeline_action_move_requested.connect(func(source_track_index: int, source_action_index: int, destination_track_index: int, start_time: float) -> void: timeline_action_move_requested.emit(source_track_index, source_action_index, destination_track_index, start_time))
	_canvas.seek_requested.connect(_on_canvas_seek_requested)
	_canvas.zoom_requested.connect(_on_canvas_zoom_requested)
	_canvas.pan_requested.connect(_on_canvas_pan_requested)
	_canvas.action_drag_started.connect(_on_action_drag_started)
	_canvas.action_drag_moved.connect(_on_action_drag_moved)
	_canvas.action_drag_finished.connect(_on_action_drag_finished)
	_canvas.minimum_size_changed.connect(_schedule_scroll_clamp)
	var horizontal_bar := _scroll_container.get_h_scroll_bar()
	var vertical_bar := _scroll_container.get_v_scroll_bar()
	horizontal_bar.gui_input.connect(_on_horizontal_scrollbar_gui_input)
	horizontal_bar.changed.connect(_schedule_scroll_clamp)
	vertical_bar.changed.connect(_schedule_scroll_clamp)
	set_process(false)
	_on_track_names_toggled(_track_names_button.button_pressed)
	_update_zoom_label()


func _process(delta: float) -> void:
	if not _action_drag_active or delta <= 0.0:
		return

	var viewport_position := _action_drag_canvas_position - Vector2(
		float(_scroll_container.scroll_horizontal),
		float(_scroll_container.scroll_vertical)
	)
	var scroll_velocity := Vector2(
		_get_edge_scroll_velocity(viewport_position.x, _scroll_container.size.x),
		_get_edge_scroll_velocity(viewport_position.y, _scroll_container.size.y)
	)
	if scroll_velocity.is_zero_approx():
		return

	var old_scroll := Vector2(
		float(_scroll_container.scroll_horizontal),
		float(_scroll_container.scroll_vertical)
	)
	var requested_scroll := old_scroll + scroll_velocity * delta
	var applied_scroll := _set_scroll_position(requested_scroll) - old_scroll
	_canvas.offset_action_drag(applied_scroll)


func set_sequence(sequence: MatineeSequence) -> void:
	_sequence = sequence
	_canvas.set_sequence(sequence)


func clear_sequence() -> void:
	_sequence = null
	_canvas.clear_sequence()


func set_selection_state(selection_state: MatineeSelectionState) -> void:
	_canvas.set_selection_state(selection_state)


func set_playback_time(time: float) -> void:
	_canvas.set_playback_time(time)
	if not _auto_follow_enabled or not _playback_active or _follow_suspended:
		return
	var playhead_x: float = _canvas.get_playhead_x()
	var viewport_width := _scroll_container.size.x
	if viewport_width <= 0.0:
		return
	var follow_margin := minf(40.0, viewport_width * 0.25)
	var left_edge := float(_scroll_container.scroll_horizontal)
	var right_edge := left_edge + viewport_width
	if playhead_x < left_edge + follow_margin:
		_set_scroll_position(Vector2(
			playhead_x - follow_margin,
			_scroll_container.scroll_vertical
		))
	elif playhead_x > right_edge - follow_margin:
		_set_scroll_position(Vector2(
			playhead_x - viewport_width + follow_margin,
			_scroll_container.scroll_vertical
		))


func set_active_action(index: int) -> void:
	_canvas.set_active_action(index)


func set_active_timeline_actions(entries: Array[Dictionary]) -> void:
	_canvas.set_active_timeline_actions(entries)


func get_track_debug_snapshot() -> Array[Dictionary]:
	return _canvas.get_track_debug_snapshot()


func set_auto_follow(enabled: bool) -> void:
	_auto_follow_enabled = enabled
	if not enabled:
		_follow_suspended = false


func set_playback_active(active: bool) -> void:
	if active and not _playback_active:
		_follow_suspended = false
	_playback_active = active


func _on_zoom_out_pressed() -> void:
	_suspend_auto_follow()
	_set_zoom(_canvas.get_pixels_per_second() / ZOOM_FACTOR)


func _on_zoom_in_pressed() -> void:
	_suspend_auto_follow()
	_set_zoom(_canvas.get_pixels_per_second() * ZOOM_FACTOR)


func _on_fit_pressed() -> void:
	if not is_instance_valid(_sequence):
		return
	_suspend_auto_follow()

	var duration: float = _canvas.get_total_duration()
	if duration <= 0.0:
		_set_zoom(48.0)
		return

	var available_width := maxf(_scroll_container.size.x - 160.0, 120.0)
	_set_zoom(available_width / duration)
	_set_scroll_position(Vector2(0.0, _scroll_container.scroll_vertical))


func _on_debug_toggled(enabled: bool) -> void:
	_canvas.set_debug_enabled(enabled)
	_schedule_scroll_clamp()


func _on_track_names_toggled(expanded: bool) -> void:
	var old_width: float = _canvas.get_label_width()
	var new_width: float = LABEL_WIDTH_EXPANDED if expanded else LABEL_WIDTH_COMPACT
	if is_equal_approx(old_width, new_width):
		return
	var zoom: float = _canvas.get_pixels_per_second()
	var old_scroll: float = float(_scroll_container.scroll_horizontal)
	var left_time: float = maxf((old_scroll - old_width) / zoom, 0.0)
	_canvas.set_label_width(new_width)
	var new_scroll: float = new_width + left_time * zoom
	_set_scroll_position(Vector2(new_scroll, _scroll_container.scroll_vertical))


func _set_zoom(value: float) -> void:
	_canvas.set_pixels_per_second(clampf(value, MIN_ZOOM, MAX_ZOOM))
	_update_zoom_label()


func _on_canvas_zoom_requested(factor: float, canvas_x: float) -> void:
	_suspend_auto_follow()
	var old_zoom: float = _canvas.get_pixels_per_second()
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var old_scroll := float(_scroll_container.scroll_horizontal)
	var viewport_anchor_x := canvas_x - old_scroll
	var anchor_time := maxf((canvas_x - _canvas.get_label_width()) / old_zoom, 0.0)

	_canvas.set_pixels_per_second(new_zoom)
	_update_zoom_label()

	var new_canvas_x: float = _canvas.get_label_width() + anchor_time * new_zoom
	var target_scroll: float = new_canvas_x - viewport_anchor_x
	_set_scroll_position(Vector2(target_scroll, _scroll_container.scroll_vertical))


func _on_canvas_pan_requested(delta_x: float) -> void:
	_suspend_auto_follow()
	var target: float = float(_scroll_container.scroll_horizontal) - delta_x
	_set_scroll_position(Vector2(target, _scroll_container.scroll_vertical))


func _on_canvas_seek_requested(time: float) -> void:
	_suspend_auto_follow()
	seek_requested.emit(time)


func _on_horizontal_scrollbar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_suspend_auto_follow()


func _on_action_drag_started(canvas_position: Vector2) -> void:
	_action_drag_active = true
	_action_drag_canvas_position = canvas_position
	_suspend_auto_follow()
	set_process(true)


func _on_action_drag_moved(canvas_position: Vector2) -> void:
	_action_drag_canvas_position = canvas_position


func _on_action_drag_finished() -> void:
	_action_drag_active = false
	_action_drag_canvas_position = Vector2.ZERO
	set_process(false)


func _get_edge_scroll_velocity(position: float, viewport_extent: float) -> float:
	if viewport_extent <= 0.0:
		return 0.0
	var edge_size := minf(AUTO_SCROLL_EDGE, viewport_extent * 0.25)
	if position < edge_size:
		return -AUTO_SCROLL_MAX_SPEED * clampf((edge_size - position) / edge_size, 0.0, 1.0)
	if position > viewport_extent - edge_size:
		return AUTO_SCROLL_MAX_SPEED * clampf(
			(position - (viewport_extent - edge_size)) / edge_size,
			0.0,
			1.0
		)
	return 0.0


func _schedule_scroll_clamp() -> void:
	if _scroll_clamp_pending:
		return
	_scroll_clamp_pending = true
	call_deferred("_clamp_scroll_to_content")


func _clamp_scroll_to_content() -> void:
	_scroll_clamp_pending = false
	if not is_inside_tree():
		return
	_set_scroll_position(Vector2(
		float(_scroll_container.scroll_horizontal),
		float(_scroll_container.scroll_vertical)
	))


func _set_scroll_position(target: Vector2) -> Vector2:
	var horizontal_bar := _scroll_container.get_h_scroll_bar()
	var vertical_bar := _scroll_container.get_v_scroll_bar()
	var horizontal_limit := maxf(horizontal_bar.max_value - horizontal_bar.page, 0.0)
	var vertical_limit := maxf(vertical_bar.max_value - vertical_bar.page, 0.0)
	_scroll_container.scroll_horizontal = int(round(clampf(target.x, 0.0, horizontal_limit)))
	_scroll_container.scroll_vertical = int(round(clampf(target.y, 0.0, vertical_limit)))
	return Vector2(
		float(_scroll_container.scroll_horizontal),
		float(_scroll_container.scroll_vertical)
	)


func _suspend_auto_follow() -> void:
	if _playback_active:
		_follow_suspended = true


func _update_zoom_label() -> void:
	if not is_instance_valid(_canvas):
		return
	_zoom_label.text = "%d px/s" % int(round(_canvas.get_pixels_per_second()))


func refresh_from_sequence() -> void:
	_canvas.refresh_from_sequence()
	_schedule_scroll_clamp()
