#!/usr/bin/env python3
"""Nawierzchnia osiedlowej połowy boiska „do rzutów": stary, wypłowiały tartan na betonie — przetarty do szarości
tam, gdzie się najwięcej gra, popękany, z zaciekami i mchem w szczelinach; linie wyblakłe i poodpryskiwane.
Kosz stoi przy prawej (wschodniej) krawędzi tekstury. Linie rysowane w powiększeniu i zmniejszane (gładkie brzegi).
Użycie: python3 tools/make_boisko_tex.py   ->  assets/tex/boisko_kort.jpg
Wymiary muszą zgadzać się z World.COURT (18 x 17 jednostek projektu, skala 0,56)."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H = 1296, 1224                    # proporcja 18:17
LEN_M = 18.0 * 0.56                  # głębokość płyty w metrach (oś X świata)
PPM = W / LEN_M
SS = 3
random.seed(4107)


def noise(size, sigma, blur=0.0):
    n = Image.effect_noise(size, sigma)
    return n.filter(ImageFilter.GaussianBlur(blur)) if blur > 0 else n


def big(scale, sigma, blur):
    return noise((max(2, W // scale), max(2, H // scale)), sigma, blur).resize((W, H), Image.BICUBIC)


def lines_mask():
    w, h = W * SS, H * SS
    ppm = PPM * SS
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    lw = int(round(0.07 * ppm))
    m = 0.3 * ppm

    def line(a, b):
        d.line([a, b], fill=255, width=lw)

    def arc(c, rad, a0, a1):
        d.arc([c[0] - rad - lw / 2, c[1] - rad - lw / 2, c[0] + rad + lw / 2, c[1] + rad + lw / 2], a0, a1, fill=255, width=lw)

    # obrys połowy boiska
    line((m, m), (w - m, m)); line((w - m, m), (w - m, h - m)); line((w - m, h - m), (m, h - m)); line((m, h - m), (m, m))
    ex = w - m                                   # linia końcowa pod koszem (prawa krawędź)
    key_l, key_w = 3.6 * ppm, 1.5 * ppm
    line((ex, h / 2 - key_w), (ex - key_l, h / 2 - key_w))
    line((ex, h / 2 + key_w), (ex - key_l, h / 2 + key_w))
    line((ex - key_l, h / 2 - key_w), (ex - key_l, h / 2 + key_w))
    arc((ex - key_l, h / 2), key_w, 90, 270)     # półkole rzutów wolnych
    for k in (1.2, 2.0, 2.8):
        for sg in (-1, 1):
            x = ex - k * ppm
            line((x, h / 2 + sg * key_w), (x, h / 2 + sg * (key_w + 0.15 * ppm)))
    hoop = (ex - 1.3 * ppm, h / 2)
    r3 = min(4.1 * ppm, h / 2 - m - 0.45 * ppm)
    arc(hoop, r3, 90, 270)                       # łuk za trzy
    line((ex, h / 2 - r3), (hoop[0], h / 2 - r3))
    line((ex, h / 2 + r3), (hoop[0], h / 2 + r3))
    arc(hoop, 0.6 * ppm, 90, 270)                # półkole pod koszem
    return im.resize((W, H), Image.LANCZOS)


def main():
    grain = noise((W, H), 30)
    blot = big(10, 70, 4)
    blot2 = big(5, 60, 3)
    streak = noise((W // 2, H // 40), 60, 2).resize((W, H), Image.BICUBIC)
    # --- gdzie tartan się przetarł do betonu: pod koszem, na linii rzutów wolnych, na dobiegu — plus losowe łaty
    worn = Image.new("L", (W, H), 0)
    dw = ImageDraw.Draw(worn)
    for fx, fy, rx, ry, v in ((0.84, 0.5, 1.5, 1.7, 255), (0.62, 0.5, 1.1, 1.2, 230), (0.4, 0.5, 1.6, 2.2, 150), (0.75, 0.2, 0.9, 0.8, 140), (0.75, 0.8, 0.9, 0.8, 140)):
        dw.ellipse([fx * W - rx * PPM, fy * H - ry * PPM, fx * W + rx * PPM, fy * H + ry * PPM], fill=v)
    worn = worn.filter(ImageFilter.GaussianBlur(0.5 * PPM))
    worn = ImageChops.add(worn, blot2.point(lambda v: 0 if v < 150 else min(255, (v - 150) * 5)))
    worn = ImageChops.multiply(worn, big(3, 80, 1.2).point(lambda v: min(255, int(v * 1.7))))
    worn = worn.point(lambda v: 0 if v < 60 else min(255, int((v - 60) * 2.2)))
    red = Image.new("RGB", (W, H))
    grey = Image.new("RGB", (W, H))
    pr, pg = red.load(), grey.load()
    g, b, s = grain.load(), blot.load(), streak.load()
    for y in range(H):
        for x in range(W):
            n = (g[x, y] - 128) / 128.0
            k = n * 0.06 + (b[x, y] - 128) / 128.0 * 0.11 + (s[x, y] - 128) / 128.0 * 0.04
            # wypłowiała, przybrudzona czerwień (dużo mniej nasycona niż nowy tartan)
            pr[x, y] = (int(255 * min(1, max(0, 0.47 + k))), int(255 * min(1, max(0, 0.235 + k * 0.7))), int(255 * min(1, max(0, 0.2 + k * 0.6))))
            c = 0.43 + n * 0.07 + (b[x, y] - 128) / 128.0 * 0.06
            pg[x, y] = (int(255 * min(1, max(0, c))), int(255 * min(1, max(0, c * 0.985))), int(255 * min(1, max(0, c * 0.95))))
    base = Image.composite(grey, red, worn)
    # --- zacieki i brud: ciemne plamy po kałużach, jaśniejszy kurz przy krawędziach
    dirt = big(7, 75, 5).point(lambda v: 0 if v < 140 else min(150, (v - 140) * 3))
    base = Image.composite(Image.new("RGB", (W, H), (58, 50, 44)), base, dirt)
    # --- pęknięcia: długie, rozgałęzione, z mchem w środku
    cr = Image.new("L", (W * 2, H * 2), 0)
    moss = Image.new("L", (W * 2, H * 2), 0)
    dc, dm = ImageDraw.Draw(cr), ImageDraw.Draw(moss)

    def crack(x, y, ang, n, wd):
        pts = [(x, y)]
        for i in range(n):
            ang += random.uniform(-0.55, 0.55)
            x += math.cos(ang) * 30
            y += math.sin(ang) * 30
            pts.append((x, y))
            if wd > 3 and random.random() < 0.12:
                crack(x, y, ang + random.choice((-1, 1)) * random.uniform(0.6, 1.2), n // 3, wd - 2)
        dc.line(pts, fill=235, width=wd)
        if wd >= 5:
            dm.line(pts, fill=200, width=max(2, wd // 3))

    for _ in range(11):
        crack(random.uniform(0, 1) * W * 2, random.uniform(0, 1) * H * 2, random.uniform(0, math.tau), random.randint(20, 55), random.choice((3, 4, 5, 7)))
    cr = cr.resize((W, H), Image.LANCZOS)
    moss = ImageChops.multiply(moss.resize((W, H), Image.LANCZOS), big(4, 90, 1).point(lambda v: 255 if v > 120 else 0))
    base = Image.composite(Image.new("RGB", (W, H), (38, 33, 30)), base, cr)
    base = Image.composite(Image.new("RGB", (W, H), (62, 84, 40)), base, moss)
    # --- linie: wyblakłe, poodpryskiwane, na przetartych miejscach prawie ich nie ma
    mask = lines_mask()
    chips = noise((W // 2, H // 2), 80, 0.8).resize((W, H), Image.BICUBIC).point(lambda v: 0 if v < 96 else (255 if v > 150 else int((v - 96) * 4.7)))
    fade = big(6, 60, 4).point(lambda v: max(110, min(235, int(v * 1.35))))
    mask = ImageChops.multiply(ImageChops.multiply(mask, chips), fade)
    mask = ImageChops.multiply(mask, ImageChops.invert(worn.point(lambda v: int(v * 0.75))))
    base = Image.composite(Image.new("RGB", (W, H), (214, 208, 194)), base, mask)
    base = base.filter(ImageFilter.GaussianBlur(0.4))
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tex", "boisko_kort.jpg")
    base.save(out, quality=90, optimize=True)
    print("zapisano", os.path.normpath(out), base.size, "%.0f KB" % (os.path.getsize(out) / 1024.0))


if __name__ == "__main__":
    main()
