@tool
class_name MatineeRuntimePreview
extends PanelContainer

signal mute_audio_toggled(enabled: bool)
signal audio_while_scrubbing_toggled(enabled: bool)

@onready var _empty_label: Label = $PreviewRoot/EmptyLabel
@onready var _cards: VBoxContainer = $PreviewRoot/Cards
@onready var _fade_overlay: ColorRect = $PreviewRoot/FadeOverlay
@onready var _dialogues: VBoxContainer = $PreviewRoot/Dialogues
@onready var _presentation_tint: ColorRect = $PreviewRoot/PresentationTint
@onready var _presentation_status: Label = $PreviewRoot/PresentationStatus
@onready var _scene_fade_overlay: ColorRect = $PreviewRoot/SceneFadeOverlay
@onready var _scene_burn_overlay: ColorRect = $PreviewRoot/SceneBurnOverlay
@onready var _scene_transition_status: Label = $PreviewRoot/SceneTransitionStatus
@onready var _camera_status: Label = $PreviewRoot/CameraStatus
@onready var _mute_audio: CheckButton = $PreviewRoot/PreviewControls/Options/MuteAudio
@onready var _scrub_audio: CheckButton = $PreviewRoot/PreviewControls/Options/ScrubAudio
@onready var _diagnostics: Label = $PreviewRoot/PreviewControls/Diagnostics


func _ready() -> void:
	_mute_audio.toggled.connect(func(value: bool) -> void: mute_audio_toggled.emit(value))
	_scrub_audio.toggled.connect(
		func(value: bool) -> void: audio_while_scrubbing_toggled.emit(value)
	)


func set_diagnostics(diagnostics: Dictionary) -> void:
	var active := int(diagnostics.get("active_clips", 0))
	var previewed := int(diagnostics.get("previewed_clips", 0))
	var unsupported := int(diagnostics.get("unsupported_clips", 0))
	var invalid := int(diagnostics.get("invalid_clips", 0))
	var summary := "%d active · %d previewed" % [active, previewed]
	if unsupported > 0:
		summary += " · %d unsupported" % unsupported
	if invalid > 0:
		summary += " · %d invalid" % invalid
	var warning := str(diagnostics.get("last_warning", ""))
	_diagnostics.text = summary if warning.is_empty() else "%s\n%s" % [summary, warning]
	_mute_audio.set_pressed_no_signal(bool(diagnostics.get("audio_muted", false)))
	_scrub_audio.set_pressed_no_signal(bool(diagnostics.get("audio_while_scrubbing", false)))


func set_preview_states(states: Array[Dictionary]) -> void:
	var card_states: Array[Dictionary] = []
	var dialogue_states: Array[Dictionary] = []
	var presentation_state: Dictionary = {}
	var scene_state: Dictionary = {}
	var camera_state: Dictionary = {}
	var fade_opacity := 0.0
	for state in states:
		match state.get("kind", &"title_card"):
			&"fade":
				fade_opacity = maxf(fade_opacity, float(state.get("opacity", 0.0)))
			&"title_card":
				card_states.append(state)
			&"chapter_card", &"location_card":
				card_states.append(state)
			&"dialogue":
				dialogue_states.append(state)
			&"presentation":
				presentation_state = state
			&"scene_transition":
				scene_state = state
			&"camera":
				camera_state = state
	_update_presentation(presentation_state)
	_update_scene_transition(scene_state)
	_update_camera(camera_state)
	_set_color_alpha(_fade_overlay, fade_opacity)
	_cards.modulate.a = 1.0 if not _empty_label.visible else 0.0
	_dialogues.modulate.a = 1.0 if not _empty_label.visible else 0.0
	_empty_label.visible = (
		card_states.is_empty()
		and dialogue_states.is_empty()
		and presentation_state.is_empty()
		and scene_state.is_empty()
		and camera_state.is_empty()
		and fade_opacity <= 0.0
	)
	_empty_label.modulate.a = 0.7 if _empty_label.visible else 0.0
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 13)
	_empty_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.67))
	_ensure_card_count(card_states.size())
	for index in range(card_states.size()):
		_update_card(_cards.get_child(index) as VBoxContainer, card_states[index])
	_ensure_dialogue_count(dialogue_states.size())
	for index in range(dialogue_states.size()):
		_update_dialogue(
			_dialogues.get_child(index) as PanelContainer,
			dialogue_states[index]
		)


