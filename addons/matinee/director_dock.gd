@tool
extends VBoxContainer

const ActionFactory := preload("res://addons/matinee/action_factory.gd")
const DirectorValidator := preload("res://addons/matinee/director_validator.gd")
const SequenceEditor := preload("res://addons/matinee/services/sequence_editor.gd")
const SelectionState := preload("res://addons/matinee/models/selection_state.gd")
const InspectorPanel := preload("res://addons/matinee/widgets/inspector_panel.gd")
const PlaybackController := preload("res://addons/matinee/playback/playback_controller.gd")
const PreviewController := preload("res://addons/matinee/preview/preview_controller.gd")
const ACTION_TREE_START_COLUMN_MIN_WIDTH := 200

var _sequence: MatineeSequence
var _undo_redo: EditorUndoRedoManager
var _observed_actions: Array[MatineeAction] = []
var _selection := SelectionState.new()
var _sequence_editor: MatineeSequenceEditor
var _playback: MatineePlaybackController
var _preview: MatineePreviewController
var _property_refresh_pending := false
var _preview_seek_pending := false
var _scene_context_provider: Callable
var _add_action_ids := {}
var _add_submenus: Array[PopupMenu] = []
var _next_add_menu_id := 0

@onready var _summary: MatineeSequenceSummary = $SequenceSummary
@onready var _toolbar: MatineeToolbar = $Toolbar
@onready var _action_tree: MatineeActionTree = $ActionTree
@onready var _timeline = $Timeline
@onready var _status_bar: MatineeStatusBar = $StatusBar
@onready var _inspector_panel: InspectorPanel = $InspectorPanel
@onready var _add_menu: PopupMenu = $AddMenu
@onready var _validation_dialog: AcceptDialog = $ValidationDialog
@onready var _validation_results: RichTextLabel = $ValidationDialog/ValidationResults
@onready var _rename_track_dialog: ConfirmationDialog = $RenameTrackDialog
@onready var _rename_track_edit: LineEdit = $RenameTrackDialog/TrackNameEdit
@onready var _runtime_preview: MatineeRuntimePreview = $RuntimePreview


func _ready() -> void:
	_sequence_editor = SequenceEditor.new()
	_sequence_editor.set_undo_redo(_undo_redo)
	_sequence_editor.tracks_applied.connect(_on_tracks_applied)

	_playback = PlaybackController.new()
	_playback.time_changed.connect(_on_playback_time_changed)
	_playback.timeline_action_changed.connect(_on_playback_timeline_action_changed)
	_playback.state_changed.connect(_on_playback_state_changed)
	_playback.playback_finished.connect(_on_playback_finished)
	_preview = PreviewController.new()
	_preview.prepare(_runtime_preview)
	_preview.preview_changed.connect(_runtime_preview.set_preview_states)
	_preview.diagnostics_changed.connect(_runtime_preview.set_diagnostics)
	_runtime_preview.mute_audio_toggled.connect(_on_preview_audio_muted)
	_runtime_preview.audio_while_scrubbing_toggled.connect(_on_preview_scrub_audio)
	set_process(false)

	_configure_action_tree()
	_action_tree.set_selection_state(_selection)
	_timeline.set_selection_state(_selection)
	_populate_add_menu()
	_connect_widget_signals()

	_selection.action_changed.connect(_on_selection_changed)
	_selection.track_changed.connect(_on_track_selection_changed)
	_selection.selection_cleared.connect(_on_selection_cleared)

	_show_empty_state()


func set_scene_context_provider(provider: Callable) -> void:
	_scene_context_provider = provider


func _process(delta: float) -> void:
	if _playback != null:
		_playback.update(delta)


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	if not _can_handle_transport_shortcut():
		return

	var handled := true
	match key_event.keycode:
		KEY_SPACE:
			if _playback.get_duration() <= 0.0:
				return
			_playback.toggle_play_pause()
		KEY_ESCAPE:
			if _playback.state == MatineePlaybackController.State.STOPPED and is_zero_approx(_playback.current_time):
				return
			_playback.stop()
		KEY_HOME:
			_seek_preview(0.0)
		KEY_END:
			_seek_preview(_playback.get_duration())
		_:
			handled = false

	if handled:
		get_viewport().set_input_as_handled()


