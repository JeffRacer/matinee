@tool
class_name MatineeTimelineAction
extends Resource


@export_category("Timeline Action")

var _action: MatineeAction

@export var action: MatineeAction:
	get:
		return _action
	set(value):
		_set_action(value)

@export_range(0.0, 86400.0, 0.01, "or_greater")
var start_time: float = 0.0

@export_range(0.0, 86400.0, 0.01, "or_greater")
var duration: float = 0.0


func _set_action(value: MatineeAction) -> void:
	if _action == value:
		return

	if (
		_action != null
		and _action.changed.is_connected(_on_action_changed)
	):
		_action.changed.disconnect(_on_action_changed)

	_action = value

	if (
		_action != null
		and not _action.changed.is_connected(_on_action_changed)
	):
		_action.changed.connect(_on_action_changed)

	emit_changed()


func _on_action_changed() -> void:
	# Matinee actions are nested subresources. Forward their change signal so
	# the timeline action and containing sequence are marked dirty when an
	# action property is edited in the Inspector.
	emit_changed()


func get_end_time() -> float:
	return maxf(start_time, 0.0) + maxf(duration, 0.0)


func is_active_at(time: float) -> bool:
	return (
		action != null
		and action.enabled
		and duration > 0.0
		and time >= start_time
		and time < get_end_time()
	)


func get_validation_issues() -> PackedStringArray:
	var issues := PackedStringArray()

	if action == null:
		issues.append(
			"Timeline action has no MatineeAction resource."
		)

	if start_time < 0.0:
		issues.append(
			"Timeline action start time cannot be negative."
		)

	if duration < 0.0:
		issues.append(
			"Timeline action duration cannot be negative."
		)

	return issues


static func from_legacy_action(
	source: MatineeAction,
	time: float
) -> MatineeTimelineAction:
	var timeline_action := MatineeTimelineAction.new()
	timeline_action.action = source
	timeline_action.start_time = maxf(time, 0.0)
	timeline_action.duration = (
		maxf(source.get_duration_seconds(), 0.0)
		if source != null
		else 0.0
	)
	return timeline_action
