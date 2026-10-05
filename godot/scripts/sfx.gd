extends Node
## Dźwięk: nagrane efekty (Kenney, CC0), ciche tło miasta, syrena oraz muzyka
## klubowa — własne pliki MP3 z folderu „muzyka” albo generowany bit.

const RATE := 22050
const FILES := {
	"click": ["click_001", "click_002", "click_003"], "open": ["open_001"], "close": ["close_001"], "back": ["back_001"],
	"select": ["select_001", "select_002"], "toggle": ["toggle_001"], "tick": ["tick_001"],
	"good": ["confirmation_001"], "level": ["confirmation_002"], "bad": ["error_003"], "error": ["error_001"], "alert": ["bong_001"],
	"cash": ["handlecoins", "handlecoins2"], "door": ["dooropen_1", "dooropen_2"], "door_close": ["doorclose_1", "doorclose_2"],
	"hit": ["select_002"], "miss": ["error_001"], "pickup": ["handlesmallleather", "cloth1"], "place": ["impactsoft_medium_000", "impactsoft_medium_001"],
	"pack": ["cloth2", "cloth3", "bookflip1"], "sms": ["pluck_001"], "drop": ["drop_001"],
}
## głośność w dB dla poszczególnych efektów (wszystko celowo ciche)
const VOL := {"click": -16.0, "open": -14.0, "close": -14.0, "back": -14.0, "select": -14.0, "toggle": -14.0, "tick": -18.0, "good": -12.0, "level": -8.0,
	"bad": -12.0, "error": -14.0, "alert": -9.0, "cash": -9.0, "door": -9.0, "door_close": -9.0, "hit": -12.0, "miss": -14.0, "pickup": -8.0, "place": -8.0, "pack": -9.0, "sms": -11.0, "drop": -12.0}

