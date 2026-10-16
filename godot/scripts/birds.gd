extends Node
## Gołębie na chodnikach przed klatkami: dziobią, drepczą, a gdy gracz podejdzie albo podbiegnie, zrywają się do lotu
## (machają skrzydłami, wznoszą się łukiem i siadają kilkanaście metrów dalej, po czasie wracają). Proste węzły bez szkieletu,
## tylko w dzień i do 70 m od gracza.

const SPOOK := 3.2           # szybki krok / stanie: spłoszenie z tej odległości
const SPOOK_RUN := 7.5       # bieg płoszy z dalszej odległości

var npc
var birds: Array = []


var _built := false


func setup(n) -> void:
	npc = n


## wejścia do klatek powstają razem ze światem, więc ptaki stawiamy przy pierwszej klatce gry
func _build() -> void:
	_built = true
	var spots: Array = G.world.entrance_spots
	if spots.is_empty():
		return
	var rg := RandomNumberGenerator.new()
	rg.seed = 2024
	var step := maxi(1, int(spots.size() / 5))
	var ps: PackedScene = load("res://assets/models/golab.glb")
	if ps == null:
		return
	var gi := 0
	while gi < spots.size() and birds.size() < 18:
		var sp: Dictionary = spots[gi]
		gi += step
		var rot: float = sp.rot
		var nrm := Vector3(sin(rot), 0.0, cos(rot))
		var home: Vector3 = sp.p + nrm * 2.4
		for k in range(rg.randi_range(3, 5)):
			var node: Node3D = ps.instantiate()
			add_child(node)
			node.scale = Vector3.ONE * rg.randf_range(0.95, 1.1)
			var off := Vector3(rg.randf_range(-1.4, 1.4), 0.0, rg.randf_range(-1.0, 1.0))
			var pos := home + off
			var b := {"node": node, "x": pos.x, "z": pos.z, "home": Vector2(home.x, home.z), "yaw": rg.randf() * TAU, "state": "peck",
				"t": rg.randf_range(0.2, 2.0), "head": node.find_child("Glowa", true, false), "wl": node.find_child("SkrzydloL", true, false),
				"wr": node.find_child("SkrzydloP", true, false), "air": 0.0, "from": Vector2.ZERO, "to": Vector2.ZERO, "h": 0.0, "bob": rg.randf() * 6.0,
				"back_t": 0.0, "dest": Vector2(pos.x, pos.z)}
			node.position = Vector3(pos.x, npc._h(pos.x, pos.z), pos.z)
			node.rotation.y = b.yaw
			node.visible = false
			birds.append(b)


func update(dt: float, pp: Vector3, outside: bool) -> void:
	if not _built and not G.world.entrance_spots.is_empty():
		_build()
	var day: bool = G.night < 0.5
	for b in birds:
		var node: Node3D = b.node
		var dist := Vector2(pp.x - b.x, pp.z - b.z).length()
		if not outside or not day or dist > 70.0:
			node.visible = false
			if b.state == "air":
				b.state = "peck"
			continue
		node.visible = true
		var running: bool = G.player != null and G.player.moving and G.player.sprinting
		match String(b.state):
			"peck":
				b.t = float(b.t) - dt
				b.bob = float(b.bob) + dt * 9.0
				# głowa w dół i w górę (dziobanie), co chwilę krok albo kilka drobnych kroków w nowe miejsce
				if b.head != null:
					var dip: float = maxf(0.0, sin(float(b.bob))) * 0.9 if float(b.t) > 0.0 else 0.0
					(b.head as Node3D).rotation.x = lerpf((b.head as Node3D).rotation.x, -dip, minf(1.0, dt * 14.0))
				if float(b.t) <= 0.0:
					var home: Vector2 = b.home
					var tgt := home + Vector2(randf_range(-1.6, 1.6), randf_range(-1.2, 1.2))
					b.dest = tgt
					b.state = "walk"
					b.t = randf_range(0.5, 1.1)
				if dist < (SPOOK_RUN if running else SPOOK):
					_flee(b, pp)
			"walk":
				b.t = float(b.t) - dt
				var d: Vector2 = (b.dest as Vector2) - Vector2(b.x, b.z)
				if d.length() > 0.05:
					var stp: Vector2 = d.normalized() * minf(d.length(), 0.9 * dt)
					b.x += stp.x
					b.z += stp.y
					b.yaw = lerp_angle(float(b.yaw), atan2(d.x, d.y), minf(1.0, dt * 10.0))
					b.bob = float(b.bob) + dt * 16.0
					if b.head != null:
						(b.head as Node3D).rotation.x = sin(float(b.bob)) * 0.18
				if float(b.t) <= 0.0 or d.length() <= 0.05:
					b.state = "peck"
					b.t = randf_range(1.0, 3.2)
				if dist < (SPOOK_RUN if running else SPOOK):
					_flee(b, pp)
			"air":
				b.air = float(b.air) + dt
				var k := clampf(float(b.air) / 2.4, 0.0, 1.0)
				var from: Vector2 = b.from
				var to: Vector2 = b.to
				var p := from.lerp(to, smoothstep(0.0, 1.0, k))
				b.x = p.x
				b.z = p.y
				var ground: float = npc._h(p.x, p.y)
				node.position = Vector3(p.x, ground + sin(k * PI) * float(b.h) + (1.0 - k) * 0.0, p.y)
				node.rotation = Vector3(-0.25 * sin(k * PI), float(b.yaw), 0.0)
				var flap := sin(float(b.air) * 62.0)
				if b.wl != null:
					(b.wl as Node3D).rotation.z = 0.3 + flap * 0.9
					(b.wr as Node3D).rotation.z = -0.3 - flap * 0.9
				if k >= 1.0:
					b.state = "peck"
					b.t = randf_range(1.0, 3.0)
					b.home = Vector2(b.x, b.z) if randf() < 0.5 else b.home
					if b.wl != null:
						(b.wl as Node3D).rotation.z = 0.0
						(b.wr as Node3D).rotation.z = 0.0
		if b.state != "air":
			node.position = Vector3(b.x, npc._h(b.x, b.z), b.z)
			node.rotation = Vector3(0.0, float(b.yaw), 0.0)


func _flee(b: Dictionary, pp: Vector3) -> void:
	var away := Vector2(b.x - pp.x, b.z - pp.z)
	if away.length() < 0.01:
		away = Vector2(1.0, 0.0)
	away = away.normalized().rotated(randf_range(-0.7, 0.7))
	b.from = Vector2(b.x, b.z)
	b.to = Vector2(b.x, b.z) + away * randf_range(9.0, 14.0)
	b.h = randf_range(3.5, 7.0)
	b.air = 0.0
	b.yaw = atan2(away.x, away.y)
	b.state = "air"
	b.home = b.to
