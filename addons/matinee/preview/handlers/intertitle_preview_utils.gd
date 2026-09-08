@tool
class_name MatineeIntertitlePreviewUtils
extends RefCounted


static func get_title_opacity(
	time: float,
	start_time: float,
	end_time: float,
	configured_fade: float
) -> float:
	var duration := maxf(end_time - start_time, 0.0)
	if duration <= 0.0:
		return 0.0
	var fade := 0.45 if configured_fade < 0.0 else maxf(configured_fade, 0.01)
	fade = minf(fade, duration * 0.5)
	if fade <= 0.0:
		return 1.0
	var elapsed := clampf(time - start_time, 0.0, duration)
	var remaining := maxf(end_time - time, 0.0)
	return clampf(minf(elapsed / fade, remaining / fade), 0.0, 1.0)
