class_name Ambient
extends RefCounted
## Ambient particle presets for the world scene (WU-057). Particles are plain
## squares tinted via `color`; low alpha and few of them keep places readable.

## Kinds a region's map.ambient may name.
const KINDS: PackedStringArray = ["petals", "leaves", "snow", "mist", "embers", "fireflies"]
const MAX_AMOUNT := 40

const PRESETS := {
	"petals": {"amount": 24, "color": Color(1.0, 0.75, 0.82, 0.55), "gravity": Vector2(6, 14), "speed": 8.0, "size": 3.0, "lifetime": 9.0},
	"leaves": {"amount": 24, "color": Color(0.85, 0.5, 0.2, 0.55), "gravity": Vector2(-8, 16), "speed": 10.0, "size": 3.5, "lifetime": 9.0},
	"snow": {"amount": 40, "color": Color(1.0, 1.0, 1.0, 0.6), "gravity": Vector2(-4, 18), "speed": 6.0, "size": 2.5, "lifetime": 10.0},
	"mist": {"amount": 14, "color": Color(0.85, 0.9, 0.9, 0.12), "gravity": Vector2(5, 0), "speed": 6.0, "size": 40.0, "lifetime": 14.0},
	"embers": {"amount": 24, "color": Color(1.0, 0.55, 0.2, 0.7), "gravity": Vector2(0, -14), "speed": 10.0, "size": 2.5, "lifetime": 6.0},
	"fireflies": {"amount": 20, "color": Color(0.95, 1.0, 0.45, 0.7), "gravity": Vector2.ZERO, "speed": 12.0, "size": 2.5, "lifetime": 7.0},
}


## The kind shown in a season ("Spring"...), from a map.ambient dict
## ({"spring": "petals", "any": "mist"}); "" for none. A season entry wins over "any".
static func kind_for(ambient: Dictionary, season: String) -> String:
	var kind := String(ambient.get(season.to_lower(), ambient.get("any", "")))
	return kind if KINDS.has(kind) else ""


## A CPUParticles2D covering `area` for the kind, or null for an unknown kind.
static func make_emitter(kind: String, area: Vector2) -> CPUParticles2D:
	if not PRESETS.has(kind):
		return null
	var preset: Dictionary = PRESETS[kind]
	var p := CPUParticles2D.new()
	p.name = "Ambient"
	p.amount = mini(int(preset["amount"]), MAX_AMOUNT)
	p.lifetime = float(preset["lifetime"])
	p.preprocess = p.lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2.0
	p.position = area / 2.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = float(preset["speed"]) * 0.3
	p.initial_velocity_max = float(preset["speed"])
	p.gravity = preset["gravity"]
	p.scale_amount_min = float(preset["size"]) * 0.6
	p.scale_amount_max = float(preset["size"])
	p.color = preset["color"]
	p.z_index = 50
	return p
