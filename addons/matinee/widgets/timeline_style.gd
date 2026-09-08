@tool
class_name MatineeTimelineStyle
extends RefCounted

var panel_background := Color(0.16, 0.16, 0.16, 1.0)
var ruler_background := Color(0.18, 0.18, 0.18, 1.0)
var row_primary := Color(0.18, 0.18, 0.18, 1.0)
var row_alternate := Color(0.2, 0.2, 0.2, 1.0)
var track_header_background := Color(0.2, 0.2, 0.2, 1.0)
var selected_track := Color(0.33, 0.55, 0.9, 0.18)
var hovered_track := Color(0.33, 0.55, 0.9, 0.08)
var selected_clip_outline := Color(0.33, 0.55, 0.9, 1.0)
var active_clip_outline := Color(0.2, 0.78, 0.45, 1.0)
var selected_active_clip_outline := Color(0.35, 0.86, 0.58, 1.0)
var muted_clip_overlay := Color(0.0, 0.0, 0.0, 0.26)
var disabled_clip_overlay := Color(0.08, 0.08, 0.08, 0.3)
var invalid_clip_fill := Color(0.78, 0.38, 0.2, 0.92)
var invalid_clip_outline := Color(0.97, 0.65, 0.24, 1.0)
var grid_major := Color(1.0, 1.0, 1.0, 0.16)
var grid_minor := Color(1.0, 1.0, 1.0, 0.08)
var separator := Color(1.0, 1.0, 1.0, 0.16)
var playhead := Color(0.95, 0.28, 0.22, 1.0)
var playhead_glow := Color(0.95, 0.28, 0.22, 0.18)
var drag_ghost := Color(0.33, 0.55, 0.9, 0.42)
var drop_destination := Color(0.33, 0.55, 0.9, 0.18)
var snap_guide := Color(0.33, 0.55, 0.9, 0.9)
var text_primary := Color(0.9, 0.9, 0.9, 1.0)
var text_secondary := Color(0.72, 0.72, 0.72, 1.0)
var warning_text := Color(0.96, 0.74, 0.28, 1.0)
var warning_panel := Color(0.08, 0.08, 0.08, 0.78)
var badge_background := Color(0.0, 0.0, 0.0, 0.18)


static func capture(control: Control):
	var style = load("res://addons/matinee/widgets/timeline_style.gd").new()
	style.text_primary = control.get_theme_color(&"font_color", &"Label")
	style.text_secondary = control.get_theme_color(&"font_disabled_color", &"Label")
	var accent: Color = control.get_theme_color(&"accent_color", &"Editor")
	var panel: Color = control.get_theme_color(&"dark_color_1", &"Editor")
	var line: Color = control.get_theme_color(&"dark_color_3", &"Editor")
	style.panel_background = panel
	style.ruler_background = _shift_toward_contrast(panel, 0.08)
	style.row_primary = panel
	style.row_alternate = _shift_toward_contrast(panel, 0.035)
	style.track_header_background = _shift_toward_contrast(panel, 0.06)
	style.selected_track = Color(accent, 0.16)
	style.hovered_track = Color(accent, 0.07)
	style.selected_clip_outline = accent
	style.active_clip_outline = accent.lerp(Color(0.2, 0.82, 0.54, 1.0), 0.55)
	style.selected_active_clip_outline = accent.lerp(style.active_clip_outline, 0.5)
	style.grid_major = Color(line, 0.34)
	style.grid_minor = Color(line, 0.16)
	style.separator = Color(line, 0.9)
	style.playhead = accent.lerp(Color(1.0, 0.32, 0.12, 1.0), 0.55)
	style.playhead_glow = Color(style.playhead, 0.18)
	style.drag_ghost = Color(accent, 0.42)
	style.drop_destination = Color(accent, 0.18)
	style.snap_guide = Color(accent, 0.92)
	style.warning_text = style.text_primary.lerp(Color(0.97, 0.73, 0.24, 1.0), 0.78)
	style.warning_panel = Color(_shift_toward_contrast(panel, 0.03), 0.9)
	style.invalid_clip_fill = Color(style.warning_text.lerp(panel, 0.25), 0.9)
	style.invalid_clip_outline = style.warning_text
	style.badge_background = Color(style.text_primary, 0.08)
	return style


func clip_fill(base_color: Color, track_muted: bool, track_enabled: bool, action_enabled: bool, invalid: bool) -> Color:
	if invalid:
		return invalid_clip_fill
	var fill: Color = base_color
	fill.a = 0.88
	if track_muted:
		fill = fill.lerp(panel_background, 0.42)
		fill.a = 0.72
	if not track_enabled:
		fill = fill.lerp(panel_background, 0.52)
		fill.a = 0.54
	if not action_enabled:
		fill = fill.lerp(panel_background, 0.36)
		fill.a = minf(fill.a, 0.52)
	return fill


func clip_outline(selected: bool, active: bool, invalid: bool, fill: Color) -> Color:
	if invalid:
		return invalid_clip_outline
	if selected and active:
		return selected_active_clip_outline
	if selected:
		return selected_clip_outline
	if active:
		return active_clip_outline
	return _shift_toward_contrast(fill, 0.18)


func clip_text(fill: Color) -> Color:
	var primary_distance := absf(text_primary.get_luminance() - fill.get_luminance())
	var secondary_distance := absf(text_secondary.get_luminance() - fill.get_luminance())
	return text_primary if primary_distance >= secondary_distance else text_secondary


static func _shift_toward_contrast(color: Color, amount: float) -> Color:
	return color.darkened(amount) if color.get_luminance() > 0.55 else color.lightened(amount)