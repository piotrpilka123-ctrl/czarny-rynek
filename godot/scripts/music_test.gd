extends RefCounted
static func run(T) -> void:
	var main=G.main
	var player=G.player
	var loc: String=player.loc
	var pos: Vector3=player.global_position
	var volume: float=G.world.club_player.volume_db
	var stream=G.world.club_player.stream
	player.loc="out"
	player.global_position=G.world.club_door
	main._slow()
	var outside: float=G.world.club_player.volume_db
	var bus:=AudioServer.get_bus_index("Klub")
	var filter=AudioServer.get_bus_effect(bus,0)
	T.ok(outside==-11.0 and filter.cutoff_hz<=2200.0,"muzyka klubu na ulicy jest cichsza i stłumiona także przy samych drzwiach")
	player.loc="club"
	player.global_position=Vector3(D.ROOMS.club.cx,0,0)
	main._slow()
	T.ok(G.world.club_player.volume_db-outside==4.0 and filter.cutoff_hz>=8900.0,"w klubie wraca pełne pasmo i dotychczasowa głośność")
	T.ok(Sfx.BLOCK_TRACKS.has("funky_disco") and Sfx.BLOCK_TRACKS.has("technomania101") and not Sfx.BLOCK_TRACKS.has("root_of_all_evil"),"z budynków lecą taneczne utwory zamiast mrocznego podkładu")
	T.ok(Sfx.CLUB_TRACKS.has("technomania101") and not Sfx.CLUB_TRACKS.has("night_prowler"),"klub ma domyślną playlistę techno zamiast mrocznego utworu")
	for id in Sfx.BLOCK_TRACKS:
		T.ok(ResourceLoader.exists("res://assets/music/%s.ogg"%id),"imprezowy utwór jest dostępny lokalnie: %s"%id)
	player.loc=loc
	player.global_position=pos
	G.world.club_player.volume_db=volume
	G.world.club_player.stream=stream
	main._slow()
