extends RefCounted
## Shader elewacji budynków. Budynek to prosta bryła — całą resztę „dorysowuje” shader:
## okna cofnięte w murze (paralaksa), wnętrza mieszkań widziane przez szybę (interior mapping,
## technika znana z dużych gier z otwartym światem), firanki, zasłony i rolety, loggie,
## klatki schodowe z luksferami, ślepe ściany szczytowe, kolory po termomodernizacji,
## odpadający tynk kamienic, zacieki. Nocą część okien świeci, w niektórych miga telewizor
## albo pulsują kolorowe ledy.

const SH := """
shader_type spatial;
global uniform float night;
global uniform float wet;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D wall_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D wall_nor : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D alt_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tex_scale = 0.22;
uniform int style = 0;              // 0 wielka płyta, 1 kamienica, 3 hala z cegły, 4 klub, 6 urząd
uniform vec2 cellsz = vec2(3.6, 3.0);
uniform float alt_amount = 0.0;     // ile tynku odpadło (widać cegłę)
instance uniform vec3 b_origin;
instance uniform vec3 b_size = vec3(4000.0, 300.0, 4000.0);
instance uniform vec3 b_wall : source_color = vec3(0.8, 0.8, 0.78);
instance uniform vec3 b_accent : source_color = vec3(0.85, 0.55, 0.3);
instance uniform float b_seed = 0.0;
instance uniform float b_dead = 0.0;
// x: ślepe ściany (1 = prostopadłe do osi X, 2 = do osi Z), y: wzór malowania, z: co ile okien klatka schodowa + przesunięcie/16
instance uniform vec4 b_opts = vec4(0.0);
// siatka okien: margines i liczba pól dla ścian wzdłuż osi X (xy) i wzdłuż osi Z (zw); 0 pól = wyśrodkuj automatycznie
instance uniform vec4 b_grid = vec4(0.0);
// „melina” z muzyką: pole (x, y) i ściana (1 = +Z, 2 = -Z, 3 = +X, 4 = -X); 0 = brak
instance uniform vec3 b_trap = vec3(0.0);
varying vec3 wpos;
varying vec3 wn;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// promień wpadający przez otwór a..b w głąb na `depth` metrów; surf: 0 tył, 1 bok, 2 góra, 3 dół
float box_trace(vec2 p, vec2 a, vec2 b, vec2 slope, float depth, out vec3 hp, out int surf) {
	vec3 rd = vec3(-slope, 1.0);
	float tx = abs(rd.x) < 0.0001 ? 1e9 : ((rd.x > 0.0 ? b.x : a.x) - p.x) / rd.x;
	float ty = abs(rd.y) < 0.0001 ? 1e9 : ((rd.y > 0.0 ? b.y : a.y) - p.y) / rd.y;
	float t = min(depth, min(tx, ty));
	surf = t >= depth ? 0 : (tx < ty ? 1 : (rd.y > 0.0 ? 2 : 3));
	hp = vec3(p, 0.0) + rd * t;
	return t;
}

// pokój za szybą: kolor ścian, podłogi, sufitu i paru mebli; `lamp` = jak mocno świeci żyrandol
vec3 room(vec2 p, vec2 size, vec2 slope, float rnd, float rnd2, out float glow) {
	vec3 hp;
	int surf;
	float depth = 3.4 + rnd * 1.2;
	float t = box_trace(p, vec2(0.0), size, slope, depth, hp, surf);
	vec3 paint = mix(vec3(0.78, 0.72, 0.6), vec3(0.55, 0.66, 0.6), rnd2);
	paint = mix(paint, vec3(0.8, 0.62, 0.52), step(0.7, rnd));
	vec3 c;
	if (surf == 0) {
		c = paint;
		// meblościanka i obrazek
		float fx = hp.x / size.x;
		float fy = hp.y / size.y;
		if (fy < 0.7 && fx > 0.08 + rnd * 0.2 && fx < 0.5 + rnd * 0.3) c = vec3(0.3, 0.2, 0.13) * (0.8 + 0.4 * step(0.5, fract(fx * 7.0)));
		else if (fy > 0.45 && fy < 0.72 && fx > 0.66 && fx < 0.88) c = vec3(0.5, 0.42, 0.3) * (0.6 + rnd2);
		else if (fy < 0.33 && fx > 0.6) c = vec3(0.35, 0.28, 0.3) * (0.7 + rnd);
	} else if (surf == 1) {
		c = paint * 0.82;
		float dz = hp.z / depth;
		if (hp.y / size.y < 0.75 && dz > 0.35 && dz < 0.6) c = vec3(0.28, 0.2, 0.14);
	} else if (surf == 2) {
		c = vec3(0.86, 0.85, 0.82);
	} else {
		c = mix(vec3(0.33, 0.22, 0.14), vec3(0.42, 0.4, 0.38), step(0.6, rnd2));
	}
	// światło: żyrandol pod sufitem na środku pokoju
	vec3 lamp = vec3(size.x * 0.5, size.y - 0.35, depth * 0.45);
	float d = length(hp - lamp);
	glow = 1.4 / (1.0 + d * d * 0.55) + 0.12;
	glow += 0.9 * smoothstep(0.3, 0.0, d);
	// za dnia: tym ciemniej, im głębiej
	return c * mix(1.0, 0.35, clamp(t / depth, 0.0, 1.0));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = normalize(wn);
	float nz = texture(noise_tex, wpos.xz * 0.05 + wpos.y * 0.03).r;
	float nz2 = texture(noise_tex, vec2(wpos.x + wpos.z, wpos.y) * 0.011 + b_seed).r;
	if (abs(n.y) > 0.5) {
		// dach: papa
		ALBEDO = vec3(0.085, 0.085, 0.095) * (0.6 + nz * 0.8);
		ROUGHNESS = 0.95;
	} else {
		bool xface = abs(n.x) > 0.5;
		float len = xface ? b_size.z : b_size.x;
		float u = xface ? (wpos.z - b_origin.z) : (wpos.x - b_origin.x);
		float v = wpos.y - b_origin.y;
		vec3 tang = xface ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		vec3 vw = normalize(CAMERA_POSITION_WORLD - wpos);
		vec2 slope = vec2(dot(vw, tang), vw.y) / max(0.12, dot(vw, n));
		// siatka okien wyśrodkowana na ścianie; resztki przy narożnikach zostają gładkim murem
		float ncell = max(1.0, floor((len - 0.5) / cellsz.x));
		float margin = len > 3000.0 ? 0.0 : (len - ncell * cellsz.x) * 0.5;
		vec2 gr = xface ? b_grid.zw : b_grid.xy;
		if (gr.y > 0.5) { margin = gr.x; ncell = gr.y; }
		float uu = u - margin;
		vec2 cell = floor(vec2(uu, v) / cellsz);
		vec2 f = fract(vec2(uu, v) / cellsz);
		vec2 p = f * cellsz;
		float floors = b_size.y > 250.0 ? 999.0 : floor((b_size.y + 0.3) / cellsz.y);
		bool grid = uu > 0.0 && (len > 3000.0 || uu < ncell * cellsz.x) && v > 0.0 && cell.y < floors;
		bool blind = (b_opts.x > 0.5 && b_opts.x < 1.5 && xface) || (b_opts.x > 1.5 && !xface);
		float rnd = hash21(cell + b_seed * 7.3);
		float rnd2 = hash21(cell * 1.7 + b_seed * 3.1 + 11.0);
		float rnd3 = hash21(cell * 2.3 + b_seed * 5.7 + 3.0);
		vec2 tuv = vec2(u, v) * tex_scale;
		vec3 tex = texture(wall_tex, tuv).rgb;
		vec3 nmap = texture(wall_nor, tuv).rgb;
		vec3 base = tex * b_wall * 1.25;
		vec3 col = base;
		float rough = 0.92;
		float metal = 0.0;
		float spec = 0.3;
		vec3 emi = vec3(0.0);
		bool flat_n = false;
		int pattern = int(b_opts.y + 0.5);
		bool ground = cell.y < 0.5;
		// --- rodzaj pola: 0 mur, 1 okno, 2 loggia, 3 klatka schodowa (luksfery), 4 okno fabryczne
		int kind = 0;
		float st_per = floor(b_opts.z);
		float st_off = floor(fract(b_opts.z) * 16.0 + 0.5);
		vec4 wr = vec4(0.2, 0.3, 0.8, 0.82);
		float recess = 0.13;
		if (grid && !blind) {
			kind = 1;
			if (style == 0) {
				bool stair = st_per > 0.5 && mod(cell.x - st_off + st_per * 8.0, st_per) < 0.5;
				bool balcony = mod(cell.x, 2.0) > 0.5;
				if (stair) { kind = ground ? 0 : 3; wr = vec4(0.34, 0.0, 0.66, 1.0); recess = 0.08; }
				else if (balcony && !ground) { kind = 2; wr = vec4(0.07, 0.05, 0.93, 0.87); recess = 1.05; }
				else wr = vec4(0.19, 0.31, 0.81, 0.81);
			} else if (style == 1) {
				wr = ground ? vec4(0.2, 0.14, 0.8, 0.76) : vec4(0.31, 0.2, 0.69, 0.8);
				recess = 0.2;
			} else if (style == 3) {
				kind = v > cellsz.y * 0.4 ? 4 : 0;
				wr = vec4(0.12, 0.2, 0.88, 0.86);
				recess = 0.22;
			} else if (style == 4) {
				kind = 0;
			} else {
				wr = vec4(0.06, 0.34, 0.94, 0.8);
				recess = 0.1;
			}
		}
		// --- mur: kolor, wzory, spoiny, cokół
		if (style == 0) {
			if (pattern == 1) {
				// pasy pod oknami w kolorze bloku
				if (f.y < 0.27 && grid) col = mix(col, b_accent * tex * 1.5, 0.82);
			} else if (pattern == 2) {
				// pionowe pasy: narożniki i klatki schodowe
				bool st = st_per > 0.5 && mod(cell.x - st_off + st_per * 8.0, st_per) < 0.5;
				if (st || uu < cellsz.x || uu > (ncell - 1.0) * cellsz.x || blind) col = mix(col, b_accent * tex * 1.5, 0.8);
			} else if (pattern == 3) {
				// kolorowe pola po ociepleniu
				float blk = hash21(floor(cell / vec2(3.0, 2.0)) + b_seed);
				if (blk > 0.55) col = mix(col, b_accent * tex * 1.55, 0.85);
				else if (blk > 0.3) col = mix(col, mix(b_accent, vec3(0.9, 0.88, 0.8), 0.6) * tex * 1.5, 0.8);
			} else if (pattern == 4) {
				// dwa dolne piętra ciemniejsze, pas pod dachem
				if (cell.y < 2.0 || cell.y > floors - 1.5) col = mix(col, b_accent * tex * 1.45, 0.8);
			}
			// spoiny płyt (po ociepleniu prawie niewidoczne)
			float seam = min(min(f.x, 1.0 - f.x) * cellsz.x, min(f.y, 1.0 - f.y) * cellsz.y);
			float seam_k = pattern >= 3 ? 0.9 : 0.5;
			col *= mix(seam_k, 1.0, smoothstep(0.0, 0.045, seam));
			if (blind && pattern < 3) {
				// szczyt: płyty co 1,2 m w pionie
				float s2 = min(fract(v / 1.5), 1.0 - fract(v / 1.5)) * 1.5;
				col *= mix(0.72, 1.0, smoothstep(0.0, 0.03, s2));
			}
		} else if (style == 1) {
			// odpadający tynk: spod spodu wychodzi cegła
			float dmg = texture(noise_tex, vec2(u, v) * 0.045 + b_seed * 1.3).r * 0.7 + texture(noise_tex, vec2(u, v) * 0.17 + 0.4).r * 0.3;
			float th = 1.0 - alt_amount * 0.62;
			float brick = smoothstep(th - 0.012, th + 0.012, dmg + (ground ? 0.07 : 0.0));
			float edge = smoothstep(th - 0.05, th - 0.012, dmg + (ground ? 0.07 : 0.0)) * (1.0 - brick);
			// gzymsy między piętrami i boniowanie parteru
			float corn = smoothstep(0.925, 0.935, f.y);
			col = mix(col, b_accent * tex * 1.45, corn * 0.85);
			col *= 1.0 - smoothstep(0.9, 0.925, f.y) * (1.0 - corn) * 0.4;
			col *= 1.0 + corn * smoothstep(0.985, 0.95, f.y) * 0.12;
			if (ground) {
				col *= 0.74;
				float groove = abs(fract(v / 0.42) - 0.5);
				col *= mix(0.6, 1.0, smoothstep(0.02, 0.06, groove));
			}
			vec3 bk = texture(alt_tex, vec2(u, v) * 0.33).rgb * vec3(0.95, 0.8, 0.72);
			// ściana ogniowa (ślepa): prawie sama cegła, tynk tylko w łatach
			if (blind) { brick = max(brick, smoothstep(0.34, 0.4, dmg)); edge *= 0.5; }
			col = mix(col, bk, brick);
			col *= 1.0 - edge * 0.45;
			if (brick > 0.5) nmap = vec3(0.5, 0.5, 1.0);
		} else if (style == 3) {
			// filary między oknami
			float pil = smoothstep(0.075, 0.065, min(f.x, 1.0 - f.x));
			col *= 1.0 + pil * 0.12;
			col *= 1.0 - smoothstep(0.075, 0.11, min(f.x, 1.0 - f.x)) * smoothstep(0.16, 0.11, min(f.x, 1.0 - f.x)) * 0.25;
		} else if (style == 4) {
			float line = smoothstep(0.03, 0.0, abs(f.y - 0.5));
			vec3 neon = mod(cell.y, 2.0) > 0.5 ? b_accent : vec3(0.17, 0.9, 1.0);
			float flick = 0.75 + 0.25 * step(0.08, fract(sin(floor(TIME * 9.0) * 12.7 + cell.y) * 43.7));
			emi = neon * line * (0.5 + night * 3.5) * flick;
			col = mix(col * 0.5, neon, line * 0.6);
		} else {
			// urząd: pasy podokienne w kolorze
			if (f.y < 0.3 && grid) col = mix(col, b_accent * tex * 1.3, 0.85);
		}
		// zacieki spod dachu i spod parapetów, brud przy ziemi
		float streak = smoothstep(0.45, 0.8, texture(noise_tex, vec2(u * 0.35, v * 0.02) + b_seed).r);
		col *= 1.0 - streak * (pattern >= 3 ? 0.14 : 0.3);
		col *= 0.8 + nz2 * 0.36;
		float top = b_size.y > 250.0 ? 99.0 : b_size.y - v;
		col *= 1.0 - smoothstep(1.6, 0.0, top) * 0.25 * (0.5 + nz);
		// cokół, a w blokach także okienka piwnic
		if (v < 0.75) {
			float pl = smoothstep(0.75, 0.72, v);
			col = mix(col, tex * vec3(0.3, 0.3, 0.31), pl * 0.85);
			if (style == 0 && grid && !blind && abs(f.x - 0.5) * cellsz.x < 0.42 && v > 0.22 && v < 0.56) {
				float bars = step(0.5, fract(u * 9.0));
				col = mix(vec3(0.015), vec3(0.2, 0.2, 0.21), bars * 0.6);
				flat_n = true;
			}
		}
		col *= mix(0.5, 1.0, smoothstep(0.0, 1.3, v + nz * 0.7));
		// --- otwory
		vec2 a = wr.xy * cellsz;
		vec2 b = wr.zw * cellsz;
		bool in_open = kind > 0 && p.x > a.x && p.x < b.x && p.y > a.y && p.y < b.y;
		float dead = step(1.0 - b_dead, rnd);
		float lit = step(rnd, ground ? 0.14 : 0.4) * (1.0 - dead);
		float fcode = xface ? (n.x > 0.0 ? 3.0 : 4.0) : (n.z > 0.0 ? 1.0 : 2.0);
		float party = (b_trap.z > 0.5 && abs(fcode - b_trap.z) < 0.5 && abs(cell.x - b_trap.x) < 0.5 && abs(cell.y - b_trap.y) < 0.5) ? 1.0 : 0.0;
		if (party > 0.5) { lit = 1.0; dead = 0.0; }
		float tv = step(0.8, rnd2) * (1.0 - party);
		vec3 light_col = mix(vec3(1.0, 0.66, 0.34), vec3(1.0, 0.86, 0.62), rnd2);
		if (tv > 0.5) light_col = vec3(0.4, 0.58, 1.0) * (0.55 + 0.45 * sin(TIME * (3.0 + rnd * 5.0) + rnd * 40.0));
		if (party > 0.5) {
			float beat = 0.5 + 0.5 * sin(TIME * 7.33 + rnd * 6.0);
			light_col = mix(vec3(0.75, 0.1, 1.0), vec3(1.0, 0.1, 0.35), beat) * (0.7 + 0.5 * beat);
		}
		if (kind > 0 && !in_open) {
			// parapet i cień pod nim, zaciek pod parapetem
			if (kind != 3 && p.y < a.y && p.y > a.y - 0.06 && p.x > a.x - 0.07 && p.x < b.x + 0.07) {
				col = vec3(0.62, 0.62, 0.6) * (0.75 + nz * 0.35);
				flat_n = true;
			} else if (kind != 3 && p.y < a.y - 0.06 && p.y > a.y - 0.16 && p.x > a.x - 0.05 && p.x < b.x + 0.05) {
				col *= 0.62 + 0.38 * smoothstep(a.y - 0.07, a.y - 0.16, p.y);
			} else if (kind != 3 && p.y < a.y - 0.16 && p.x > a.x && p.x < b.x) {
				col *= 1.0 - 0.28 * smoothstep(0.5, 0.8, texture(noise_tex, vec2(u * 0.9, v * 0.05)).r) * smoothstep(a.y - 1.2, a.y - 0.16, p.y);
			}
			if (style == 1) {
				// opaska wokół okna
				if (p.x > a.x - 0.16 && p.x < b.x + 0.16 && p.y > a.y - 0.06 && p.y < b.y + 0.2) col = mix(col, b_accent * tex * 1.5, 0.6);
				if (p.y > b.y + 0.14 && p.y < b.y + 0.24 && p.x > a.x - 0.24 && p.x < b.x + 0.24) col *= 1.12;
			}
		}
		if (in_open) {
			flat_n = true;
			vec3 hp;
			int surf;
			float t = box_trace(p, a, b, slope, recess, hp, surf);
			vec2 q = (hp.xy - a) / (b - a);
			if (kind == 2) {
				// ---- loggia: ściany pomalowane po swojemu, w głębi drzwi balkonowe i okno
				vec3 lc = b_accent * (0.75 + nz * 0.3);
				lc = mix(lc, vec3(0.86, 0.84, 0.78), step(0.6, rnd2));
				lc = mix(lc, mix(vec3(0.55, 0.7, 0.62), vec3(0.85, 0.7, 0.5), rnd), step(0.86, rnd3));
				lc *= tex * 1.5;
				if (surf == 1) col = lc * 0.66;
				else if (surf == 2) col = vec3(0.5, 0.5, 0.48) * tex * 0.8;
				else if (surf == 3) col = vec3(0.34, 0.33, 0.32) * (0.8 + nz * 0.3);
				else {
					col = lc * 0.8;
					// drzwi balkonowe (z lewej) i okno
					bool door = q.x > 0.1 && q.x < 0.36 && q.y < 0.84;
					bool win = q.x > 0.36 && q.x < 0.9 && q.y > 0.34 && q.y < 0.84;
					if (door || win) {
						vec2 w0 = door ? vec2(0.1, 0.0) : vec2(0.36, 0.34);
						vec2 w1 = door ? vec2(0.36, 0.84) : vec2(0.9, 0.84);
						vec2 qq = (q - w0) / (w1 - w0);
						vec2 dm = min(qq, 1.0 - qq) * (w1 - w0) * (b - a);
						if (min(dm.x, dm.y) < 0.06 || (!door && abs(qq.x - 0.5) * (w1.x - w0.x) * (b.x - a.x) < 0.03)) {
							col = rnd2 > 0.5 ? vec3(0.34, 0.24, 0.15) : vec3(0.84, 0.85, 0.84);
						} else {
							float cur = step(0.35, rnd) * (0.6 + 0.4 * sin(qq.x * 40.0 + rnd * 9.0) * 0.3);
							vec3 gl = mix(vec3(0.04, 0.05, 0.065), vec3(0.72, 0.7, 0.64) * (0.6 + rnd2 * 0.4), cur * 0.75);
							if (dead > 0.5) gl = vec3(0.02);
							col = gl * (1.0 - night * 0.6);
							rough = 0.12;
							spec = 0.6;
							emi = light_col * lit * night * (0.55 + cur * 0.5);
						}
					}
				}
				// w głębi loggii jest ciemniej
				col *= mix(1.0, 0.62, clamp(t / recess, 0.0, 1.0));
			} else if (surf != 0) {
				// ---- ościeże (grubość muru): góra w cieniu, parapet jasny
				col = base * (surf == 2 ? 0.42 : (surf == 3 ? 0.95 : 0.6));
			} else if (kind == 3) {
				// ---- luksfery klatki schodowej
				vec2 gq = fract(q * vec2(4.0, cellsz.y / 0.19 * (wr.w - wr.y)));
				float mort = min(min(gq.x, 1.0 - gq.x), min(gq.y, 1.0 - gq.y));
				vec3 gb = vec3(0.16, 0.21, 0.2) * (0.7 + 0.6 * hash21(floor(q * vec2(4.0, 60.0)) + cell));
				col = mix(vec3(0.36, 0.36, 0.34), gb, smoothstep(0.04, 0.1, mort));
				rough = 0.22;
				spec = 0.7;
				// nie na każdym piętrze świeci żarówka
				float bulb = step(0.3, hash21(vec2(cell.y * 3.1, b_seed + cell.x)));
				emi = vec3(1.0, 0.8, 0.46) * night * 0.2 * bulb * smoothstep(0.04, 0.1, mort) * (0.5 + 0.5 * hash21(vec2(cell.y, b_seed)));
			} else if (kind == 4) {
				// ---- okno hali: drobne szybki w stalowej kratownicy, część wybita
				vec2 pq = q * vec2(5.0, 4.0);
				vec2 gq = fract(pq);
				float bar = min(min(gq.x, 1.0 - gq.x) * 0.2 * (b.x - a.x), min(gq.y, 1.0 - gq.y) * 0.25 * (b.y - a.y));
				float pr = hash21(floor(pq) + cell * 7.0 + b_seed);
				if (bar < 0.03) { col = vec3(0.1, 0.085, 0.075) * (0.8 + nz * 0.4); rough = 0.7; }
				else if (pr < b_dead * 0.7) { col = vec3(0.012); rough = 1.0; }
				else if (pr < b_dead * 0.7 + 0.12) { col = vec3(0.3, 0.24, 0.16) * (0.7 + nz * 0.5); rough = 0.9; }
				else {
					col = mix(vec3(0.05, 0.065, 0.08), vec3(0.16, 0.2, 0.22), pr) * (0.6 + 0.4 * q.y);
					rough = 0.2;
					spec = 0.6;
					metal = 0.2;
				}
			} else {
				// ---- okno: rama, szyba, firanki, a za nimi pokój
				vec2 dm = min(q, 1.0 - q) * (b - a);
				float parts = (b.x - a.x) > 1.7 ? 3.0 : 2.0;
				float mull = abs(fract(q.x * parts + 0.5) - 0.5) / parts * (b.x - a.x);
				float fw = style == 1 ? 0.075 : 0.06;
				float frame_t = step(0.5, rnd2);
				vec3 frame_c = style == 3 ? vec3(0.12, 0.1, 0.09) : mix(vec3(0.86, 0.87, 0.86), vec3(0.33, 0.23, 0.14), frame_t * step(0.25, b_dead + (style == 1 ? 0.3 : 0.0) + rnd * 0.3));
				bool transom = style == 1 && abs(q.y - 0.7) * (b.y - a.y) < 0.03;
				if (min(dm.x, dm.y) < fw || mull < 0.028 || transom) {
					col = frame_c * (0.8 + nz * 0.3);
					rough = 0.55;
				} else if (dead > 0.5) {
					// pustostan: dykta albo wybita szyba
					col = rnd2 > 0.5 ? vec3(0.32, 0.25, 0.17) * (0.7 + nz * 0.5) : vec3(0.012);
					rough = 0.92;
				} else {
					// zasłony/firanka 10 cm za szybą
					vec2 qc = (hp.xy - slope * 0.1 - a) / (b - a);
					float ctype = (style == 1 && ground) ? 4.0 : floor(rnd3 * 5.0);
					float cur = 0.0;
					vec3 cc = vec3(0.9, 0.89, 0.85);
					float fold = 0.82 + 0.18 * sin(qc.x * 70.0 + rnd * 20.0);
					if (ctype < 1.0) { cur = 0.62; cc *= fold; }
					else if (ctype < 2.0) {
						float sd = step(qc.x, 0.2 + rnd * 0.12) + step(0.8 - rnd2 * 0.12, qc.x);
						cur = clamp(sd, 0.0, 1.0);
						cc = mix(vec3(0.55, 0.3, 0.26), vec3(0.3, 0.42, 0.5), rnd) * fold;
						cur = max(cur, 0.5 * step(0.4, rnd2));
						if (sd < 0.5) cc = vec3(0.9, 0.89, 0.85) * fold;
					}
					else if (ctype < 3.0) { cur = step(1.0 - (0.2 + rnd2 * 0.65), qc.y); cc = mix(vec3(0.82, 0.78, 0.68), vec3(0.5, 0.52, 0.56), rnd); }
					else if (ctype < 4.0) { cur = 0.85 * step(0.35, fract(qc.y * 26.0)) * step(1.0 - (0.4 + rnd * 0.6), qc.y); cc = vec3(0.8, 0.8, 0.78); }
					if (qc.x < 0.0 || qc.x > 1.0 || qc.y < 0.0 || qc.y > 1.0) cur = 0.0;
					float glow;
					vec2 rp = vec2(hp.x, hp.y);
					vec3 rc = room(rp, cellsz, slope, rnd, rnd2, glow);
					// kwiatek na parapecie
					float pot = step(0.72, rnd) * smoothstep(0.1, 0.07, length((q - vec2(0.2 + rnd2 * 0.6, 0.08)) * (b - a) * vec2(1.0, 0.75)));
					rc = mix(rc, vec3(0.16, 0.3, 0.12), pot);
					vec3 inside = mix(rc, cc, cur);
					float day = 1.0 - night;
					col = inside * mix(0.05, 0.3, cur) * (0.35 + 0.65 * day);
					emi = inside * day * mix(0.04, 0.0, cur);
					emi += (rc * glow * (1.0 - cur) + cc * cur * 0.75) * light_col * lit * night * (1.15 + party * 0.9);
					rough = 0.07;
					spec = 0.75;
				}
			}
		}
		ALBEDO = col;
		ROUGHNESS = rough;
		METALLIC = metal;
		SPECULAR = spec;
		EMISSION = emi;
		if (!flat_n) { NORMAL_MAP = nmap; NORMAL_MAP_DEPTH = 0.8; }
	}
}
"""
