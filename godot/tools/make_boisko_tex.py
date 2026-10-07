#!/usr/bin/env python3
"""Tekstura nawierzchni boiska przed blokiem: czerwony tartan z białymi liniami do koszykówki.
Linie są rysowane w trzykrotnym powiększeniu i zmniejszane, więc mają gładkie krawędzie (wcześniej gra
malowała je sama przy starcie, piksel po pikselu — z bliska wychodziły schodki).
Użycie: python3 tools/make_boisko_tex.py   ->  assets/tex/boisko_kort.jpg
Wymiary boiska muszą zgadzać się z World.COURT (28 x 17 jednostek projektu, skala 0,56)."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H = 2048, 1244                    # proporcja 28:17
LEN_M = 28.0 * 0.56                  # długość płyty w metrach
PPM = W / LEN_M                      # pikseli na metr
SS = 3                               # nadpróbkowanie linii
random.seed(4107)


def noise(size, sigma, blur=0.0):
    n = Image.effect_noise(size, sigma)
    return n.filter(ImageFilter.GaussianBlur(blur)) if blur > 0 else n


def lines_mask():
    w, h = W * SS, H * SS
    ppm = PPM * SS
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    lw = int(round(0.075 * ppm))                 # linia 7,5 cm
    m = 0.35 * ppm                               # odstęp obrysu od krawędzi płyty

    def line(a, b):
        d.line([a, b], fill=255, width=lw)
        r = lw / 2.0
        for p in (a, b):
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)

    def arc(c, rad, a0, a1):
        d.arc([c[0] - rad - lw / 2, c[1] - rad - lw / 2, c[0] + rad + lw / 2, c[1] + rad + lw / 2], a0, a1, fill=255, width=lw)

    line((m, m), (w - m, m)); line((w - m, m), (w - m, h - m)); line((w - m, h - m), (m, h - m)); line((m, h - m), (m, m))
    line((w / 2, m), (w / 2, h - m))
    arc((w / 2, h / 2), 1.2 * ppm, 0, 360)
    # kropka na środku
    d.ellipse([w / 2 - lw, h / 2 - lw, w / 2 + lw, h / 2 + lw], fill=255)
    for side in (0, 1):
        ex = m if side == 0 else w - m
        dx = 1.0 if side == 0 else -1.0
        key_l, key_w = 3.4 * ppm, 1.5 * ppm
        line((ex, h / 2 - key_w), (ex + dx * key_l, h / 2 - key_w))
        line((ex, h / 2 + key_w), (ex + dx * key_l, h / 2 + key_w))
        line((ex + dx * key_l, h / 2 - key_w), (ex + dx * key_l, h / 2 + key_w))
        a0, a1 = (-90, 90) if side == 0 else (90, 270)
        arc((ex + dx * key_l, h / 2), key_w, a0, a1)
        # znaczniki przy polu rzutów wolnych
        for k in (1.2, 1.9, 2.6):
            for sg in (-1, 1):
                x = ex + dx * k * ppm
                y0 = h / 2 + sg * key_w
                line((x, y0), (x, y0 + sg * 0.16 * ppm))
        # łuk za trzy punkty: środek pod obręczą
        hoop = (ex + dx * 1.35 * ppm, h / 2)
        r3 = min(3.6 * ppm, h / 2 - m - 0.8 * ppm)
        arc(hoop, r3, a0, a1)
        line((ex, h / 2 - r3), (hoop[0], h / 2 - r3))
        line((ex, h / 2 + r3), (hoop[0], h / 2 + r3))
    return im.resize((W, H), Image.LANCZOS)


def main():
    # --- podkład: tartan o drobnym ziarnie, z plamami wypłowienia i ciemniejszymi zaciekami
    grain = noise((W, H), 26)                                    # ziarno granulatu
    blotch = noise((W // 8, H // 8), 60, 5).resize((W, H), Image.BICUBIC)   # duże plamy
    streak = noise((W // 2, H // 32), 55, 2).resize((W, H), Image.BICUBIC)  # smugi po deszczu wzdłuż boiska
    base = Image.new("RGB", (W, H))
    px = base.load()
    g, b, s = grain.load(), blotch.load(), streak.load()
    for y in range(H):
        for x in range(W):
            k = (g[x, y] - 128) / 128.0 * 0.055 + (b[x, y] - 128) / 128.0 * 0.07 + (s[x, y] - 128) / 128.0 * 0.03
            px[x, y] = (int(255 * max(0.0, min(1.0, 0.60 + k))), int(255 * max(0.0, min(1.0, 0.19 + k * 0.5))), int(255 * max(0.0, min(1.0, 0.14 + k * 0.4))))
    # --- wytarte, jaśniejsze place pod koszami i na środku
    worn = Image.new("L", (W, H), 0)
    dw = ImageDraw.Draw(worn)
    for fx, fy, rad in ((0.11, 0.5, 2.1), (0.89, 0.5, 2.1), (0.5, 0.5, 1.5), (0.22, 0.5, 1.3), (0.78, 0.5, 1.3)):
        r = rad * PPM
        dw.ellipse([fx * W - r, fy * H - r * 0.85, fx * W + r, fy * H + r * 0.85], fill=120)
    worn = worn.filter(ImageFilter.GaussianBlur(0.55 * PPM))
    worn = ImageChops.multiply(worn, noise((W // 4, H // 4), 70, 3).resize((W, H), Image.BICUBIC).point(lambda v: min(255, int(v * 1.5))))
    base = Image.composite(Image.new("RGB", (W, H), (190, 96, 80)), base, worn)
    # --- pęknięcia: kilka cienkich, ciemnych rys
    cr = Image.new("L", (W * 2, H * 2), 0)
    dc = ImageDraw.Draw(cr)
    for _ in range(9):
        x, y = random.uniform(0.05, 0.95) * W * 2, random.uniform(0.05, 0.95) * H * 2
        ang = random.uniform(0, math.tau)
        pts = [(x, y)]
        for _ in range(random.randint(14, 30)):
            ang += random.uniform(-0.5, 0.5)
            x += math.cos(ang) * 26
            y += math.sin(ang) * 26
            pts.append((x, y))
        dc.line(pts, fill=150, width=3)
    cr = cr.resize((W, H), Image.LANCZOS)
    base = Image.composite(Image.new("RGB", (W, H), (70, 24, 20)), base, cr)
    # --- linie: farba starta nierówno (więcej pod koszami), brzegi gładkie
    mask = lines_mask()
    wear = noise((W // 3, H // 3), 75, 1.2).resize((W, H), Image.BICUBIC).point(lambda v: 255 if v > 78 else int(110 + v))
    mask = ImageChops.multiply(mask, wear)
    mask = ImageChops.multiply(mask, ImageChops.invert(worn.point(lambda v: int(v * 0.9))))
    paint = Image.new("RGB", (W, H), (236, 233, 224))
    base = Image.composite(paint, base, mask)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tex", "boisko_kort.jpg")
    base.save(out, quality=90, optimize=True)
    print("zapisano", os.path.normpath(out), base.size, "%.0f KB" % (os.path.getsize(out) / 1024.0))


if __name__ == "__main__":
    main()
