#!/usr/bin/env python3
"""Ikony przedmiotów rysowane od zera (PNG z przezroczystością) do assets/items/:
woreczki strunowe z towarem, worki i słoiki „luzem”, opakowane cegły, gotówka i drobiazgi ze sklepu."""
import os, random, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'items')
os.makedirs(OUT, exist_ok=True)
S = 4            # nadpróbkowanie
N = 192          # rozmiar docelowy
W = N * S
FONT = os.path.join(ROOT, 'assets', 'fonts', 'bebas.ttf')

IMPORT = '''[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
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


def canvas():
    return Image.new('RGBA', (W, W), (0, 0, 0, 0))


def P(v):
    return int(v * S)


def save(im, name):
    # miękki cień pod przedmiotem
    sh = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    a = im.split()[3].filter(ImageFilter.GaussianBlur(P(4)))
    shadow = Image.new('RGBA', (W, W), (0, 0, 0, 255))
    shadow.putalpha(a.point(lambda v: int(v * 0.45)))
    sh.alpha_composite(shadow, (P(2), P(4)))
    sh.alpha_composite(im)
    sh.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, name + '.png'), optimize=True)
    p = os.path.join(OUT, name + '.png.import')
    if not os.path.exists(p):
        open(p, 'w').write(IMPORT)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + ((c[3],) if len(c) > 3 else ())


# ---------------------------------------------------------------- zawartość
def buds(d, box, rnd, n=16):
    x0, y0, x1, y1 = box
    greens = [(78, 122, 44), (96, 140, 52), (62, 104, 38), (112, 150, 60), (84, 116, 40)]
    pts = []
    for i in range(n):
        x = rnd.uniform(x0 + P(8), x1 - P(8))
        y = y1 - P(8) - (rnd.random() ** 1.5) * (y1 - y0 - P(16))
        pts.append((y, x))
    for y, x in sorted(pts):
        r = rnd.uniform(P(9), P(15))
        c = rnd.choice(greens)
        for k in range(6):
            a = rnd.uniform(0, math.tau)
            rr = r * rnd.uniform(0.45, 0.75)
            cx, cy = x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.4
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=shade(c, rnd.uniform(0.75, 1.2)) + (255,))
        for k in range(5):
            a = rnd.uniform(0, math.tau)
            px, py = x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.5
            d.line([(px, py), (px + rnd.uniform(-P(3), P(3)), py - P(3))], fill=(206, 120, 40, 255), width=P(1))


def powder(d, box, rnd, col, grain=(0.92, 1.06), chunks=0):
    x0, y0, x1, y1 = box
    top = y0 + (y1 - y0) * 0.35
    pts = [(x0, y1)]
    n = 14
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = top + (y1 - top) * (0.55 * (2 * t - 1) ** 2) + rnd.uniform(-P(2), P(2))
        pts.append((x, y))
    pts.append((x1, y1))
    d.polygon(pts, fill=col + (255,))
    for i in range(500):
        x = rnd.uniform(x0, x1)
        y = rnd.uniform(top, y1)
        t = (x - x0) / (x1 - x0)
        if y < top + (y1 - top) * (0.55 * (2 * t - 1) ** 2):
            continue
        r = rnd.uniform(P(0.6), P(1.5))
        d.ellipse([x - r, y - r, x + r, y + r], fill=shade(col, rnd.uniform(*grain)) + (255,))
    for i in range(chunks):
        x = rnd.uniform(x0 + P(12), x1 - P(12))
        y = rnd.uniform(top + P(10), y1 - P(8))
        r = rnd.uniform(P(5), P(9))
        d.polygon([(x - r, y + r * 0.4), (x - r * 0.3, y - r), (x + r, y - r * 0.4), (x + r * 0.5, y + r)], fill=shade(col, rnd.uniform(0.96, 1.08)) + (255,))
        d.line([(x - r * 0.3, y - r), (x + r, y - r * 0.4)], fill=(255, 255, 255, 255), width=P(1))


def crystals(d, box, rnd, col=(150, 205, 250), n=34):
    x0, y0, x1, y1 = box
    for i in range(n):
        x = rnd.uniform(x0 + P(6), x1 - P(6))
        y = y1 - P(6) - (rnd.random() ** 1.6) * (y1 - y0) * 0.6
        r = rnd.uniform(P(5), P(11))
        a = rnd.uniform(0, math.tau)
        pts = []
        for k in range(rnd.choice([4, 5, 6])):
            aa = a + math.tau * k / 5 + rnd.uniform(-0.3, 0.3)
            rr = r * rnd.uniform(0.5, 1.0)
            pts.append((x + math.cos(aa) * rr, y + math.sin(aa) * rr * 0.8))
        c = shade(col, rnd.uniform(0.8, 1.2))
        d.polygon(pts, fill=c + (235,), outline=(235, 248, 255, 255))
        d.line([pts[0], pts[2]], fill=(255, 255, 255, 200), width=P(1))


CONTENT = {
    'dym': lambda d, b, r: buds(d, b, r),
    'szron': lambda d, b, r: powder(d, b, r, (232, 222, 190), chunks=2),
    'krysztal': lambda d, b, r: crystals(d, b, r),
    'snieg': lambda d, b, r: powder(d, b, r, (246, 247, 250), grain=(0.94, 1.02), chunks=5),
}


# ---------------------------------------------------------------- opakowania
def baggie(name, kind, seed, big=False):
    rnd = random.Random(seed)
    im = canvas()
    d = ImageDraw.Draw(im)
    x0, x1 = (P(46), P(146)) if not big else (P(30), P(162))
    y0, y1 = (P(28), P(170)) if not big else (P(22), P(174))
    r = P(10)
    # folia: lekko niebieskawa, półprzezroczysta
    d.rounded_rectangle([x0, y0, x1, y1], r, fill=(214, 226, 236, 120), outline=(240, 246, 250, 230), width=P(2))
    inner = canvas()
    di = ImageDraw.Draw(inner)
    CONTENT[kind](di, (x0 + P(5), y0 + P(40), x1 - P(5), y1 - P(5)), rnd)
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([x0 + P(3), y0 + P(26), x1 - P(3), y1 - P(3)], r, fill=255)
    im.paste(inner, (0, 0), Image.composite(inner.split()[3], Image.new('L', (W, W), 0), mask))
    d = ImageDraw.Draw(im)
    # zamknięcie strunowe
    d.rectangle([x0 + P(2), y0 + P(12), x1 - P(2), y0 + P(22)], fill=(196, 208, 220, 210))
    d.line([(x0 + P(2), y0 + P(15)), (x1 - P(2), y0 + P(15))], fill=(210, 60, 60, 255), width=P(2))
    d.line([(x0 + P(2), y0 + P(19)), (x1 - P(2), y0 + P(19))], fill=(70, 110, 200, 255), width=P(1))
    # odblaski folii
    gl = canvas()
    dg = ImageDraw.Draw(gl)
    dg.polygon([(x0 + P(10), y0 + P(30)), (x0 + P(24), y0 + P(30)), (x0 + P(12), y1 - P(14)), (x0 + P(6), y1 - P(14))], fill=(255, 255, 255, 90))
    dg.polygon([(x1 - P(26), y0 + P(30)), (x1 - P(20), y0 + P(30)), (x1 - P(30), y1 - P(30)), (x1 - P(34), y1 - P(30))], fill=(255, 255, 255, 60))
    im.alpha_composite(gl.filter(ImageFilter.GaussianBlur(P(1.5))))
    save(im, name)


def jar(name, seed):
    rnd = random.Random(seed)
    im = canvas()
    d = ImageDraw.Draw(im)
    x0, x1, y0, y1 = P(40), P(152), P(46), P(176)
    d.rounded_rectangle([x0, y0, x1, y1], P(14), fill=(200, 220, 228, 110), outline=(236, 244, 248, 230), width=P(2))
    inner = canvas()
    buds(ImageDraw.Draw(inner), (x0 + P(4), y0 + P(8), x1 - P(4), y1 - P(4)), rnd, n=30)
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([x0 + P(4), y0 + P(10), x1 - P(4), y1 - P(4)], P(11), fill=255)
    im.paste(inner, (0, 0), Image.composite(inner.split()[3], Image.new('L', (W, W), 0), mask))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([x0 - P(3), P(22), x1 + P(3), P(50)], P(6), fill=(64, 66, 72, 255), outline=(110, 112, 120, 255), width=P(2))
    for i in range(9):
        x = x0 + P(4) + i * P(13)
        d.line([(x, P(26)), (x, P(46))], fill=(40, 42, 46, 255), width=P(2))
    gl = canvas()
    ImageDraw.Draw(gl).polygon([(x0 + P(12), y0 + P(14)), (x0 + P(28), y0 + P(14)), (x0 + P(24), y1 - P(16)), (x0 + P(10), y1 - P(16))], fill=(255, 255, 255, 80))
    im.alpha_composite(gl.filter(ImageFilter.GaussianBlur(P(2))))
    save(im, name)


def sack(name, kind, seed):
    """worek z towarem luzem: folia zawiązana u góry"""
    rnd = random.Random(seed)
    im = canvas()
    d = ImageDraw.Draw(im)
    body = [(P(38), P(176)), (P(28), P(110)), (P(52), P(60)), (P(84), P(46)), (P(108), P(46)), (P(140), P(60)), (P(164), P(110)), (P(154), P(176))]
    d.polygon(body, fill=(210, 224, 234, 120), outline=(240, 246, 250, 230))
    inner = canvas()
    CONTENT[kind](ImageDraw.Draw(inner), (P(34), P(70), P(158), P(172)), rnd)
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).polygon([(P(42), P(172)), (P(34), P(112)), (P(56), P(72)), (P(136), P(72)), (P(158), P(112)), (P(150), P(172))], fill=255)
    im.paste(inner, (0, 0), Image.composite(inner.split()[3], Image.new('L', (W, W), 0), mask))
    d = ImageDraw.Draw(im)
    d.polygon([(P(84), P(46)), (P(72), P(18)), (P(96), P(26)), (P(120), P(18)), (P(108), P(46))], fill=(220, 232, 240, 170), outline=(240, 246, 250, 230))
    d.rounded_rectangle([P(80), P(40), P(112), P(50)], P(3), fill=(190, 60, 50, 255))
    gl = canvas()
    ImageDraw.Draw(gl).polygon([(P(50), P(80)), (P(64), P(76)), (P(50), P(160)), (P(42), P(160))], fill=(255, 255, 255, 80))
    im.alpha_composite(gl.filter(ImageFilter.GaussianBlur(P(2))))
    save(im, name)


def brick(name, kind, seed):
    """sprasowana kostka owinięta folią i taśmą"""
    rnd = random.Random(seed)
    im = canvas()
    d = ImageDraw.Draw(im)
    base = {'dym': (74, 96, 50), 'szron': (196, 176, 130), 'krysztal': (150, 196, 232), 'snieg': (238, 240, 244)}[kind]
    tape = {'dym': (28, 28, 30), 'szron': (150, 110, 60), 'krysztal': (40, 44, 52), 'snieg': (24, 24, 26)}[kind]
    # bryła w rzucie: góra, przód, bok
    top = [(P(34), P(74)), (P(120), P(52)), (P(166), P(78)), (P(80), P(102))]
    front = [(P(34), P(74)), (P(80), P(102)), (P(80), P(150)), (P(34), P(122))]
    side = [(P(80), P(102)), (P(166), P(78)), (P(166), P(126)), (P(80), P(150))]
    d.polygon(top, fill=shade(base, 1.12) + (255,))
    d.polygon(front, fill=shade(base, 0.72) + (255,))
    d.polygon(side, fill=shade(base, 0.9) + (255,))
    # faktura sprasowanego towaru
    for i in range(260):
        x = rnd.uniform(P(36), P(164))
        y = rnd.uniform(P(54), P(148))
        r = rnd.uniform(P(0.8), P(2.2))
        d.ellipse([x - r, y - r, x + r, y + r], fill=shade(base, rnd.uniform(0.8, 1.15)) + (120,))
    mask = Image.new('L', (W, W), 0)
    dm = ImageDraw.Draw(mask)
    for poly in (top, front, side):
        dm.polygon(poly, fill=255)
    im.putalpha(Image.composite(im.split()[3], Image.new('L', (W, W), 0), mask))
    d = ImageDraw.Draw(im)
    # taśma: dwa pasy w poprzek i jeden wzdłuż
    for t in (0.3, 0.7):
        a = (top[0][0] + (top[1][0] - top[0][0]) * t, top[0][1] + (top[1][1] - top[0][1]) * t)
        b = (top[3][0] + (top[2][0] - top[3][0]) * t, top[3][1] + (top[2][1] - top[3][1]) * t)
        w = P(7)
        d.polygon([(a[0] - w, a[1]), (a[0] + w, a[1] - P(2)), (b[0] + w, b[1] - P(2)), (b[0] - w, b[1])], fill=tape + (255,))
        d.polygon([(b[0] - w, b[1]), (b[0] + w, b[1] - P(2)), (b[0] + w, b[1] + P(46)), (b[0] - w, b[1] + P(48))], fill=shade(tape, 0.8) + (255,))
    # folia: odblask
    gl = canvas()
    ImageDraw.Draw(gl).polygon([(P(60), P(70)), (P(118), P(56)), (P(128), P(60)), (P(70), P(76))], fill=(255, 255, 255, 110))
    im.alpha_composite(gl.filter(ImageFilter.GaussianBlur(P(1.5))))
    d = ImageDraw.Draw(im)
    if kind == 'snieg':
        # stempel na wierzchu
        cx, cy = P(118), P(78)
        d.ellipse([cx - P(13), cy - P(8), cx + P(13), cy + P(8)], outline=(170, 30, 30, 255), width=P(2))
        d.line([(cx - P(7), cy), (cx + P(7), cy)], fill=(170, 30, 30, 255), width=P(2))
    for poly in (top, front, side):
        d.line(poly + [poly[0]], fill=(20, 20, 22, 200), width=P(1))
    save(im, name)


def cash(name, n=3):
    im = canvas()
    d = ImageDraw.Draw(im)
    cols = [(86, 140, 96), (96, 128, 170), (170, 140, 86)]
    for i in range(n):
        y = P(120) - i * P(22)
        c = cols[i % 3]
        pts = [(P(26), y), (P(120), y - P(26)), (P(168), y - P(6)), (P(74), y + P(22))]
        d.polygon(pts, fill=c + (255,), outline=shade(c, 0.6) + (255,))
        d.polygon([(P(26), y), (P(74), y + P(22)), (P(74), y + P(30)), (P(26), y + P(8))], fill=shade(c, 0.7) + (255,))
        d.polygon([(P(74), y + P(22)), (P(168), y - P(6)), (P(168), y + P(2)), (P(74), y + P(30))], fill=shade(c, 0.85) + (255,))
        d.ellipse([P(86), y - P(12), P(110), y + P(2)], outline=shade(c, 1.4) + (255,), width=P(2))
        d.polygon([(P(60), y - P(2)), (P(74), y - P(6)), (P(122), y + P(10)), (P(108), y + P(14))], fill=(230, 226, 210, 255))
    save(im, name)


def empty_bags(name):
    im = canvas()
    d = ImageDraw.Draw(im)
    for i in range(3):
        o = i * P(14)
        d.rounded_rectangle([P(40) + o, P(40) + o * 0.5, P(120) + o, P(150) + o * 0.5], P(8), fill=(214, 226, 236, 110), outline=(240, 246, 250, 235), width=P(2))
        d.line([(P(42) + o, P(54) + o * 0.5), (P(118) + o, P(54) + o * 0.5)], fill=(210, 60, 60, 255), width=P(2))
    save(im, name)


def paper_bag(name, col, label, accent):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.polygon([(P(48), P(40)), (P(144), P(40)), (P(154), P(172)), (P(38), P(172))], fill=col + (255,), outline=shade(col, 0.6) + (255,))
    d.polygon([(P(48), P(40)), (P(144), P(40)), (P(138), P(24)), (P(54), P(24))], fill=shade(col, 0.85) + (255,))
    d.rectangle([P(52), P(84), P(140), P(134)], fill=accent + (255,))
    f = ImageFont.truetype(FONT, P(22))
    b = d.textbbox((0, 0), label, font=f)
    d.text((P(96) - (b[2] - b[0]) / 2 - b[0], P(109) - (b[3] - b[1]) / 2 - b[1]), label, font=f, fill=(250, 250, 244, 255))
    save(im, name)


def phone(name):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([P(62), P(22), P(130), P(172)], P(12), fill=(34, 36, 42, 255), outline=(90, 94, 104, 255), width=P(2))
    d.rounded_rectangle([P(70), P(36), P(122), P(84)], P(4), fill=(120, 160, 130, 255))
    for r in range(4):
        for c in range(3):
            x, y = P(74) + c * P(17), P(96) + r * P(17)
            d.rounded_rectangle([x, y, x + P(12), y + P(11)], P(3), fill=(70, 74, 84, 255))
    save(im, name)


def bottle(name, col, label):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([P(60), P(60), P(132), P(174)], P(12), fill=col + (255,), outline=shade(col, 0.6) + (255,), width=P(2))
    d.rectangle([P(82), P(34), P(110), P(62)], fill=shade(col, 0.8) + (255,))
    d.rounded_rectangle([P(78), P(22), P(114), P(38)], P(4), fill=(40, 42, 46, 255))
    d.rectangle([P(66), P(92), P(126), P(146)], fill=(240, 238, 226, 255))
    f = ImageFont.truetype(FONT, P(17))
    b = d.textbbox((0, 0), label, font=f)
    d.text((P(96) - (b[2] - b[0]) / 2 - b[0], P(119) - (b[3] - b[1]) / 2 - b[1]), label, font=f, fill=(40, 44, 40, 255))
    save(im, name)


def seeds(name):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.polygon([(P(52), P(30)), (P(140), P(30)), (P(146), P(170)), (P(46), P(170))], fill=(232, 224, 200, 255), outline=(150, 140, 110, 255))
    d.rectangle([P(52), P(30), P(140), P(52)], fill=(70, 120, 60, 255))
    # liść
    cx, cy = P(96), P(112)
    for a in (-1.2, -0.6, 0.0, 0.6, 1.2):
        ln = P(40) if a == 0 else (P(32) if abs(a) < 1 else P(22))
        ex, ey = cx + math.sin(a) * ln, cy - math.cos(a) * ln
        d.polygon([(cx, cy), ((cx + ex) / 2 - math.cos(a) * P(6), (cy + ey) / 2 - math.sin(a) * P(6)), (ex, ey), ((cx + ex) / 2 + math.cos(a) * P(6), (cy + ey) / 2 + math.sin(a) * P(6))], fill=(62, 120, 52, 255))
    d.line([(cx, cy), (cx, cy + P(26))], fill=(62, 120, 52, 255), width=P(3))
    save(im, name)


def canister(name, col, label):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([P(42), P(54), P(150), P(174)], P(10), fill=col + (255,), outline=shade(col, 0.6) + (255,), width=P(2))
    d.rounded_rectangle([P(58), P(30), P(110), P(60)], P(8), outline=shade(col, 0.7) + (255,), width=P(6))
    d.rounded_rectangle([P(118), P(36), P(142), P(58)], P(4), fill=(40, 42, 46, 255))
    d.polygon([(P(60), P(96)), (P(132), P(96)), (P(96), P(150))], fill=(240, 200, 40, 255), outline=(30, 30, 30, 255))
    f = ImageFont.truetype(FONT, P(26))
    d.text((P(91), P(100)), "!", font=f, fill=(30, 30, 30, 255))
    f2 = ImageFont.truetype(FONT, P(14))
    b = d.textbbox((0, 0), label, font=f2)
    d.text((P(96) - (b[2] - b[0]) / 2 - b[0], P(76) - b[1]), label, font=f2, fill=(250, 250, 250, 255))
    save(im, name)


def wet_buds(name, seed):
    rnd = random.Random(seed)
    im = canvas()
    d = ImageDraw.Draw(im)
    for i in range(5):
        x = P(40) + i * P(28)
        d.line([(x, P(26)), (x, P(60))], fill=(110, 90, 60, 255), width=P(3))
        buds(d, (x - P(16), P(52), x + P(16), P(168)), rnd, n=7)
    d.line([(P(20), P(26)), (P(172), P(26))], fill=(170, 170, 176, 255), width=P(4))
    save(im, name)


for i, k in enumerate(['dym', 'szron', 'krysztal', 'snieg']):
    baggie('pack_' + k, k, 10 + i)
    brick('brick_' + k, k, 30 + i)
    if k == 'dym':
        jar('bulk_' + k, 20)
    else:
        sack('bulk_' + k, k, 20 + i)
cash('cash')
empty_bags('woreczki')
paper_bag('majeranek', (120, 150, 96), 'MAJERANEK', (64, 96, 52))
paper_bag('cukier', (236, 236, 228), 'CUKIER PUDER', (60, 100, 170))
seeds('nasiona')
phone('burner')
bottle('nawoz', (70, 130, 80), 'NAWÓZ')
canister('chemia', (60, 90, 150), 'ODCZYNNIK')
canister('woda', (70, 150, 200), 'WODA')
wet_buds('mokry_susz', 77)
print(len([f for f in os.listdir(OUT) if f.endswith('.png')]), 'ikon')
