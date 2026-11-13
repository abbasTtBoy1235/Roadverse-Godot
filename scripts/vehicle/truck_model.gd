class_name TruckModel
extends Node3D
## Socket for a real truck mesh. Drop `models/truck.glb` into the project and this
## fits it to the simulation on its own:
##
##   1. scales it to a real width,
##   2. turns it the right way round (GLB trucks are usually modelled facing +Z),
##   3. drops it on the ground and centres it,
##   4. leaves the four `VehicleWheel3D` anchors exactly where the handling was
##      tuned for (Godot re-applies their scene transforms anyway) and hangs the
##      model's own wheel meshes on pivots that steer and roll,
##   5. resizes the chassis collider to the mesh.
##
## With no file present the procedural truck is used and nothing changes.

const MODEL_PATH := "res://models/truck.glb"
const WHEEL_KEYS := ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]

@export_group("Fit")
## Real-world width to scale the mesh to, in metres.
@export var target_width := 2.5
## Most GLB trucks are modelled nose-first down +Z; Godot's forward is -Z.
@export var turn_around := true
@export var auto_fit := true

@export_group("Wheels")
@export var adopt_wheels := true
## Meshes whose name contains this are treated as wheels.
@export var wheel_name_hint := "wheel"

var has_model := false
var model_wheels: Array[String] = []
## Length of the fitted mesh, in metres.
var model_length := 0.0
var model_width := 0.0
var model_height := 0.0
## Rear edge of the fitted mesh in truck space: where a trailer should hang.
var model_rear_z := 0.0
## Front edge of the fitted mesh: where the lamps belong.
var model_front_z := 0.0
## How many glass panels were made transparent. Test hook.
var glass_panel_count := 0

var _truck: VehicleBody3D
var _model_root: Node3D


static func model_exists() -> bool:
	return ResourceLoader.exists(MODEL_PATH)


func _ready() -> void:
	_truck = get_parent() as VehicleBody3D

	if _truck == null:
		return

	if not model_exists():
		return

	var scene := load(MODEL_PATH) as PackedScene

	if scene == null:
		push_warning("TruckModel: %s is not a loadable scene." % MODEL_PATH)
		return

	var root := scene.instantiate() as Node3D

	if root == null:
		push_warning("TruckModel: %s has no 3D root node." % MODEL_PATH)
		return

	apply_model(root)


## Takes over an already-instantiated model. Public so the headless suite can
## feed it a synthetic tree instead of shipping a GLB in the repo.
func apply_model(root: Node3D) -> bool:
	if root == null or _truck == null:
		return false

	_model_root = root
	add_child(_model_root)
	has_model = true

	_hide_placeholder()

	if auto_fit:
		_fit_to_simulation()

	if adopt_wheels:
		_adopt_wheels()

	_make_glass_transparent()
	return true


## Exporters ship cab glass as opaque dark plastic, which makes the cockpit
## camera blind. Any surface whose material smells of glass gets a proper
## transparent duplicate, tinted and see-through from both sides.
func _make_glass_transparent() -> void:
	for node in _descendants(self):
		var instance := node as MeshInstance3D

		if instance == null or instance.mesh == null:
			continue

		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D

			if material == null:
				continue

			var mat_name := material.resource_name.to_lower()

			if not (mat_name.contains("glass") or mat_name.contains("wind")):
				continue

			var glass := material.duplicate() as StandardMaterial3D
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

			var tint := glass.albedo_color
			tint.a = 0.18
			glass.albedo_color = tint
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED

			instance.set_surface_override_material(surface, glass)
			glass_panel_count += 1


# ------------------------------------------------------------------- fitting --

func _hide_placeholder() -> void:
	for name in ["Body", "Cab"]:
		var node := _truck.get_node_or_null(name) as Node3D

		if node != null:
			node.visible = false


