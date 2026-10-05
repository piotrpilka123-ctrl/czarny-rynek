#!/usr/bin/env python3
"""Aranżuje podkład zwiastuna z pętli wygenerowanej przez grę (beat.wav, 8 taktów, 140 BPM).
Użycie: soundtrack.py <beat.wav> <wyjście.wav> <takty> — stłumione intro, pełny bit, wyciszenie przed tytułem, uderzenie na tytuł."""
import sys, wave, array, math, random

src, dst, bars = sys.argv[1], sys.argv[2], int(sys.argv[3])
w = wave.open(src, 'rb')
rate = w.getframerate()
assert w.getsampwidth() == 2 and w.getnchannels() == 1, 'oczekiwano mono 16 bit'
loop = array.array('h'); loop.frombytes(w.readframes(w.getnframes())); w.close()
loop = [s / 32768.0 for s in loop]
bar = 4 * 60.0 / 140.0
n_bar = int(round(bar * rate))
total = int(round((bars * bar + 1.6) * rate))
L = len(loop)

def lowpass(buf, a):
    out = []; y = 0.0
    for s in buf:
        y += (s - y) * a
        out.append(y)
    return out

full = [loop[i % L] for i in range(total)]
muffled = lowpass(lowpass(full, 0.06), 0.06)
out = [0.0] * total
title_bar = bars - 4
for i in range(total):
    b = i / n_bar
    if b < 4.0:                       # intro: stłumione, z narastaniem
        k = min(1.0, b / 3.7) ** 2
        s = muffled[i] * 1.9 * (0.55 + 0.45 * k) + full[i] * 0.12 * k
        s *= min(1.0, i / (rate * 1.2))
    elif b < title_bar - 2.0:         # pełny bit
        s = full[i]
    elif b < title_bar:               # dwa takty oddechu przed tytułem
        k = (b - (title_bar - 2.0)) / 2.0
        s = muffled[i] * 1.8 * (1.0 - 0.35 * k) + full[i] * 0.25 * (1.0 - k)
    else:                             # tytuł: pętla startuje od początku razem z planszą
        s = loop[(i - int(title_bar * n_bar)) % L]
    out[i] = s
random.seed(7)
# narastający szum przed tytułem
r0 = int((title_bar - 1.0) * n_bar); r1 = int(title_bar * n_bar); y = 0.0
for i in range(r0, r1):
    k = (i - r0) / (r1 - r0)
    y += (random.uniform(-1, 1) - y) * (0.04 + 0.5 * k * k)
    out[i] += y * 0.22 * k * k
# uderzenie na tytuł
i0 = int(title_bar * n_bar); ph = 0.0
for i in range(int(rate * 1.8)):
    t = i / rate
    f = 38.0 + 55.0 * math.exp(-t * 9.0)
    ph += f / rate
    if i0 + i < total:
        out[i0 + i] += math.sin(ph * 2 * math.pi) * math.exp(-t * 2.2) * 0.75
# wyciszenie końcówki
fade = int(rate * 2.6)
for i in range(fade):
    out[total - 1 - i] *= (i / fade) ** 1.5
# 44,1 kHz stereo, miękki limiter
dst_rate = 44100
ratio = rate / dst_rate
n_out = int(total / ratio)
pcm = array.array('h')
for j in range(n_out):
    x = j * ratio
    i = int(x); fr = x - i
    s = out[i] * (1 - fr) + (out[i + 1] if i + 1 < total else 0.0) * fr
    s = math.tanh(s * 1.15) * 0.92
    v = int(max(-1.0, min(1.0, s)) * 32000)
    pcm.append(v); pcm.append(v)
o = wave.open(dst, 'wb'); o.setnchannels(2); o.setsampwidth(2); o.setframerate(dst_rate); o.writeframes(pcm.tobytes()); o.close()
print('podkład: %.1f s' % (n_out / dst_rate))
