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
	"punch": ["impactpunch_medium_000", "impactpunch_medium_001"], "thud": ["impactsoft_medium_002", "impactsoft_medium_001"],
	# nagrania z Freesound (CC0): łomot pięścią w drzwi, seria uderzeń, zwykłe pukanie, bieg kilku osób korytarzem
	"lomot": ["lomot_1", "lomot_2", "lomot_3", "lomot_4"], "lomot_seria": ["lomot_seria"], "pukanie": ["pukanie"], "bieg_korytarz": ["bieg_korytarz"],
}
## głośność w dB dla poszczególnych efektów (wszystko celowo ciche)
const VOL := {"click": -16.0, "open": -14.0, "close": -14.0, "back": -14.0, "select": -14.0, "toggle": -14.0, "tick": -18.0, "good": -12.0, "level": -8.0,
	"bad": -12.0, "error": -14.0, "alert": -9.0, "cash": -9.0, "door": -9.0, "door_close": -9.0, "hit": -12.0, "miss": -14.0, "pickup": -8.0, "place": -8.0, "pack": -9.0, "sms": -11.0, "drop": -12.0,
	"lomot": -3.0, "lomot_seria": -2.0, "pukanie": -7.0, "bieg_korytarz": -6.0, "thud": -12.0, "punch": -12.0}

