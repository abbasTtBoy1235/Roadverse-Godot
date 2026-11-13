# Roadverse

A night-driving **truck simulator** for PC, built in **Godot 4.7** (Forward+).

> Status: **playable vertical slice.** Main menu, settings, pause menu, a truck with a real
> gearbox, a synthesised diesel engine plus tyre and wind noise, spinning and steering wheels, a
> mouse-driven chase camera, a real GLB truck, two-way traffic that brakes for the car
> ahead, collision on the guardrails, trees and overpass pillars, and rain that soaks the tarmac
> into a mirror. There is one job to do: haul the load to the gate at the far end of the road
> without wrecking it. No save system yet.

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
| `tests/test_day_cycle.gd` | day/night model and sky gradient — 30 checks |
| `tests/test_road_geometry.gd` | procedural road, toll plaza, two cities, depots and signals — 181 checks |
| `tests/test_camera_orbit.gd` | camera orbit maths — 15 checks |
| `tests/ui_flow.tscn` | menus, settings persistence, camera wiring, minimap and slots — 70 checks |
| `tests/camera_follow.tscn` | the camera keeps up with the truck — 8 checks |
| `tests/test_audio_traffic.gd` | engine synth, traffic wrap, car-following and signal maths — 23 checks |
| `tests/test_weather_noise.gd` | tyre, wind, fog, wetness, grip and ambience maths — 25 checks |
| `tests/test_mission.gd` | damage, scoring, arrival and beacon maths — 17 checks |
| `tests/test_career.gd` | routes, pay, ranks, job kinds, leaderboard, achievements and save slots — 58 checks |
| `tests/drive_state.tscn` | wheels, audio, traffic, rain, barriers, props, a full delivery, the payout, the fuel burn, the fitted truck model and no second trailer |
| `tests/mission_failure.tscn` | a wrecked load fails the job and pays nothing — 11 checks |
| `tests/smoke_test.tscn` | real physics — 9 checks |

**565 checks total.** The same suite runs on every push in GitHub Actions
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
godot --headless --path . --script res://tests/test_weather_noise.gd
godot --headless --path . --script res://tests/test_mission.gd
godot --headless --path . --script res://tests/test_career.gd
godot --headless --path . res://tests/drive_state.tscn
godot --headless --path . res://tests/mission_failure.tscn
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
| Road ribbon | gentle alternating bends (`bend_amplitude`), 1.5 km by default, ramped in from the origin so the truck spawns on the asphalt |
| Surfaces | no image files anywhere: `TextureFactory` paints deterministic asphalt grain, mottled ground turf, concrete and facade grime pixel by pixel; flat ribbons carry world-planar UVs so textures tile by the metre |
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
| Two cities | a lower-rise loading city over the first quarter of the route and a taller delivery city over the last third — six building columns deep per side, with open country and the toll between them |
| Freight depots | a warehouse, dock canopy, marked loading bay and container stacks in each city: `LOADING DEPOT` where every job starts, `DELIVERY DEPOT` beside the destination gate |
| Traffic signals | two signalised zebra crossings per city on a 16 s cycle; pedestrians cross on the red phase, and NPC traffic brakes to a stop at it (amber at the line means clear the crossing) |
| Fuel station | canopy, six pumps and a shop at 35% of the route — park in the bay and the pumps fill the tank at $2/L, billed to the career wallet |
| Traffic | 17 NPC cars and vans looping both lanes, with spinning wheels, brake lamps and headlights |
| Barrier | the guardrails are real collision boxes, so the truck bounces off instead of driving through |
| City | 400+ blocks across the two cities and the downtown beyond the end, on a real street grid with avenues and cross streets, 8,200 lit windows, 12 tower beacons |

Repeated props use `MultiMeshInstance3D`, so ~900 instances cost a handful of draw calls.
Generation takes **30 ms** headless. Change `seed_value` on the `Road` node for a different
layout; the geometry test asserts that the same seed reproduces the same layout.

---

## The truck

The truck is a **real GLB now**: `models/truck.glb` (Sketchfab export, 36k triangles) is fitted
automatically — scaled to 2.5 m wide, turned to face -Z, dropped on its wheels, the four
`VehicleWheel3D` anchors kept exactly where the handling was tuned for, the model's own eight
wheels hung on pivots that roll with road speed and steer up front, the chassis collider resized to
the mesh, and the lamps moved to the real nose and tail. The GLB is a complete truck with its own
cargo body, so there is no separate trailer behind it any more. Delete the file and the procedural
truck comes back, unchanged.

## Real art (optional)