func set_undo_redo(manager: EditorUndoRedoManager) -> void:
	_undo_redo = manager
	if _sequence_editor != null:
		_sequence_editor.set_undo_redo(manager)


func set_sequence(sequence: MatineeSequence) -> void:
	if _sequence == sequence:
		_refresh()
		if _preview != null:
			_preview.rebuild(sequence)
		if _playback != null:
			_playback.rebuild()
		return

	_disconnect_observed_resources()
	_clear_preview()
	_sequence = sequence
	_selection.set_sequence(sequence)
	if _preview != null:
		_preview.set_sequence(sequence)

	if is_instance_valid(_sequence) and not _sequence.changed.is_connected(_on_sequence_changed):
		_sequence.changed.connect(_on_sequence_changed)

	_connect_actions()
	if _playback != null:
		_playback.set_sequence(sequence)
	_refresh()


func _configure_action_tree() -> void:
	_action_tree.set_column_title(0, "Start")
	_action_tree.set_column_title(1, "Action")
	_action_tree.set_column_title(2, "Duration")
	# Tree hierarchy indentation is rendered inside column 0. Reserve enough
	# space for that indentation plus a complete MM:SS.t timestamp.
	_action_tree.set_column_custom_minimum_width(0, ACTION_TREE_START_COLUMN_MIN_WIDTH)
	_action_tree.set_column_expand(0, false)
	_action_tree.set_column_expand(1, true)
	_action_tree.set_column_custom_minimum_width(2, 72)
	_action_tree.set_column_expand(2, false)


func _populate_add_menu() -> void:
	for submenu: PopupMenu in _add_submenus:
		if is_instance_valid(submenu):
			submenu.queue_free()
	_add_submenus.clear()
	_add_menu.clear()
	_add_action_ids.clear()
	_next_add_menu_id = 0
	_populate_add_menu_branch(_add_menu, ActionFactory.get_menu_tree(), "")


func _populate_add_menu_branch(menu: PopupMenu, branch: Dictionary, path: String) -> void:
	var labels: Array = branch.keys()
	labels.sort()
	for label_value in labels:
		var label := str(label_value)
		var value: Variant = branch[label]
		if value is Dictionary and value.has("id"):
			var menu_id := _next_add_menu_id
			_next_add_menu_id += 1
			_add_action_ids[menu_id] = StringName(value["id"])
			menu.add_item(label, menu_id)
			if not menu.id_pressed.is_connected(_on_add_action_selected):
				menu.id_pressed.connect(_on_add_action_selected)
			continue
		if not value is Dictionary:
			continue
		var submenu := PopupMenu.new()
		submenu.name = "AddAction_%s" % (path + "_" + label).replace("/", "_").replace(" ", "_")
		menu.add_child(submenu)
		_add_submenus.append(submenu)
		menu.add_submenu_item(label, submenu.name)
		_populate_add_menu_branch(submenu, value, path + "/" + label)


func _connect_widget_signals() -> void:
	_toolbar.add_pressed.connect(_show_add_menu)
	_toolbar.add_track_pressed.connect(_add_track)
	_toolbar.duplicate_pressed.connect(_duplicate_selected)
	_toolbar.delete_pressed.connect(_delete_selected)
	_toolbar.move_up_pressed.connect(_move_selected_up)
	_toolbar.move_down_pressed.connect(_move_selected_down)
	_toolbar.rename_track_pressed.connect(_show_rename_track_dialog)
	_toolbar.track_mute_toggled.connect(_toggle_selected_track_mute)
	_toolbar.track_lock_toggled.connect(_toggle_selected_track_lock)
	_toolbar.track_visibility_toggled.connect(_toggle_selected_track_visibility)
	_toolbar.track_enabled_toggled.connect(_toggle_selected_track_enabled)
	_toolbar.rewind_pressed.connect(func() -> void: _seek_preview(0.0))
	_toolbar.play_pause_pressed.connect(func() -> void: _playback.toggle_play_pause())
	_toolbar.stop_pressed.connect(func() -> void: _playback.stop())
	_toolbar.speed_changed.connect(_on_playback_speed_changed)
	_toolbar.loop_toggled.connect(_on_loop_toggled)
	_toolbar.preview_toggled.connect(_on_preview_toggled)
	_toolbar.validate_pressed.connect(_validate_sequence)
	_toolbar.inspect_sequence_pressed.connect(_inspect_sequence)
	_add_menu.id_pressed.connect(_on_add_action_selected)
	_action_tree.timeline_action_selected.connect(_on_track_action_selected)
	_action_tree.track_selected.connect(_on_track_selected)
	_action_tree.timeline_action_move_requested.connect(_on_tree_timeline_action_move_requested)
	_action_tree.track_move_requested.connect(_on_tree_track_move_requested)
	_timeline.timeline_action_selected.connect(_on_track_action_selected)
	_timeline.track_selected.connect(_on_track_selected)
	_timeline.timeline_action_move_requested.connect(_on_timeline_action_move_requested)
	_timeline.seek_requested.connect(_seek_preview)
	_inspector_panel.property_edited.connect(_on_inspector_property_edited)
	_rename_track_dialog.confirmed.connect(_rename_selected_track)