var muted := false
var sounds := {}
var steps := {}
var pool: Array = []
var pool_i := 0
var step_player: AudioStreamPlayer
var siren_player: AudioStreamPlayer
var siren_near: AudioStreamPlayer      # szybki sygnał „yelp”, gdy radiowóz albo patrol jest tuż za plecami
var _siren_yelp: AudioStream = null
var amb_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var club_stream: AudioStream = null
var club_files: Array = []
var club_file_i := 0
var _task := -1
var _abort := false
var _amb: AudioStreamWAV = null
var _rain: AudioStreamWAV = null
var _siren: AudioStream = null
var _train: AudioStreamWAV = null
var _syll: Array = []
var _banks := {}                # barwa głosu → zestaw sylab
var phone_player: AudioStreamPlayer
## Barwy głosu: f0 = wysokość (Hz), mouth = skala formantów (mniejsza = „większe” gardło), damp = jak szybko gaśnie
## impuls (mniej = bardziej dźwięczny), rasp = chrypa, breath = przydech, bright = ostrość, dur = długość sylaby.
const VOICES := {
	"tenor": {"f0": 122.0, "mouth": 1.0, "damp": 420.0, "rasp": 0.01, "breath": 0.02, "bright": 0.42, "dur": 0.1},
	"bas": {"f0": 88.0, "mouth": 0.86, "damp": 340.0, "rasp": 0.03, "breath": 0.03, "bright": 0.34, "dur": 0.125},
	"chrypa": {"f0": 104.0, "mouth": 0.93, "damp": 500.0, "rasp": 0.13, "breath": 0.07, "bright": 0.42, "dur": 0.11},
	"mlody": {"f0": 138.0, "mouth": 1.06, "damp": 440.0, "rasp": 0.015, "breath": 0.04, "bright": 0.5, "dur": 0.09},
	"starszy": {"f0": 108.0, "mouth": 0.97, "damp": 380.0, "rasp": 0.07, "breath": 0.08, "bright": 0.36, "dur": 0.13},
	"nosowy": {"f0": 128.0, "mouth": 1.16, "damp": 300.0, "rasp": 0.01, "breath": 0.01, "bright": 0.3, "dur": 0.105},
	"kobieta": {"f0": 205.0, "mouth": 1.18, "damp": 460.0, "rasp": 0.01, "breath": 0.05, "bright": 0.52, "dur": 0.095},
	"kobieta_niska": {"f0": 176.0, "mouth": 1.1, "damp": 400.0, "rasp": 0.03, "breath": 0.08, "bright": 0.44, "dur": 0.11},
}
## kto jaką barwą mówi; reszta dostaje barwę z imienia (kobiece imiona — głosy kobiece)
const VOICE_OF := {
	"Ty": ["mlody", 0.97], "Kuba": ["mlody", 0.97], "Wiktor": ["bas", 0.95], "Nieznany numer": ["chrypa", 0.86], "Mama": ["kobieta_niska", 1.0],
	"Wujek Staś": ["starszy", 0.95], "Ola z Neonu": ["kobieta", 1.04], "Mecenas Lipko": ["nosowy", 1.0], "Areszt śledczy": ["chrypa", 1.0],
	"Pan Zenek": ["starszy", 0.9], "Pan Rysiek": ["tenor", 0.93], "Pani Grażyna": ["kobieta_niska", 1.06], "Siwy": ["chrypa", 1.0],
}
var _voice_cache := {}
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
	siren_near = AudioStreamPlayer.new()
	siren_near.volume_db = -60.0
	siren_near.bus = "Efekty"
	add_child(siren_near)
	amb_player = AudioStreamPlayer.new()
	amb_player.volume_db = -60.0
	amb_player.bus = "Otoczenie"
	add_child(amb_player)
	rain_player = AudioStreamPlayer.new()
	rain_player.volume_db = -60.0
	rain_player.bus = "Otoczenie"
	add_child(rain_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -13.0
	voice_player.bus = "Glosy"
	add_child(voice_player)
	# rozmówca w słuchawce: ta sama mowa, ale przez wąskie pasmo telefonu
	phone_player = AudioStreamPlayer.new()
	phone_player.volume_db = -10.0
	phone_player.bus = "Telefon"
	add_child(phone_player)
	intro_player = AudioStreamPlayer.new()
	intro_player.volume_db = -5.0
	intro_player.bus = "Muzyka"
	add_child(intro_player)
	for k in FILES:
		sounds[k] = []
		for f in FILES[k]:
			for ext in ["ogg", "wav"]:
				var path := "res://assets/sfx/%s.%s" % [f, ext]
				if ResourceLoader.exists(path):
					sounds[k].append(load(path))
					break
	for surf in ["concrete", "grass", "wood", "carpet"]:
		steps[surf] = []
		for i in range(5):
			var path := "res://assets/sfx/footstep_%s_00%d.ogg" % [surf, i]
			if ResourceLoader.exists(path):
				steps[surf].append(load(path))
	_scan_music()
	_load_tracks()
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
	# słuchawka telefonu: wąskie pasmo (300–3400 Hz) i odrobina przesteru
	var tb := _add_bus("Telefon", "Glosy")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 420.0
	AudioServer.add_bus_effect(tb, hp)
	var lpt := AudioEffectLowPassFilter.new()
	lpt.cutoff_hz = 3000.0
	AudioServer.add_bus_effect(tb, lpt)
	var ds := AudioEffectDistortion.new()
	ds.mode = AudioEffectDistortion.MODE_OVERDRIVE
	ds.drive = 0.22
	ds.post_gain = -2.0
	AudioServer.add_bus_effect(tb, ds)
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
		if _siren_yelp != null:
			siren_near.stream = _siren_yelp
			siren_near.volume_db = -60.0
			siren_near.play()
	elif not on and siren_player.playing:
		siren_player.stop()
		siren_near.stop()


## Ogłuszenie: cały dźwięk gry na chwilę głuchnie (filtr dolnoprzepustowy na szynie głównej) i powoli wraca.
var _stun_fx: AudioEffectLowPassFilter = null

## `delay`: ile sekund po ciosie świat zaczyna głuchnąć — przez ten czas słychać jeszcze samo uderzenie i pisk w uszach.
func stun(secs := 6.0, delay := 0.0) -> void:
	var bi := AudioServer.get_bus_index("Master")
	if _stun_fx == null:
		_stun_fx = AudioEffectLowPassFilter.new()
		_stun_fx.resonance = 0.7
		AudioServer.add_bus_effect(bi, _stun_fx)
	var idx := AudioServer.get_bus_effect_count(bi) - 1
	for i in range(AudioServer.get_bus_effect_count(bi)):
		if AudioServer.get_bus_effect(bi, i) == _stun_fx:
			idx = i
	AudioServer.set_bus_effect_enabled(bi, idx, true)
	_stun_fx.cutoff_hz = 380.0 if delay <= 0.0 else 16000.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_property(_stun_fx, "cutoff_hz", 380.0, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(secs * 0.45)
	tw.tween_property(_stun_fx, "cutoff_hz", 16000.0, secs * 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): AudioServer.set_bus_effect_enabled(bi, idx, false))


func stun_off() -> void:
	if _stun_fx == null:
		return
	var bi := AudioServer.get_bus_index("Master")
	for i in range(AudioServer.get_bus_effect_count(bi)):
		if AudioServer.get_bus_effect(bi, i) == _stun_fx:
			AudioServer.set_bus_effect_enabled(bi, i, false)


## syrenę słychać tym głośniej, im bliżej jest najbliższy ścigający patrol (metry)
## Z daleka niesie się zawodzenie; kiedy pościg jest o kilkanaście metrów, policja przełącza na szybki sygnał.
func siren_dist(d: float) -> void:
	var near := clampf((24.0 - d) / 10.0, 0.0, 1.0) if _siren_yelp != null else 0.0
	siren_player.volume_db = lerpf(-13.0, -31.0, clampf(d / 70.0, 0.0, 1.0)) - near * 30.0
	siren_near.volume_db = lerpf(-60.0, -12.0, near)


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


func gunshot(vol_db := 0.0) -> void:
	if muted:
		return
	boom_prepare()
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = _boom
	p.volume_db = -5.0 + vol_db
	p.pitch_scale = randf_range(2.5, 2.9)
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


## PROLOG: impreza z nagrań (CC0, spis w LICENCJE.md). Muzyka i głosy idą przez własną szynę z filtrem
## dolnoprzepustowym: najpierw bas zza ściany, potem filtr się otwiera, na końcu znów wszystko głuchnie.
const PARTY_MUSIC := "res://assets/music/technomania101.ogg"
const PARTY_FROM := 98.0          # od tej sekundy utworu: 12 s narastania, potem najgłośniejsza część
var party_player: AudioStreamPlayer = null
var party_fx: Array = []
var party_fx_i := 0
var party_lp: AudioEffectLowPassFilter = null
var party_sounds := {}

func party_prepare() -> void:
	if party_player != null:
		return
	var bi := _add_bus("Impreza", "Master")
	party_lp = AudioEffectLowPassFilter.new()
	party_lp.cutoff_hz = 180.0
	party_lp.resonance = 0.6
	AudioServer.add_bus_effect(bi, party_lp)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.55
	rv.wet = 0.16
	rv.dry = 0.9
	AudioServer.add_bus_effect(bi, rv)
	party_player = AudioStreamPlayer.new()
	party_player.bus = "Impreza"
	add_child(party_player)
	if ResourceLoader.exists(PARTY_MUSIC):
		party_player.stream = load(PARTY_MUSIC)
	for i in range(16):
		var p := AudioStreamPlayer.new()
		p.bus = "Impreza"
		add_child(p)
		party_fx.append(p)
	for n in ["impreza_stereo", "okrzyki_1", "okrzyki_2", "gwar_baru", "brawa_bar", "spiew", "wciaganie_1", "wciaganie_2", "wciagniecie", "wiwat_1", "wiwat_2", "wiwat_3", "wiwat_4", "wiwat_5", "tlum", "wymioty_1", "wymioty_2", "wibracja"]:
		for ext in ["ogg", "wav"]:
			var path := "res://assets/sfx/party/%s.%s" % [n, ext]
			if ResourceLoader.exists(path):
				party_sounds[n] = load(path)
				break
	# stukanie kartą i zgarnianie kreski składamy z nagrań, które gra już ma (Kenney, CC0)
	for n in ["tick_001", "tick_002", "cloth1", "cloth2", "cloth3", "cloth4"]:
		var path2 := "res://assets/sfx/%s.ogg" % n
		if ResourceLoader.exists(path2):
			party_sounds[n] = load(path2)


func party_play() -> void:
	party_low_k = 1.0
	if muted:
		return
	party_prepare()
	party_cut(180.0)
	if party_player.stream != null:
		party_player.volume_db = -30.0
		party_player.play(PARTY_FROM)


func party_cut(hz: float) -> void:
	if party_lp != null:
		party_lp.cutoff_hz = clampf(hz, 80.0, 20000.0)


func party_vol(db: float) -> void:
	if party_player != null:
		party_player.volume_db = db


## pojedynczy odgłos imprezy; `close` = blisko i wyraźnie (poza filtrem), np. wciągnięcie kreski.
## `dur` > 0 ucina nagranie po tylu sekundach (nagrania wciągania mają po kilka powtórzeń — gra potrzebuje jednego).
func party_sfx(name: String, db := 0.0, pitch := 1.0, close := false, from := 0.0, dur := 0.0) -> AudioStreamPlayer:
	if muted or not party_sounds.has(name):
		return null
	var p: AudioStreamPlayer = _party_voice()
	var previous_tween: Tween = p.get_meta("cut_tween", null)
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	p.set_meta("cut_tween", null)
	p.bus = "Efekty" if close else "Impreza"
	p.stream = party_sounds[name]
	p.volume_db = db
	p.set_meta("base", pitch)
	p.pitch_scale = pitch * (1.0 if close else maxf(0.9, party_low_k))
	p.play(from)
	if dur > 0.0:
		var st: AudioStream = p.stream
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		p.set_meta("cut_tween", tw)
		tw.tween_interval(dur)
		tw.tween_property(p, "volume_db", -50.0, 0.18)
		tw.tween_callback(func():
			if p.stream == st:
				p.stop())
	return p


## wolny głos z puli (długie nagrania nie mogą być ucinane przez krótkie stuknięcia)
func _party_voice() -> AudioStreamPlayer:
	for i in range(party_fx.size()):
		var q: AudioStreamPlayer = party_fx[(party_fx_i + i) % party_fx.size()]
		if not q.playing:
			party_fx_i = (party_fx_i + i + 1) % party_fx.size()
			return q
	var p: AudioStreamPlayer = party_fx[party_fx_i]
	party_fx_i = (party_fx_i + 1) % party_fx.size()
	return p


## Głosy imprezy „siadają”: k < 1 obniża wszystko, co gra zza filtra (śmiechy, śpiewy, gwar) — tak słyszy
## je ktoś, komu robi się niedobrze i kto odchodzi w stronę łazienki.
var party_low_k := 1.0

func party_low(k: float) -> void:
	party_low_k = clampf(k, 0.5, 1.0)
	for p in party_fx:
		if p.playing and p.bus == "Impreza":
			p.pitch_scale = float(p.get_meta("base", 1.0)) * maxf(0.9, party_low_k)


## Robienie kreski tuż przy uchu: siekanie kartą po blacie (dwie serie), zgarnianie w kreskę, dwa stuknięcia
## na wyrównanie — i dopiero długie wciągnięcie. Zwraca czas (s), po którym zaczyna się wciągnięcie.
func party_line(chop := true) -> float:
	if muted:
		return 3.6 if chop else 0.4
	if not chop:
		_party_at(0.4, "wciagniecie" if party_sounds.has("wciagniecie") else "wciaganie_1", 1.0, 1.0)
		return 0.4
	var taps: Array = []
	var t := 0.0
	for i in range(8):
		taps.append([t, 0.0 if i == 0 else -4.0, randf_range(1.22, 1.4)])
		t += randf_range(0.095, 0.125)
	t += 0.28
	for i in range(11):
		taps.append([t, -1.0 if i == 0 else -4.5, randf_range(1.3, 1.5)])
		t += randf_range(0.075, 0.1)
	var scrapes := [[t + 0.3, -7.0, 1.7, "cloth1"], [t + 0.72, -6.0, 1.9, "cloth3"], [t + 1.08, -8.0, 2.15, "cloth2"]]
	var fin := t + 1.5
	taps.append([fin, -2.0, 1.15])
	taps.append([fin + 0.16, -3.0, 1.2])
	for e in taps:
		_party_at(float(e[0]), "tick_001" if randf() < 0.6 else "tick_002", float(e[1]) + 3.0, float(e[2]))
	for e in scrapes:
		_party_at(float(e[0]), String(e[3]), float(e[1]) + 3.0, float(e[2]))
	var at := fin + 0.62
	_party_at(at, "wciagniecie" if party_sounds.has("wciagniecie") else "wciaganie_1", 1.0, 1.0)
	return at


func _party_at(delay: float, name: String, db: float, pitch: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(maxf(0.01, delay))
	tw.tween_callback(func():
		if party_player != null and party_player.playing:
			party_sfx(name, db, pitch, true))


## kilka szybkich kroków (ktoś wbiega do łazienki)
func party_steps(n := 6, gap := 0.19) -> void:
	if muted:
		return
	var arr: Array = steps.get("tile", steps.get("concrete", []))
	if arr.is_empty():
		return
	for i in range(n):
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(i * gap)
		tw.tween_callback(func():
			var p: AudioStreamPlayer = _party_voice()
			p.bus = "Efekty"
			p.stream = arr.pick_random()
			p.volume_db = -5.0 + i * 1.2
			p.pitch_scale = randf_range(1.05, 1.2)
			p.play())


func party_stop() -> void:
	if party_player != null:
		party_player.stop()
	for p in party_fx:
		p.stop()
	party_solo(false)


## Scena imprezy gra sama: na jej czas milkną szyny, które do niej nie należą (muzyka gry, otoczenie, radio z bloku,
## klub, głosy, telefon) — wcześniej potrafiły się przebijać dźwięki spoza prologu.
const PARTY_QUIET := ["Muzyka", "Otoczenie", "Blok", "Klub", "Glosy", "Telefon"]
var _party_solo := false

func party_solo(on: bool) -> void:
	if on == _party_solo:
		return
	_party_solo = on
	for nm in PARTY_QUIET:
		var bi := AudioServer.get_bus_index(nm)
		if bi >= 0:
			AudioServer.set_bus_mute(bi, on)
	if on:
		ring(false)
		if intro_player != null and intro_player.playing:
			intro_player.stop()


## telefon: wibracja w kieszeni (nagranie), zapętlana, dopóki ktoś nie odbierze
var ring_player: AudioStreamPlayer = null

func ring(on: bool) -> void:
	if ring_player == null:
		ring_player = AudioStreamPlayer.new()
		ring_player.bus = "Efekty"
		add_child(ring_player)
		var path := "res://assets/sfx/party/wibracja.ogg"
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = true
			ring_player.stream = st
	if on and not muted and ring_player.stream != null:
		if not ring_player.playing:
			ring_player.volume_db = -3.0
			ring_player.play()
	else:
		ring_player.stop()


## głuche uderzenie w tył głowy (prolog) i dzwonienie w uszach
func knock() -> void:
	if muted:
		return
	if not _care.has("knock"):
		var n := int(2.6 * RATE)
		var buf := PackedFloat32Array()
		buf.resize(n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in range(n):
			var t := float(i) / RATE
			var thump := sin(TAU * (70.0 + 90.0 * exp(-t * 40.0)) * t) * exp(-t * 9.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 55.0) * 0.5
			var ring := sin(TAU * 3150.0 * t) * 0.09 * minf(1.0, t * 3.0) * clampf((2.6 - t) / 1.6, 0.0, 1.0)
			buf[i] = clampf(thump * 0.95 + ring, -1.0, 1.0)
		_care["knock"] = _wav(buf)
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = _care["knock"]
	p.volume_db = -2.0
	p.pitch_scale = 1.0
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
	voice_player.pitch_scale = clampf(voice * randf_range(0.94, 1.07), 0.5, 2.0)
	voice_player.play()


## barwa i wysokość głosu postaci: [nazwa barwy, mnożnik wysokości]. Znane postacie mają swoje (VOICE_OF),
## pozostałe dostają barwę z imienia — zawsze tę samą, więc klienta poznaje się po głosie.
func voice_for(who: String) -> Array:
	if _voice_cache.has(who):
		return _voice_cache[who]
	var out: Array = VOICE_OF.get(who, [])
	if out.is_empty():
		var first := who.get_slice(" ", 0).to_lower()
		var last := who.get_slice(" ", who.get_slice_count(" ") - 1).to_lower()
		var fem: bool = (last.ends_with("a") or first in ["pani", "ola", "baśka", "mama"]) and not last in ["kuba", "numer", "wrona", "siwy"] and first != "pan"
		var h := absi(who.hash())
		var pool: Array = ["kobieta", "kobieta_niska"] if fem else ["tenor", "bas", "chrypa", "mlody", "starszy", "nosowy"]
		out = [pool[h % pool.size()], 0.93 + float((h / 7) % 16) / 100.0]
	_voice_cache[who] = out
	return out


## jedna sylaba mowy postaci `who`; phone = rozmówca w słuchawce (wąskie pasmo). Kuba mówi ciszej — to „nasz” głos.
func say(who: String, phone := false) -> void:
	if muted or who == "":
		return
	var v := voice_for(who)
	var bank: Array = _banks.get(String(v[0]), _syll)
	if bank.is_empty():
		return
	var mine: bool = who == "Ty" or who == "Kuba"
	var pl: AudioStreamPlayer = phone_player if (phone and not mine) else voice_player
	pl.stream = bank.pick_random()
	pl.pitch_scale = clampf(float(v[1]) * randf_range(0.95, 1.06), 0.5, 2.0)
	pl.volume_db = (-16.0 if mine else -13.0) if pl == voice_player else -10.0
	pl.play()


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
	# bezpiecznik: scena imprezy wycisza resztę dźwięków tylko na swój czas — poza prologiem wszystko gra
	if _party_solo and G.prologue == null:
		party_solo(false)
	_city_tick(outside, night)
	var r := (-40.0 + rain * 22.0 - (0.0 if outside else 12.0)) if rain > 0.05 else -70.0
	rain_player.volume_db = lerpf(rain_player.volume_db, r, 0.05)


## Żyjące miasto w tle — z nagrań, które gra już ma: przytłumiony gwar ludzi za dnia i co kilkadziesiąt sekund
## coś z daleka (trzaśnięcie drzwi, skrzypnięcie, łomot w śmietnik, kroki, syrena gdzieś na mieście).
## To namiastka: prawdziwe tło (ruch uliczny, ptaki, psy, tramwaj) wymaga nowych nagrań na otwartej licencji.
## Gdy w assets/sfx/miasto/ leżą nagrania (tools/make_miasto.py: dzien.wav, ptaki.wav, pies_N.wav), tło gra z nich:
## ruch uliczny w pętli, ptaki o świcie i ciszej w dzień, nocą pies w oddali. Bez plików zostaje namiastka.
const CITY_DIR := "res://assets/sfx/miasto/"
var city_murmur: AudioStreamPlayer = null
var city_fx: AudioStreamPlayer = null
var city_birds: AudioStreamPlayer = null
var city_real := false
var _city_dogs: Array = []
var _city_next := 12.0
var _city_last := 0

func _city_tick(outside: bool, night: float) -> void:
	if city_murmur == null:
		city_murmur = AudioStreamPlayer.new()
		city_murmur.bus = "Otoczenie" if AudioServer.get_bus_index("Otoczenie") >= 0 else "Master"
		city_murmur.volume_db = -70.0
		add_child(city_murmur)
		city_fx = AudioStreamPlayer.new()
		city_fx.bus = city_murmur.bus
		add_child(city_fx)
		var day := _loop_wav(CITY_DIR + "dzien.wav")
		if day != null:
			city_murmur.stream = day
			city_real = true
		else:
			party_prepare()
			if party_sounds.has("gwar_baru"):
				city_murmur.stream = party_sounds["gwar_baru"]
				city_murmur.pitch_scale = 0.82
		var birds := _loop_wav(CITY_DIR + "ptaki.wav")
		if birds != null:
			city_birds = AudioStreamPlayer.new()
			city_birds.bus = city_murmur.bus
			city_birds.volume_db = -70.0
			city_birds.stream = birds
			add_child(city_birds)
		for k in range(1, 6):
			if ResourceLoader.exists(CITY_DIR + "pies_%d.wav" % k):
				_city_dogs.append(load(CITY_DIR + "pies_%d.wav" % k))
	if city_murmur.stream != null:
		if not city_murmur.playing:
			city_murmur.play(randf() * 4.0)
		# gwar słychać w dzień na dworze; nocą i w mieszkaniu prawie znika
		var m := (-41.0 - night * 16.0) if outside else -62.0
		if city_real:
			# nagrany ruch uliczny: w dzień wyraźny, nocą daleki szum, w mieszkaniu przez zamknięte okno
			m = (-26.0 - night * 11.0) if outside else -50.0
		city_murmur.volume_db = lerpf(city_murmur.volume_db, m, 0.03)
	if city_birds != null:
		var b := city_birds_level(G.hour() if G.S != null else 12.0) if outside else 0.0
		if b > 0.01 and not city_birds.playing:
			city_birds.play(randf() * 3.0)
		city_birds.volume_db = lerpf(city_birds.volume_db, (-48.0 + b * 22.0) if b > 0.01 else -70.0, 0.03)
		if city_birds.playing and city_birds.volume_db < -66.0:
			city_birds.stop()
	var now := Time.get_ticks_msec()
	_city_next -= float(now - _city_last) / 1000.0 if _city_last > 0 else 0.0
	_city_last = now
	if _city_next > 0.0 or not outside or city_fx.playing:
		return
	_city_next = randf_range(14.0, 42.0) * (1.0 + night * 0.8)
	var picks: Array = [["door_close", -19.0, 0.8], ["creak", -22.0, 0.75], ["thud", -18.0, 0.7], ["lomot", -27.0, 0.6], ["impactmetal", -22.0, 0.7], ["syrena", -33.0, 0.92]]
	if night > 0.4 and not _city_dogs.is_empty():
		# nocą najczęściej słychać psa gdzieś za blokami
		for _k in range(4):
			picks.append(["pies", -23.0, 1.0])
	var pick: Array = picks.pick_random()
	var st: AudioStream = null
	if String(pick[0]) == "pies":
		st = _city_dogs.pick_random()
	elif String(pick[0]) == "syrena":
		var pth := "res://assets/sfx/syrena_wail.wav"
		if night > 0.3 and ResourceLoader.exists(pth):
			st = load(pth)
	elif String(pick[0]) == "impactmetal":
		for cand in ["res://assets/sfx/impactmetal_light_000.ogg", "res://assets/sfx/impactmetal_light_001.ogg"]:
			if ResourceLoader.exists(cand):
				st = load(cand)
				break
	elif sounds.has(String(pick[0])) and not sounds[String(pick[0])].is_empty():
		st = sounds[String(pick[0])].pick_random()
	if st == null:
		return
	city_fx.stream = st
	city_fx.volume_db = float(pick[1]) + randf_range(-4.0, 2.0)
	city_fx.pitch_scale = float(pick[2]) * randf_range(0.92, 1.08)
	city_fx.play()
	if String(pick[0]) == "syrena":
		# syrena przejeżdża gdzieś daleko: kilka sekund i cichnie
		var tw := create_tween()
		tw.tween_interval(3.5)
		tw.tween_property(city_fx, "volume_db", -60.0, 2.5)
		tw.tween_callback(city_fx.stop)


## jak głośno śpiewają ptaki o danej godzinie (0…1): najgłośniej o świcie, w dzień cicho, od zmierzchu wcale
static func city_birds_level(h: float) -> float:
	var dawn := clampf(1.0 - absf(h - 6.2) / 2.6, 0.0, 1.0)
	var day := 0.32 if (h >= 8.0 and h < 18.5) else 0.0
	return maxf(dawn, day)


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
	# głosy rozmówców: sylaby do mamrotania — impuls krtaniowy i dwa formanty samogłoski. Każda barwa (VOICES) ma
	# własną wysokość, „usta” (formanty), chrypę, przydech i tempo, więc postacie różnią się nie tylko wysokością tonu.
	var vowels := [[700.0, 1150.0], [520.0, 1750.0], [320.0, 2200.0], [480.0, 900.0], [360.0, 760.0], [620.0, 1400.0], [430.0, 1100.0], [560.0, 1000.0]]
	var banks := {}
	for vn in VOICES:
		var V: Dictionary = VOICES[vn]
		var bank: Array = []
		for vi in range(vowels.size()):
			if _abort:
				return
			var dur: float = float(V.dur) + 0.02 * (vi % 4)
			var sn := int(dur * RATE)
			var sbuf := PackedFloat32Array()
			sbuf.resize(sn)
			var f0: float = float(V.f0) + (vi % 3) * float(V.f0) * 0.07
			var f1: float = vowels[vi][0] * float(V.mouth)
			var f2: float = vowels[vi][1] * float(V.mouth)
			var soft := 0.0
			var per := 1.0 / f0
			var tp := 0.0
			for i in range(sn):
				var tt := float(i) / RATE
				tp += 1.0 / RATE
				if tp >= per:
					# nowy impuls: chrypa to nierówne odstępy między impulsami, lekki zjazd tonu na końcu sylaby
					tp -= per
					per = (1.0 / (f0 * (1.0 - 0.1 * tt / dur))) * (1.0 + randf_range(-1.0, 1.0) * float(V.rasp))
				var e := exp(-tp * float(V.damp))
				var v := (sin(tp * TAU * f1) * 0.8 + sin(tp * TAU * f2) * 0.35) * e
				v += randf_range(-1.0, 1.0) * float(V.breath) * (0.4 + 0.6 * e)
				if vi % 3 == 0 and i < int(0.018 * RATE):
					v += randf_range(-0.5, 0.5) * (1.0 - float(i) / (0.018 * RATE))
				var a := minf(1.0, float(i) / (0.012 * RATE)) * minf(1.0, float(sn - i) / (0.03 * RATE))
				soft += (v - soft) * float(V.bright)
				sbuf[i] = soft * a * 0.85
			bank.append(_wav(sbuf))
		banks[vn] = bank
	var syl: Array = banks["tenor"]
	_set_banks.call_deferred(banks)
	_set_voice.call_deferred(s4, syl)
	if not tracks.is_empty():
		return
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
	# radio w kawalerce: własny bit i biesiadne disco
	if not _abort:
		_radio_ready.call_deferred(_wav(_gen_trap(1312, 144.0, 1.0), true))
	if not _abort:
		_radio_ready.call_deferred(_wav(_gen_disco(), true))


func _set_loops(s1: AudioStreamWAV, s2: AudioStreamWAV, s3: AudioStreamWAV) -> void:
	_siren = s1
	# nagrana syrena elektroniczna (Freesound, CC0) zamiast syntezy: zawodzenie w pętli, a z bliska szybki „yelp”
	var rec := _loop_wav("res://assets/sfx/syrena_wail.wav")
	if rec != null:
		_siren = rec
	_siren_yelp = _loop_wav("res://assets/sfx/syrena_yelp.wav")
	_amb = s2
	_rain = s3


## nagranie WAV ustawione do grania w kółko (cały plik); null, gdy pliku nie ma
func _loop_wav(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamWAV:
		var w := (st as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		return w
	return st


func _set_banks(b: Dictionary) -> void:
	_banks = b


func _set_voice(tr: AudioStreamWAV, syl: Array) -> void:
	_train = tr
	_syll = syl


func _club_ready(s: AudioStreamWAV) -> void:
	club_stream = s


var trap_streams: Array = []
var radio_streams: Array = []     # radio w kawalerce: [bit z bloków, biesiadne disco]

func _radio_ready(s: AudioStreamWAV) -> void:
	radio_streams.append(s)


## wesołe, przaśne disco na radio: stopa na raz, bas „um-pa”, klaśnięcia i piskliwa melodyjka w dur
func _gen_disco() -> PackedFloat32Array:
	var bpm := 128.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4.0 * beat * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1995
	var roots := [48.0, 45.0, 41.0, 43.0, 48.0, 45.0, 41.0, 43.0]      # C, a, F, G
	var tunes := [[72, 76, 79, 76, 72, 76, 79, 84], [72, 76, 81, 76, 72, 76, 81, 84], [72, 77, 81, 77, 72, 77, 81, 84], [74, 79, 83, 79, 74, 79, 83, 86]]
	var s8 := beat / 2.0
	for bar in range(bars):
		if _abort:
			return b
		var t0 := bar * 4.0 * beat
		for q in range(4):
			# stopa
			var i0 := int((t0 + q * beat) * RATE)
			for i in range(int(0.22 * RATE)):
				if i0 + i >= n:
					break
				var tt := float(i) / RATE
				b[i0 + i] += sin(TAU * (50.0 + 110.0 * exp(-tt * 34.0)) * tt) * exp(-tt * 13.0) * 0.6
			# bas na „i”: oktawa wyżej
			var i1 := int((t0 + q * beat + s8) * RATE)
			var fb := _mtof(float(roots[bar]) - 12.0 + (12.0 if q % 2 == 1 else 0.0))
			for i in range(int(s8 * 0.9 * RATE)):
				if i1 + i >= n:
					break
				var tt2 := float(i) / RATE
				var sq := 1.0 if fmod(tt2 * fb, 1.0) < 0.5 else -1.0
				b[i1 + i] += (sin(TAU * fb * tt2) * 0.7 + sq * 0.12) * exp(-tt2 * 6.0) * minf(1.0, tt2 * 300.0) * 0.4
			# klaśnięcie na 2 i 4, hi-hat na każde „i”
			if q % 2 == 1:
				var lp := 0.0
				for i in range(int(0.14 * RATE)):
					if i0 + i >= n:
						break
					var nz := rng.randf_range(-1.0, 1.0)
					lp += (nz - lp) * 0.4
					b[i0 + i] += (nz - lp) * exp(-float(i) / RATE * 26.0) * 0.3
			var hp := 0.0
			for i in range(int(0.05 * RATE)):
				if i1 + i >= n:
					break
				var nz2 := rng.randf_range(-1.0, 1.0)
				hp += (nz2 - hp) * 0.2
				b[i1 + i] += (nz2 - hp) * exp(-float(i) / RATE * 70.0) * 0.1
		# melodyjka: ósemki, brzmienie taniego keyboardu (prostokąt z wibrato)
		var tune: Array = tunes[bar % 4]
		for k in range(8):
			var i3 := int((t0 + k * s8) * RATE)
			var fm := _mtof(float(tune[k]))
			for i in range(int(s8 * 0.85 * RATE)):
				if i3 + i >= n:
					break
				var tt3 := float(i) / RATE
				var ph := tt3 * fm * (1.0 + 0.006 * sin(tt3 * 38.0))
				var sq2 := (1.0 if fmod(ph, 1.0) < 0.35 else -1.0) * 0.5 + sin(TAU * ph) * 0.5
				b[i3 + i] += sq2 * exp(-tt3 * 5.0) * minf(1.0, tt3 * 250.0) * 0.11
		# akord „pad” w tle
		for iv in [0.0, 4.0 if roots[bar] != 45.0 else 3.0, 7.0]:
			var fc := _mtof(float(roots[bar]) + 12.0 + float(iv))
			var i4 := int(t0 * RATE)
			for i in range(int(4.0 * beat * RATE)):
				if i4 + i >= n:
					break
				b[i4 + i] += sin(TAU * fc * float(i) / RATE) * 0.03
	var peak := 0.001
	for i in range(n):
		peak = maxf(peak, absf(b[i]))
	for i in range(n):
		b[i] = b[i] / peak * 0.9
	return b

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


## Muzyka z nagrań na licencji CC0 (assets/music, spis w LICENCJE.md): klub, radio w kawalerce, okna bloków.
const TRACKS := {
	"night_prowler": "Night Prowler — section31",
	"sewer_nightclub": "Sewer Nightclub — section31",
	"root_of_all_evil": "The Root of All Evil — Cleyton Kauffman",
	"funky_disco": "Funky Disco Beats — Fupi",
}
const CLUB_TRACKS := ["night_prowler", "sewer_nightclub"]
const RADIO_TRACKS := ["root_of_all_evil", "funky_disco"]
const BLOCK_TRACKS := ["root_of_all_evil", "sewer_nightclub", "night_prowler"]
var tracks := {}
var club_i := 0

func _load_tracks() -> void:
	for id in TRACKS:
		var path := "res://assets/music/%s.ogg" % id
		if not ResourceLoader.exists(path):
			continue
		var st = load(path)
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
			tracks[id] = st
	radio_streams.clear()
	for id in RADIO_TRACKS:
		if tracks.has(id):
			radio_streams.append(tracks[id])
	for id in BLOCK_TRACKS:
		if tracks.has(id):
			trap_streams.append(tracks[id])


# ---------------------------------------------------------------- muzyka filmowa prologu
## Podkład pod sceny: napięcie w laboratorium → akcja przy nalocie → skradanie na zewnątrz → dramat po wybuchu.
## Nagrania z internetu (licencje w LICENCJE.md); dwa odtwarzacze, żeby jeden motyw przechodził płynnie w drugi.
const SCORE := {"napiecie": "pro_napiecie", "akcja": "pro_akcja", "skradanie": "pro_skradanie", "dramat": "pro_final"}
## skradanie i laboratorium grają cicho, w tle — mają tylko trzymać napięcie, nie zagłuszać kroków i latarek
const SCORE_DB := {"napiecie": -12.5, "akcja": -7.0, "skradanie": -17.5, "dramat": -5.0}
## od której sekundy gra motyw (dramat ma 11 s cichego wstępu — wybuch potrzebuje pełnej orkiestry od razu)
## „dramat”: uderzenie orkiestry wypada w 18,0 s utworu — start tuż przed nim, żeby trafiło równo w wybuch
const SCORE_FROM := {"dramat": 17.96}
var _score_players: Array = []
var _score_i := 0
var _score_now := ""
var _score_streams := {}


func _score_stream(key: String) -> AudioStream:
	if not _score_streams.has(key):
		var st: AudioStream = null
		for ext in ["ogg", "mp3"]:
			var path := "res://assets/music/%s.%s" % [String(SCORE.get(key, "")), ext]
			if ResourceLoader.exists(path):
				st = load(path)
				break
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		elif st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_score_streams[key] = st
	return _score_streams[key]


var _score_token := 0

## Zmienia motyw: poprzedni powoli wycisza się do zera (`fade` sekund), potem jest chwila ciszy (`gap`),
## i dopiero wtedy wchodzi następny (`fade_in`). Pusty `key` = samo wyciszenie.
func score(key: String, fade := 2.5, fade_in := 1.2, gap := 3.0) -> void:
	if key == _score_now:
		return
	_score_now = key
	_score_token += 1
	var token := _score_token
	if _score_players.is_empty():
		for i in range(2):
			var p := AudioStreamPlayer.new()
			p.bus = "Muzyka" if AudioServer.get_bus_index("Muzyka") >= 0 else "Master"
			p.volume_db = -60.0
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(p)
			_score_players.append(p)
	var wait := 0.0
	for old in _score_players:
		if (old as AudioStreamPlayer).playing:
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(old, "volume_db", -60.0, maxf(0.05, fade)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback((old as AudioStreamPlayer).stop)
			wait = maxf(0.05, fade) + maxf(0.0, gap)
	var st := _score_stream(key) if key != "" else null
	if st == null or muted:
		return
	if wait > 0.0:
		await get_tree().create_timer(wait + 0.05, true).timeout
		if token != _score_token:
			return
	_score_i = 1 - _score_i
	var cur: AudioStreamPlayer = _score_players[_score_i]
	cur.stream = st
	cur.volume_db = -40.0
	cur.play(float(SCORE_FROM.get(key, 0.0)))
	var tw2 := create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_property(cur, "volume_db", float(SCORE_DB.get(key, -8.0)), maxf(0.05, fade_in))


func score_name() -> String:
	return _score_now


func radio_track_name(i: int) -> String:
	return String(TRACKS.get(RADIO_TRACKS[i], "")) if i >= 0 and i < RADIO_TRACKS.size() else ""


func next_club_stream() -> AudioStream:
	if club_files.is_empty() and not tracks.is_empty():
		for _try in range(CLUB_TRACKS.size()):
			var id: String = CLUB_TRACKS[club_i % CLUB_TRACKS.size()]
			club_i += 1
			if tracks.has(id):
				# w klubie utwory lecą po kolei, więc ta kopia się nie zapętla
				var one: AudioStreamOggVorbis = (tracks[id] as AudioStreamOggVorbis).duplicate()
				one.loop = false
				return one
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
	if not tracks.is_empty():
		return String(TRACKS.get(CLUB_TRACKS[(club_i - 1 + CLUB_TRACKS.size()) % CLUB_TRACKS.size()], ""))
	return "Blokowisko 140 (bit z gry)"
