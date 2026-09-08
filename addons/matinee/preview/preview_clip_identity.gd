@tool
class_name MatineePreviewClipIdentity
extends RefCounted


static func from_entry(entry: Dictionary) -> StringName:
	var clip := entry.get("timeline_action") as MatineeTimelineAction
	var action := entry.get("action") as MatineeAction
	var clip_id := clip.get_instance_id() if is_instance_valid(clip) else 0
	var action_id := action.get_instance_id() if is_instance_valid(action) else 0
	return StringName("%d:%d:%d:%d" % [
		clip_id,
		action_id,
		int(entry.get("track_index", -1)),
		int(entry.get("action_index", -1)),
	])
