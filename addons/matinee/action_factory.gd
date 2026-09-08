@tool
class_name MatineeActionFactory
extends RefCounted

const ACTION_TYPES: Array[Dictionary] = [
	{"id": &"title_card", "label": "Title Card", "category_path": "Presentation/Title Card", "script_path": "res://addons/matinee/core/actions/title_card_action.gd"},
	{"id": &"background_image", "label": "Background Image", "category_path": "Presentation/Background Image", "script_path": "res://addons/matinee/core/actions/background_image_action.gd"},
	{"id": &"chapter", "label": "Chapter Card", "category_path": "Presentation/Chapter Card", "script_path": "res://addons/matinee/core/actions/chapter_action.gd"},
	{"id": &"location", "label": "Location Card", "category_path": "Presentation/Location Card", "script_path": "res://addons/matinee/core/actions/location_action.gd"},
	{"id": &"fade", "label": "Fade", "category_path": "Presentation/Fade", "script_path": "res://addons/matinee/core/actions/fade_action.gd"},
	{"id": &"cinematic", "label": "Cinematic", "category_path": "Presentation/Cinematic", "script_path": "res://addons/matinee/core/actions/cinematic_action.gd"},
	{"id": &"presentation", "label": "Presentation", "category_path": "Presentation/Presentation", "script_path": "res://addons/matinee/core/actions/presentation_action.gd"},
	{"id": &"dialogue", "label": "Dialogue", "category_path": "Dialogue/Dialogue", "script_path": "res://addons/matinee/core/actions/dialogue_action.gd"},
	{"id": &"camera", "label": "Camera", "category_path": "Camera/Camera", "script_path": "res://addons/matinee/core/actions/camera_action.gd"},
	{"id": &"play_music", "label": "Play Music", "category_path": "Audio/Music/Play Music", "script_path": "res://addons/matinee/core/actions/play_music_action.gd"},
	{"id": &"stop_music", "label": "Stop Music", "category_path": "Audio/Music/Stop Music", "script_path": "res://addons/matinee/core/actions/stop_music_action.gd"},
	{"id": &"pause_music", "label": "Pause Music", "category_path": "Audio/Music/Pause Music", "script_path": "res://addons/matinee/core/actions/pause_music_action.gd"},
	{"id": &"resume_music", "label": "Resume Music", "category_path": "Audio/Music/Resume Music", "script_path": "res://addons/matinee/core/actions/resume_music_action.gd"},
	{"id": &"sfx", "label": "Sound Effect", "category_path": "Audio/Sound Effects/Sound Effect", "script_path": "res://addons/matinee/core/actions/sfx_action.gd"},
	{"id": &"voice", "label": "Voice", "category_path": "Audio/Voice/Voice", "script_path": "res://addons/matinee/core/actions/voice_action.gd"},
	{"id": &"ambience", "label": "Ambience", "category_path": "Audio/Ambience/Ambience", "script_path": "res://addons/matinee/core/actions/ambience_action.gd"},
	{"id": &"scene", "label": "Scene Change", "category_path": "Gameplay/Scene Change", "script_path": "res://addons/matinee/core/actions/scene_action.gd"},
	{"id": &"wait", "label": "Wait", "category_path": "Gameplay/Wait", "script_path": "res://addons/matinee/core/actions/wait_action.gd"},
]


static func get_types() -> Array[Dictionary]:
	return ACTION_TYPES


static func get_menu_tree() -> Dictionary:
	var root := {}
	for entry: Dictionary in ACTION_TYPES:
		var categories := str(entry.get("category_path", entry.get("label", "Action"))).split("/", false)
		var branch := root
		for category_index in range(categories.size() - 1):
			var category := categories[category_index]
			if not branch.has(category):
				branch[category] = {}
			branch = branch[category]
		branch[categories[categories.size() - 1]] = entry
	return root


static func create(action_id: StringName) -> MatineeAction:
	for entry in ACTION_TYPES:
		if entry.id == action_id:
			var script_path := str(entry.get("script_path", ""))
			if script_path.is_empty() or not ResourceLoader.exists(script_path):
				return null
			var script := ResourceLoader.load(script_path, "Script") as Script
			if script == null:
				return null
			return script.new() as MatineeAction
	return null
