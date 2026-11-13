class_name TextureFactory
extends RefCounted
## Procedural textures, painted pixel by pixel with a fixed seed: the game
## ships no image files, but flat colour reads cheap. Every generator is
## deterministic, so tests can measure the noise instead of eyeballing it.

const SEED := 20261112


static func _canvas(size: int, base: Color) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(base)
	return image


static func _speckle(image: Image, rng: RandomNumberGenerator, amount: int, dark: float, light: float) -> void:
	var size := image.get_width()

	for i in amount:
		var x := rng.randi_range(0, size - 1)
		var y := rng.randi_range(0, size - 1)
		var pixel := image.get_pixel(x, y)
		var shift := rng.randf_range(-dark, light)
		image.set_pixel(x, y, Color(
			clampf(pixel.r + shift, 0.0, 1.0),
			clampf(pixel.g + shift, 0.0, 1.0),
			clampf(pixel.b + shift, 0.0, 1.0), 1.0))


static func _blotch(image: Image, rng: RandomNumberGenerator, amount: int, tint: Color, radius_min: int, radius_max: int) -> void:
	var size := image.get_width()

	for i in amount:
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var radius := rng.randi_range(radius_min, radius_max)

		for y in range(maxi(0, cy - radius), mini(size, cy + radius)):
			for x in range(maxi(0, cx - radius), mini(size, cx + radius)):
				if Vector2(x - cx, y - cy).length() > float(radius):
					continue

				var pixel := image.get_pixel(x, y)
				image.set_pixel(x, y, pixel.lerp(tint, 0.35))


static func _blur(image: Image) -> Image:
	var size := image.get_width()
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)

	for y in size:
		for x in size:
			var sum := Color(0, 0, 0, 0)
			var count := 0

			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var sx := clampi(x + dx, 0, size - 1)
					var sy := clampi(y + dy, 0, size - 1)
					sum += image.get_pixel(sx, sy)
					count += 1

			out.set_pixel(x, y, sum / float(count))

	return out


## Dark asphalt: fine grain, faint patching, the odd pale scar.
static func asphalt(size := 256) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1

	var image := _canvas(size, Color(0.075, 0.075, 0.085))
	_blotch(image, rng, 26, Color(0.10, 0.10, 0.11), 10, 30)
	_blotch(image, rng, 14, Color(0.05, 0.05, 0.06), 8, 22)
	_speckle(image, rng, size * 22, 0.05, 0.07)
	image = _blur(image)
	_speckle(image, rng, size * 48, 0.05, 0.09)

	return ImageTexture.create_from_image(image)


## Roadside ground: mossy greens and dry browns in soft patches.
static func ground(size := 256) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2

	var image := _canvas(size, Color(0.055, 0.075, 0.04))
	_blotch(image, rng, 60, Color(0.09, 0.11, 0.05), 12, 42)
	_blotch(image, rng, 44, Color(0.13, 0.10, 0.055), 8, 30)
	_blotch(image, rng, 30, Color(0.035, 0.06, 0.03), 10, 34)
	_speckle(image, rng, size * 16, 0.03, 0.035)
	image = _blur(image)
	_speckle(image, rng, size * 8, 0.02, 0.025)

	return ImageTexture.create_from_image(image)


## Pale concrete with weather streaks, for slabs, islands and aprons.
static func concrete(size := 128) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3

	var image := _canvas(size, Color(0.24, 0.23, 0.22))
	_blotch(image, rng, 18, Color(0.19, 0.185, 0.18), 8, 24)
	_blotch(image, rng, 10, Color(0.29, 0.28, 0.27), 6, 18)
	_speckle(image, rng, size * 14, 0.035, 0.035)
	image = _blur(image)

	return ImageTexture.create_from_image(image)


## Barely-there grime for tower facades: keeps big walls from reading as
## flat-shaded cardboard without fighting the emissive windows.
static func facade(size := 128) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 4

	var image := _canvas(size, Color(0.92, 0.93, 0.97))
	_blotch(image, rng, 16, Color(0.78, 0.79, 0.84), 10, 26)
	_blotch(image, rng, 10, Color(0.86, 0.84, 0.80), 8, 20)
	_speckle(image, rng, size * 8, 0.05, 0.05)
	image = _blur(image)

	return ImageTexture.create_from_image(image)
