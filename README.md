# Roadverse

A night-driving **truck simulator** for PC, built in **Godot 4.7** (Forward+).

> Status: **playable vertical slice.** Main menu, settings, pause menu, a truck with a real
> gearbox and a synthesised diesel engine, spinning and steering wheels, a mouse-driven chase
> camera, oncoming traffic, and a detailed procedural night road with guardrails, lamps, trees,
> power lines, an overpass and a distant skyline. There is no cargo, mission or save system yet.

[![verify](https://github.com/abbasTtBoy1235/Roadverse-Godot/actions/workflows/verify.yml/badge.svg)](https://github.com/abbasTtBoy1235/Roadverse-Godot/actions/workflows/verify.yml)

Everything in this repository is generated from code and primitives — no imported models,
textures or audio — so a fresh clone runs immediately.

---

## Requirements

- **Godot 4.7** (standard build, no .NET needed)
- Linux, macOS or Windows

## Run

```bash
godot --path .              # or open project.godot in the Godot editor and press F5
```

The game boots into the main menu. **PLAY** loads the driving scene, **SETTINGS** stores your
mouse sensitivity, invert-Y and fullscreen choice in `user://settings.cfg`.

## Controls

| Action | Key |
|---|---|
| Throttle | `W` / `↑` |
| Brake / reverse | `S` / `↓` |
| Steer | `A` `D` / `←` `→` |
| Handbrake | `Space` |
| Shift up / down (manual mode only) | `E` / `Q` |
| Headlights | `L` |
| Camera: chase / close / cockpit | `C` |
| Look around | Move the mouse (captured while driving) |
| Zoom the camera | Mouse wheel |
| Recentre the camera | Middle mouse button |
| Pause menu | `Esc` |
| Restart | `R` |

The gearbox is **automatic by default**. Uncheck `automatic` on the `Truck` node to drive it
manually with `E` / `Q`.

---

## Verification

Everything below was actually executed on this project (see "What the tests caught" for why
that matters):

```bash
./tools/verify.sh
```

That runs three steps headlessly:

| Step | What it proves |
|---|---|
| `--import` | the project imports, every script compiles, all `class_name`s register |
| `tests/test_gearbox.gd` | gearbox logic — 20 checks |
| `tests/test_day_cycle.gd` | day/night model — 20 checks |
| `tests/test_road_geometry.gd` | procedural road — 90 checks |
| `tests/test_camera_orbit.gd` | camera orbit maths — 15 checks |
| `tests/ui_flow.tscn` | menus, settings persistence, camera wiring — 34 checks |
| `tests/camera_follow.tscn` | the camera keeps up with the truck — 5 checks |
| `tests/test_audio_traffic.gd` | engine synth + traffic maths — 12 checks |
| `tests/drive_state.tscn` | wheels spin/steer, audio follows revs, traffic moves — 14 checks |
| `tests/smoke_test.tscn` | real physics — 9 checks |

**219 checks total.** The same suite runs on every push in GitHub Actions
(`.github/workflows/verify.yml`), which downloads the Godot binary and calls `tools/verify.sh`
— no licence, no secrets, no containers.

Raw commands, if you prefer:

```bash
godot --headless --path . --script res://tests/test_gearbox.gd
godot --headless --path . --script res://tests/test_day_cycle.gd
godot --headless --path . --script res://tests/test_road_geometry.gd
godot --headless --path . --script res://tests/test_camera_orbit.gd
godot --headless --path . res://tests/ui_flow.tscn
godot --headless --path . res://tests/camera_follow.tscn
godot --headless --path . --script res://tests/test_audio_traffic.gd
godot --headless --path . res://tests/drive_state.tscn
godot --headless --path . res://tests/smoke_test.tscn
```

The smoke test builds its own ground, spawns `truck.tscn`, waits for it to settle, applies
throttle via `Input.action_press`, and asserts that the truck:

1. comes to rest before throttle,
2. does not fall through the ground,
3. automatically upshifts,
4. reaches at least 8 km/h,
5. moves **forward** (not backwards),
6. keeps a sane engine RPM,
7. never produces NaN / exploded velocity,
8. turns right when you steer right,
9. does not roll over in the turn.

---

## The road and roadside

`RoadBuilder` generates the map from a `Curve3D` — no imported assets:

| Element | How |
|---|---|
| Road ribbon | gentle alternating bends (`bend_amplitude`), 640 m, ramped in from the origin so the truck spawns on the asphalt |
| Surface | asphalt + gravel shoulders + solid edge lines + dashed centre line, all extruded along the curve |
| Guardrails | continuous beam on both sides plus posts every 5 m |
| Delineators | orange reflector posts every 24 m |
| Street lamps | alternating sides, slightly varied colour temperature and energy |
| Trees | trunk + cone canopy pairs, scattered 7–26 m off the road |
| Rocks, power poles, signs | scattered along the curve with a deterministic seed |
| Cat's eyes | emissive road studs every 8 m along the centre line |
| Power lines | catenary wires with sag between the crossbars |
| Fence | post-and-rail fence on the far side |
| Kilometre markers | reflective plates every 100 m |
| Shrubs | scattered low bushes between the road and the trees |
| Overpass | concrete deck with parapets and pillars at 55% of the route |
| Distant hills | low-poly silhouettes 240–420 m out, no collision |
| City glow | emissive skyline past the end of the road, picked up by the glow pass |
| Traffic | seven oncoming cars looping the other lane, each with emissive lamps and one light |

Repeated props use `MultiMeshInstance3D`, so ~900 instances cost a handful of draw calls.
Generation takes **30 ms** headless. Change `seed_value` on the `Road` node for a different
layout; the geometry test asserts that the same seed reproduces the same layout.

---

## Sound and wheels

- **Engine audio is synthesised, not sampled.** `EngineAudio` fills an `AudioStreamGenerator`
  with a four-stroke firing frequency (`rpm / 120 * cylinders`) plus three harmonics, and scales
  the gain with revs and pedal load. No audio files, same as everything else in this repo.
- **Wheels are driven visually.** Physics wheels do not move their children, so `WheelVisuals`
  spins each mesh by `get_rpm()` and yaws the steered wheels. The pivot uses Godot's YXZ Euler
  order so steering wraps around the spin, not the other way round.

---

## Camera

`CameraOrbit` is the pure maths (yaw wrap, pitch clamp, zoom clamp, recentring); `ChaseCamera`
applies it.

- **Free mouse look**: the pointer is captured while driving, so moving the mouse always rotates
  the view — no button to hold. `Esc` releases it (pause menu).
- After `auto_recentre_delay` (1.2 s) without mouse movement the camera eases back behind the truck.
- **Wheel** zooms, **middle click** recentres, `C` cycles chase / close / cockpit.
- If the camera ever ends up further than `snap_distance` (45 m) behind, it snaps instead of
  drifting — a safety net so it can never detach from the truck.
- Sensitivity and invert-Y come from the settings file.

The `camera_follow` test drives the real scene for five seconds and asserts the gap between
truck and camera stays between 5 m and 30 m the whole time; that is the regression test for
"the camera stays behind while I drive".

---

## Menus

- **Main menu** (`scenes/menu.tscn`): PLAY / SETTINGS / QUIT, built in code.
- **Pause menu** (`Esc` inside the game): RESUME / RESTART / MAIN MENU / QUIT. Its process mode
  is `ALWAYS` so it keeps working while the tree is paused.
- Settings persist to `user://settings.cfg`.

---

## Day / night cycle

`TimeOfDay` drives the sun, moon, ambient light and fog from `DayCycle`, a pure model
(hour 0..24 in, light parameters out) that is unit tested.

- Default: starts at **21:00**, one full day takes **15 real minutes** (`day_length_seconds = 900`)
- Set `enabled = false` on the `TimeOfDay` node for a permanently frozen night
- The HUD shows the in-game clock next to the gear and RPM

Because it is pure, the interesting parts are verifiable without a renderer: sun elevation
(+90° at noon, −90° at midnight, 0° at sunrise/sunset), energy swaps between sun and moon,
no discontinuity across midnight, and night ambient brightness below daytime.

---

## Project layout

```
project.godot
scenes/
  main.tscn          night world: environment, moonlight, ground, road, camera, HUD
  truck.tscn         VehicleBody3D, 4 wheels, lights, visual body
scripts/
  core/input_setup.gd      input actions, registered at runtime (autoload)
  core/game.gd             restart, optional telemetry for tests
  vehicle/gearbox.gd       pure logic, no engine dependency
  vehicle/truck_controller.gd  engine curve + gearbox -> VehicleBody3D
  vehicle/truck_lights.gd  headlights / brake lights by group
  world/road_builder.gd    procedural asphalt, lane markings, street lamps
  world/day_cycle.gd       pure day/night model (no engine dependency)
  world/time_of_day.gd     applies DayCycle to sun, moon, ambient and fog
  camera/chase_camera.gd   chase / close / cockpit
  ui/hud.gd                speed, gear, rpm, light state
tests/
  test_gearbox.gd    headless unit tests
  smoke_test.gd      headless physics test (+ smoke_test.tscn)
```

---

## Design notes

- **The gear ratio carries the sign.** Reverse ratios are negative, so `wheel_torque()`
  returns negative torque in reverse. Never multiply that by a direction again — the two
  negatives cancel and the truck drives forward in reverse. This bit us once; the unit
  test `reverse ratio yields negative torque` exists because of it.
- **`VehicleBody3D` pushes towards +Z for positive `engine_force`**, while the project (like
  every node in `truck.tscn`) faces **-Z**. The controller negates the force in one place,
  with a comment, and the smoke test asserts the truck moves forward.
- **Tuning is calibrated, not guessed.** Track width (2.3 m), centre of mass (`y = 0.55`),
  suspension stiffness (60) and the high-speed steering limit (5°) were chosen by running
  the smoke test repeatedly: at first the truck rolled onto its side in a 3-second turn at
  35 km/h. The roll-over assertion in the smoke test is what keeps that from regressing.
- **`Gearbox` knows nothing about Godot**, so it is tested without spawning a scene, and it
  is identical in spirit to the C# version in the Unity prototype.

## What the tests caught

Written down because it is the honest reason to have them:

1. Reverse torque had **two** sign flips and produced forward torque in reverse.
2. The truck drove **backwards** because of the `VehicleBody3D` +Z convention.
3. Steering was **inverted**: "right" turned left.
4. The truck **rolled over** when turning at 35 km/h (wide track + lower COM fixed it).

All four would have shipped invisibly in a code-only review.

---

## Known gaps

- [ ] No visual verification of the night lighting — headless has no renderer, so materials,
      fog and light intensities are unverified by tests
- [ ] Only one sound layer (engine). No tyre, wind, brake or horn audio
- [ ] Traffic has no collision or AI driving behaviour — it is a fixed loop
- [ ] No traffic, no cargo, no missions, no save system
- [ ] Roadside props have no collision — you can drive through trees and the overpass pillars
- [ ] Power line wires are not modelled (poles only)
- [ ] Truck is 4-wheeled; no trailer articulation yet

## License

Private, all rights reserved (no license file yet).
