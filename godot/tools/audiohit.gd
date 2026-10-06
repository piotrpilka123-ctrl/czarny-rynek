extends SceneTree
## głośność fragmentu utworu w oknach 0,1 s — do trafienia uderzeniem w klatkę: Godot --headless --path . --script tools/audiohit.gd -- plik od do
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var t0: float = float(args[1]) if args.size() > 1 else 0.0
	var t1: float = float(args[2]) if args.size() > 2 else 10.0
	var st: AudioStream = AudioStreamOggVorbis.load_from_file(path) if path.ends_with(".ogg") else AudioStreamMP3.load_from_file(path)
	var pb: AudioStreamPlayback = st.instantiate_playback()
	pb.start(t0)
	var t := t0
	var line := ""
	while t < t1:
		var fr: PackedVector2Array = pb.mix_audio(1.0, 4410)
		if fr.is_empty():
			break
		var acc := 0.0
		for v in fr:
			var x := (v.x + v.y) * 0.5
			acc += x * x
		line += "%.1f:%.3f " % [t, sqrt(acc / fr.size())]
		t += 0.1
	print("HIT ", path.get_file(), " dł. %.1f s  " % st.get_length(), line)
	quit()