func _update_camera(state: Dictionary) -> void:
	_camera_status.visible = not state.is_empty()
	if state.is_empty():
		return
	var mode := str(state.get("mode", "Cut"))
	if mode == "Blend":
		mode = "Blend %.2fs - %s %s - %d%%" % [
			float(state.get("blend_duration", 0.0)),
			str(state.get("transition", "Linear")),
			str(state.get("ease", "In Out")),
			roundi(float(state.get("blend_progress", 0.0)) * 100.0),
		]
	var zoom := "Configured camera zoom"
	if bool(state.get("uses_zoom_override", false)):
		zoom = "Zoom override %s" % str(state.get("zoom_override", Vector2.ONE))
	_camera_status.text = "CAMERA - %s\n%s\nFollow: %s\n%s\n%s" % [
		str(state.get("target_camera", "Missing target")),
		mode,
		str(state.get("follow_target", "Disabled")),
		zoom,
		str(state.get("preview_limitation", "")),
	]


func clear_preview() -> void:
	set_preview_states([])


func _update_presentation(state: Dictionary) -> void:
	var visible := not state.is_empty()
	_presentation_tint.visible = visible
	_presentation_status.visible = visible
	if not visible:
		return
	var overlay_strength := clampf(float(state.get("master_opacity", 1.0)), 0.0, 1.0)
	if overlay_strength <= 0.0:
		_set_color_alpha(_presentation_tint, 0.0)
		return
	var master_opacity := clampf(float(state.get("master_opacity", 1.0)), 0.0, 1.0)
	var vignette := clampf(float(state.get("vignette_strength", 0.0)), 0.0, 1.0)
	var grain_strength := clampf(float(state.get("grain_strength", 0.0)), 0.0, 1.0)
	var film_tint := master_opacity * (0.035 + vignette * 0.08)
	var grain_tint := clampf(grain_strength * 0.025, 0.0, 0.04)
	_set_color_alpha(_presentation_tint, film_tint + grain_tint)
	var effects := PackedStringArray()
	if float(state.get("grain_strength", 0.0)) > 0.0:
		effects.append("Grain")
	if float(state.get("flicker_strength", 0.0)) > 0.0:
		effects.append("Flicker")
	if float(state.get("dust_opacity", 0.0)) > 0.0:
		effects.append("Dust")
	if float(state.get("scratches_opacity", 0.0)) > 0.0:
		effects.append("Scratches")
	if vignette > 0.0:
		effects.append("Vignette")
	if float(state.get("gate_weave_amount", 0.0)) > 0.0:
		effects.append("Gate Weave")
	var effect_summary := "Clean" if effects.is_empty() else " · ".join(effects)
	_presentation_status.text = "FILM · %s\n%s" % [
		str(state.get("preset_name", "Movie Mode")),
		effect_summary,
	]


func _update_scene_transition(state: Dictionary) -> void:
	var visible := not state.is_empty()
	_scene_transition_status.visible = visible
	_scene_burn_overlay.visible = false
	_set_color_alpha(_scene_fade_overlay, 0.0)
	if not visible:
		return
	var transition: StringName = state.get("transition", &"fade")
	var phase: StringName = state.get("phase", &"complete")
	if transition == &"film_burn" and phase not in [&"complete", &"async"]:
		_scene_burn_overlay.visible = true
		var material := _scene_burn_overlay.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter(
				&"progress",
				clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
			)
			material.set_shader_parameter(
				&"burn_origin",
				state.get("burn_origin", Vector2(0.35, 0.55)) as Vector2
			)
	_scene_transition_status.text = "%s · %s" % [
		_get_scene_phase_label(transition, phase),
		str(state.get("scene_label", "Scene")),
	]
	if transition == &"fade":
		_set_color_alpha(
			_scene_fade_overlay,
			clampf(float(state.get("opacity", 0.0)), 0.0, 1.0)
		)


func _set_color_alpha(node: ColorRect, target_value: float) -> void:
	if node == null:
		return
	var current_value := float(node.color.a)
	if is_equal_approx(current_value, target_value):
		return
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "color:a", target_value, 0.12)


func _get_scene_phase_label(
	transition: StringName,
	phase: StringName
) -> String:
	match phase:
		&"fade_out":
			return "FADE OUT"
		&"fade_in":
			return "FADE IN"
		&"burn_out":
			return "BURN OUT"
		&"burn_in":
			return "BURN IN"
		&"hold_before_change":
			return "HOLD · OLD SCENE"
		&"hold_after_change":
			return "HOLD · NEW SCENE"
		&"cut":
			return "CUT"
		&"trigger":
			return "TRIGGER %s" % str(transition).to_upper().replace("_", " ")
		&"async":
			return "ASYNC %s" % str(transition).to_upper().replace("_", " ")
		_:
			return "CHANGED"


func _create_card() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 2)

	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.modulate = Color(0.78, 0.74, 0.66)
	kicker.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	container.add_child(kicker)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	container.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color(0.84, 0.84, 0.82))
	container.add_child(subtitle)

	return container


