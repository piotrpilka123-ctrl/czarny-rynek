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
var _intro: AudioStreamWAV = null
var intro_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shot") or String(a).begins_with("--test") or String(a) == "--mute":
			muted = true
	_build_bus()
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Efekty"
		add_child(p)
		pool.append(p)
	step_player = AudioStreamPlayer.new()
	step_player.bus = "Efekty"
	add_child(step_player)
	siren_player = AudioStreamPlayer.new()
	siren_player.volume_db = -30.0
	siren_player.bus = "Efekty"
	add_child(siren_player)
	amb_player = AudioStreamPlayer.new()
	amb_player.volume_db = -60.0
	amb_player.bus = "Otoczenie"
	add_child(amb_player)
	rain_player = AudioStreamPlayer.new()
	rain_player.volume_db = -60.0
	rain_player.bus = "Otoczenie"
	add_child(rain_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -19.0
	voice_player.bus = "Glosy"
	add_child(voice_player)
	intro_player = AudioStreamPlayer.new()
	intro_player.volume_db = -5.0
	intro_player.bus = "Muzyka"
	add_child(intro_player)
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


## Szyny: Muzyka (klub, bloki, wstęp), Efekty, Otoczenie (miasto, deszcz, kolejka), Glosy.
## „Klub” i „Blok” to muzyka zza ściany — przytłumiona filtrem i wpięta w szynę Muzyka.
const GROUPS := {"master": "Master", "music": "Muzyka", "sfx": "Efekty", "ambient": "Otoczenie", "voice": "Glosy"}

func _add_bus(nm: String, send: String) -> int:
	var i := AudioServer.get_bus_index(nm)
	if i >= 0:
		return i
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nm)
	AudioServer.set_bus_send(i, send)
	return i


func _build_bus() -> void:
	if AudioServer.get_bus_index("Klub") >= 0:
		return
	for nm in ["Muzyka", "Efekty", "Otoczenie", "Glosy"]:
		_add_bus(nm, "Master")
	var i := _add_bus("Klub", "Muzyka")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 420.0
	lp.resonance = 0.5
	AudioServer.add_bus_effect(i, lp)
	var j := _add_bus("Blok", "Muzyka")
	var lp2 := AudioEffectLowPassFilter.new()
	lp2.cutoff_hz = 900.0
	lp2.resonance = 0.6
	AudioServer.add_bus_effect(j, lp2)


## głośność grupy 0..1 (0 = cisza)
func set_volume(group: String, v: float) -> void:
	var i := AudioServer.get_bus_index(String(GROUPS.get(group, "")))
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(v, 0.0001, 1.0)))
	if i > 0:
		AudioServer.set_bus_mute(i, v <= 0.001)


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


## podkład wstępu fabularnego (groza + syreny); gotowy chwilę po starcie gry
func intro_ready() -> bool:
	return _intro != null


func intro_play(from := 0.0) -> void:
	if muted or _intro == null or from >= _intro.get_length() - 0.2:
		return
	intro_player.stream = _intro
	intro_player.volume_db = -5.0
	intro_player.play(maxf(0.0, from))


func intro_stop(fade := 1.0) -> void:
	if not intro_player.playing:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(intro_player, "volume_db", -60.0, fade)
	tw.tween_callback(intro_player.stop)


func _set_intro(st: AudioStreamWAV) -> void:
	_intro = st


