# models/

Drop-in folder for real art. Nothing here is required: with an empty folder the
game uses the procedural truck, the procedural trailer and the procedural road.

## How to get the file here

Binary uploads are blocked in chat (only images and text), so use one of these:

1. **Direct link — easiest and best.** Put the GLB anywhere that serves it and send the URL:
   - GitHub: open the file, click **Raw**, copy that address.
   - Dropbox: replace `?dl=0` with `?raw=1`.
   - Google Drive: `https://drive.google.com/uc?export=download&id=<FILE_ID>`.
   Then it is one command:
   ```bash
   ./tools/fetch-model.sh "https://……/truck.glb"
   ```
   That downloads it to `models/truck.glb`, then runs `tools/inspect_glb.py` and prints the
   node tree, size, triangle count and whether the wheel nodes were found.

2. **Base64 text** for small files (< ~2 MB): `base64 -w0 truck.glb > truck.glb.b64.txt` and send
   the `.txt`. It round-trips to a GLB exactly, but big files are impractical this way.

3. **Screenshots** (PNG/JPG are allowed): useful for judging the look, which is the part automated
   checks cannot see — but a picture cannot become a mesh.

## What is in here now

`truck.glb` — 1.27 MB, 36,332 triangles, 35 materials, exported from **Sketchfab**
(`generator: Sketchfab-13.84.0`). The socket fits it automatically:

```
raw       : 3.45 x 4.51 x 15.91 m, cab facing +Z, origin 2.29 m under the ground
fitted to : 2.50 x 3.27 x 11.53 m, cab facing -Z, front axle on WheelFL,
            wheels on the ground, chassis collider resized, lamps on the real nose,
            trailer hitch moved to z 6.89
```

> **Licence:** this file came from a third-party upload. Before this repo is published
> anywhere else, add the model's author and licence here (Sketchfab pages usually state
> CC-BY or CC-BY-NC). If it is CC-BY, the attribution line below is the minimum:
>
> ```
> Truck model: <author> — <title> — <url> — licensed under CC-BY 4.0
> ```

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