func _fit_to_simulation() -> void:
	var first := model_bounds()

	if first.size.x <= 0.001:
		return

	# Scale by width: the tyres have to sit inside the lane, and the physics is
	# not moving for anybody.
	var clusters := _wheel_clusters()
	var scale_factor := target_width / first.size.x

	_model_root.scale = Vector3.ONE * scale_factor

	if turn_around:
		_model_root.rotation.y = PI

	var box := model_bounds()
	model_width = box.size.x
	model_height = box.size.y
	model_length = box.size.z

	# Line the model's own axles up with the wheel anchors the physics uses, so
	# the visible wheels steer around the same points that the tyre model does.
	var anchors := _anchor_reference()
	var fitted := _axle_centres()

	var offset := Vector3(-box.get_center().x, anchors.y - fitted.y, anchors.z - fitted.z)
	_model_root.position = offset

	box = model_bounds()
	model_rear_z = box.end.z
	model_front_z = box.position.z

	_resize_chassis()
	_move_lights(box)


## Distance between the model's outermost axles, in metres.
func _axle_spread(clusters: Array[Dictionary]) -> float:
	var low := INF
	var high := -INF

	for cluster in clusters:
		var z: float = (cluster["centre"] as Vector3).z
		low = minf(low, z)
		high = maxf(high, z)

	return high - low


## Where the front axle sits in the truck's own space, and how high the anchors are.
func _anchor_reference() -> Vector3:
	var front := _truck.get_node_or_null("WheelFL") as VehicleWheel3D

	if front == null:
		return Vector3(-3.0, 0.6, 0.0)

	return Vector3(front.position.x, front.position.y, front.position.z)


## Midpoint between the front and rear axle of the model.
func _axle_centres() -> Vector3:
	var clusters := _wheel_clusters()

	if clusters.is_empty():
		return Vector3.ZERO

	var front := INF
	var rear := -INF
	var height := -INF

	for cluster in clusters:
		var centre: Vector3 = cluster["centre"]
		front = minf(front, centre.z)
		rear = maxf(rear, centre.z)
		height = maxf(height, centre.y)

	return Vector3(0.0, height, front)


## Wheelbase of the truck's own wheels.
func physics_wheelbase() -> float:
	var front := _truck.get_node_or_null("WheelFL") as VehicleWheel3D
	var rear := _truck.get_node_or_null("WheelRL") as VehicleWheel3D

	if front == null or rear == null:
		return 5.6

	return absf(front.position.z - rear.position.z)


## Lamps were placed for the placeholder box; move them to the real nose and tail
## so the beams do not start inside the bodywork.
func _move_lights(box: AABB) -> void:
	var lights := _truck.get_node_or_null("Lights")

	if lights == null:
		return

	var width := maxf(0.7, box.size.x * 0.34)
	var height := clampf(box.size.y * 0.3, 0.6, 1.6)

	for node in lights.get_children():
		var light := node as Node3D

		if light == null:
			continue

		if node.is_in_group("rv_headlight"):
			light.position = Vector3(
				-1.0 if light.position.x < 0.0 else 1.0,
				height,
				box.position.z + 0.15
			) * Vector3(1.0, 1.0, 1.0)

			# Keep the side sign, but at the nose.
			light.position.x = -width if light.position.x < 0.0 else width
		elif node.is_in_group("rv_brakelight"):
			light.position.x = -width if light.position.x < 0.0 else width
			light.position.y = height
			light.position.z = box.end.z - 0.15


func _resize_chassis() -> void:
	var collision := _truck.get_node_or_null("Chassis") as CollisionShape3D
	var shape := collision.shape as BoxShape3D if collision != null else null

	if shape == null:
		return

	var box := model_bounds()

	shape.size = Vector3(box.size.x * 0.92, maxf(1.0, box.size.y * 0.8), box.size.z * 0.9)
	collision.position = Vector3(box.get_center().x, box.size.y * 0.45, box.get_center().z)


## AABB of everything under the model, in the socket's own space (which is the
## truck's space: this node sits at the truck's origin with no transform).
func model_bounds() -> AABB:
	var box := AABB()
	var first := true
	var inverse := global_transform.affine_inverse()

	for node in _descendants(self):
		var instance := node as MeshInstance3D

		if instance == null or instance.mesh == null:
			continue

		var local: AABB = inverse * (instance.global_transform * instance.get_aabb())

		if first:
			box = local
			first = false
		else:
			box = box.merge(local)

	return box


# -------------------------------------------------------------------- wheels --