## Muzyka wstępu, 27 s: niski dron z dysonansem, „bicie serca”, zbliżająca się syrena,
## cisza po zatrzymaniu, narastający szum i uderzenie na planszę „trzy tygodnie później”.
func _gen_intro() -> PackedFloat32Array:
	var dur := 27.0
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 540
	var ph_s := 0.0          # syrena
	var lp_s := 0.0
	var lp_n := 0.0          # szum
	var ph_i := 0.0          # uderzenie
	var hit := 21.5
	for i in range(n):
		if _abort and i % 2048 == 0:
			return b
		var t := float(i) / RATE
		# dron: D1 + D2 z powolnym falowaniem, od 4 s dochodzi mała sekunda (napięcie)
		var trem := 0.8 + 0.2 * sin(t * TAU * 0.13)
		var dr := sin(t * TAU * 36.71) * 0.3 + sin(t * TAU * 73.42 + sin(t * TAU * 0.21) * 1.4) * 0.16 + sin(t * TAU * 110.0) * 0.045
		var ten := clampf((t - 4.0) / 6.0, 0.0, 1.0)
		dr += (sin(t * TAU * 146.83) + sin(t * TAU * 155.56)) * 0.035 * ten * (0.7 + 0.3 * sin(t * TAU * 0.31))
		var v := dr * trem * minf(1.0, t / 1.5)
		# bicie serca: dwa stłumione uderzenia co 1,25 s, coraz wyraźniejsze
		var hb := fmod(t, 1.25)
		var hk := 0.0
		if hb < 0.22:
			hk = sin(hb * TAU * (62.0 - hb * 110.0)) * exp(-hb * 22.0)
		elif hb > 0.3 and hb < 0.52:
			hk = sin((hb - 0.3) * TAU * (54.0 - (hb - 0.3) * 100.0)) * exp(-(hb - 0.3) * 24.0) * 0.7
		v += hk * (0.14 + 0.2 * clampf(t / 20.0, 0.0, 1.0)) * (1.0 if t < hit else maxf(0.0, 1.0 - (t - hit)))
		# syrena policyjna: nadjeżdża (1–9,5 s), gaśnie przy zatrzymaniu; potem druga, odjeżdżająca (13–20 s)
		var sa := 0.0
		var fsh := 1.0
		if t > 1.0 and t < 9.8:
			var kk := (t - 1.0) / 8.5
			sa = kk * kk * 0.2 * clampf((9.8 - t) / 0.35, 0.0, 1.0)
			fsh = 1.0 + 0.03 * (1.0 - kk)
		elif t > 13.0 and t < 20.5:
			var k2 := (t - 13.0) / 7.5
			sa = (1.0 - k2) * (1.0 - k2) * 0.11 * clampf((t - 13.0) / 0.6, 0.0, 1.0)
			fsh = 0.965
		if sa > 0.0:
			var sw := 0.5 + 0.5 * sin(t * TAU * 0.62)
			var fq := (620.0 + 520.0 * sw * sw) * fsh
			ph_s += fq / RATE
			var raw := sin(ph_s * TAU) * 0.7 + sin(ph_s * TAU * 2.0) * 0.2 + sin(ph_s * TAU * 3.0) * 0.1
			lp_s += (raw - lp_s) * (0.12 + 0.3 * sa * 4.0)
			v += lp_s * sa
		# narastający szum przed uderzeniem
		if t > 18.2 and t < hit:
			var kr := (t - 18.2) / (hit - 18.2)
			lp_n += (rng.randf_range(-1.0, 1.0) - lp_n) * (0.02 + 0.4 * kr * kr)
			v += lp_n * 0.3 * kr * kr
		# uderzenie
		if t >= hit:
			var ti := t - hit
			ph_i += (34.0 + 70.0 * exp(-ti * 8.0)) / RATE
			v += sin(ph_i * TAU) * exp(-ti * 1.5) * 0.85
			if ti < 0.5:
				v += rng.randf_range(-1.0, 1.0) * exp(-ti * 18.0) * 0.25
		# wyciszenie końca
		v *= clampf((dur - t) / 3.2, 0.0, 1.0)
		b[i] = clampf(v, -1.0, 1.0)
	return b


## wybuch: głuchy łomot z opadającym tonem, trzask i długi pogłos (generowany przy pierwszym użyciu)
var _boom: AudioStreamWAV = null

