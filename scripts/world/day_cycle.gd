class_name DayCycle
extends RefCounted
## Pure day/night model: hour of day (0..24) -> sun pitch, light energies,
## ambient and fog colours. No nodes, no engine state, so it is unit tested
## headlessly in tests/test_day_cycle.gd.
##
## 0.0 = midnight, 6.0 = sunrise, 12.0 = noon, 18.0 = sunset.

const NIGHT_SKY := Color(0.012, 0.018, 0.038)
const DAY_SKY := Color(0.42, 0.62, 0.92)
const DUSK_SKY := Color(0.98, 0.52, 0.26)
const NIGHT_AMBIENT := Color(0.20, 0.26, 0.40)
const DAY_AMBIENT := Color(0.78, 0.84, 0.95)
const NIGHT_FOG := Color(0.05, 0.07, 0.12)
const DAY_FOG := Color(0.62, 0.70, 0.82)


## Sun height in degrees: +90 at noon, -90 at midnight, 0 at sunrise/sunset.
static func sun_elevation(hour: float) -> float:
	var wrapped := fposmod(hour, 24.0)
	return -cos((wrapped / 24.0) * TAU) * 90.0


## DirectionalLight3D pitch: the light points straight down at noon.
static func sun_pitch_degrees(hour: float) -> float:
	return -sun_elevation(hour)


## 0 while the sun is below the horizon, 1 at full daylight, smooth between.
static func day_factor(hour: float) -> float:
	return clampf(smoothstep(-6.0, 12.0, sun_elevation(hour)), 0.0, 1.0)


static func sun_energy(hour: float) -> float:
	return lerpf(0.0, 1.15, day_factor(hour))


static func moon_energy(hour: float) -> float:
	return lerpf(0.24, 0.0, day_factor(hour))


static func ambient_energy(hour: float) -> float:
	return lerpf(0.34, 0.95, day_factor(hour))


static func ambient_color(hour: float) -> Color:
	return NIGHT_AMBIENT.lerp(DAY_AMBIENT, day_factor(hour))


static func fog_color(hour: float) -> Color:
	return NIGHT_FOG.lerp(DAY_FOG, day_factor(hour))


## 1 at deep night, 0 at full day: the master dimmer for every lamp in the game.
static func night_factor(hour: float) -> float:
	return 1.0 - day_factor(hour)


## Sky/background colour: night blue, day blue, and a warm band at the horizon
## hours when the sun sits within a few degrees of it.
static func sky_color(hour: float) -> Color:
	var colour := NIGHT_SKY.lerp(DAY_SKY, day_factor(hour))
	var dusk := clampf(1.0 - absf(sun_elevation(hour)) / 16.0, 0.0, 1.0)
	return colour.lerp(DUSK_SKY, dusk * 0.5)


## Bloom sells the night; in daylight it just washes the sky out.
static func glow_intensity(hour: float) -> float:
	return lerpf(0.55, 0.12, day_factor(hour))


## Fog thins out in daylight so the city stays visible.
static func fog_density(hour: float) -> float:
	return lerpf(0.008, 0.0028, day_factor(hour))


## True when it is dark enough that headlights should be on.
static func is_night(hour: float) -> bool:
	return day_factor(hour) < 0.2


## "21:07" style clock string, useful for the HUD.
static func clock_string(hour: float) -> String:
	var wrapped := fposmod(hour, 24.0)
	var hours := int(wrapped)
	var minutes := int((wrapped - hours) * 60.0)
	return "%02d:%02d" % [hours, minutes]
