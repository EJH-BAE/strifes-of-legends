extends Node

var preview = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func apply_bus() -> void:
	var master := float(preview["master"]) if preview != null else Settings.master
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if master <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(master))

func set_voice(_style: String) -> void:
	pass

func play_as(_style: String, kind: String) -> void:
	play(kind)

func play(kind: String) -> void:
	var gain := float(preview["sfx"]) if preview != null else Settings.sfx
	var master_v := float(preview["master"]) if preview != null else Settings.master
	if gain <= 0.001 or master_v <= 0.001:
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.stream = _clip(kind)
	player.volume_db = linear_to_db(clampf(gain, 0.001, 1.0)) - 2.0
	player.finished.connect(player.queue_free)
	player.play()

func _clip(kind: String) -> AudioStreamWAV:
	var rate := 44100
	var dur := _dur(kind)
	var count := maxi(1, int(rate * dur))
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var seed := kind.hash()
	for i in count:
		var t := float(i) / float(rate)
		var n := _noise(i, seed)
		var s := clampf(_wave(kind, t, dur, n), -1.0, 1.0)
		var v := int(s * 32767.0)
		bytes[i * 2] = v & 255
		bytes[i * 2 + 1] = (v >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _dur(kind: String) -> float:
	match kind:
		"click":
			return 0.045
		"step", "move":
			return 0.07
		"attack", "slash", "hit":
			return 0.12
		"q":
			return 0.26
		"w", "heal":
			return 0.34
		"e", "dash", "flash":
			return 0.18
		"r", "nexus":
			return 0.62
		"recall":
			return 0.8
		"death":
			return 0.45
		"tower":
			return 0.28
		"coin", "ping", "chime":
			return 0.2
		"error":
			return 0.16
		_:
			return 0.08

func _noise(i: int, seed: int) -> float:
	var x := (i * 1103515245 + seed * 12345) & 0x7fffffff
	x = (x ^ (x >> 11)) & 0x7fffffff
	return float(x % 10000) / 5000.0 - 1.0

func _wave(kind: String, t: float, dur: float, n: float) -> float:
	var k := clampf(t / dur, 0.0, 1.0)
	match kind:
		"click":
			return n * exp(-t * 90.0) * 0.55
		"step", "move":
			return n * exp(-t * 42.0) * 0.4
		"attack", "slash":
			return n * exp(-t * 16.0) * (0.25 + 0.45 * (1.0 - k))
		"hit", "tower":
			return n * exp(-t * 20.0) * 0.5 + n * exp(-t * 6.0) * 0.12
		"death", "nexus":
			return n * exp(-t * 5.0) * (1.0 - k) * 0.42
		"dash", "flash":
			return n * exp(-t * 8.0) * (1.0 - k) * 0.38
		"error":
			var hit = 1.0 if t < 0.04 or (t > 0.08 and t < 0.12) else 0.0
			return n * exp(-t * 24.0) * 0.4 * hit
		"q":
			return _bell(t, 520.0) + n * exp(-t * 30.0) * 0.18
		"w", "heal":
			return _bell(t, 392.0) * 0.8 + _bell(max(t - 0.06, 0.0), 588.0) * 0.45
		"e":
			return _bell(t, 740.0) * 0.7 + n * exp(-t * 18.0) * 0.2
		"r":
			return _bell(t, 196.0) * 0.9 + _bell(t, 494.0) * 0.35 + n * exp(-t * 4.0) * 0.12
		"recall":
			return _bell(t, 330.0) * 0.35 + _bell(max(t - 0.12, 0.0), 494.0) * 0.3 + _bell(max(t - 0.24, 0.0), 659.0) * 0.25
		"coin":
			return _bell(t, 988.0) * 0.45 + _bell(max(t - 0.05, 0.0), 1318.0) * 0.35
		"ping", "chime":
			return _bell(t, 880.0) * 0.4 + n * exp(-t * 25.0) * 0.15
		_:
			return n * exp(-t * 20.0) * 0.2

func _bell(t: float, freq: float) -> float:
	var body := sin(TAU * freq * t) * exp(-t * 9.0)
	var spark := sin(TAU * freq * 2.41 * t) * exp(-t * 16.0) * 0.35
	var glass := sin(TAU * freq * 3.97 * t) * exp(-t * 22.0) * 0.18
	return (body + spark + glass) * 0.28
