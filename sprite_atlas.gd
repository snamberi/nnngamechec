extends RefCounted
## Player animation sheets, decoded directly so fresh clones and headless tests
## do not depend on editor import caches. Eight frames per animation row.

const SHEET_PATH = "res://assets/players.png"
const COLUMNS = 8
const ROWS = ["idle", "run", "dribble", "shot", "layup", "dunk", "pass", "defend"]
const CANVAS = Vector2i(80, 80)
const PIVOT = Vector2(40, 70)
const HOME = Color("243d5a")
const AWAY = Color("8c343a")
const CREAM = Color("f4eee0")
static var textures: Array = []
static var preview_textures: Array = []
static var source_rects: Array[Rect2i] = []
static var frame_bounds: Array[Rect2i] = []
static var loaded = false
static var load_error = ""
static var source_size = Vector2i.ZERO

static func ensure_loaded() -> bool:
	if loaded:
		return load_error.is_empty()
	loaded = true
	var source = Image.load_from_file(SHEET_PATH)
	if source == null or source.is_empty():
		load_error = "Player sprite sheet is missing: " + SHEET_PATH
		push_error(load_error)
		return false
	source.convert(Image.FORMAT_RGBA8)
	source_size = source.get_size()
	if source_size.x < 8 or source_size.y < 8:
		load_error = "Player sprite sheet must contain an 8 by 8 frame grid."
		push_error(load_error)
		return false
	var frames: Array[Image] = []
	var idle_heights: Array[int] = []
	var tallest = 1
	var widest = 1
	for row in range(8):
		for column in range(8):
			var left = roundi(column * source_size.x / 8.0)
			var top = roundi(row * source_size.y / 8.0)
			var right = roundi((column + 1) * source_size.x / 8.0)
			var bottom = roundi((row + 1) * source_size.y / 8.0)
			var cell = Rect2i(left, top, right - left, bottom - top)
			source_rects.append(cell)
			var tile = source.get_region(cell)
			clean_frame(tile)
			var bounds = tile.get_used_rect()
			if bounds.size.x <= 0 or bounds.size.y <= 0:
				load_error = "Empty player sprite frame: row %d column %d" % [row, column]
				push_error(load_error)
				return false
			frame_bounds.append(bounds)
			tallest = maxi(tallest, bounds.size.y)
			widest = maxi(widest, bounds.size.x)
			frames.append(tile.get_region(bounds))
			if row == 0:
				idle_heights.append(bounds.size.y)
	idle_heights.sort()
	var sprite_scale = 43.0 / float(idle_heights[4])
	sprite_scale = minf(sprite_scale, minf(68.0 / tallest, 76.0 / widest))
	# The same scale is applied to every animation: a raised arm extends
	# the silhouette instead of shrinking the player to fit a frame.
	for variant in range(6):
		var set_frames: Array[Texture2D] = []
		var full_frames: Array[Texture2D] = []
		for frame in frames:
			var sprite: Image = frame.duplicate()
			palette(sprite, variant)
			full_frames.append(ImageTexture.create_from_image(sprite))
			var width = maxi(1, roundi(sprite.get_width() * sprite_scale))
			var height = maxi(1, roundi(sprite.get_height() * sprite_scale))
			sprite.resize(width, height, Image.INTERPOLATE_NEAREST)
			var normalized = Image.create(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
			normalized.fill(Color.TRANSPARENT)
			var destination = Vector2i(roundi(PIVOT.x - width / 2.0), roundi(PIVOT.y) - height)
			normalized.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), destination)
			set_frames.append(ImageTexture.create_from_image(normalized))
		textures.append(set_frames)
		preview_textures.append(full_frames)
	return true

static func clean_frame(tile: Image) -> void:
	# Import cleanup: ignore transparent edge noise and known chroma-key
	# residue. The largest connected silhouette rejects detached speckles.
	var width = tile.get_width()
	var height = tile.get_height()
	for y in range(height):
		for x in range(width):
			var color = tile.get_pixel(x, y)
			var key_red = color.r > 0.8 and color.g < 0.2 and color.b < 0.2
			var key_magenta = minf(color.r, color.b) > color.g * 1.25 and color.r > 0.09 and color.b > 0.09
			if color.a < 0.8 or key_red or key_magenta:
				tile.set_pixel(x, y, Color.TRANSPARENT)
	var visited = PackedByteArray()
	visited.resize(width * height)
	var largest = PackedInt32Array()
	for y in range(height):
		for x in range(width):
			var index = y * width + x
			if visited[index] != 0 or tile.get_pixel(x, y).a < 0.8:
				continue
			var component = PackedInt32Array([index])
			visited[index] = 1
			var cursor = 0
			while cursor < component.size():
				var current = component[cursor]
				cursor += 1
				var cx = current % width
				var cy = current / width
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx = cx + dx
						var ny = cy + dy
						if nx < 0 or nx >= width or ny < 0 or ny >= height:
							continue
						var next = ny * width + nx
						if visited[next] == 0 and tile.get_pixel(nx, ny).a >= 0.8:
							visited[next] = 1
							component.append(next)
			if component.size() > largest.size():
				largest = component
	var keep = PackedByteArray()
	keep.resize(width * height)
	for index in largest:
		keep[index] = 1
	for y in range(height):
		for x in range(width):
			if keep[y * width + x] == 0:
				tile.set_pixel(x, y, Color.TRANSPARENT)

