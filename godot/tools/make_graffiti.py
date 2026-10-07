#!/usr/bin/env python3
"""Generuje tekstury graffiti i wyblakłych napisów (PNG z przezroczystością) do assets/graffiti/.
Wszystko rysowane od zera czcionkami z assets/fonts (licencje OFL/Apache) — bez cudzych grafik."""
import os, random, math, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'assets', 'fonts')
OUT = os.path.join(ROOT, 'assets', 'graffiti')
os.makedirs(OUT, exist_ok=True)
F = {'sedg': 'sedgwick.ttf', 'spray': 'spray.ttf', 'marker': 'marker.ttf', 'bebas': 'bebas.ttf', 'oswald': 'oswald.ttf', 'barlowc': 'barlowc.ttf'}


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, F[name]), size)


def safe(fnt, txt):
    """czcionki „marker” i „spray” nie mają polskich znaków — wtedy bierzemy Sedgwick"""
    return fnt if all(ord(c) < 128 for c in txt) or fnt in ('sedg', 'bebas', 'oswald', 'barlowc') else 'sedg'


def noise(size, scale, seed):
    """miękki szum 0..255 (rozmyte losowe piksele)"""
    rnd = random.Random(seed)
    w, h = size
    small = Image.new('L', (max(2, w // scale), max(2, h // scale)))
    small.putdata([rnd.randint(0, 255) for _ in range(small.size[0] * small.size[1])])
    return small.resize(size, Image.BICUBIC)


def speckle(size, seed, density=0.5):
    rnd = random.Random(seed)
    im = Image.new('L', size)
    im.putdata([255 if rnd.random() < density else 0 for _ in range(size[0] * size[1])])
    return im


def text_mask(txt, fnt, size, pos=None, stroke=0, spacing=4, align='center', angle=0.0):
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    box = d.multiline_textbbox((0, 0), txt, font=fnt, stroke_width=stroke, spacing=spacing, align=align)
    tw, th = box[2] - box[0], box[3] - box[1]
    if pos is None:
        pos = ((size[0] - tw) // 2 - box[0], (size[1] - th) // 2 - box[1])
    d.multiline_text(pos, txt, font=fnt, fill=255, stroke_width=stroke, stroke_fill=255, spacing=spacing, align=align)
    if angle:
        m = m.rotate(angle, resample=Image.BICUBIC)
    return m


def fit_font(name, txt, size, margin=0.86, stroke=0, spacing=4):
    lo, hi = 10, 900
    d = ImageDraw.Draw(Image.new('L', (8, 8)))
    while hi - lo > 2:
        mid = (lo + hi) // 2
        b = d.multiline_textbbox((0, 0), txt, font=font(name, mid), stroke_width=stroke, spacing=spacing)
        if b[2] - b[0] <= size[0] * margin and b[3] - b[1] <= size[1] * margin:
            lo = mid
        else:
            hi = mid
    return font(name, lo)


def sprayed(mask, seed, soft=1.6, grain=0.25, halo=0.22):
    """krawędź jak ze sprayu: lekko miękka, ziarnista, z mgiełką farby dookoła"""
    size = mask.size
    core = mask.filter(ImageFilter.GaussianBlur(soft))
    core = core.point(lambda v: 0 if v < 70 else min(255, int((v - 70) * 2.2)))
    if grain > 0:
        g = ImageChops.multiply(noise(size, 3, seed), noise(size, 9, seed + 1)).point(lambda v: 255 - int(grain * 255 * (1.0 - v / 160.0)) if v < 160 else 255)
        core = ImageChops.multiply(core, g)
    if halo > 0:
        h = mask.filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * halo))
        h = ImageChops.multiply(h, speckle(size, seed + 2, 0.55).filter(ImageFilter.GaussianBlur(0.6)))
        core = ImageChops.lighter(core, h)
    return core


def drips(mask, seed, count=6, color_mask=None):
    """zacieki farby spod dolnych krawędzi liter"""
    rnd = random.Random(seed)
    w, h = mask.size
    out = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(out)
    px = mask.load()
    for _ in range(count * 4):
        if count <= 0:
            break
        x = rnd.randint(int(w * 0.08), int(w * 0.92))
        ys = [y for y in range(h - 2, 0, -3) if px[x, y] > 200]
        if not ys:
            continue
        y0 = ys[0]
        ln = rnd.randint(int(h * 0.04), int(h * 0.2))
        wd = rnd.choice([2, 3, 3, 4])
        d.line([(x, y0 - 2), (x, min(h - 3, y0 + ln))], fill=255, width=wd)
        d.ellipse([x - wd, min(h - 3, y0 + ln) - wd, x + wd, min(h - 3, y0 + ln) + wd], fill=255)
        count -= 1
    return out.filter(ImageFilter.GaussianBlur(0.7))


def colorize(alpha, rgb):
    im = Image.new('RGBA', alpha.size, rgb + (0,))
    im.putalpha(alpha)
    return im


def gradient(size, top, bottom):
    w, h = size
    g = Image.new('RGB', (1, h))
    g.putdata([tuple(int(top[i] + (bottom[i] - top[i]) * y / (h - 1)) for i in range(3)) for y in range(h)])
    return g.resize(size)


def save(im, name, meta):
    # przezroczyste piksele dostają kolor sąsiadów, żeby mipmapy nie robiły ciemnych obwódek
    rgb = im.convert('RGB').filter(ImageFilter.GaussianBlur(4))
    base = Image.composite(im.convert('RGB'), rgb, im.split()[3].point(lambda v: 255 if v > 8 else 0))
    out = base.convert('RGBA')
    out.putalpha(im.split()[3])
    out.save(os.path.join(OUT, name + '.png'), optimize=True)
    META[name] = meta


META = {}
PAL = [(232, 232, 228), (214, 48, 44), (52, 120, 226), (18, 18, 20), (242, 204, 40), (62, 190, 96), (236, 96, 190), (250, 130, 30), (120, 60, 200)]


def tag(name, txt, seed, color=None, fnt='marker'):
    rnd = random.Random(seed)
    size = (512, 256)
    f = fit_font(safe(fnt, txt), txt, size, 0.8)
    m = text_mask(txt, f, size, angle=rnd.uniform(-7, 7))
    d = ImageDraw.Draw(m)
    # zawijas: podkreślenie albo gwiazdka
    if rnd.random() < 0.6:
        y = rnd.randint(205, 228)
        pts = [(60 + i * 20, y + int(6 * math.sin(i * 0.9 + seed))) for i in range(20)]
        d.line(pts, fill=255, width=rnd.choice([5, 6, 8]), joint='curve')
    a = sprayed(m, seed, soft=1.2, grain=0.3, halo=0.16)
    a = ImageChops.lighter(a, drips(m, seed, rnd.choice([0, 1, 2, 3])))
    c = color or rnd.choice(PAL)
    save(colorize(a.point(lambda v: int(v * 0.92)), c), name, {'w': 2, 'h': 1, 'kind': 'tag'})


def throwup(name, txt, seed, fill=None, edge=None):
    rnd = random.Random(seed)
    size = (1024, 512)
    stroke = 16
    f = fit_font('sedg', txt, size, 0.8, stroke)
    inner = text_mask(txt, f, size)
    outer = text_mask(txt, f, size, stroke=stroke)
    fill = fill or rnd.choice(PAL)
    edge = edge or rnd.choice([(14, 14, 16), (240, 240, 236)])
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    # cień bryły
    sh = ImageChops.offset(outer, 14, 12)
    im = Image.alpha_composite(im, colorize(sprayed(sh, seed + 5, 1.5, 0.15, 0.0).point(lambda v: int(v * 0.75)), (10, 10, 12)))
    im = Image.alpha_composite(im, colorize(sprayed(outer, seed, 1.4, 0.12, 0.2), edge))
    g = gradient(size, tuple(min(255, int(c * 1.25) + 20) for c in fill), tuple(int(c * 0.7) for c in fill)).convert('RGBA')
    g.putalpha(sprayed(inner, seed + 1, 1.0, 0.35, 0.0))
    im = Image.alpha_composite(im, g)
    # błyski
    hl = Image.new('L', size, 0)
    hd = ImageDraw.Draw(hl)
    for _ in range(9):
        x, y = rnd.randint(120, 900), rnd.randint(130, 330)
        hd.ellipse([x, y, x + rnd.randint(8, 20), y + rnd.randint(4, 9)], fill=255)
    hl = ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(1.5)), inner)
    im = Image.alpha_composite(im, colorize(hl, (255, 255, 255)))
    dr = drips(outer, seed, rnd.randint(2, 6))
    im = Image.alpha_composite(im, colorize(dr, edge))
    save(im, name, {'w': 2, 'h': 1, 'kind': 'throw'})


