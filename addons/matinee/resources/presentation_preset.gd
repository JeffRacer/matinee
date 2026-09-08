class_name MatineePresentationPreset
extends Resource

@export_category("Preset")
@export var preset_name: String = "Classic 1957"

@export_multiline
var description: String = ""

@export_category("Master")
@export var movie_mode_enabled: bool = true

@export_range(0.0, 1.0, 0.01)
var master_opacity: float = 1.0

@export_category("Color Grade")
@export var color_grade_enabled: bool = false
@export_range(0.0, 1.0, 0.01) var color_grade_effect_strength: float = 0.0
@export_range(0.0, 2.0, 0.01) var color_grade_saturation: float = 1.0
@export_range(0.0, 2.0, 0.01) var color_grade_contrast: float = 1.0
@export_range(-0.5, 0.5, 0.01) var color_grade_brightness: float = 0.0
@export_range(0.0, 2.0, 0.01) var color_grade_red_boost: float = 1.0
@export_range(0.0, 2.0, 0.01) var color_grade_green_boost: float = 1.0
@export_range(0.0, 2.0, 0.01) var color_grade_blue_boost: float = 1.0
@export_range(0.0, 0.5, 0.01) var color_grade_black_lift: float = 0.0
@export_range(0.0, 1.0, 0.01) var color_grade_color_separation: float = 0.0

@export_category("Grain")
@export var grain_enabled: bool = true

@export_range(0.0, 0.30, 0.001)
var grain_strength: float = 0.055

@export_range(50.0, 1200.0, 1.0)
var grain_scale: float = 420.0

@export_range(0.0, 20.0, 0.05)
var grain_animation_speed: float = 8.0

@export_range(0.25, 3.0, 0.01)
var grain_contrast: float = 1.15

@export_range(0.0, 2.0, 0.01)
var grain_shadow_boost: float = 0.35

@export_category("Flicker")
@export var flicker_enabled: bool = true

@export_range(0.0, 0.20, 0.001)
var flicker_strength: float = 0.018

@export_range(0.0, 0.20, 0.001)
var flicker_contrast_strength: float = 0.010

@export_range(0.0, 20.0, 0.05)
var flicker_speed: float = 7.0

@export_range(0.0, 0.40, 0.001)
var flicker_rare_dip_strength: float = 0.05

@export_range(0.0, 1.0, 0.001)
var flicker_rare_dip_frequency: float = 0.04

@export_range(-0.10, 0.10, 0.001)
var flicker_warm_shift: float = 0.008

@export_category("Dust")
@export var dust_enabled: bool = true

@export_range(0.0, 1.0, 0.01)
var dust_opacity: float = 0.13

@export_range(1, 300, 1)
var dust_particle_count: int = 55

@export_range(0.1, 20.0, 0.1)
var dust_lifetime: float = 5.0

@export_range(0.0, 300.0, 1.0)
var dust_minimum_speed: float = 8.0

@export_range(0.0, 300.0, 1.0)
var dust_maximum_speed: float = 24.0

@export_category("Scratches")
@export var scratches_enabled: bool = true

@export_range(0.0, 1.0, 0.001)
var scratches_opacity: float = 0.14

@export_range(0.0, 1.0, 0.001)
var scratches_frequency: float = 0.07

@export_range(0.0001, 0.03, 0.0001)
var scratches_width: float = 0.0015

@export_range(0.0, 10.0, 0.05)
var scratches_speed: float = 1.1

@export_range(0.02, 1.0, 0.01)
var scratches_duration: float = 0.14

@export_range(0.0, 1.0, 0.01)
var scratches_vertical_breakup: float = 0.42

@export_range(0.0, 1.0, 0.01)
var scratches_dark_chance: float = 0.18

@export_category("Vignette")
@export var vignette_enabled: bool = true

@export_range(0.0, 1.0, 0.01)
var vignette_strength: float = 0.22

@export_range(0.1, 1.5, 0.01)
var vignette_radius: float = 0.82

@export_range(0.01, 1.0, 0.01)
var vignette_softness: float = 0.42

@export_range(0.25, 2.0, 0.01)
var vignette_vertical_scale: float = 0.78

@export var vignette_center_offset: Vector2 = Vector2.ZERO

@export_category("Gate Weave")
@export var gate_weave_enabled: bool = true

@export_range(0.0, 8.0, 0.1)
var gate_weave_amount: float = 0.75

@export_range(0.02, 1.0, 0.01)
var gate_weave_interval: float = 0.18
