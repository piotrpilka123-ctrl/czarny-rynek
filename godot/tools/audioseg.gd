extends SceneTree
## odcinki dźwięku w nagraniu (start–koniec, szczyt): Godot --headless --path . --script tools/audioseg.gd -- plik [próg 0..1] [min. przerwa s]
## Służy do wycinania pojedynczych odgłosów z dłuższych nagrań (np. jedno wciągnięcie z serii).
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var thr: float = float(args[1]) if args.size() > 1 else 0.2
	var gap: float = float(args[2]) if args.size() > 2 else 0.25
	var st: AudioStream = AudioStreamOggVorbis.load_from_file(path) if path.ends_with(".ogg") else AudioStreamMP3.load_from_file(path)
	var pb: AudioStreamPlayback = st.instantiate_playback()
	pb.start(0.0)
	var env: Array = []
	var t := 0.0
	while t < st.get_length():
		var fr: PackedVector2Array = pb.mix_audio(1.0, 2205)
		if fr.is_empty():
			break
		var acc := 0.0
		for v in fr:
			var x := (v.x + v.y) * 0.5
			acc += x * x
		env.append(sqrt(acc / fr.size()))
		t += 0.05
	var peak := 0.0001
	for e in env:
		peak = maxf(peak, e)
	var out := ""
	var s := -1.0
	var last := -9.0
	var mx := 0.0
	for i in range(env.size()):
		var tt := i * 0.05
		if float(env[i]) > peak * thr:
			if s < 0.0:
				s = tt
				mx = 0.0
			last = tt
			mx = maxf(mx, float(env[i]))
		elif s >= 0.0 and tt - last > gap:
			out += "%.2f-%.2f(%.2f) " % [s, last + 0.05, mx]
			s = -1.0
	if s >= 0.0:
		out += "%.2f-%.2f(%.2f) " % [s, last + 0.05, mx]
	print("SEG ", path.get_file(), " dł. %.1f s, szczyt %.2f: " % [st.get_length(), peak], out)
	quit()
