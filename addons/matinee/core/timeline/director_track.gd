@tool
class_name MatineeTrack
extends Resource

enum TrackType {
	GENERAL,
	VISUAL,
	AUDIO,
	CAMERA,
	GAMEPLAY,
}

@export_category("Track")
@export var track_name: String = "Track"
@export var track_type: TrackType = TrackType.GENERAL
@export var enabled: bool = true
@export var muted: bool = false
@export var locked: bool = false
@export var visible: bool = true
@export var color: Color = Color(0.36, 0.58, 0.86)
@export var allows_overlap: bool = true

@export_category("Timeline Actions")
@export var actions: Array[MatineeTimelineAction] = []


func get_duration_seconds() -> float:
	var duration := 0.0
	for timeline_action in actions:
		if timeline_action == null or timeline_action.action == null:
			continue
		if not timeline_action.action.enabled:
			continue
		duration = maxf(duration, timeline_action.get_end_time())
	return duration


func get_enabled_action_count() -> int:
	var count := 0
	for timeline_action in actions:
		if timeline_action != null and timeline_action.action != null and timeline_action.action.enabled:
			count += 1
	return count


func get_validation_issues() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if track_name.strip_edges().is_empty():
		issues.append({"action_index": -1, "message": "Track name cannot be empty."})
	for action_index in range(actions.size()):
		var timeline_action := actions[action_index]
		if timeline_action == null:
			issues.append({"action_index": action_index, "message": "Timeline action entry is empty."})
			continue
		for message in timeline_action.get_validation_issues():
			issues.append({"action_index": action_index, "message": message})
	if not allows_overlap:
		for left_index in range(actions.size()):
			var left := actions[left_index]
			if left == null or left.action == null or left.duration <= 0.0:
				continue
			for right_index in range(left_index + 1, actions.size()):
				var right := actions[right_index]
				if right == null or right.action == null or right.duration <= 0.0:
					continue
				if left.start_time < right.get_end_time() and right.start_time < left.get_end_time():
					issues.append({"action_index": right_index, "message": "Timeline actions overlap on a track that disallows overlap."})
	return issues


static func from_legacy_actions(legacy_actions: Array[MatineeAction]) -> MatineeTrack:
	var track := MatineeTrack.new()
	track.track_name = "Main"
	var start_time := 0.0
	for action in legacy_actions:
		var timeline_action := MatineeTimelineAction.from_legacy_action(action, start_time)
		track.actions.append(timeline_action)
		if action != null and action.enabled:
			start_time += timeline_action.duration
	return track
