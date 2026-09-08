@tool
class_name MatineeToolbar
extends HBoxContainer

signal add_pressed
signal add_track_pressed
signal duplicate_pressed
signal delete_pressed
signal move_up_pressed
signal move_down_pressed
signal rename_track_pressed
signal track_mute_toggled
signal track_lock_toggled
signal track_visibility_toggled
signal track_enabled_toggled
signal validate_pressed
signal inspect_sequence_pressed
signal rewind_pressed
signal play_pause_pressed
signal stop_pressed
signal speed_changed(speed: float)
signal loop_toggled(enabled: bool)
signal preview_toggled(enabled: bool)

@onready var _add_button: Button = $AddButton
@onready var _add_track_button: Button = $AddTrackButton
@onready var _duplicate_button: Button = $DuplicateButton
@onready var _delete_button: Button = $DeleteButton
@onready var _move_up_button: Button = $MoveUpButton
@onready var _move_down_button: Button = $MoveDownButton
@onready var _track_menu_button: MenuButton = $TrackMenuButton
@onready var _rewind_button: Button = $RewindButton
@onready var _play_pause_button: Button = $PlayPauseButton
@onready var _stop_button: Button = $StopButton
@onready var _speed_option: OptionButton = $SpeedOption
@onready var _loop_button: CheckButton = $LoopButton
@onready var _preview_button: CheckButton = $PreviewButton
@onready var _validate_button: Button = $ValidateButton
@onready var _inspect_sequence_button: Button = $InspectSequenceButton


func _ready() -> void:
	_add_button.pressed.connect(func() -> void: add_pressed.emit())
	_add_track_button.pressed.connect(func() -> void: add_track_pressed.emit())
	_duplicate_button.pressed.connect(func() -> void: duplicate_pressed.emit())
	_delete_button.pressed.connect(func() -> void: delete_pressed.emit())
	_move_up_button.pressed.connect(func() -> void: move_up_pressed.emit())
	_move_down_button.pressed.connect(func() -> void: move_down_pressed.emit())
	_rewind_button.pressed.connect(func() -> void: rewind_pressed.emit())
	_play_pause_button.pressed.connect(func() -> void: play_pause_pressed.emit())
	_stop_button.pressed.connect(func() -> void: stop_pressed.emit())
	_validate_button.pressed.connect(func() -> void: validate_pressed.emit())
	_inspect_sequence_button.pressed.connect(func() -> void: inspect_sequence_pressed.emit())
	_loop_button.toggled.connect(func(enabled: bool) -> void: loop_toggled.emit(enabled))
	_preview_button.toggled.connect(func(enabled: bool) -> void: preview_toggled.emit(enabled))
	_configure_track_menu()

	_speed_option.clear()
	_add_speed_item("0.25x", 0.25)
	_add_speed_item("0.5x", 0.5)
	_add_speed_item("1x", 1.0)
	_add_speed_item("1.5x", 1.5)
	_add_speed_item("2x", 2.0)
	_speed_option.select(2)
	_speed_option.item_selected.connect(_on_speed_selected)


func set_context(
	has_sequence: bool,
	selected_index: int,
	action_count: int,
	has_playable_duration: bool,
	selected_track_index: int = -1,
	track_count: int = 0,
	has_selected_action: bool = false
) -> void:
	var has_track_selection := selected_track_index >= 0 and selected_track_index < track_count
	var has_action_selection := has_selected_action and selected_index >= 0
	var has_selection := has_action_selection or has_track_selection
	_add_button.disabled = not has_sequence
	_add_track_button.disabled = not has_sequence
	_duplicate_button.disabled = not has_selection
	_delete_button.disabled = not has_selection
	var selected_position := selected_index if has_action_selection else selected_track_index
	var selected_count := action_count if has_action_selection else track_count
	_move_up_button.disabled = not has_selection or selected_position <= 0
	_move_down_button.disabled = not has_selection or selected_position >= selected_count - 1
	_rewind_button.disabled = not has_playable_duration
	_play_pause_button.disabled = not has_playable_duration
	_stop_button.disabled = not has_playable_duration
	_speed_option.disabled = not has_playable_duration
	_loop_button.disabled = not has_playable_duration
	_preview_button.disabled = not has_sequence
	_validate_button.disabled = not has_sequence
	_inspect_sequence_button.disabled = not has_sequence


func set_playing(is_playing: bool) -> void:
	_play_pause_button.text = "⏸" if is_playing else "▶"
	_play_pause_button.tooltip_text = "Pause playback (Space)." if is_playing else "Play the sequence (Space)."


func set_track_context(track: MatineeTrack) -> void:
	_track_menu_button.disabled = track == null
	var popup := _track_menu_button.get_popup()
	if track == null:
		return
	popup.set_item_checked(popup.get_item_index(1), track.muted)
	popup.set_item_checked(popup.get_item_index(2), track.locked)
	popup.set_item_checked(popup.get_item_index(3), track.visible)
	popup.set_item_checked(popup.get_item_index(4), track.enabled)


func set_loop_enabled(enabled: bool) -> void:
	_loop_button.set_pressed_no_signal(enabled)


func set_preview_enabled(enabled: bool) -> void:
	_preview_button.set_pressed_no_signal(enabled)


func get_add_popup_position() -> Vector2i:
	var screen_position := _add_button.get_screen_position()
	return Vector2i(screen_position + Vector2(0.0, _add_button.size.y))


func _add_speed_item(label: String, speed: float) -> void:
	_speed_option.add_item(label)
	_speed_option.set_item_metadata(_speed_option.item_count - 1, speed)


func _on_speed_selected(index: int) -> void:
	speed_changed.emit(float(_speed_option.get_item_metadata(index)))


func _configure_track_menu() -> void:
	var popup := _track_menu_button.get_popup()
	popup.clear()
	popup.add_item("Rename…", 0)
	popup.add_check_item("Muted", 1)
	popup.add_check_item("Locked", 2)
	popup.add_check_item("Visible", 3)
	popup.add_check_item("Enabled", 4)
	popup.id_pressed.connect(_on_track_menu_id_pressed)


func _on_track_menu_id_pressed(id: int) -> void:
	match id:
		0:
			rename_track_pressed.emit()
		1:
			track_mute_toggled.emit()
		2:
			track_lock_toggled.emit()
		3:
			track_visibility_toggled.emit()
		4:
			track_enabled_toggled.emit()
