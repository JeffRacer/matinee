@tool
class_name MatineeAudioPreviewService
extends RefCounted

const ROOT_NAME := "BRPreviewAudioRoot"

var _preview_root: Node
var _audio_root: Node
var _players := {}
var _looping := {}
var _play_counts := {}
var _started := {}
var _muted := false
var _audio_while_scrubbing := false


func prepare(preview_root: Node) -> void:
	if _preview_root == preview_root and is_instance_valid(_audio_root):
		return
	cleanup()
	_preview_root = preview_root
	if not is_instance_valid(_preview_root):
		return
	_audio_root = Node.new()
	_audio_root.name = ROOT_NAME
	_preview_root.add_child(_audio_root)


func set_muted(enabled: bool) -> void:
	_muted = enabled
	if _muted:
		stop_all()


func set_audio_while_scrubbing(enabled: bool) -> void:
	_audio_while_scrubbing = enabled


func play_clip(
	clip_id: StringName,
	stream: AudioStream,
	local_time: float,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	looping: bool = false
) -> bool:
	if _muted or stream == null or not _ensure_root():
		return false
	var player := _get_or_create_player(clip_id)
	var stream_changed := player.stream != stream
	player.stream = stream
	player.volume_db = clampf(volume_db, -80.0, 24.0)
	player.pitch_scale = clampf(pitch_scale, 0.01, 4.0)
	_looping[clip_id] = looping
	if stream_changed or not bool(_started.get(clip_id, false)):
		if player.is_inside_tree():
			player.play(_clamp_seek_time(stream, local_time))
		_started[clip_id] = true
		_play_counts[clip_id] = int(_play_counts.get(clip_id, 0)) + 1
	return true


func update_clip(clip_id: StringName, local_time: float, paused: bool) -> void:
	var player := _players.get(clip_id) as AudioStreamPlayer
	if not is_instance_valid(player):
		return
	player.stream_paused = paused
	if not paused and player.stream != null and player.playing and player.is_inside_tree():
		var target := _clamp_seek_time(player.stream, local_time)
		if absf(player.get_playback_position() - target) > 0.35:
			player.seek(target)


func play_one_shot(
	clip_id: StringName,
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> bool:
	if _muted or stream == null or not _ensure_root():
		return false
	var player := _get_or_create_player(clip_id)
	player.stop()
	player.stream = stream
	player.volume_db = clampf(volume_db, -80.0, 24.0)
	player.pitch_scale = clampf(pitch_scale, 0.01, 4.0)
	_looping[clip_id] = false
	if player.is_inside_tree():
		player.play()
	_started[clip_id] = true
	_play_counts[clip_id] = int(_play_counts.get(clip_id, 0)) + 1
	return true


func pause_all() -> void:
	for player: AudioStreamPlayer in _players.values():
		if is_instance_valid(player):
			player.stream_paused = true


func resume_all() -> void:
	if _muted:
		return
	for player: AudioStreamPlayer in _players.values():
		if is_instance_valid(player):
			player.stream_paused = false


func stop_clip(clip_id: StringName) -> void:
	var player := _players.get(clip_id) as AudioStreamPlayer
	_players.erase(clip_id)
	_looping.erase(clip_id)
	_started.erase(clip_id)
	if not is_instance_valid(player):
		return
	player.stop()
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	player.queue_free()


func stop_all() -> void:
	var clip_ids: Array = _players.keys()
	for clip_id in clip_ids:
		stop_clip(clip_id)


func cleanup() -> void:
	stop_all()
	_players.clear()
	_looping.clear()
	_started.clear()
	_play_counts.clear()
	if is_instance_valid(_audio_root):
		if _audio_root.get_parent() != null:
			_audio_root.get_parent().remove_child(_audio_root)
		_audio_root.queue_free()
	_audio_root = null
	_preview_root = null


func get_player_count() -> int:
	return _players.size()


func get_play_count(clip_id: StringName) -> int:
	return int(_play_counts.get(clip_id, 0))


func has_player(clip_id: StringName) -> bool:
	return is_instance_valid(_players.get(clip_id))


func get_debug_snapshot() -> Dictionary:
	return {
		"player_count": _players.size(),
		"play_counts": _play_counts.duplicate(),
		"muted": _muted,
		"audio_while_scrubbing": _audio_while_scrubbing,
	}


func _ensure_root() -> bool:
	if is_instance_valid(_audio_root):
		return true
	if not is_instance_valid(_preview_root):
		return false
	prepare(_preview_root)
	return is_instance_valid(_audio_root)


func _get_or_create_player(clip_id: StringName) -> AudioStreamPlayer:
	var player := _players.get(clip_id) as AudioStreamPlayer
	if is_instance_valid(player):
		return player
	player = AudioStreamPlayer.new()
	player.name = "BRPreviewAudio_%s" % String(clip_id).replace(":", "_")
	player.finished.connect(_on_player_finished.bind(clip_id))
	_audio_root.add_child(player)
	_players[clip_id] = player
	return player


func _on_player_finished(clip_id: StringName) -> void:
	var player := _players.get(clip_id) as AudioStreamPlayer
	if not is_instance_valid(player) or not bool(_looping.get(clip_id, false)) or _muted:
		return
	if player.is_inside_tree():
		player.play()
	_play_counts[clip_id] = int(_play_counts.get(clip_id, 0)) + 1


func _clamp_seek_time(stream: AudioStream, time: float) -> float:
	var length := stream.get_length()
	if length <= 0.0:
		return maxf(time, 0.0)
	return clampf(time, 0.0, maxf(length - 0.001, 0.0))
