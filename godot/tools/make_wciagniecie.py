#!/usr/bin/env python3
"""Długie wciągnięcie nosem do prologu: z nagrania „Sniffing” (spookymodem, opengameart.org, CC-BY 3.0)
wycina najdłuższy wdech, zwalnia go i skleja z samym sobą w jeden ciąg ok. 1,4 s — narasta i urywa się nagle.
Użycie: python3 tools/make_wciagniecie.py ścieżka/Sniffing.wav"""
import sys, os, wave, struct, math

src = sys.argv[1]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
w = wave.open(src)
sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
raw = struct.unpack('<%dh' % (n * ch), w.readframes(n))
mono = [sum(raw[i * ch:(i + 1) * ch]) / ch / 32768.0 for i in range(n)]
seg = mono[int(0.19 * sr):int(0.67 * sr)]
# wolniej = dłużej i niżej (głębszy wdech)
rate = 0.72
slow = []
pos = 0.0
while pos < len(seg) - 1:
    i = int(pos)
    f = pos - i
    slow.append(seg[i] * (1 - f) + seg[i + 1] * f)
    pos += rate
L = len(slow)
fade = int(0.2 * sr)
total = int(1.42 * sr)
out = [0.0] * total
step = int(L - fade * 1.1)
k = 0
start = 0
while start < total:
    for i in range(L):
        j = start + i
        if j >= total:
            break
        g = 1.0
        if i < fade and k > 0:
            g = math.sin(0.5 * math.pi * i / fade)
        if i > L - fade:
            g *= math.cos(0.5 * math.pi * (i - (L - fade)) / fade)
        out[j] += slow[i] * g
    start += step
    k += 1
# kształt: szybki początek, narastanie do końca, nagłe urwanie
for j in range(total):
    t = j / sr
    env = min(1.0, t / 0.07) * (0.55 + 0.45 * min(1.0, t / 1.1))
    if t > 1.32:
        env *= max(0.0, 1.0 - (t - 1.32) / 0.09)
    out[j] *= env
peak = max(abs(v) for v in out) or 1.0
out = [v / peak * 0.85 for v in out]
dst = os.path.join(ROOT, 'assets', 'sfx', 'party', 'wciagniecie.wav')
o = wave.open(dst, 'w')
o.setnchannels(1)
o.setsampwidth(2)
o.setframerate(sr)
o.writeframes(struct.pack('<%dh' % total, *[int(max(-1.0, min(1.0, v)) * 32767) for v in out]))
o.close()
print('wciagniecie.wav  %.2f s' % (total / sr))