func _adopt_wheels() -> void:
	var clusters := _wheel_clusters()

	if clusters.size() < 2:
		return

	var visuals := _truck.get_node_or_null("WheelVisuals") as WheelVisuals

	var front_z := INF
	for cluster in clusters:
		front_z = minf(front_z, (cluster["centre"] as Vector3).z)

	for cluster in clusters:
		var centre: Vector3 = cluster["centre"]
		var group := cluster["node"] as Node3D

		if group == null:
			continue

		# One pivot per wheel, at the wheel's own centre, so it can roll about
		# its axle and steer about its kingpin without touching the physics.
		var pivot := Node3D.new()
		pivot.name = "ModelWheel_%s" % String(group.name)
		pivot.position = centre
		add_child(pivot)

		# The primitive cylinders are only there for the model-less fallback.
		for key in WHEEL_KEYS:
			var anchor := _truck.get_node_or_null(key) as VehicleWheel3D
			var visual := anchor.get_node_or_null("Spin/Visual") as Node3D if anchor != null else null

			if visual != null:
				visual.visible = false

		group.reparent(pivot, true)
		model_wheels.append(String(group.name))

		if visuals != null:
			visuals.register_model_wheel(pivot, centre.z <= front_z + 0.6)


## Groups every wheel-ish node into wheels: a tyre and its rim are one wheel.
## Works on node names, because exporters usually keep the mesh instances
## anonymous (Object_34) and only name the groups above them.
func _wheel_clusters() -> Array[Dictionary]:
	var hint := wheel_name_hint.to_lower()
	var clusters: Array[Dictionary] = []

	for node in _descendants(self):
		if not String(node.name).to_lower().contains(hint):
			continue

		var box := _bounds_of(node)

		if box.size.length() < 0.01:
			continue

		var centre := box.get_center()
		var merged := false

		for cluster in clusters:
			var known: Vector3 = cluster["centre"]

			if known.distance_to(centre) <= maxf(0.3, box.size.y * 0.5):
				var joined: AABB = (cluster["box"] as AABB).merge(box)
				cluster["box"] = joined
				cluster["centre"] = joined.get_center()
				cluster["meshes"].append_array(_meshes_of(node))
				merged = true
				break

		if not merged:
			clusters.append({
				"box": box,
				"centre": centre,
				"meshes": _meshes_of(node),
			})

	for cluster in clusters:
		var box: AABB = cluster["box"]
		cluster["centre"] = box.get_center()
		cluster["radius"] = box.size.y * 0.5
		cluster["node"] = _common_ancestor(cluster["meshes"])

	return clusters


func _meshes_of(root: Node) -> Array[Node]:
	var out: Array[Node] = []

	for node in _descendants(root):
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			out.append(node)

	return out


## The lowest node that contains every wheel mesh of one wheel.
func _common_ancestor(members: Array) -> Node3D:
	if members.is_empty():
		return null

	var candidate: Node = members[0]

	for member in members:
		while candidate != null and not _is_ancestor(candidate, member):
			candidate = candidate.get_parent()

	return candidate as Node3D


func _is_ancestor(candidate: Node, node: Node) -> bool:
	var walk: Node = node

	while walk != null:
		if walk == candidate:
			return true

		walk = walk.get_parent()

	return false


func _bounds_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inverse := global_transform.affine_inverse()

	for child in _descendants(node):
		var instance := child as MeshInstance3D

		if instance == null or instance.mesh == null:
			continue

		var world: AABB = inverse * (instance.global_transform * instance.get_aabb())

		if first:
			box = world
			first = false
		else:
			box = box.merge(world)

	return box


func _descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []

	if root == null:
		return out

	for child in root.get_children():
		out.append(child)
		out.append_array(_descendants(child))

	return out


## Test hook: every wheel cluster found on the model, in truck space.
func wheel_report() -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	for cluster in _wheel_clusters():
		var centre: Vector3 = cluster["centre"]
		out.append({
			"name": String((cluster["node"] as Node).name) if cluster["node"] != null else "?",
			"x": centre.x, "y": centre.y, "z": centre.z,
			"radius": cluster["radius"],
		})

	return out


## Test hook: how many wheels the model supplied.
func adopted_wheel_count() -> int:
	return model_wheels.size()