def piece(name, txt, seed, c1, c2, edge=(12, 12, 14), cloud=None):
    rnd = random.Random(seed)
    size = (1536, 768)
    stroke = 20
    f = fit_font('sedg', txt, size, 0.74, stroke, spacing=-10)
    inner = text_mask(txt, f, size, spacing=-10)
    outer = text_mask(txt, f, size, stroke=stroke, spacing=-10)
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    if cloud:
        cl = outer.filter(ImageFilter.MaxFilter(31)).filter(ImageFilter.GaussianBlur(26)).point(lambda v: 255 if v > 60 else 0).filter(ImageFilter.GaussianBlur(3))
        im = Image.alpha_composite(im, colorize(sprayed(cl, seed + 9, 2.0, 0.3, 0.25).point(lambda v: int(v * 0.9)), cloud))
    # bryła 3D: kilka przesuniętych kopii
    for k in range(18, 0, -3):
        sh = ImageChops.offset(outer, k, k)
        im = Image.alpha_composite(im, colorize(sh.filter(ImageFilter.GaussianBlur(0.8)), tuple(int(c * 0.35) for c in c2)))
    im = Image.alpha_composite(im, colorize(sprayed(outer, seed, 1.2, 0.08, 0.2), edge))
    g = gradient(size, c1, c2).convert('RGBA')
    g.putalpha(sprayed(inner, seed + 1, 0.9, 0.25, 0.0))
    im = Image.alpha_composite(im, g)
    # pasek światła u góry liter
    top = ImageChops.subtract(inner, ImageChops.offset(inner, 0, 10)).filter(ImageFilter.GaussianBlur(1.2))
    im = Image.alpha_composite(im, colorize(top.point(lambda v: int(v * 0.8)), (255, 255, 255)))
    # gwiazdki / kropki dookoła
    ex = Image.new('L', size, 0)
    ed = ImageDraw.Draw(ex)
    for _ in range(14):
        x, y = rnd.randint(40, size[0] - 40), rnd.randint(40, size[1] - 40)
        r = rnd.randint(4, 12)
        ed.ellipse([x - r, y - r, x + r, y + r], fill=255)
    ex = ImageChops.subtract(ex, outer.filter(ImageFilter.MaxFilter(15)))
    im = Image.alpha_composite(im, colorize(sprayed(ex, seed + 3, 1.0, 0.2, 0.3), c1))
    im = Image.alpha_composite(im, colorize(drips(outer, seed, rnd.randint(3, 7)), edge))
    save(im, name, {'w': 2, 'h': 1, 'kind': 'piece'})