func _refresh() -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(_sequence):
		_show_empty_state()
		return

	var preserve_inspector_focus := _inspector_has_keyboard_focus()

	_disconnect_action_signals()
	_connect_actions()
	_summary.set_sequence(_sequence)
	_action_tree.set_sequence(_sequence)
	_timeline.set_sequence(_sequence)
	_timeline.set_playback_time(_playback.current_time)
	_timeline.set_active_action(_playback.get_current_action_index())
	_update_toolbar_state()

	var selected_index := _selection.action_index
	var selected_action := _get_action(_selection.track_index, selected_index)
	if selected_action != null:
		if selected_action != _selection.action:
			_selection.select_action(selected_action, selected_index)
		_action_tree.select_timeline_action(_selection.track_index, selected_index)
		if not preserve_inspector_focus:
			if _selection.timeline_action != null:
				_inspector_panel.inspect_timeline_action(_selection.timeline_action)
			else:
				_inspector_panel.inspect_action(selected_action)
	else:
		if _selection.track != null and _selection.action == null:
			if not preserve_inspector_focus:
				_inspector_panel.inspect_track(_selection.track)
		else:
			_selection.clear_selection()
			if not preserve_inspector_focus:
				_inspector_panel.inspect_sequence(_sequence)

	_update_playback_status()


func _refresh_editor_views() -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(_sequence):
		_show_empty_state()
		return

	# Refresh timeline/tree/status data without asking EditorInspector to edit()
	# the resource again. Re-editing the resource recreates property controls and
	# steals keyboard focus while the user is typing.
	_disconnect_action_signals()
	_connect_actions()
	_summary.set_sequence(_sequence)
	_action_tree.set_sequence(_sequence)
	_timeline.set_sequence(_sequence)
	_timeline.set_playback_time(_playback.current_time)
	_timeline.set_active_action(_playback.get_current_action_index())

	var selected_index := _selection.action_index
	if selected_index >= 0:
		_action_tree.select_timeline_action(_selection.track_index, selected_index)

	_update_toolbar_state()
	_update_playback_status()


func _show_add_menu() -> void:
	if not is_instance_valid(_sequence):
		return
	if not _sequence.is_current_track_format():
		_show_unsupported_legacy_status()
		return
	_add_menu.position = _toolbar.get_add_popup_position()
	_add_menu.popup()


func _on_add_action_selected(menu_id: int) -> void:
	if not is_instance_valid(_sequence) or not _sequence.is_current_track_format():
		_show_unsupported_legacy_status()
		return
	if not _add_action_ids.has(menu_id):
		return

	var action := ActionFactory.create(_add_action_ids[menu_id])
	if action == null:
		_status_bar.set_error("Could not create the selected action type.")
		return

	if not _ensure_default_track_for_edit():
		return
	var track_index := _get_action_target_track_index()
	if track_index < 0:
		_status_bar.set_error("No unlocked track is available for the selected action.")
		return
	var clip := MatineeTimelineAction.new()
	clip.action = action
	var selected_action_index := _selection.action_index if _selection.track_index == track_index else -1
	clip.start_time = _sequence_editor.get_new_timeline_action_start_time(
		_sequence,
		track_index,
		selected_action_index,
		_playback.current_time
	)
	clip.duration = maxf(action.get_duration_seconds(), 0.0)
	var insert_index := _sequence_editor.get_timeline_action_insert_index(
		_sequence,
		track_index,
		selected_action_index,
		clip.start_time
	)
	if not _sequence_editor.add_timeline_action(_sequence, track_index, clip, insert_index):
		_status_bar.set_error("Could not add the selected action.")


