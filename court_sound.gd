extends RefCounted
## Small synthesized court sounds. Separate RNG keeps audio from changing play.
static var cache: Dictionary = {}

static func sample(kind: String) -> AudioStreamWAV:
	if cache.has(kind):
		return cache[kind]
	var duration: float = {"bounce": 0.14, "pass": 0.08, "rim": 0.19, "swish": 0.32, "release": 0.08, "whistle": 0.4}.get(kind, 0.1)
	var rate = 22050
	var count = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var random = RandomNumberGenerator.new()
	random.seed = 912
	var previous = 0.0
	for n in range(count):
		var t = float(n) / rate
		var life = float(n) / count
		var noise = random.randf_range(-1, 1)
		previous = lerpf(previous, noise, 0.16)
		var v = 0.0
		match kind:
			"bounce": v = sin(TAU * (105 * t - 170 * t * t)) * exp(-t * 31) * 0.36 + noise * exp(-t * 100) * 0.18
			"pass": v = previous * sin(life * PI) * 0.4
			"rim": v = (sin(TAU * 540 * t) * 0.15 + sin(TAU * 877 * t) * 0.08 + noise * 0.04) * exp(-t * 22)
			"swish": v = previous * sin(life * PI) * exp(-t * 3) * 0.7
			"release": v = noise * exp(-t * 65) * 0.06
			"whistle": v = (sin(TAU * 2300 * t) + sin(TAU * 2450 * t) * 0.3) * minf(t * 40, 1) * (1 - life) * 0.1
		bytes.encode_s16(n * 2, int(clampf(v, -1, 1) * 32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	cache[kind] = wav
	return wav

static func play(player: AudioStreamPlayer, kind: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	player.stream = sample(kind)
	player.volume_db = -5
	player.play()