func _update_card(card: VBoxContainer, state: Dictionary) -> void:
	card.modulate.a = clampf(float(state.get("opacity", 1.0)), 0.0, 1.0)
	var kicker := card.get_node("Kicker") as Label
	var title := card.get_node("Title") as Label
	var subtitle := card.get_node("Subtitle") as Label
	var is_location: bool = state.get("kind") == &"location_card"
	var is_title: bool = state.get("kind") == &"title_card"
	var alignment: HorizontalAlignment = (
		HORIZONTAL_ALIGNMENT_LEFT
		if is_location
		else HORIZONTAL_ALIGNMENT_CENTER
	)
	card.alignment = (
		BoxContainer.ALIGNMENT_END
		if is_location
		else BoxContainer.ALIGNMENT_CENTER
	)
	kicker.text = str(state.get("kicker", ""))
	kicker.visible = not kicker.text.is_empty()
	kicker.horizontal_alignment = alignment

	title.text = str(state.get("main_text", ""))
	title.horizontal_alignment = alignment
	title.add_theme_font_size_override("font_size", 20 if is_location else 24)
	title.modulate = Color.WHITE

	subtitle.text = str(state.get("subtitle", ""))
	subtitle.visible = not subtitle.text.strip_edges().is_empty()
	subtitle.horizontal_alignment = alignment
	subtitle.modulate = Color.WHITE

	var default_title_color := (
		Color(0.97, 0.93, 0.84)
		if is_location
		else Color(0.96, 0.94, 0.88)
	)
	var default_subtitle_color := Color(0.84, 0.84, 0.82)

	if is_title and bool(state.get("use_custom_text_colors", false)):
		title.add_theme_color_override(
			"font_color",
			state.get("main_font_color", default_title_color) as Color
		)
		subtitle.add_theme_color_override(
			"font_color",
			state.get("subtitle_font_color", default_subtitle_color) as Color
		)
	else:
		title.add_theme_color_override("font_color", default_title_color)
		subtitle.add_theme_color_override("font_color", default_subtitle_color)

	if is_title and bool(state.get("use_outline", false)):
		var outline_color: Color = state.get("outline_color", Color.BLACK)
		title.add_theme_color_override("font_outline_color", outline_color)
		title.add_theme_constant_override(
			"outline_size",
			maxi(int(state.get("main_outline_size", 4)), 0)
		)

		if bool(state.get("outline_subtitle", true)):
			subtitle.add_theme_color_override("font_outline_color", outline_color)
			subtitle.add_theme_constant_override(
				"outline_size",
				maxi(int(state.get("subtitle_outline_size", 3)), 0)
			)
		else:
			subtitle.remove_theme_color_override("font_outline_color")
			subtitle.remove_theme_constant_override("outline_size")
	else:
		title.remove_theme_color_override("font_outline_color")
		title.remove_theme_constant_override("outline_size")
		subtitle.remove_theme_color_override("font_outline_color")
		subtitle.remove_theme_constant_override("outline_size")


func _ensure_card_count(count: int) -> void:
	while _cards.get_child_count() < count:
		_cards.add_child(_create_card())
	while _cards.get_child_count() > count:
		var child := _cards.get_child(_cards.get_child_count() - 1)
		_cards.remove_child(child)
		child.queue_free()


func _create_dialogue() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.05, 0.045, 0.96)
	style.border_color = Color(0.35, 0.31, 0.24, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)

	var speaker := Label.new()
	speaker.name = "Speaker"
	speaker.add_theme_font_size_override("font_size", 14)
	speaker.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	content.add_child(speaker)

	var separator := HSeparator.new()
	content.add_child(separator)

	var message := Label.new()
	message.name = "Message"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	content.add_child(message)

	return panel


func _update_dialogue(panel: PanelContainer, state: Dictionary) -> void:
	var speaker := panel.get_node("Content/Speaker") as Label
	var message := panel.get_node("Content/Message") as Label
	speaker.text = str(state.get("speaker", "UNKNOWN"))
	speaker.add_theme_font_size_override("font_size", 13)
	speaker.modulate = state.get("name_color", Color.WHITE) as Color
	message.text = str(state.get("message", ""))
	message.modulate = state.get("text_color", Color.WHITE) as Color


func _ensure_dialogue_count(count: int) -> void:
	while _dialogues.get_child_count() < count:
		_dialogues.add_child(_create_dialogue())
	while _dialogues.get_child_count() > count:
		var child := _dialogues.get_child(_dialogues.get_child_count() - 1)
		_dialogues.remove_child(child)
		child.queue_free()
