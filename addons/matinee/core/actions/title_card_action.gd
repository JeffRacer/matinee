@tool
class_name MatineeTitleCardAction
extends MatineeAction


@export_category("Title Card")

@export_multiline
var main_text: String = "TITLE"

@export_multiline
var subtitle: String = ""

@export_range(-1.0, 15.0, 0.1)
var hold_duration: float = -1.0

@export_range(-1.0, 5.0, 0.05)
var fade_duration: float = -1.0


@export_category("Text Color")

## Overrides the normal title-card font colors for this action only.
@export var use_custom_text_colors: bool = false

## Font color used by the main title when custom colors are enabled.
@export var main_font_color: Color = Color.WHITE

## Font color used by the subtitle when custom colors are enabled.
@export var subtitle_font_color: Color = Color.WHITE


@export_category("Text Outline")

## Adds a border around the title-card text for readability.
@export var use_outline: bool = false

## Color used for the title and subtitle outline.
@export var outline_color: Color = Color.BLACK

## Width of the outline around the main title.
@export_range(0, 24, 1)
var main_outline_size: int = 4

## Also applies an outline to the subtitle when one is present.
@export var outline_subtitle: bool = true

## Width of the subtitle outline.
@export_range(0, 24, 1)
var subtitle_outline_size: int = 3


func _init() -> void:
	action_name = "Title Card"


func play(director: Node) -> void:
	if main_text.strip_edges().is_empty():
		push_warning(
			"MatineeTitleCardAction has an empty title."
		)
		return

	var main_label := director.get(
		"main_title_label"
	) as Label
	var subtitle_label := director.get(
		"subtitle_label"
	) as Label

	var original_main_settings: LabelSettings = null
	var original_subtitle_settings: LabelSettings = null

	if main_label != null:
		original_main_settings = main_label.label_settings
		main_label.label_settings = _build_styled_settings(
			main_label,
			main_font_color,
			main_outline_size,
			true
		)

	if subtitle_label != null:
		original_subtitle_settings = subtitle_label.label_settings
		subtitle_label.label_settings = _build_styled_settings(
			subtitle_label,
			subtitle_font_color,
			subtitle_outline_size,
			outline_subtitle
		)

	await director.show_title_card(
		main_text,
		hold_duration,
		subtitle,
		fade_duration
	)

	if main_label != null and is_instance_valid(main_label):
		main_label.label_settings = original_main_settings

	if subtitle_label != null and is_instance_valid(subtitle_label):
		subtitle_label.label_settings = original_subtitle_settings


func get_duration_seconds() -> float:
	var actual_hold := (
		2.5
		if hold_duration < 0.0
		else maxf(hold_duration, 0.1)
	)
	var actual_fade := (
		0.45
		if fade_duration < 0.0
		else maxf(fade_duration, 0.01)
	)
	return actual_fade + actual_hold + actual_fade


func _build_styled_settings(
	label: Label,
	custom_color: Color,
	outline_size: int,
	allow_outline: bool
) -> LabelSettings:
	var settings: LabelSettings

	if label.label_settings != null:
		settings = label.label_settings.duplicate(true) as LabelSettings
	else:
		settings = LabelSettings.new()
		settings.font = label.get_theme_font("font")
		settings.font_size = label.get_theme_font_size("font_size")
		settings.font_color = label.get_theme_color("font_color")
		settings.outline_color = label.get_theme_color(
			"font_outline_color"
		)
		settings.outline_size = label.get_theme_constant(
			"outline_size"
		)

	if use_custom_text_colors:
		settings.font_color = custom_color

	if use_outline and allow_outline:
		settings.outline_color = outline_color
		settings.outline_size = maxi(outline_size, 0)
	elif use_outline:
		settings.outline_size = 0

	return settings