def slogan(name, txt, seed, color, fnt='spray', size=(1024, 384)):
    rnd = random.Random(seed)
    f = fit_font(safe(fnt, txt), txt, size, 0.86)
    m = text_mask(txt, f, size, angle=rnd.uniform(-2.5, 2.5))
    a = sprayed(m, seed, 1.4, 0.3, 0.2)
    a = ImageChops.lighter(a, drips(m, seed, rnd.randint(1, 5)))
    save(colorize(a.point(lambda v: int(v * 0.9)), color), name, {'w': size[0] / size[1], 'h': 1, 'kind': 'slogan'})


def ghost(name, lines, seed, color, frame=True, size=(1024, 1024), fnt='bebas', keep=0.8):
    """wyblakły malowany napis (reklama, hasło) — farba zeszła razem z tynkiem"""
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    n = len(lines)
    pad = 70
    if frame:
        d.rectangle([24, 24, size[0] - 24, size[1] - 24], outline=255, width=14)
        d.rectangle([48, 48, size[0] - 48, size[1] - 48], outline=255, width=4)
    row = (size[1] - pad * 2) / n
    for i, ln in enumerate(lines):
        f = fit_font(fnt, ln, (size[0] - pad * 2, row), 0.94)
        b = d.textbbox((0, 0), ln, font=f)
        d.text(((size[0] - (b[2] - b[0])) / 2 - b[0], pad + row * i + (row - (b[3] - b[1])) / 2 - b[1]), ln, font=f, fill=255)
    er = ImageChops.multiply(noise(size, 40, seed), noise(size, 7, seed + 1))
    er = er.point(lambda v: 0 if v < int(255 * (1.0 - keep) * 0.42) else min(255, int(v * 4.5) + 40))
    er = ImageChops.multiply(er, noise(size, 2, seed + 2).point(lambda v: 170 + v // 3))
    a = ImageChops.multiply(m.filter(ImageFilter.GaussianBlur(0.8)), er).point(lambda v: int(v * 0.86))
    save(colorize(a, color), name, {'w': size[0] / size[1], 'h': 1, 'kind': 'ghost'})


def number(name, txt, seed, color=(28, 28, 30)):
    size = (512, 512)
    f = fit_font('bebas', txt, size, 0.9)
    m = text_mask(txt, f, size)
    er = ImageChops.multiply(noise(size, 30, seed), noise(size, 5, seed + 1)).point(lambda v: 60 if v < 30 else min(255, 120 + v * 2))
    a = ImageChops.multiply(m.filter(ImageFilter.GaussianBlur(0.7)), er).point(lambda v: int(v * 0.92))
    save(colorize(a, color), name, {'w': 1, 'h': 1, 'kind': 'number'})


def stain(name, seed, color=(20, 18, 16)):
    """zaciek / plama na murze albo chodniku"""
    size = (512, 512)
    a = ImageChops.multiply(noise(size, 90, seed), noise(size, 24, seed + 1))
    a = ImageChops.multiply(a, noise(size, 6, seed + 2).point(lambda v: 120 + v // 2))
    rad = Image.new('L', size, 0)
    ImageDraw.Draw(rad).ellipse([40, 40, 472, 472], fill=255)
    rad = rad.filter(ImageFilter.GaussianBlur(70))
    a = ImageChops.multiply(a.point(lambda v: 0 if v < 26 else min(255, (v - 26) * 5)), rad)
    save(colorize(a.point(lambda v: int(v * 0.75)), color), name, {'w': 1, 'h': 1, 'kind': 'stain'})


def poster(name, seed, paper, ink, head, lines, accent=None, strips=False, size=(384, 544)):
    """plakat / ogłoszenie: papier, nagłówek, drobny druk, czasem paski z numerem do oderwania"""
    rnd = random.Random(seed)
    w, h = size
    im = Image.new('RGB', size, paper)
    d = ImageDraw.Draw(im)
    if accent:
        d.rectangle([0, 0, w, int(h * 0.3)], fill=accent)
    hf = fit_font('bebas', head, (w - 40, int(h * 0.26)), 0.96, spacing=0)
    hb = d.multiline_textbbox((0, 0), head, font=hf, spacing=0, align='center')
    d.multiline_text(((w - (hb[2] - hb[0])) / 2 - hb[0], int(h * 0.04) - hb[1] + (h * 0.24 - (hb[3] - hb[1])) / 2), head, font=hf, fill=(paper if accent else ink), spacing=0, align='center')
    y = int(h * 0.36)
    for ln in lines:
        big = ln.startswith('!')
        t = ln[1:] if big else ln
        f = fit_font('oswald' if big else 'barlowc', t, (w - 50, 64 if big else 34), 0.98)
        b = d.textbbox((0, 0), t, font=f)
        d.text(((w - (b[2] - b[0])) / 2 - b[0], y - b[1]), t, font=f, fill=ink)
        y += (b[3] - b[1]) + (22 if big else 14)
    gone = []
    if strips:
        sy = int(h * 0.8)
        d.line([(0, sy), (w, sy)], fill=ink, width=2)
        n = 8
        for i in range(n):
            x = int(w * i / n)
            d.line([(x, sy), (x, h)], fill=ink, width=1)
            if rnd.random() < 0.35:
                gone.append([x + 1, sy + 2, int(w * (i + 1) / n) - 1, h])
    # zabrudzenia, zagniecenia, podarte rogi
    dirt = ImageChops.multiply(noise(size, 90, seed), noise(size, 30, seed + 1)).filter(ImageFilter.GaussianBlur(6)).point(lambda v: 222 + int(v * 0.16))
    im = ImageChops.multiply(im, Image.merge('RGB', (dirt, dirt, dirt)))
    a = Image.new('L', size, 255)
    ad = ImageDraw.Draw(a)
    for cx, cy in [(0, 0), (w, 0), (0, h), (w, h)]:
        if rnd.random() < 0.45:
            r = rnd.randint(18, 60)
            ad.polygon([(cx, cy), (cx + (r if cx == 0 else -r), cy), (cx, cy + (r if cy == 0 else -r))], fill=0)
    for g in gone:
        ad.rectangle(g, fill=0)
    out = im.convert('RGBA')
    out.putalpha(a)
    out.save(os.path.join(OUT, name + '.png'), optimize=True)
    META[name] = {'w': w / h, 'h': 1, 'kind': 'poster'}


random.seed(7)
POSTERS = [
    ((232, 220, 192), (120, 26, 26), "CONCERT", ["!THE SLAGHEAP BAND", "school gym, PS 12", "Saturday 7 PM", "free entry"], None, False),
    ((240, 236, 224), (20, 22, 26), "LOST\nDOG", ["!answers to REKS", "ginger mutt, red collar", "last seen by the pavilion", "REWARD"], None, True),
    ((232, 208, 64), (20, 22, 26), "CARS\nWANTED", ["!CASH ON THE SPOT", "running, crashed, no papers", "we come to you"], None, True),
    ((216, 220, 228), (28, 62, 138), "ELECTIONS", ["!Your vote counts", "polling place: Hutnik Culture House", "Sunday 7:00–21:00"], (28, 62, 138), False),
    ((232, 224, 208), (176, 72, 44), "0% LOAN", ["!NO CHECKS • NO QUESTIONS", "decision in 15 minutes", "12 Hutnicza St"], (176, 72, 44), False),
    ((26, 20, 32), (255, 60, 208), "DISCO\nNEON", ["!FRIDAY / SATURDAY", "NEON club • from 9 PM", "ladies free before 10"], None, False),
    ((240, 240, 232), (36, 64, 46), "TUTORING", ["!MATHS • PHYSICS", "cheap, I come to you", "engineering student"], None, True),
    ((216, 208, 184), (58, 54, 48), "RUBBLE\nREMOVAL", ["!SKIPS 3–7 m³", "fast and cheap", "Saturdays too"], None, True),
    ((201, 196, 184), (138, 28, 28), "HUTNIK\n— STAL", ["!DERBY", "Sunday 3 PM", "stadium on Robotnicza St", "everyone to the match!"], (138, 28, 28), False),
    ((236, 232, 220), (18, 18, 20), "WANTED", ["!POLICE APPEAL", "male, about 30", "drug dealing", "3rd Precinct, call 997"], (18, 18, 20), False),
    ((244, 240, 228), (30, 30, 34), "FOR SALE", ["!FIAT 126p", "1988, garage kept", "price negotiable"], None, True),
    ((226, 232, 226), (40, 90, 60), "ROOM\nTO LET", ["!BLOCK 9, 3rd floor", "working person only", "no addictions"], None, True),
    ((250, 246, 230), (190, 30, 30), "CIRCUS", ["!“ARENA”", "field by the pitch", "3 days only!", "acrobats • clowns • horses"], (250, 200, 40), False),
    ((228, 228, 232), (20, 20, 24), "WARNING", ["!BASEMENT BREAK-INS", "keep the doors locked", "estate management"], None, False),
]
for i, (paper, ink, head, lines, accent, strips) in enumerate(POSTERS):
    poster('poster_%02d' % i, 800 + i, paper, ink, head, lines, accent, strips)

TAGS = ["DBS", "SKERO", "MZK", "HWK", "ZGR", "KSH", "1986", "STEEL", "BLOCKS", "JARA", "ELO", "LOVE", "PUNK", "HIP-HOP", "STAY", "SIWY", "HTK", "BLOCK 7", "RAP", "ESTATE", "NIGHT", "KUBA", "B7", "ZAGŁĘBIE"]
for i, t in enumerate(TAGS):
    tag('tag_%02d' % i, t, 100 + i, fnt=['marker', 'sedg', 'marker', 'spray'][i % 4])
THROWS = [("DBS", (236, 96, 190)), ("HWK", (52, 120, 226)), ("STEEL", (214, 48, 44)), ("KSH", (242, 204, 40)), ("MZK", (62, 190, 96)), ("ELO", (250, 130, 30)), ("B7", (232, 232, 228)), ("ZGR", (120, 60, 200))]
for i, (t, c) in enumerate(THROWS):
    throwup('throw_%02d' % i, t, 200 + i, fill=c)
piece('piece_00', "HUTNIK '86", 300, (255, 90, 80), (150, 20, 30), cloud=(240, 240, 235))
piece('piece_01', "STEEL\nBLOCKS", 301, (90, 190, 255), (30, 70, 190), cloud=(20, 20, 26))
piece('piece_02', "OLD MILL\nLIVES", 302, (245, 245, 240), (150, 150, 160), edge=(120, 20, 20))
piece('piece_03', "ZAGŁĘBIE", 303, (255, 220, 60), (240, 120, 20), cloud=(30, 30, 34))
piece('piece_04', "NO FUTURE", 304, (250, 215, 50), (200, 110, 10))
piece('piece_05', "DEAD MILL", 305, (235, 235, 235), (140, 140, 150), edge=(110, 15, 15))
piece('piece_06', "OLD TOWN", 306, (110, 230, 140), (20, 110, 60), cloud=(16, 26, 18))
piece('piece_07', "SIWY\nR.I.P.", 307, (240, 240, 240), (120, 120, 130))
piece('piece_08', "HUTNIK\nRULES", 308, (255, 255, 255), (214, 48, 44), edge=(20, 20, 90))
piece('piece_09', "BLOCK 7\nRUNS IT", 309, (250, 130, 30), (160, 50, 10), cloud=(236, 236, 230))
SLOG = [("SIWY WAS HERE", (18, 18, 20)), ("I LOVE YOU ANKA", (214, 48, 44)), ("TRUST NO ONE", (232, 232, 228)), ("TRUTH HURTS", (242, 204, 40)), ("STEEL IS US", (52, 120, 226)),
        ("END OF THE WORLD", (232, 232, 228)), ("NO WAY OUT", (214, 48, 44)), ("FREEDOM", (18, 18, 20)), ("BLOCKS RULE HERE", (232, 232, 228)), ("STAY HERE", (62, 190, 96)),
        ("WHERE IS SIWY?", (18, 18, 20)), ("THE MILL WON'T DIE", (214, 48, 44))]
for i, (t, c) in enumerate(SLOG):
    slogan('slogan_%02d' % i, t, 400 + i, c, fnt=['spray', 'marker', 'spray', 'sedg'][i % 4])
ghost('ghost_00', ["HUTNIK", "STEELWORKS", "1952"], 500, (60, 58, 56))
ghost('ghost_01', ["COAL", "STEEL", "WORK"], 501, (120, 40, 34))
ghost('ghost_02', ["DRINK", "MILK"], 502, (40, 70, 120))
ghost('ghost_03', ["CINEMA", "“STALOWNIK”"], 503, (70, 66, 60), size=(1024, 512))
ghost('ghost_04', ["LAUNDRY", "DRY CLEANING"], 504, (50, 80, 70), size=(1024, 512))
ghost('ghost_05', ["DEPARTMENT STORE", "HUTNIK"], 505, (110, 44, 36), size=(1024, 512))
ghost('ghost_06', ["A CLEAN ESTATE", "IS OUR PRIDE"], 506, (60, 60, 64), size=(1024, 384), frame=False)
for n in ["3", "5", "7", "9", "11", "13"]:
    number('num_' + n, n, 600 + int(n))
for i in range(4):
    stain('stain_%02d' % i, 700 + i * 7)
json.dump(META, open(os.path.join(OUT, 'graffiti.json'), 'w'), indent=1)
IMPORT = '''[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
'''
for n in META:
    p = os.path.join(OUT, n + '.png.import')
    if not os.path.exists(p):
        open(p, 'w').write(IMPORT)
print(len(META), 'tekstur')
