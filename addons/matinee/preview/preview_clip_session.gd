@tool
class_name MatineePreviewClipSession
extends RefCounted

enum State { INACTIVE, ENTERED, ACTIVE, EXITED, RESET }

var clip_id: StringName
var track_index: int = -1
var action_index: int = -1
var timeline_action: MatineeTimelineAction
var action: MatineeAction
var handler: Variant
var local_time: float = 0.0
var previous_local_time: float = 0.0
var state: State = State.INACTIVE
var entered: bool = false
var one_shot_fired: bool = false
var owned_preview_resources: Array = []
var last_preview_error: String = ""
var failed: bool = false
var last_update_timestamp: int = 0


func configure(entry: Dictionary, preview_handler: Variant) -> void:
	clip_id = MatineePreviewClipIdentity.from_entry(entry)
	track_index = int(entry.get("track_index", -1))
	action_index = int(entry.get("action_index", -1))
	timeline_action = entry.get("timeline_action") as MatineeTimelineAction
	action = entry.get("action") as MatineeAction
	handler = preview_handler


func update_time(timeline_time: float, start_time: float) -> void:
	previous_local_time = local_time
	local_time = maxf(timeline_time - start_time, 0.0)
	last_update_timestamp = Time.get_ticks_msec()
