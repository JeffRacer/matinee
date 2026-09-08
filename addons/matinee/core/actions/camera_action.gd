@tool
class_name MatineeCameraAction
extends MatineeAction

@export_category("Camera")
@export var camera_path: NodePath
@export var cut_immediately: bool = false
@export_range(0.0, 30.0, 0.01, "or_greater") var blend_duration: float = 0.5
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_category("Follow")
@export var use_follow_target: bool = false
@export var follow_target_path: NodePath
@export var preserve_camera_position_on_enter: bool = false

@export_category("Zoom")
@export var use_zoom_override: bool = false
@export var zoom_override: Vector2 = Vector2.ONE

@export_category("Exit")
@export var restore_previous_camera: bool = true


func _init() -> void:
	action_name = "Camera"


func play(director: Node) -> void:
	if director == null or not director.has_method("play_camera_action"):
		push_warning("MatineeCameraAction requires a Matinee camera runtime handler.")
		return
	await director.call("play_camera_action", self)


func get_duration_seconds() -> float:
	return 0.0 if cut_immediately else maxf(blend_duration, 0.0)


func get_editor_name() -> String:
	return "Camera"


func get_editor_summary() -> String:
	var mode := "Cut" if is_cut() else "Blend %.2fs" % maxf(blend_duration, 0.0)
	var target := str(camera_path)
	if target.is_empty():
		target = "Missing target"
	return "%s · %s" % [mode, target]


func get_editor_color() -> Color:
	return Color(0.42, 0.78, 0.96) if enabled else Color(0.55, 0.55, 0.55)


func is_cut() -> bool:
	return cut_immediately or is_zero_approx(blend_duration)


func get_validation_issues(scene_context: Node = null) -> PackedStringArray:
	var issues := PackedStringArray()
	if camera_path.is_empty():
		issues.append("Camera Action requires a target Camera2D path.")
	elif scene_context != null:
		var target := scene_context.get_node_or_null(camera_path)
		if target == null:
			issues.append("Camera target could not be resolved: %s" % camera_path)
		elif not target is Camera2D:
			issues.append("Camera target is not a Camera2D: %s" % camera_path)
	if blend_duration < 0.0:
		issues.append("Camera blend duration cannot be negative.")
	if use_zoom_override and (zoom_override.x <= 0.0 or zoom_override.y <= 0.0):
		issues.append("Camera zoom override components must be greater than zero.")
	if use_follow_target:
		if follow_target_path.is_empty():
			issues.append("Camera follow is enabled but no follow target path is set.")
		elif scene_context != null:
			var follow_target := scene_context.get_node_or_null(follow_target_path)
			if follow_target == null:
				issues.append("Camera follow target could not be resolved: %s" % follow_target_path)
			elif not follow_target is Node2D:
				issues.append("Camera follow target is not a Node2D: %s" % follow_target_path)
	return issues


func get_transition_label() -> String:
	match transition_type:
		Tween.TRANS_LINEAR: return "Linear"
		Tween.TRANS_SINE: return "Sine"
		Tween.TRANS_QUINT: return "Quint"
		Tween.TRANS_QUART: return "Quart"
		Tween.TRANS_QUAD: return "Quad"
		Tween.TRANS_EXPO: return "Expo"
		Tween.TRANS_ELASTIC: return "Elastic"
		Tween.TRANS_CUBIC: return "Cubic"
		Tween.TRANS_CIRC: return "Circ"
		Tween.TRANS_BOUNCE: return "Bounce"
		Tween.TRANS_BACK: return "Back"
		Tween.TRANS_SPRING: return "Spring"
		_: return "Transition %d" % transition_type


func get_ease_label() -> String:
	match ease_type:
		Tween.EASE_IN: return "In"
		Tween.EASE_OUT: return "Out"
		Tween.EASE_IN_OUT: return "In Out"
		Tween.EASE_OUT_IN: return "Out In"
		_: return "Ease %d" % ease_type