func _get_action_target_track_index() -> int:
	return _sequence_editor.get_editable_track_index(_sequence, _selection.track_index)


func _duplicate_selected() -> void:
	if _has_valid_track_selection() and _selection.action == null:
		if not _sequence_editor.duplicate_track(_sequence, _selection.track_index):
			_status_bar.set_error("Could not duplicate the selected track.")
		return
	if not _has_valid_selection():
		return
	if not _sequence_editor.duplicate_timeline_action(_sequence, _selection.track_index, _selection.action_index):
		_status_bar.set_error("Could not duplicate the selected action.")


func _delete_selected() -> void:
	if _has_valid_track_selection() and _selection.action == null:
		if not _sequence_editor.remove_track(_sequence, _selection.track_index):
			_status_bar.set_error("Could not delete the selected track.")
		return
	if not _has_valid_selection():
		return
	if not _sequence_editor.delete_timeline_action(_sequence, _selection.track_index, _selection.action_index):
		_status_bar.set_error("Could not delete the selected action.")


func _move_selected_up() -> void:
	if _has_valid_track_selection() and _selection.action == null:
		if _selection.track_index > 0:
			_sequence_editor.move_track(_sequence, _selection.track_index, _selection.track_index - 1)
		return
	var selected_index := _selection.action_index
	if not _has_valid_selection() or selected_index <= 0:
		return

	_sequence_editor.move_timeline_action(_sequence, _selection.track_index, selected_index, _selection.track_index, selected_index - 1)


func _move_selected_down() -> void:
	if _has_valid_track_selection() and _selection.action == null:
		if _selection.track_index < _sequence.tracks.size() - 1:
			_sequence_editor.move_track(_sequence, _selection.track_index, _selection.track_index + 1)
		return
	var selected_index := _selection.action_index
	if not _has_valid_selection() or selected_index >= _sequence.tracks[_selection.track_index].actions.size() - 1:
		return

	_sequence_editor.move_timeline_action(_sequence, _selection.track_index, selected_index, _selection.track_index, selected_index + 1)


func _show_rename_track_dialog() -> void:
	if not _has_valid_track_selection():
		return
	_rename_track_edit.text = _selection.track.track_name
	_rename_track_dialog.popup_centered(Vector2i(360, 110))
	_rename_track_edit.grab_focus()
	_rename_track_edit.select_all()


func _rename_selected_track() -> void:
	if not _has_valid_track_selection():
		return
	if not _sequence_editor.rename_track(_sequence, _selection.track_index, _rename_track_edit.text):
		_status_bar.set_error("Track names cannot be empty or unchanged.")


func _toggle_selected_track_mute() -> void:
	if _has_valid_track_selection():
		_sequence_editor.set_track_muted(_sequence, _selection.track_index, not _selection.track.muted)


func _toggle_selected_track_lock() -> void:
	if _has_valid_track_selection():
		_sequence_editor.set_track_locked(_sequence, _selection.track_index, not _selection.track.locked)


func _toggle_selected_track_visibility() -> void:
	if _has_valid_track_selection():
		_sequence_editor.set_track_visible(_sequence, _selection.track_index, not _selection.track.visible)


func _toggle_selected_track_enabled() -> void:
	if _has_valid_track_selection():
		_sequence_editor.set_track_enabled(_sequence, _selection.track_index, not _selection.track.enabled)


func _on_tree_timeline_action_move_requested(source_track_index: int, source_action_index: int, destination_track_index: int, destination_action_index: int) -> void:
	if not _sequence_editor.move_timeline_action(_sequence, source_track_index, source_action_index, destination_track_index, destination_action_index):
		_status_bar.set_error("Could not move the selected timeline clip.")


