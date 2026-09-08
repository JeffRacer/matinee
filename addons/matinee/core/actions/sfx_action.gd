@tool
class_name MatineeSFXAction
extends MatineeAction

enum SFXMode { GENERAL, UI, WORLD }

@export_category("Sound Effect")
@export var mode: SFXMode = SFXMode.GENERAL
@export var stream: AudioStream
@export_range(-80.0, 12.0, 0.1) var volume_db: float = 0.0
@export_range(0.01, 4.0, 0.01) var pitch_scale: float = 1.0
@export var world_target_path: NodePath
@export var fallback_world_position: Vector2 = Vector2.ZERO
@export_range(1.0, 10000.0, 1.0) var max_distance: float = 1200.0
@export var wait_for_completion: bool = false


func _init() -> void:
	action_name = "Sound Effect"


func play(director: Node) -> void:
	if stream == null:
		push_warning("MatineeSFXAction has no stream assigned.")
		return
	var sfx_manager := _get_runtime_service()
	if sfx_manager == null:
		push_warning("MatineeSFXAction requires a configured host audio service (runtime_service_path).")
		return

	var playback_handle := -1
	match mode:
		SFXMode.GENERAL:
			playback_handle = int(sfx_manager.call("play_stream", stream, volume_db, pitch_scale))
		SFXMode.UI:
			playback_handle = int(sfx_manager.call("play_ui", stream, volume_db, pitch_scale))
		SFXMode.WORLD:
			var world_position := fallback_world_position
			if director != null and not world_target_path.is_empty():
				var target := director.get_node_or_null(world_target_path) as Node2D
				if target != null:
					world_position = target.global_position
			playback_handle = int(sfx_manager.call(
				"play_world",
				stream,
				world_position,
				volume_db,
				pitch_scale,
				max_distance
			))
	if playback_handle >= 0 and director != null and director.has_method("register_sequence_sfx_handle"):
		director.call("register_sequence_sfx_handle", playback_handle)

	if wait_for_completion and playback_handle >= 0:
		while bool(sfx_manager.call("is_playing", playback_handle)):
			await sfx_manager.sound_finished

func get_duration_seconds() -> float:
	if not wait_for_completion or stream == null:
		return 0.0
	return maxf(stream.get_length(), 0.0)
