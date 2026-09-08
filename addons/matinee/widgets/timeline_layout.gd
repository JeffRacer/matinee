@tool
class_name MatineeTimelineLayout
extends RefCounted

const DEFAULT_LABEL_WIDTH := 132.0
const DEFAULT_RULER_HEIGHT := 30.0
const DEFAULT_ROW_HEIGHT := 44.0
const DEFAULT_BAR_MARGIN := 5.0
const DEFAULT_MIN_BAR_WIDTH := 8.0
const DEFAULT_MIN_CANVAS_WIDTH := 420.0
const DEFAULT_DEBUG_LINE_HEIGHT := 16.0
const DEFAULT_DEBUG_MIN_WIDTH := 1180.0
const MIN_PIXELS_PER_SECOND := 12.0
const MAX_PIXELS_PER_SECOND := 3840.0

var label_width := DEFAULT_LABEL_WIDTH
var ruler_height := DEFAULT_RULER_HEIGHT
var row_height := DEFAULT_ROW_HEIGHT
var bar_margin := DEFAULT_BAR_MARGIN
var min_bar_width := DEFAULT_MIN_BAR_WIDTH
var min_canvas_width := DEFAULT_MIN_CANVAS_WIDTH
var debug_line_height := DEFAULT_DEBUG_LINE_HEIGHT
var debug_min_width := DEFAULT_DEBUG_MIN_WIDTH
var pixels_per_second := 48.0
var canvas_size := Vector2(min_canvas_width, ruler_height + row_height)
var visible_rect := Rect2(Vector2.ZERO, canvas_size)


func set_pixels_per_second(value: float) -> void:
	pixels_per_second = clampf(value, MIN_PIXELS_PER_SECOND, MAX_PIXELS_PER_SECOND)


func set_canvas_size(value: Vector2) -> void:
	canvas_size = Vector2(maxf(value.x, min_canvas_width), maxf(value.y, ruler_height + row_height))


func set_visible_rect(value: Rect2) -> void:
	visible_rect = value


func time_to_x(time: float) -> float:
	return label_width + maxf(time, 0.0) * pixels_per_second


func x_to_time(x: float) -> float:
	return maxf((x - label_width) / pixels_per_second, 0.0)


func row_y(index: int) -> float:
	return ruler_height + float(index) * row_height


func row_index_at(position_y: float) -> int:
	if position_y < ruler_height:
		return -1
	return int(floor((position_y - ruler_height) / row_height))


func ruler_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(canvas_size.x, ruler_height))


func content_rect() -> Rect2:
	return Rect2(label_width, ruler_height, maxf(canvas_size.x - label_width, 0.0), maxf(canvas_size.y - ruler_height, 0.0))


func track_header_rect(track_index: int) -> Rect2:
	return Rect2(0.0, row_y(track_index), label_width, row_height)


func track_row_rect(track_index: int) -> Rect2:
	return Rect2(0.0, row_y(track_index), canvas_size.x, row_height)


func clip_rect(track_index: int, start_time: float, duration: float) -> Rect2:
	return Rect2(
		time_to_x(start_time),
		row_y(track_index) + bar_margin,
		maxf(maxf(duration, 0.0) * pixels_per_second, min_bar_width),
		row_height - bar_margin * 2.0
	)


func clip_text_rect(rect: Rect2, padding: float) -> Rect2:
	return Rect2(
		rect.position.x + padding,
		rect.position.y,
		maxf(rect.size.x - padding * 2.0, 0.0),
		rect.size.y
	)


func debug_overlay_rect(row_count: int, debug_line_count: int) -> Rect2:
	var debug_y := row_y(maxi(row_count, 1))
	var overlay_height := maxf(float(debug_line_count) * debug_line_height + 8.0, debug_line_height + 8.0)
	return Rect2(0.0, debug_y, canvas_size.x, overlay_height)


func content_height(row_count: int, debug_line_count: int, debug_enabled: bool) -> float:
	var result := ruler_height + float(maxi(row_count, 1)) * row_height
	if debug_enabled:
		result += debug_overlay_rect(row_count, debug_line_count).size.y
	return result


func canvas_width(total_duration: float, debug_enabled: bool) -> float:
	var result := label_width + maxf(total_duration, 0.0) * pixels_per_second + 80.0
	if debug_enabled:
		result = maxf(result, debug_min_width)
	return maxf(result, min_canvas_width)


func canvas_minimum_size(total_duration: float, row_count: int, debug_line_count: int, debug_enabled: bool) -> Vector2:
	return Vector2(
		canvas_width(total_duration, debug_enabled),
		content_height(row_count, debug_line_count, debug_enabled)
	)


func visible_time_range() -> Dictionary:
	var start_time := x_to_time(visible_rect.position.x)
	var end_time := x_to_time(visible_rect.position.x + visible_rect.size.x)
	return {
		"start": start_time,
		"end": maxf(end_time, start_time),
	}


func drag_destination_row(position_y: float, row_count: int) -> int:
	return clampi(row_index_at(position_y), 0, maxi(row_count - 1, 0))


func snapped_time_for_x(position_x: float, snap_interval: float) -> float:
	return snappedf(x_to_time(position_x), snap_interval)


func is_event_marker(duration: float) -> bool:
	return is_zero_approx(maxf(duration, 0.0))