func _on_tree_track_move_requested(source_track_index: int, destination_track_index: int) -> void:
	if not _sequence_editor.move_track(_sequence, source_track_index, destination_track_index):
		_status_bar.set_error("Could not move the selected track.")


func _validate_sequence() -> void:
	if not is_instance_valid(_sequence):
		return

	var previewable_types: Array[StringName] = []
	if _preview != null:
		previewable_types = _preview.get_previewable_action_types()
	var scene_context: Node
	if _scene_context_provider.is_valid():
		scene_context = _scene_context_provider.call() as Node
	var issues: Array[Dictionary] = DirectorValidator.validate(
		_sequence,
		previewable_types,
		scene_context
	)
	var errors := 0
	var warnings := 0
	var lines: Array[String] = []

	for issue in issues:
		var severity := str(issue.get("severity", "warning"))
		var action_index := int(issue.get("action_index", -1))
		var message := str(issue.get("message", "Unknown issue."))
		var location := "Sequence" if action_index < 0 else "Action %d" % (action_index + 1)

		if severity == "error":
			errors += 1
			lines.append("[color=#ff7777][b]ERROR[/b][/color]  %s — %s" % [location, message])
		else:
			warnings += 1
			lines.append("[color=#ffd166][b]WARNING[/b][/color]  %s — %s" % [location, message])

	if issues.is_empty():
		_validation_results.text = "[color=#7ee787][b]VALID[/b][/color]\n\n%d actions checked. No issues found." % _sequence.get_enabled_action_count()
		_status_bar.set_info("Validation passed: %d actions checked." % _sequence.get_enabled_action_count())
	else:
		_validation_results.text = "[b]%d error(s), %d warning(s)[/b]\n\n%s" % [errors, warnings, "\n\n".join(lines)]
		_status_bar.set_warning("Validation found %d error(s) and %d warning(s)." % [errors, warnings])

	_validation_dialog.popup_centered(Vector2i(620, 420))


func _on_tracks_applied(sequence: MatineeSequence, track_index: int, action_index: int) -> void:
	if sequence != _sequence:
		return
	var action := _get_action(track_index, action_index)
	if action != null:
		_selection.select_action(action, action_index, track_index)
	elif track_index >= 0 and track_index < _sequence.tracks.size() and _sequence.tracks[track_index] != null:
		_selection.select_track(_sequence.tracks[track_index], track_index)
	else:
		_selection.clear_selection()
	_preview.rebuild(_sequence)
	_playback.rebuild()
	_refresh()


func _has_valid_selection() -> bool:
	return (
		is_instance_valid(_sequence)
		and _selection.action_index >= 0
		and _selection.track_index >= 0
		and _selection.track_index < _sequence.tracks.size()
		and _selection.action_index < _sequence.tracks[_selection.track_index].actions.size()
		and _selection.action == _get_action(_selection.track_index, _selection.action_index)
	)


func _has_valid_track_selection() -> bool:
	return (
		is_instance_valid(_sequence)
		and _sequence.is_current_track_format()
		and _selection.track_index >= 0
		and _selection.track_index < _sequence.tracks.size()
		and _selection.track == _sequence.tracks[_selection.track_index]
	)


func _add_track() -> void:
	if not is_instance_valid(_sequence):
		return
	if not _sequence.is_current_track_format():
		_show_unsupported_legacy_status()
		return
	var track := MatineeTrack.new()
	track.track_name = _get_next_track_name()
	var insert_index := _sequence.tracks.size()
	if _has_valid_track_selection():
		insert_index = _selection.track_index + 1
	if not _sequence_editor.add_track(_sequence, track, insert_index):
		_status_bar.set_error("Could not add a track.")


func _get_next_track_name() -> String:
	var suffix := 1
	var names := {}
	for track in _sequence.tracks:
		if track != null:
			names[track.track_name.to_lower()] = true
	while names.has("track %d" % suffix):
		suffix += 1
	return "Track %d" % suffix


