@tool
class_name MatineeSequenceSummary
extends VBoxContainer

@onready var _sequence_name_label: Label = $SequenceName
@onready var _duration_label: Label = $SummaryGrid/DurationValue
@onready var _action_count_label: Label = $SummaryGrid/ActionsValue
@onready var _timing_label: Label = $SummaryGrid/TimingValue


func set_sequence(sequence: MatineeSequence) -> void:
	if not is_instance_valid(sequence):
		show_empty_state()
		return

	_sequence_name_label.text = sequence.sequence_name
	_duration_label.text = sequence.get_formatted_duration()
	_action_count_label.text = str(sequence.get_enabled_action_count())
	_timing_label.text = sequence.get_timing_label()


func show_empty_state() -> void:
	_sequence_name_label.text = "Select a MatineeSequence resource"
	_duration_label.text = "—"
	_action_count_label.text = "—"
	_timing_label.text = "—"
