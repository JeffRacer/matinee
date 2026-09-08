@tool
class_name MatineeBackgroundImageAction2
extends MatineeAction


enum Mode {
	SHOW,
	HIDE,
}


const STAGE_NAME: StringName = &"DirectorBackgroundStage"
const COLOR_RECT_NAME: StringName = &"BackgroundColor"
const TEXTURE_RECT_NAME: StringName = &"BackgroundTexture"

const TITLE_BACKGROUND_PATH := NodePath(
	"CinematicLayer/TitleCardRoot/TitleBackground"
)


@export_category("Background Image")

@export var mode: Mode = Mode.SHOW

## Texture displayed behind title cards and other CinematicLayer content.
@export var texture: Texture2D

## Solid color rendered behind the texture. This remains useful when an image
## uses transparent pixels or does not completely fill the viewport.
@export var background_color: Color = Color(
	0.012,
	0.01,
	0.009,
	1.0
)

## Multiplies the texture color and alpha.
@export var texture_tint: Color = Color.WHITE

@export var stretch_mode: TextureRect.StretchMode = (
	TextureRect.STRETCH_KEEP_ASPECT_COVERED
)

@export_range(0.0, 5.0, 0.05)
var fade_duration: float = 0.45

## When enabled, ordinary MatineeTitleCardAction backgrounds become transparent while
## this stage is visible, allowing title text to appear over the image.
@export var show_behind_title_cards: bool = true


func _init() -> void:
	action_name = "Background Image"


func play(director: Node) -> void:
	if director == null:
		push_warning(
			"BackgroundImageAction requires a Matinee instance."
		)
		return

	match mode:
		Mode.SHOW:
			await _show_background(director)

		Mode.HIDE:
			await _hide_background(director)


func get_duration_seconds() -> float:
	return maxf(
		fade_duration,
		0.0
	)


func get_validation_issues(
	_scene_context: Node = null
) -> PackedStringArray:
	var issues := PackedStringArray()

	if mode == Mode.SHOW and texture == null:
		issues.append(
			"Background Image SHOW mode requires a texture."
		)

	return issues


func get_editor_summary() -> String:
	if mode == Mode.HIDE:
		return "Hide cinematic background"

	if texture == null:
		return "No texture assigned"

	var path := texture.resource_path

	if path.is_empty():
		return "Show background texture"

	return path.get_file().get_basename()


## Immediately removes the persistent Matinee background stage.
##
## Use this from Matinee.reset_presentation_to_clean_state() or before
## changing to a scene that should not retain a cinematic background.
static func clear_background(
	director: Node
) -> void:
	if director == null:
		return

	var stage := director.get_node_or_null(
		NodePath(
			"CinematicLayer/"
			+ str(STAGE_NAME)
		)
	) as Control

	if stage != null:
		stage.visible = false
		stage.modulate = Color.WHITE
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var color_rect := stage.get_node_or_null(
			NodePath(
				str(COLOR_RECT_NAME)
			)
		) as ColorRect

		if color_rect != null:
			color_rect.color = Color(
				0.0,
				0.0,
				0.0,
				0.0
			)

		var texture_rect := stage.get_node_or_null(
			NodePath(
				str(TEXTURE_RECT_NAME)
			)
		) as TextureRect

		if texture_rect != null:
			texture_rect.texture = null
			texture_rect.modulate = Color.WHITE

	_set_title_background_visible_static(
		director,
		true
	)


func _show_background(
	director: Node
) -> void:
	if texture == null:
		push_warning(
			"BackgroundImageAction cannot show a null texture."
		)
		return

	var stage := _get_or_create_stage(
		director
	)

	if stage == null:
		return

	var color_rect := stage.get_node_or_null(
		NodePath(
			str(COLOR_RECT_NAME)
		)
	) as ColorRect

	var texture_rect := stage.get_node_or_null(
		NodePath(
			str(TEXTURE_RECT_NAME)
		)
	) as TextureRect

	if color_rect == null or texture_rect == null:
		push_warning(
			"BackgroundImageAction stage is missing its visual nodes."
		)
		return

	color_rect.color = background_color
	texture_rect.texture = texture
	texture_rect.modulate = texture_tint
	texture_rect.stretch_mode = stretch_mode

	stage.visible = true
	stage.modulate = Color.WHITE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if show_behind_title_cards:
		_set_title_background_visible(
			director,
			false
		)

	var duration := maxf(
		fade_duration,
		0.0
	)

	if duration <= 0.0:
		return

	stage.modulate.a = 0.0

	var tween := director.create_tween()

	tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	tween.set_trans(
		Tween.TRANS_SINE
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		stage,
		"modulate:a",
		1.0,
		duration
	)

	await tween.finished


func _hide_background(
	director: Node
) -> void:
	var stage := director.get_node_or_null(
		NodePath(
			"CinematicLayer/"
			+ str(STAGE_NAME)
		)
	) as Control

	if stage == null:
		_set_title_background_visible(
			director,
			true
		)
		return

	var duration := maxf(
		fade_duration,
		0.0
	)

	if duration > 0.0 and stage.visible:
		var tween := director.create_tween()

		tween.set_pause_mode(
			Tween.TWEEN_PAUSE_PROCESS
		)

		tween.set_trans(
			Tween.TRANS_SINE
		)

		tween.set_ease(
			Tween.EASE_IN
		)

		tween.tween_property(
			stage,
			"modulate:a",
			0.0,
			duration
		)

		await tween.finished

	clear_background(
		director
	)


func _get_or_create_stage(
	director: Node
) -> Control:
	var cinematic_layer := director.get_node_or_null(
		"CinematicLayer"
	) as CanvasLayer

	if cinematic_layer == null:
		push_warning(
			"BackgroundImageAction could not find "
			+ "Matinee/CinematicLayer."
		)
		return null

	var existing := cinematic_layer.get_node_or_null(
		NodePath(
			str(STAGE_NAME)
		)
	) as Control

	if existing != null:
		return existing

	var stage := Control.new()

	stage.name = STAGE_NAME
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.visible = false

	cinematic_layer.add_child(
		stage
	)

	stage.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var color_rect := ColorRect.new()

	color_rect.name = COLOR_RECT_NAME
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.color = Color.TRANSPARENT

	stage.add_child(
		color_rect
	)

	color_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var texture_rect := TextureRect.new()

	texture_rect.name = TEXTURE_RECT_NAME
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	texture_rect.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR
	)

	stage.add_child(
		texture_rect
	)

	texture_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Draw beneath FadeRect and all title-card content. FadeRect can therefore
	# still cover the background during transitions.
	var fade_rect := cinematic_layer.get_node_or_null(
		"FadeRect"
	) as Control

	if fade_rect != null:
		cinematic_layer.move_child(
			stage,
			fade_rect.get_index()
		)
	else:
		cinematic_layer.move_child(
			stage,
			0
		)

	return stage


func _set_title_background_visible(
	director: Node,
	background_visible: bool
) -> void:
	_set_title_background_visible_static(
		director,
		background_visible
	)


static func _set_title_background_visible_static(
	director: Node,
	background_visible: bool
) -> void:
	if director == null:
		return

	var title_background := director.get_node_or_null(
		TITLE_BACKGROUND_PATH
	) as ColorRect

	if title_background == null:
		return

	var color := title_background.color

	color.a = (
		1.0
		if background_visible
		else 0.0
	)

	title_background.color = color