func _ensure_default_track_for_edit() -> bool:
	if not _sequence.is_current_track_format():
		_show_unsupported_legacy_status()
		return false
	if not _sequence.tracks.is_empty():
		return true
	var main_track := MatineeTrack.new()
	main_track.track_name = "Main"
	return _sequence_editor.add_track(_sequence, main_track, 0)


func _get_action(track_index: int, action_index: int) -> MatineeAction:
	if not is_instance_valid(_sequence) or track_index < 0 or track_index >= _sequence.tracks.size():
		return null
	var track := _sequence.tracks[track_index]
	if track == null or action_index < 0 or action_index >= track.actions.size():
		return null
	var clip := track.actions[action_index]
	return clip.action if clip != null else null


func _can_handle_transport_shortcut() -> bool:
	if _playback == null or not is_instance_valid(_sequence):
		return false

	var viewport := get_viewport()
	if viewport == null:
		return false

	var focus_owner := viewport.gui_get_focus_owner()

	# EditorInspector controls can briefly report no focus while editing.
	# Never run transport shortcuts in that ambiguous state.
	if focus_owner == null:
		return false

	if not is_ancestor_of(focus_owner):
		return false

	if (
		_inspector_panel != null
		and (
			focus_owner == _inspector_panel
			or _inspector_panel.is_ancestor_of(focus_owner)
		)
	):
		return false

	if _focus_reserves_keyboard_input(focus_owner):
		return false

	# Transport shortcuts only work from timeline/tree/toolbar controls.
	return (
		focus_owner == _timeline
		or _timeline.is_ancestor_of(focus_owner)
		or focus_owner == _action_tree
		or _action_tree.is_ancestor_of(focus_owner)
		or focus_owner == _toolbar
		or _toolbar.is_ancestor_of(focus_owner)
	)


func _focus_reserves_keyboard_input(focus_owner: Control) -> bool:
	var current: Control = focus_owner
	while current != null:
		if current is LineEdit or current is TextEdit or current is SpinBox:
			return true
		# EditorInspector property controls may focus an internal wrapper instead of
		# the LineEdit or TextEdit that ultimately consumes the keyboard event.
		if current is EditorInspector:
			return true
		if current == self:
			break
		current = current.get_parent_control()
	return false


func _inspector_has_keyboard_focus() -> bool:
	return (
		_inspector_panel != null
		and _inspector_panel.has_keyboard_focus()
	)

func _on_track_action_selected(action: MatineeAction, track_index: int, action_index: int) -> void:
	_selection.select_action(action, action_index, track_index)


func _on_track_selected(track: MatineeTrack, track_index: int) -> void:
	_selection.select_track(track, track_index)


func _on_track_selection_changed(track: MatineeTrack, _track_index: int) -> void:
	if is_node_ready() and track != null:
		_inspector_panel.inspect_track(track)
		_status_bar.set_info("Selected track %s · %d clip%s." % [
			track.track_name,
			track.actions.size(),
			"" if track.actions.size() == 1 else "s",
		])
	_update_toolbar_state()


func _on_timeline_action_move_requested(source_track_index: int, source_action_index: int, destination_track_index: int, start_time: float) -> void:
	if not _sequence_editor.move_timeline_action_to_time(_sequence, source_track_index, source_action_index, destination_track_index, start_time):
		_status_bar.set_error("Could not move or ripple-reorder the selected timeline clip.")


func _update_toolbar_state() -> void:
	var has_sequence := is_instance_valid(_sequence)
	var action_count := _sequence.get_enabled_action_count() if has_sequence else 0
	var has_playable_duration := (
		has_sequence
		and _playback != null
		and _playback.get_duration() > 0.0
	)
	_toolbar.set_context(
		has_sequence,
		_selection.action_index,
		action_count,
		has_playable_duration,
		_selection.track_index,
		_sequence.tracks.size() if has_sequence else 0,
		_selection.action != null
	)
	_toolbar.set_playing(_playback.state == MatineePlaybackController.State.PLAYING)
	_toolbar.set_loop_enabled(_playback.loop_enabled)
	_toolbar.set_track_context(_selection.track if _has_valid_track_selection() else null)


func _inspect_sequence() -> void:
	_selection.clear_selection()
	_status_bar.set_info("Editing the MatineeSequence resource.")


