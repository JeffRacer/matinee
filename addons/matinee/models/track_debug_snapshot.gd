@tool
class_name MatineeTrackDebugSnapshot
extends RefCounted


static func build(
	sequence: MatineeSequence,
	selection_state: MatineeSelectionState,
	active_timeline_actions: Dictionary,
	pixels_per_second: float,
	visible_rect: Rect2,
	label_width: float,
	ruler_height: float,
	row_height: float,
	bar_margin: float,
	minimum_bar_width: float
) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	if not is_instance_valid(sequence) or not sequence.is_current_track_format():
		return snapshot
	for track_index in range(sequence.tracks.size()):
		var track := sequence.tracks[track_index]
		var track_data := {
			"track_index": track_index,
			"track_name": "<null>" if track == null else track.track_name,
			"track_type": "Invalid" if track == null else _get_track_type_name(track.track_type),
			"muted": false if track == null else track.muted,
			"locked": false if track == null else track.locked,
			"visible": false if track == null else track.visible,
			"enabled": false if track == null else track.enabled,
			"clip_count": 0 if track == null else track.actions.size(),
			"row_y": ruler_height + float(track_index) * row_height,
			"clips": [],
		}
		if track == null:
			snapshot.append(track_data)
			continue
		var clip_data: Array[Dictionary] = []
		for action_index in range(track.actions.size()):
			var clip := track.actions[action_index]
			var rect := _get_clip_rect(
				track_index, clip, pixels_per_second, label_width,
				ruler_height, row_height, bar_margin, minimum_bar_width
			)
			var selected := (
				selection_state != null
				and selection_state.track_index == track_index
				and selection_state.action_index == action_index
			)
			var active := active_timeline_actions.has("%d:%d" % [track_index, action_index])
			var drawable := true
			var reason := ""
			if clip == null:
				drawable = false
				reason = "null timeline clip"
			elif clip.action == null:
				drawable = false
				reason = "null wrapped action"
			elif is_nan(clip.start_time) or is_inf(clip.start_time) or clip.start_time < 0.0:
				drawable = false
				reason = "invalid start time"
			elif is_nan(clip.duration) or is_inf(clip.duration) or clip.duration < 0.0:
				drawable = false
				reason = "invalid duration"
			elif not track.visible:
				drawable = false
				reason = "hidden track"
			elif rect.size.x <= 0.0:
				drawable = false
				reason = "zero-width clip"
			elif not visible_rect.intersects(rect):
				drawable = false
				reason = "outside visible range"
			var stale_selection := selected and selection_state.timeline_action != clip
			if stale_selection:
				drawable = false
				reason = "stale selection reference"
			clip_data.append({
				"action_index": action_index,
				"action_name": "<null>" if clip == null or clip.action == null else clip.action.get_editor_name(),
				"action_is_null": clip == null or clip.action == null,
				"start_time": 0.0 if clip == null else clip.start_time,
				"duration": 0.0 if clip == null else clip.duration,
				"end_time": 0.0 if clip == null else clip.get_end_time(),
				"x": rect.position.x,
				"width": rect.size.x,
				"selected": selected,
				"active": active,
				"drawable": drawable,
				"reason": reason,
				"stale_selection": stale_selection,
			})
		track_data["clips"] = clip_data
		snapshot.append(track_data)
	return snapshot


static func _get_clip_rect(
	track_index: int,
	clip: MatineeTimelineAction,
	pixels_per_second: float,
	label_width: float,
	ruler_height: float,
	row_height: float,
	bar_margin: float,
	minimum_bar_width: float
) -> Rect2:
	if clip == null or track_index < 0:
		return Rect2()
	return Rect2(
		label_width + maxf(clip.start_time, 0.0) * pixels_per_second,
		ruler_height + float(track_index) * row_height + bar_margin,
		maxf(maxf(clip.duration, 0.0) * pixels_per_second, minimum_bar_width),
		row_height - bar_margin * 2.0
	)


static func _get_track_type_name(track_type: int) -> String:
	match track_type:
		MatineeTrack.TrackType.VISUAL:
			return "Visual"
		MatineeTrack.TrackType.AUDIO:
			return "Audio"
		MatineeTrack.TrackType.CAMERA:
			return "Camera"
		MatineeTrack.TrackType.GAMEPLAY:
			return "Gameplay"
		_:
			return "General"