Everything in this repo is generated in code, but the truck has a **socket** for a real mesh:
drop `models/truck.glb` in and `TruckModel` swaps it in on the next run — placeholder boxes hidden,
physics untouched, and any child nodes named `wheel_fl`/`wheel_fr`/`wheel_rl`/`wheel_rr` are
re-parented onto the spin pivots so they steer and roll. With no file present the procedural truck
is used and nothing else changes. Requirements (format, axis, scale, licence) are in
[`models/README.md`](models/README.md).

## Fuel and the cost of driving

- The tank holds 60 L and burns `0.020 + 0.10 × pedal × (0.4 + 0.6 × revs)` litres per second, so
  a full-throttle haul drinks roughly twice what a steady one does. A job never strands you —
  the gauge is there to make the pedal a decision.
- **Fuel is money.** Each route has a par (`6 L per 620 m`); burning under it pays an economy
  bonus of up to $200 on top of the delivery fee, and burning over it pays nothing extra.
- **Run dry and the engine stops making power** — the throttle is ignored, the synth drops to
  idle, and you coast. Refuelled at the start of every job, as if the yard fuelled you.
- A guardrail strike now **shakes the camera**: the follow camera measures the drop in speed each
  physics frame and kicks, then decays.

## The career

- **Every job generates its own road.** `Career` keeps your job number; `CareerMath.route_seed()`
  turns it into a seed and `Game._enter_tree()` hands it to the road *before* the road builds
  itself. Route length also grows with the job number, from 1.25 km to nearly 2 km — and the
  pay, par time and fuel allowance scale with the distance, as do traffic and pedestrian density.
- **Pay and rank.** A delivery pays `score × 0.12`; the ranks ladder is Rookie → Junior driver →
  Company driver → Long-haul driver → Owner-operator. The menu and HUD both show where you stand.
- **A wrecked load is a failed job.** Damage reaches 100% and the run ends with no pay and the
  same route waiting for you — the job index only advances on a delivery.
- **Results screen.** Delivered or wrecked, the world pauses, the numbers are on screen, and
  `Enter` takes the next route (fresh scene, fresh seed, fresh road).
- Saved in `user://career.cfg` — job number, cash, deliveries and best score.
- **Three save slots and a driver profile.** The CAREER panel names the driver and switches
  between `career_slot0..2.cfg`; the profile file remembers who you are and which slot is
  live, and pre-slot careers migrate into slot 1 automatically.
- Start over by deleting that file, or `Career.reset_progress()`.

Jobs also come in kinds, rotating with the job index: **standard**, **fragile**
(damage per hit ×2.2) and **urgent** (a 20% tighter par clock, +25% score for
beating it). Every delivery enters a persistent **top-ten leaderboard**, and
**achievements** (first load, a flawless run, 10 deliveries, 10 km hauled, a
900+ score, $12,000 held) unlock as the career grows — both live in the menu's
CAREER panel, and fresh unlocks are announced on the results screen.

## The job

- A delivery is a **gate at the far end of the road** (92% of the way along) plus a load in the
  cargo body. The HUD shows the cargo, the percentage covered, the clock and the damage taken.
- **Damage comes from shocks**, not from touching things: a speed change above 3 m/s in one frame
  dents the load. Hitting a guardrail at 60 km/h costs you; rolling gently off the shoulder does not.
- **Arrival needs you to be slow** — under 15 km/h at the gate — so you have to actually stop the
  rig instead of clipping the post at full tilt.
- Score = `base × condition × (0.6 + 0.4 × time factor)`, capped at the base. Clean and quick wins.
- `R` restarts the run; there is no save yet.

## One truck, no trailer

There is no towed trailer any more. The GLB is a complete truck — cab, cargo body, four axles — so
when the game also hung its old procedural trailer behind it, the rig looked like a road train with
two trailers. The trailer node and its kinematic articulation model were removed; the mission,
cargo and scoring never depended on it. The chase camera now measures its distance from the back
of the truck itself.

## Traffic

Seventeen NPC vehicles, two lanes. Ten come at you in the oncoming lane; seven crawl along in
your lane at 9–14 m/s, which makes them things to overtake. Cars and vans wear different paint,
carry glass cabins and roll on spinning wheels. Each one measures the gap to the vehicle ahead
in its own lane and settles on `follow_speed(cruise, gap, safe_gap)`: cruise when clear, a
proportional crawl as it closes in, stopped when the gap is gone. Brake lamps light up while
decelerating — hard braking, gentle acceleration, the way traffic really moves. Right-hand
traffic throughout: same-direction cars keep to your side of the road, oncoming cars to the
far side. And they are **solid** — every car is a kinematic physics body with a collision box,
so you cannot drive through them; a hit costs speed, cargo condition and a camera kick, exactly
like the guardrails.

**Pedestrians too:** 26 walkers stroll both sidewalks with swinging arms and legs, in both
directions, wrapping at the ends of the road so the roadside never empties.