var muted := false
var sounds := {}
var steps := {}
var pool: Array = []
var pool_i := 0
var step_player: AudioStreamPlayer
var siren_player: AudioStreamPlayer
var amb_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var club_stream: AudioStream = null
var club_files: Array = []
var club_file_i := 0
var _task := -1
var _abort := false
var _amb: AudioStreamWAV = null
var _rain: AudioStreamWAV = null
var _siren: AudioStreamWAV = null
var _train: AudioStreamWAV = null
var _syll: Array = []
var voice_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shot") or String(a).begins_with("--test") or String(a) == "--mute":
			muted = true
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	step_player = AudioStreamPlayer.new()
	add_child(step_player)
	siren_player = AudioStreamPlayer.new()
	siren_player.volume_db = -30.0
	add_child(siren_player)
	amb_player = AudioStreamPlayer.new()
	amb_player.volume_db = -60.0
	add_child(amb_player)
	rain_player = AudioStreamPlayer.new()
	rain_player.volume_db = -60.0
	add_child(rain_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -13.0
	add_child(voice_player)
	_build_bus()
	for k in FILES:
		sounds[k] = []
		for f in FILES[k]:
			var path := "res://assets/sfx/%s.ogg" % f
			if ResourceLoader.exists(path):
				sounds[k].append(load(path))
	for surf in ["concrete", "grass", "wood", "carpet"]:
		steps[surf] = []
		for i in range(5):
			var path := "res://assets/sfx/footstep_%s_00%d.ogg" % [surf, i]
			if ResourceLoader.exists(path):
				steps[surf].append(load(path))
	_scan_music()
	if muted:
		AudioServer.set_bus_mute(0, true)
	else:
		_task = WorkerThreadPool.add_task(_generate)


func _exit_tree() -> void:
	_abort = true
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _build_bus() -> void:
	if AudioServer.get_bus_index("Klub") >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Klub")
	AudioServer.set_bus_send(i, "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 420.0
	lp.resonance = 0.5
	AudioServer.add_bus_effect(i, lp)


## 0 = na ulicy (przytłumione basy zza ściany), 1 = tuż przy drzwiach
func set_club_open(k: float) -> void:
	var i := AudioServer.get_bus_index("Klub")
	if i < 0:
		return
	var lp = AudioServer.get_bus_effect(i, 0)
	if lp != null:
		lp.cutoff_hz = lerpf(420.0, 9000.0, clampf(k, 0.0, 1.0) * clampf(k, 0.0, 1.0))


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)


func play(sound: String, vol_db := 0.0) -> void:
	if muted or not sounds.has(sound) or sounds[sound].is_empty():
		return
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = sounds[sound].pick_random()
	p.volume_db = float(VOL.get(sound, -12.0)) + vol_db
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()


func step(surface: String, sprinting: bool) -> void:
	if muted:
		return
	var arr: Array = steps.get(surface, steps.get("concrete", []))
	if arr.is_empty():
		return
	step_player.stream = arr.pick_random()
	step_player.volume_db = -15.0 if sprinting else -19.0
	step_player.pitch_scale = randf_range(0.92, 1.08)
	step_player.play()


func siren(on: bool) -> void:
	if on and not siren_player.playing and not muted and _siren != null:
		siren_player.stream = _siren
		siren_player.play()
	elif not on and siren_player.playing:
		siren_player.stop()


## mamrotanie rozmówcy (jak w Simsach): jedna „sylaba” o wysokości głosu postaci
func mumble(voice := 1.0) -> void:
	if muted or _syll.is_empty():
		return
	voice_player.stream = _syll.pick_random()
	voice_player.pitch_scale = clampf(voice * randf_range(0.94, 1.07), 0.5, 2.0)
	voice_player.play()


func train_stream() -> AudioStream:
	return _train


## ciche tło: szum miasta i deszcz
func ambient(outside: bool, night: float, rain: float) -> void:
	if muted:
		return
	if _amb != null and not amb_player.playing:
		amb_player.stream = _amb
		amb_player.play()
	if _rain != null and not rain_player.playing:
		rain_player.stream = _rain
		rain_player.play()
	var a := (-27.0 - night * 4.0) if outside else -44.0
	amb_player.volume_db = lerpf(amb_player.volume_db, a, 0.05)
	var r := (-40.0 + rain * 22.0 - (0.0 if outside else 12.0)) if rain > 0.05 else -70.0
	rain_player.volume_db = lerpf(rain_player.volume_db, r, 0.05)


# ---------------------------------------------------------------- synteza (w wątku roboczym)
func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


func _noise_loop(dur: float, smooth: float, wobble: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var v := 0.0
	var v2 := 0.0
	for i in range(n):
		if _abort:
			return b
		v += (randf_range(-1.0, 1.0) - v) * smooth
		v2 += (v - v2) * smooth * 2.0
		var env := 0.7 + 0.3 * sin(float(i) / n * TAU * wobble)
		b[i] = v2 * env
	# płynne zapętlenie
	var x := int(RATE * 0.4)
	for i in range(x):
		var k := float(i) / x
		b[i] = b[i] * k + b[n - x + i] * (1.0 - k)
	return b.slice(0, n - x)


func _generate() -> void:
	# syrena: miękka, odległa
	var n := int(3.0 * RATE)
	var sb := PackedFloat32Array()
	sb.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var f := 560.0 + 170.0 * sin(t * TAU / 3.0 * 2.0)
		ph += f / RATE
		sb[i] = sin(ph * TAU) * 0.22 + sin(ph * TAU * 2.0) * 0.05
	var s1 := _wav(sb, true)
	var amb := _noise_loop(7.0, 0.012, 2.0)
	for i in range(amb.size()):
		amb[i] *= 5.0
	var s2 := _wav(amb, true)
	var rn := _noise_loop(5.0, 0.35, 3.0)
	for i in range(rn.size()):
		rn[i] *= 0.9
	var s3 := _wav(rn, true)
	_set_loops.call_deferred(s1, s2, s3)
	# kolejka na estakadzie: dudnienie i stukot
	var tn := int(4.0 * RATE)
	var tb := PackedFloat32Array()
	tb.resize(tn)
	var lp := 0.0
	var lp2 := 0.0
	for i in range(tn):
		if _abort:
			return
		var tt := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (randf_range(-1.0, 1.0) - lp2) * 0.25
		var clack := fmod(tt, 0.5)
		var env: float = exp(-clack * 26.0) + (exp(-(clack - 0.12) * 30.0) * 0.7 if clack >= 0.12 else 0.0)
		tb[i] = lp * 3.2 + sin(tt * TAU * 46.0) * 0.12 + lp2 * env * 0.35
	var xf := int(RATE * 0.3)
	for i in range(xf):
		var kf := float(i) / xf
		tb[i] = tb[i] * kf + tb[tn - xf + i] * (1.0 - kf)
	var s4 := _wav(tb.slice(0, tn - xf), true)
	# sylaby do mamrotania: impuls krtaniowy + dwa formanty samogłoski
	var vowels := [[700.0, 1150.0], [520.0, 1750.0], [320.0, 2200.0], [480.0, 900.0], [360.0, 760.0], [620.0, 1400.0], [430.0, 1100.0], [560.0, 1000.0]]
	var syl: Array = []
	for vi in range(vowels.size()):
		if _abort:
			return
		var dur := 0.1 + 0.02 * (vi % 4)
		var sn := int(dur * RATE)
		var sbuf := PackedFloat32Array()
		sbuf.resize(sn)
		var f0 := 118.0 + (vi % 3) * 9.0
		var period := int(RATE / f0)
		var f1: float = vowels[vi][0]
		var f2: float = vowels[vi][1]
		var soft := 0.0
		for i in range(sn):
			var tp := float(i % period) / RATE
			var e := exp(-tp * 420.0)
			var v := (sin(tp * TAU * f1) * 0.8 + sin(tp * TAU * f2) * 0.35) * e
			if vi % 3 == 0 and i < int(0.018 * RATE):
				v += randf_range(-0.5, 0.5) * (1.0 - float(i) / (0.018 * RATE))
			var a := minf(1.0, float(i) / (0.012 * RATE)) * minf(1.0, float(sn - i) / (0.03 * RATE))
			soft += (v - soft) * 0.42
			sbuf[i] = soft * a * 0.85
		syl.append(_wav(sbuf))
	_set_voice.call_deferred(s4, syl)
	if club_files.is_empty() and not _abort:
		var beat := _gen_trap()
		if not _abort:
			_club_ready.call_deferred(_wav(beat, true))


func _set_loops(s1: AudioStreamWAV, s2: AudioStreamWAV, s3: AudioStreamWAV) -> void:
	_siren = s1
	_amb = s2
	_rain = s3


func _set_voice(tr: AudioStreamWAV, syl: Array) -> void:
	_train = tr
	_syll = syl


func _club_ready(s: AudioStreamWAV) -> void:
	club_stream = s


func _mtof(nn: float) -> float:
	return 440.0 * pow(2.0, (nn - 69.0) / 12.0)


## własny bit w klimacie polskiego trapu: 140 BPM, bas 808, werbel na „trzy”, hi-haty z rolkami
func _gen_trap() -> PackedFloat32Array:
	var bpm := 140.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4.0 * beat * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var roots := [29.0, 29.0, 32.0, 27.0, 29.0, 29.0, 24.0, 27.0]   # F, F, As, Es, F, F, C, Es
	var s16 := beat / 4.0
	for bar in range(bars):
		if _abort:
			return b
		var t0 := bar * 4.0 * beat
		# bas 808 + stopa
		var pat := [0, 6, 10] if bar % 2 == 0 else [0, 3, 8, 11]
		for st in pat:
			var at = t0 + st * s16
			var f0 := _mtof(float(roots[bar]) + (12.0 if st == 10 else 0.0))
			var i0 := int(at * RATE)
			var len := int(beat * 1.6 * RATE)
			var ph := 0.0
			for i in range(len):
				if i0 + i >= n:
					break
				var tt := float(i) / RATE
				var f := f0 * (1.0 + 2.2 * exp(-tt * 38.0))
				ph += f / RATE
				var env := exp(-tt * 2.6) * minf(1.0, tt * 400.0)
				var x := sin(ph * TAU)
				b[i0 + i] += clampf(x * 1.6, -1.0, 1.0) * env * 0.5
		# werbel / klask na „trzy”
		for sn in [8]:
			var i1 := int((t0 + sn * s16) * RATE)
			var lp := 0.0
			for i in range(int(0.22 * RATE)):
				if i1 + i >= n:
					break
				var tt2 := float(i) / RATE
				var nz := rng.randf_range(-1.0, 1.0)
				lp += (nz - lp) * 0.45
				b[i1 + i] += (nz - lp) * exp(-tt2 * 17.0) * 0.34 + sin(tt2 * TAU * 190.0) * exp(-tt2 * 28.0) * 0.2
		# hi-haty: ósemki z rolkami
		var st2 := 0.0
		while st2 < 16.0:
			var roll := rng.randf() < 0.16
			var cnt := 3 if roll else 1
			for r in range(cnt):
				var i2 := int((t0 + (st2 + r * (2.0 / cnt)) * s16) * RATE)
				var hp := 0.0
				var vol := 0.085 if int(st2) % 4 == 0 else 0.06
				for i in range(int(0.035 * RATE)):
					if i2 + i >= n:
						break
					var nz2 := rng.randf_range(-1.0, 1.0)
					hp += (nz2 - hp) * 0.25
					b[i2 + i] += (nz2 - hp) * exp(-float(i) / RATE * 95.0) * vol
			st2 += 2.0
		# mroczna melodia: dzwonki w moll
		var mel := [[0, 65.0], [3, 68.0], [6, 72.0], [8, 68.0], [11, 67.0], [14, 65.0]] if bar % 4 < 2 else [[0, 63.0], [4, 67.0], [6, 70.0], [10, 68.0], [12, 65.0]]
		for m in mel:
			var i3 := int((t0 + float(m[0]) * s16) * RATE)
			var fm := _mtof(float(m[1]))
			for i in range(int(0.9 * RATE)):
				if i3 + i >= n:
					break
				var tt3 := float(i) / RATE
				var e := exp(-tt3 * 4.5) * minf(1.0, tt3 * 300.0)
				b[i3 + i] += (sin(tt3 * TAU * fm) * 0.6 + sin(tt3 * TAU * fm * 2.01) * 0.25 + sin(tt3 * TAU * fm * 3.0) * 0.08) * e * 0.09
	# proste echo dla przestrzeni
	var dl := int(s16 * 3.0 * RATE)
	for i in range(dl, n):
		b[i] += b[i - dl] * 0.18
	var peak := 0.001
	for i in range(n):
		peak = maxf(peak, absf(b[i]))
	for i in range(n):
		b[i] = b[i] / peak * 0.9
	return b


# ---------------------------------------------------------------- muzyka klubu
func _scan_music() -> void:
	var dirs := ["res://muzyka", OS.get_executable_path().get_base_dir().path_join("muzyka")]
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if f.to_lower().ends_with(".mp3"):
				club_files.append(d.path_join(f))
	club_files.shuffle()


func next_club_stream() -> AudioStream:
	if not club_files.is_empty():
		for _try in range(club_files.size()):
			var path: String = club_files[club_file_i % club_files.size()]
			club_file_i += 1
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null:
				continue
			var st := AudioStreamMP3.new()
			st.data = f.get_buffer(f.get_length())
			f.close()
			return st
	return club_stream


func club_track_name() -> String:
	if not club_files.is_empty():
		return club_files[(club_file_i - 1 + club_files.size()) % club_files.size()].get_file().get_basename()
	return "Blokowisko 140 (bit z gry)"
