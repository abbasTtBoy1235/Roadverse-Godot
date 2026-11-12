# models/

Drop-in folder for real art. Nothing here is required: with an empty folder the
game uses the procedural truck, the procedural trailer and the procedural road.

## The truck

Put the mesh at **`models/truck.glb`** and it is picked up automatically on the
next run (`TruckModel` in `scenes/truck.tscn`). Check the log for
`[truck] model loaded`.

Requirements, so it slots in without breaking physics:

| Thing | Value |
|---|---|
| Format | **`.glb`** (Godot 4 imports glTF/GLB natively; it does **not** import `.fbx` or `.blend`) |
| Up axis | +Y, forward is **-Z** (Godot convention) |
| Origin | centre of the truck, **on the ground** (y = 0 is the road) |
| Scale | metres, 1 unit = 1 m. Reference truck is 2.4 m wide, 2.6 m tall, 8.0 m long |
| Wheel nodes | optional, but big win: name them `wheel_fl`, `wheel_fr`, `wheel_rl`, `wheel_rr` |
| Size | keep it under ~20 MB; textures can be embedded in the GLB |
| Materials | PBR (metallic/roughness). Headlights and brake lights stay procedural |

What the loader does:

- hides the placeholder `Body` and `Cab` boxes,
- keeps all the physics (`VehicleWheel3D` × 4) and the chase camera exactly as they are,
- if the model has children named `wheel_fl`/`wheel_fr`/`wheel_rl`/`wheel_rr`, parents them
  under the existing spin pivots, so they **steer and roll** with the simulation.

If your file is `.fbx` or `.blend`, export it from Blender as GLB first
(File → Export → glTF 2.0, format "glTF Binary (.glb)").

## Licence

This repo is public, so the model needs to be one you can publish: your own work,
CC0, or a licence that allows redistribution. Tell me the source and I will add the
attribution line to the README.

## Trailer

Same idea, `models/trailer.glb`, when the tractor is done — the trailer script builds
its body in code today.
