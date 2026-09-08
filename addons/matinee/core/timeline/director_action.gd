@tool
class_name MatineeAction
extends Resource

@export_category("Action")
@export var enabled: bool = true
## Optional host service path relative to the SceneTree root.
@export var runtime_service_path: NodePath
@export var action_name: String = "Matinee Action"


func play(_director: Node) -> void:
	# Child action resources override this function.
	await Engine.get_main_loop().process_frame


## Estimated amount of timeline time consumed by this action.
## Return 0.0 for immediate actions.
func get_duration_seconds() -> float:
	return 0.0


## False means the duration depends on player input or runtime state.
func has_exact_duration() -> bool:
	return true


## Action-specific authoring issues. Scene-dependent validation may pass a
## runtime or edited-scene root; resources must remain valid without one.
func get_validation_issues(_scene_context: Node = null) -> PackedStringArray:
	return PackedStringArray()


## Resolves an optional project autoload without creating a compile-time
## dependency on the game that hosts the editor plugin.
func _get_runtime_service() -> Node:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if runtime_service_path.is_empty() or scene_tree == null or scene_tree.root == null:
		return null
	return scene_tree.root.get_node_or_null(runtime_service_path)


## Human-readable label used by Matinee editor tools.
func get_editor_name() -> String:
	var configured := action_name.strip_edges()
	if not configured.is_empty() and configured != "Matinee Action":
		return configured
	var script := get_script() as Script
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name().replace("Action", "").replace("_", " ").capitalize().strip_edges()
	return "Matinee Action"


## Optional one-line detail displayed beside the action name.
func get_editor_summary() -> String:
	if "message" in self:
		var text := str(get("message")).strip_edges().replace("\n", " ")
		if text.length() > 48:
			text = text.left(45) + "..."
		return text
	if "main_text" in self:
		return str(get("main_text")).strip_edges()
	if "chapter_title" in self:
		return str(get("chapter_title")).strip_edges()
	if "location_name" in self:
		return str(get("location_name")).strip_edges()
	if "scene_path" in self and not str(get("scene_path")).is_empty():
		return str(get("scene_path")).get_file().get_basename()
	if "track_id" in self and get("track_id") != &"":
		return str(get("track_id"))
	if "track" in self and get("track") != null:
		var track_resource := get("track") as Resource
		return track_resource.resource_path.get_file().get_basename()
	if "stream" in self and get("stream") != null:
		var stream_resource := get("stream") as Resource
		return stream_resource.resource_path.get_file().get_basename()
	return ""


## Tint used by editor lists and the future timeline view.
func get_editor_color() -> Color:
	if not enabled:
		return Color(0.55, 0.55, 0.55)
	match get_editor_name():
		"Fade": return Color(0.78, 0.62, 0.95)
		"Dialogue": return Color(0.55, 0.72, 1.0)
		"Music": return Color(0.52, 0.9, 0.66)
		"Ambience": return Color(0.58, 0.84, 0.72)
		"Sound Effect", "Voice": return Color(0.95, 0.72, 0.45)
		"Scene Change", "Cinematic": return Color(0.98, 0.58, 0.58)
		"Title Card", "Chapter Card", "Location Card": return Color(0.95, 0.86, 0.5)
		_: return Color(0.86, 0.86, 0.86)
