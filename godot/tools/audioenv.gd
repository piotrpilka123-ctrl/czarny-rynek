extends SceneTree
## głośność utworu w czasie (okna 2 s) — do wybrania miejsca, od którego ma grać: Godot --headless --path . --script tools/audioenv.gd -- plik
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://assets/music/technomania101.ogg"
	var st: AudioStream = AudioStreamOggVorbis.load_from_file(path) if path.ends_with(".ogg") else AudioStreamMP3.load_from_file(path)
	var pb: AudioStreamPlayback = st.instantiate_playback()
	pb.start(0.0)
	var t := 0.0
	var line := ""
	while t < st.get_length() - 2.0:
		var fr: PackedVector2Array = pb.mix_audio(1.0, 88200)
		if fr.is_empty():
			break
		var acc := 0.0
		var lp := 0.0
		var low := 0.0
		for v in fr:
			var x := (v.x + v.y) * 0.5
			acc += x * x
			lp += (x - lp) * 0.02
			low += lp * lp
		line += "%d:%.2f/%.2f " % [int(t), sqrt(acc / fr.size()), sqrt(low / fr.size())]
		t += 2.0
	print("ENV ", path.get_file(), " (czas: głośność/bas)  ", line)
	quit()