---

## Rain and barriers

- **`F` cycles the weather:** clear → rain → snow → fog. `Weather` spawns CPU particles in a box around the truck and drags them
  with it, so the rain is always where you are. The wetness value eases in over about a second:
  while it rises, `RoadBuilder.set_wetness()` lowers the asphalt roughness (0.95 → 0.16) and
  raises metallic (0 → 0.6), which is what turns the tarmac into a mirror under the lamps.
  Fog density follows at the same time — and it is a pea-souper in fog mode.
- **Weather steals grip.** The truck scales every wheel's friction slip by the front it is
  driving through: dry 1.0, wet rain down to 0.75, snow 0.55. Snow means braking early.
- **The guardrails are physics.** ~512 boxes follow the curve at the rail's lateral offset,
  parented to one `StaticBody3D`. They are 1.25 m tall, so the truck leans on them instead of
  driving off the edge into the void.

---

## Sound and wheels

- **Engine audio is synthesised, not sampled.** `EngineAudio` fills an `AudioStreamGenerator`
  with a four-stroke firing frequency (`rpm / 120 * cylinders`) plus three harmonics, and scales
  the gain with revs and pedal load. No audio files, same as everything else in this repo.
- **The world has ambience.** `AmbientAudio` runs two more noise generators: a deep city hum
  that swells inside either city and dies in the countryside between them, and a weather
  layer — rain hiss, smothered hush under snow, near-silence in fog.
- **Tyre and wind noise are synthesised too.** `RoadNoise` pushes filtered white noise through
  two generators: a low-passed rumble for the tyres (`~speed^0.55`) and a bright hiss for the
  wind (`~speed^2`), both smoothed so they swell rather than snap.
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

- **Main menu** (`scenes/menu.tscn`): PLAY / CAREER / HOW TO PLAY / SETTINGS / QUIT, built in
  code. The CAREER panel shows cash, rank, progress to the next rank, deliveries, best score
  and the next job, and can reset the career; HOW TO PLAY explains the run and the controls.
- **Pause menu** (`Esc` inside the game): RESUME / RESTART / MAIN MENU / QUIT. Its process mode
  is `ALWAYS` so it keeps working while the tree is paused.
- Settings persist to `user://settings.cfg`: mouse sensitivity, inverted look, fullscreen,
  master volume, camera FOV, chase-camera height, day length (5/15/30/60 minutes) and
  graphics quality — which genuinely drives MSAA (off/2x/4x), render scale (75/90/100%),
  volumetric fog, SSAO contact shadows, SSR wet-road reflections and shadow reach.

---

## Day / night cycle

`TimeOfDay` drives the sun, moon, sky colour, ambient light, fog and bloom from `DayCycle`, a
procedural sky shader (`scripts/world/sky.gdshader`) paints a DayCycle-driven gradient with
sun and moon discs and hash-based stars that fade in at night, the environment's ambient and
reflected light come from that sky, and volumetric fog (quality tier permitting) lets lamps
and headlights cut visible cones through the dark. Every lamp bulb also wears an additive
billboard halo driven by the same lamp dimmer, the truck's headlights carry translucent beam
cones, and a gentle colour grade (contrast/saturation) is applied to the whole frame. On the
medium and high quality tiers SSAO grounds everything in its corners, and on high, SSR turns
the rain-soaked asphalt (metallic under `set_wetness`) into a mirror for lamps and signs.
pure model (hour 0..24 in, light parameters out) that is unit tested. One `night_factor` dimmer
is broadcast to everything that glows — street lamps, lamp glass, the 4,200 city windows, the
skyline, tower beacons and NPC headlights — so dawn and dusk happen everywhere at once: lamps
fade out as the sky warms orange at sunrise, and the city lights come back on at dusk.

- Default: starts at **07:00**, one full day takes **15 real minutes** (`day_length_seconds = 900`)
- Set `enabled = false` on the `TimeOfDay` node for a permanently frozen night
- The HUD shows the in-game clock next to the gear and RPM
- A **minimap** in the top-right corner draws the live route from the road's own curve:
  both depots, the toll plaza, the delivery gate and the truck, on every dealt route

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
- [ ] No brake squeal, horn or indicator click sounds yet
- [ ] Traffic never changes lane, so it follows rather than overtakes
- [ ] Cargo weight does      not affect the tractor
- [ ] No fuel, engine wear, hours-of-service or trailer damage
- [ ] No multi-stop routes, no cargo market, no garage or truck upgrades
- [ ] Only the guardrails collide — trees, rocks and the overpass pillars are still ghost geometry
- [ ] Power line wires are not modelled (poles only)
- [ ] Truck is 4-wheeled; no trailer articulation yet

## License

Private, all rights reserved (no license file yet).