func _on_selection_changed(action: MatineeAction, index: int) -> void:
	if not is_node_ready():
		return

	var inspected_object: Object = _selection.timeline_action if _selection.timeline_action != null else action
	if not _inspector_panel.is_inspecting(inspected_object):
		if _selection.timeline_action != null:
			_inspector_panel.inspect_timeline_action(_selection.timeline_action)
		else:
			_inspector_panel.inspect_action(action)

	if (
		_playback.state == MatineePlaybackController.State.STOPPED
		and is_instance_valid(_sequence)
	):
		var selected_count := 0
		if _selection.track_index >= 0 and _selection.track_index < _sequence.tracks.size():
			selected_count = _sequence.tracks[_selection.track_index].actions.size()
		_status_bar.set_info(
			"Editing clip %d of %d on %s." % [
				index + 1,
				selected_count,
				_selection.track.track_name if _selection.track != null else "the timeline",
			]
		)

	_update_toolbar_state()


func _on_selection_cleared() -> void:
	if not is_node_ready():
		return

	if is_instance_valid(_sequence):
		_inspector_panel.inspect_sequence(_sequence)
	else:
		_inspector_panel.clear()
	_update_toolbar_state()
	
func _on_playback_time_changed(time: float) -> void:
	_timeline.set_playback_time(time)
	_timeline.set_active_timeline_actions(_playback.get_active_entries())
	_sync_preview(time)
	_update_playback_status()


func _on_playback_action_changed(action: MatineeAction, index: int) -> void:
	_timeline.set_active_action(index)
	if action != null and index >= 0:
		_selection.select_action(action, index)
	_update_playback_status()


func _on_playback_timeline_action_changed(action: MatineeAction, track_index: int, action_index: int) -> void:
	_timeline.set_active_action(action_index)
	_update_playback_status()

func _on_playback_state_changed(state: int) -> void:
	set_process(state == MatineePlaybackController.State.PLAYING)
	_timeline.set_playback_active(state == MatineePlaybackController.State.PLAYING)
	if state == MatineePlaybackController.State.STOPPED:
		_clear_preview()
	elif _preview != null and _preview.enabled:
		_sync_preview(_playback.current_time)
	_update_toolbar_state()
	_update_playback_status()


func _on_playback_finished() -> void:
	_timeline.set_active_action(-1)
	if _preview != null and _preview.enabled:
		_sync_preview(_playback.current_time)
	else:
		_clear_preview()
	_update_playback_status()


func _on_playback_speed_changed(speed: float) -> void:
	_playback.playback_speed = speed
	_update_playback_status()


func _on_loop_toggled(enabled: bool) -> void:
	_playback.loop_enabled = enabled
	_update_playback_status()


func _on_preview_toggled(enabled: bool) -> void:
	_preview.set_enabled(enabled)
	_runtime_preview.visible = enabled
	if enabled:
		_preview_seek_pending = true
		_sync_preview(_playback.current_time)
	else:
		_runtime_preview.clear_preview()
	_update_toolbar_state()


func _on_preview_audio_muted(enabled: bool) -> void:
	_preview.set_audio_muted(enabled)
	if not enabled and _preview.enabled:
		_sync_preview(_playback.current_time)


func _on_preview_scrub_audio(enabled: bool) -> void:
	_preview.set_audio_while_scrubbing(enabled)


func _sync_preview(time: float) -> void:
	if _preview == null:
		return
	_preview.evaluate(
		time,
		_playback.get_active_entries(),
		_playback.state,
		_preview_seek_pending
	)
	_preview_seek_pending = false


func _seek_preview(time: float) -> void:
	_preview_seek_pending = true
	_playback.seek(time)


func _clear_preview() -> void:
	if _preview != null:
		_preview.clear()
	if is_instance_valid(_runtime_preview):
		_runtime_preview.clear_preview()