func boom_prepare() -> void:
	if _boom != null:
		return
	var n := int(2.6 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4477
	for i in range(n):
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# trzask na początku: szeroki szum, potem coraz bardziej stłumiony
		var cut := lerpf(0.55, 0.02, clampf(t / 0.5, 0.0, 1.0))
		lp += (noise - lp) * cut
		lp2 += (lp - lp2) * 0.25
		var body := lp2 * exp(-t * 2.4) * 1.6
		var crack := noise * exp(-t * 38.0) * 0.8
		# łomot: sinus spadający z 90 do 32 Hz
		var f := lerpf(90.0, 32.0, clampf(t / 0.6, 0.0, 1.0))
		ph += TAU * f / RATE
		var thump := sin(ph) * exp(-t * 3.2) * 0.95
		var rumble := lp2 * exp(-t * 1.1) * 0.5 * (0.6 + 0.4 * sin(t * 23.0))
		buf[i] = clampf((body + crack + thump + rumble) * minf(1.0, t * 400.0), -1.0, 1.0)
	_boom = _wav(buf)


func boom(vol_db := 0.0) -> void:
	if muted:
		return
	boom_prepare()
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = _boom
	p.volume_db = -3.0 + vol_db
	p.pitch_scale = randf_range(0.88, 1.06)
	p.play()


## odgłosy doglądania roślin (generowane przy pierwszym użyciu): lanie wody, grzechot granulek, sekator
var _care := {}

func care(what: String) -> void:
	if muted:
		return
	if not _care.has(what):
		var rng := RandomNumberGenerator.new()
		rng.seed = 91 + what.length()
		var secs: float = {"water": 1.7, "shake": 1.3, "snip": 0.16}.get(what, 0.3)
		var n := int(secs * RATE)
		var buf := PackedFloat32Array()
		buf.resize(n)
		var lp := 0.0
		var hp := 0.0
		for i in range(n):
			var t := float(i) / RATE
			var nz := rng.randf_range(-1.0, 1.0)
			var env := minf(1.0, t * 12.0) * minf(1.0, (secs - t) * 6.0)
			match what:
				"water":
					# szum przez filtr z falującym odcięciem + pojedyncze „plumknięcia”
					lp += (nz - lp) * (0.22 + 0.1 * sin(t * 31.0) + 0.06 * sin(t * 7.3))
					hp = lp - hp * 0.6
					buf[i] = (lp * 0.5 + hp * 0.25 + sin(t * TAU * (420.0 + 260.0 * sin(t * 53.0))) * 0.05 * maxf(0.0, sin(t * 37.0))) * env * 0.8
				"shake":
					# ziarenka o plastik: krótkie trzaski w rytmie potrząsania
					var gate := pow(maxf(0.0, sin(t * TAU * 6.5)), 6.0)
					lp += (nz - lp) * 0.7
					buf[i] = (nz - lp) * gate * env * 0.7
				_:
					# sekator: metaliczny klik i krótki trzask łodygi
					lp += (nz - lp) * 0.5
					buf[i] = ((nz - lp) * exp(-t * 60.0) * 0.9 + sin(t * TAU * 2300.0) * exp(-t * 90.0) * 0.35)
		_care[what] = _wav(buf)
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = _care[what]
	p.volume_db = {"water": -11.0, "shake": -12.0, "snip": -8.0}.get(what, -10.0)
	p.pitch_scale = randf_range(0.95, 1.06)
	p.play()


## megafon: kilka ostrych, niskich „sylab” (tekst pokazuje napis na ekranie)
func megaphone() -> void:
	if muted or _syll.is_empty():
		return
	for i in range(3):
		var p: AudioStreamPlayer = pool[pool_i]
		pool_i = (pool_i + 1) % pool.size()
		p.stream = _syll.pick_random()
		p.volume_db = -4.0
		p.pitch_scale = 0.62 + i * 0.05
		p.play()


## mamrotanie rozmówcy (jak w Simsach): jedna „sylaba” o wysokości głosu postaci
func mumble(voice := 1.0) -> void:
	if muted or _syll.is_empty():
		return
	voice_player.stream = _syll.pick_random()
	voice_player.pitch_scale = clampf(voice * randf_range(0.97, 1.04), 0.6, 1.7)
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
	# najpierw podkład wstępu — może być potrzebny zaraz po kliknięciu „Nowa gra”
	var ib := _gen_intro()
	if _abort:
		return
	_set_intro.call_deferred(_wav(ib))
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
	# głos rozmówcy: krótkie, ciepłe „pyknięcia” (miękki atak, szybkie wybrzmienie, lekki zjazd tonu)
	# zamiast brzęczących sylab — dużo mniej męczące przy dłuższych rozmowach
	var tones := [196.0, 220.0, 174.6, 207.7, 185.0, 233.1, 164.8, 246.9]
	var syl: Array = []
	for vi in range(tones.size()):
		if _abort:
			return
		var dur := 0.085 + 0.01 * (vi % 3)
		var sn := int(dur * RATE)
		var sbuf := PackedFloat32Array()
		sbuf.resize(sn)
		var f0: float = tones[vi]
		var vph := 0.0
		var soft := 0.0
		for i in range(sn):
			var tt := float(i) / RATE
			vph += f0 * (1.0 - 0.07 * tt / dur) / RATE
			var v := sin(vph * TAU) + sin(vph * TAU * 2.0) * 0.22 + sin(vph * TAU * 3.0) * 0.06
			var a := sin(minf(1.0, tt / 0.012) * PI * 0.5) * exp(-tt * 30.0) * minf(1.0, float(sn - i) / (0.015 * RATE))
			soft += (v - soft) * 0.5
			sbuf[i] = soft * a * 0.7
		syl.append(_wav(sbuf))
	_set_voice.call_deferred(s4, syl)
	if club_files.is_empty() and not _abort:
		var beat := _gen_trap()
		if not _abort:
			_club_ready.call_deferred(_wav(beat, true))
	# bity lecące z okien bloków: inne tempo i tonacja niż w klubie
	for e in [[303, 128.0, -3.0], [707, 150.0, 2.0], [512, 136.0, -5.0]]:
		if _abort:
			return
		var tb2 := _gen_trap(int(e[0]), float(e[1]), float(e[2]))
		if not _abort:
			_trap_ready.call_deferred(_wav(tb2, true))


func _set_loops(s1: AudioStreamWAV, s2: AudioStreamWAV, s3: AudioStreamWAV) -> void:
	_siren = s1
	_amb = s2
	_rain = s3


func _set_voice(tr: AudioStreamWAV, syl: Array) -> void:
	_train = tr
	_syll = syl


func _club_ready(s: AudioStreamWAV) -> void:
	club_stream = s


var trap_streams: Array = []

func _trap_ready(s: AudioStreamWAV) -> void:
	trap_streams.append(s)


func _mtof(nn: float) -> float:
	return 440.0 * pow(2.0, (nn - 69.0) / 12.0)


## własny bit w klimacie polskiego trapu: 140 BPM, bas 808, werbel na „trzy”, hi-haty z rolkami
func _gen_trap(seed_v := 808, bpm := 140.0, shift := 0.0) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4.0 * beat * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var roots := [29.0 + shift, 29.0 + shift, 32.0 + shift, 27.0 + shift, 29.0 + shift, 29.0 + shift, 24.0 + shift, 27.0 + shift]   # F, F, As, Es, F, F, C, Es
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
			var fm := _mtof(float(m[1]) + shift)
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