static func palette(sprite: Image, variant: int) -> void:
	var away = variant >= 3
	var skin_offset: float = [-0.12, 0.05, 0.0][variant % 3]
	for y in range(sprite.get_height()):
		for x in range(sprite.get_width()):
			var color = sprite.get_pixel(x, y)
			if color.a < 0.25:
				continue
			# Neutral light fabric becomes burgundy for the away team.
			# Warm skin remains distinct from cream cloth and blue trim.
			var light_fabric = color.r > 0.65 and color.g > 0.62 and color.b > 0.45 and color.b / maxf(0.01, color.r) > 0.68 and color.g / maxf(0.01, color.r) > 0.8
			if away and y < sprite.get_height() * 0.7 and light_fabric:
				var shade = clampf((color.r + color.g + color.b) / 3.0, 0.4, 1.0)
				color = Color(AWAY.r * shade, AWAY.g * shade, AWAY.b * shade, color.a)
			elif color.r > color.g * 1.17 and color.g > color.b * 1.12 and color.b < 0.64:
				color.r = clampf(color.r + skin_offset, 0, 1)
				color.g = clampf(color.g + skin_offset * 0.75, 0, 1)
				color.b = clampf(color.b + skin_offset * 0.55, 0, 1)
			sprite.set_pixel(x, y, color)

static func animation_for(g, i: int) -> Vector2i:
	var p: Dictionary = g.players[i]
	var action: String = p.get("action", "idle")
	var running: bool = Vector2(p.get("velocity", Vector2.ZERO)).length() > 8
	var row = 0
	var frame = int(g.elapsed * 4 + i) % 8
	if running:
		row = 2 if i == g.carrier else 1
		frame = int(p.get("step", 0.0) * 0.65) % 8
	elif i == g.carrier:
		row = 2
		frame = int(g.elapsed * 9) % 8
	elif p.team != g.possession:
		row = 7
		frame = int(g.elapsed * 3 + i) % 3
	if action in ["cross", "spin", "stepback"]:
		row = 2
		frame = clampi(int((1.0 - p.action_time / 0.38) * 8), 0, 7)
	elif action in ["jumper", "fake"]:
		row = 3
		var duration = 0.5 if action == "fake" else 0.75
		frame = clampi(int((1.0 - p.action_time / duration) * (4 if action == "fake" else 8)), 0, 7)
	elif action in ["layup", "reverse", "floater"]:
		row = 4
		frame = clampi(int((1.0 - p.action_time / 0.75) * 8), 0, 7)
	elif action in ["two_hand", "tomahawk"]:
		row = 5
		frame = clampi(int((1.0 - p.action_time / 0.75) * 8), 0, 7)
	elif action == "pass":
		row = 6
		frame = clampi(int((1.0 - p.action_time / 0.35) * 8), 0, 7)
	elif action in ["block", "screen"]:
		row = 7
		frame = 1 if action == "screen" else clampi(int((1.0 - p.action_time / 0.6) * 8), 0, 7)
	if i == g.controlled and g.charge >= 0:
		row = 3
		frame = clampi(int(g.charge / 0.7 * 3), 0, 3)
	return Vector2i(frame, row)

static func player(g, i: int) -> void:
	if not ensure_loaded():
		return
	var p: Dictionary = g.players[i]
	var pos: Vector2 = Vector2(p.pos).round()
	var selection = HOME if i < 3 else AWAY
	# Neutral contact shadows stay on the floor while players rise.
	g.draw_set_transform(pos, 0, Vector2(1, 0.32))
	g.draw_circle(Vector2.ZERO, 11, Color(0.13, 0.10, 0.08, 0.23))
	g.draw_set_transform(Vector2.ZERO)
	if i == g.controlled:
		g.draw_arc(pos + Vector2(0, 1), 13, 0, TAU, 28, selection, 1.5)
		g.draw_colored_polygon(PackedVector2Array([pos + Vector2(-3, 14), pos + Vector2(3, 14), pos + Vector2(0, 10)]), selection)
	var clip = animation_for(g, i)
	var jumping: float = sin(float(p.get("jump", 0.0)) * PI) * (15.0 if p.action in ["two_hand", "tomahawk"] else 9.0)
	var face_left: bool = Vector2(p.get("facing", Vector2.RIGHT)).x < -0.1
	var texture: Texture2D = textures[i % 6][clip.y * 8 + clip.x]
	var offset = pos - PIVOT - Vector2(0, roundf(jumping))
	var target = Rect2(offset, Vector2(CANVAS))
	if face_left:
		target.size.x *= -1
	g.draw_texture_rect(texture, target, false)
	if i == g.controlled:
		g.draw_rect(Rect2(pos + Vector2(-11, 5), Vector2(22, 3)), Color("3b3530"))
		g.draw_rect(Rect2(pos + Vector2(-11, 5), Vector2(22 * p.stamina, 2)), Color("527450") if p.stamina > 0.23 else Color("b17e35"))
	if p.get("stun", 0.0) > 0:
		g.draw_circle(pos + Vector2(-5, -49), 1.5, Color("b17e35"))
		g.draw_circle(pos + Vector2(4, -51), 1.5, Color("b17e35"))

static func preview(g, area: Rect2, team: int = 0, row: int = 0, frame: int = 0) -> void:
	if not ensure_loaded():
		return
	var variant = clampi(team * 3, 0, 5)
	var texture: Texture2D = preview_textures[variant][clampi(row, 0, 7) * 8 + posmod(frame, 8)]
	var size: Vector2 = texture.get_size()
	var factor = minf(area.size.x / size.x, area.size.y / size.y)
	var scaled = size * factor
	var target = Rect2(area.position + Vector2((area.size.x - scaled.x) * 0.5, area.size.y - scaled.y), scaled)
	g.draw_texture_rect(texture, target, false)
