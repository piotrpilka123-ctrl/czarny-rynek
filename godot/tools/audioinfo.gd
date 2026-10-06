extends SceneTree
## Długość, tempo i „ciężar basu” utworów z assets/music (sprawdzenie, czy pasują do klubu / radia):
## Godot --headless --path . --script tools/audioinfo.gd
func _init() -> void:
	for dir in ["res://assets/music", "res://assets/sfx/party"]:
		_scan(dir)
	quit()


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if not (f.ends_with(".ogg") or f.ends_with(".mp3")):
			continue
		var st: AudioStream = AudioStreamOggVorbis.load_from_file(dir + "/" + f) if f.ends_with(".ogg") else AudioStreamMP3.load_from_file(dir + "/" + f)
		if st == null:
			print("AUDIO %s — nie da się wczytać" % f)
			continue
		var pb: AudioStreamPlayback = st.instantiate_playback()
		pb.start(20.0 if st.get_length() > 60.0 else 0.0)
		var rate := 44100.0
		var secs := minf(40.0, st.get_length() - 1.0)
		var env := PackedFloat32Array()     # obwiednia basu, 100 próbek na sekundę
		var lp := 0.0
		var acc := 0.0
		var all := 0.0
		var low := 0.0
		var peak := 0.0
		var cnt := 0
		var left := int(secs * rate)
		while left > 0:
			var fr: PackedVector2Array = pb.mix_audio(1.0, mini(4410, left))
			if fr.is_empty():
				break
			left -= fr.size()
			for v in fr:
				var x := (v.x + v.y) * 0.5
				lp += (x - lp) * 0.02          # ok. 140 Hz
				acc += lp * lp
				low += lp * lp
				all += x * x
				peak = maxf(peak, absf(x))
				cnt += 1
				if cnt % 441 == 0:
					env.append(sqrt(acc / 441.0))
					acc = 0.0
		# tempo: autokorelacja przyrostów obwiedni
		var on := PackedFloat32Array()
		for i in range(1, env.size()):
			on.append(maxf(0.0, env[i] - env[i - 1]))
		var best := 0.0
		var best_bpm := 0.0
		for bpm10 in range(700, 1800, 5):
			var bpm := bpm10 / 10.0
			var lag := 6000.0 / bpm
			var s := 0.0
			for i in range(on.size() - int(lag) - 2):
				var j := i + lag
				var a := on[int(j)] * (1.0 - fmod(j, 1.0)) + on[int(j) + 1] * fmod(j, 1.0)
				s += on[i] * a
			if s > best:
				best = s
				best_bpm = bpm
		print("AUDIO %-24s długość %5.1f s | tempo ok. %5.1f BPM | bas %2d%% energii | szczyt %.2f | średnio %.3f" % [f, st.get_length(), best_bpm, int(100.0 * low / maxf(0.000001, all)), peak, sqrt(all / maxf(1.0, cnt))])