func _update_playback_status() -> void:
	if not is_instance_valid(_sequence) or _playback == null:
		return
	if not _sequence.is_current_track_format():
		_show_unsupported_legacy_status()
		return
	if _sequence.get_enabled_action_count() == 0:
		_status_bar.show_empty_sequence()
		return
	var state_name := "■ Stopped"
	match _playback.state:
		MatineePlaybackController.State.PLAYING:
			state_name = "▶ Playing"
		MatineePlaybackController.State.PAUSED:
			state_name = "⏸ Paused"
	var active_entries := _playback.get_active_entries()
	var action := _playback.get_current_action()
	var action_name := action.get_editor_name() if action != null else "No active action"
	if active_entries.size() > 1:
		action_name = "Multiple active clips (%d)" % active_entries.size()
	_status_bar.set_playback(
		state_name,
		_playback.current_time,
		_playback.get_duration(),
		action_name,
		_playback.get_current_action_index(),
		_sequence.get_enabled_action_count(),
		_playback.playback_speed,
		_playback.loop_enabled
	)


func _on_sequence_changed() -> void:
	# Structural modifications made through MatineeSequenceEditor already perform
	# their own rebuild and full refresh. Avoid reacting here because nested
	# resource text edits may propagate this signal on every keystroke.
	pass


func _on_inspector_property_edited(property: StringName) -> void:
	if not _property_affects_timeline(property):
		return

	if _preview != null:
		_preview.rebuild(_sequence)
	if _playback != null:
		_playback.rebuild()

	if not _property_refresh_pending:
		_property_refresh_pending = true
		call_deferred("_refresh_property_views")

func _property_affects_timeline(property: StringName) -> bool:
	return property in [
		&"action",
		&"enabled",
		&"start_time",
		&"duration",
		&"hold_duration",
		&"fade_duration",
		&"delay_after_close",
		&"wait_until_closed",
		&"track",
		&"stream",
		&"mode",
		&"loop_stream",
		&"volume_db",
		&"pitch_scale",
		&"track_id",
		&"restart",
		&"wait_for_completion",
		&"cut_immediately",
		&"blend_duration",
		&"transition_type",
		&"ease_type",
		&"use_follow_target",
		&"use_zoom_override",
		&"zoom_override",
		&"restore_previous_camera",
		&"preserve_camera_position_on_enter",
		&"track_index",
		&"muted",
		&"locked",
		&"visible",
		&"track_name",
		&"track_type",
		&"color",
		&"allows_overlap",
	]

func _connect_actions() -> void:
	_observed_actions.clear()

	if not is_instance_valid(_sequence):
		return

	for action in _sequence.get_all_actions():
		if action == null or _observed_actions.has(action):
			continue

		_observed_actions.append(action)

		# Do not connect action.changed here.
		#
		# EditorInspector changes exported String properties one character at a
		# time. Resource.changed would rebuild playback and timeline selection
		# during each keystroke, destroying the active text editor.


func _disconnect_action_signals() -> void:
	_observed_actions.clear()


func _disconnect_observed_resources() -> void:
	_disconnect_action_signals()

	if is_instance_valid(_sequence) and _sequence.changed.is_connected(_on_sequence_changed):
		_sequence.changed.disconnect(_on_sequence_changed)


func _show_empty_state() -> void:
	if not is_node_ready():
		return

	_summary.show_empty_state()
	_action_tree.clear_sequence()
	_timeline.clear_sequence()
	_status_bar.show_empty_state()
	_inspector_panel.clear()
	_clear_preview()
	if _playback != null:
		_playback.set_sequence(null)
	_update_toolbar_state()


func _exit_tree() -> void:
	set_process(false)
	if _preview != null:
		_preview.cleanup()
	if is_instance_valid(_runtime_preview):
		_runtime_preview.clear_preview()
	_disconnect_observed_resources()

func _refresh_property_views() -> void:
	_property_refresh_pending = false
	if not is_node_ready() or not is_instance_valid(_sequence):
		return

	# Do not rebuild ActionTree or reassign the Inspector here.
	# Tree reconstruction can reclaim editor keyboard focus.
	_summary.set_sequence(_sequence)
	_action_tree.refresh()
	_timeline.refresh_from_sequence()
	_timeline.set_playback_time(_playback.current_time)
	_timeline.set_active_action(_playback.get_current_action_index())
	_update_toolbar_state()
	_update_playback_status()


func _show_unsupported_legacy_status() -> void:
	_status_bar.set_error("Unsupported legacy sequence. Run the MatineeSequence migration tool before editing.")
