#!/usr/bin/env python3
"""Dźwięki z nagrań (Freesound, wszystkie CC0 — źródła w tools/audio_src/, lista w LICENCJE.md):
syrena policyjna w pętli (zawodząca i szybka „yelp”), okrzyki rozbawionej grupy na imprezę w prologu,
łomot pięścią w drzwi, zwykłe pukanie oraz bieg kilku osób korytarzem słyszany przez ścianę.
Potrzebuje numpy — uruchamiać Pythonem Blendera:
  /Applications/Blender.app/Contents/Resources/4.5/python/bin/python3.11 tools/make_dzwieki2.py
Nagrania mp3 zamienia na WAV systemowym afconvert (macOS)."""
import os, subprocess, wave, tempfile
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'audio_src')
SFX = os.path.join(ROOT, 'assets', 'sfx')
SR = 44100
_tmp = tempfile.mkdtemp()


def load(fid):
    out = os.path.join(_tmp, fid + '.wav')
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@%d' % SR, '-c', '1', os.path.join(SRC, 'freesound_%s.mp3' % fid), out], check=True)
    w = wave.open(out)
    a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    w.close()
    return a


def save(rel, a, peak=0.89):
    a = np.asarray(a, dtype=np.float64)
    m = np.max(np.abs(a)) + 1e-9
    a = a / m * peak
    path = os.path.join(SFX, rel)
    w = wave.open(path, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((np.clip(a, -1, 1) * 32767.0).astype(np.int16).tobytes())
    w.close()
    print('%-28s %5.2f s  %4d KB' % (rel, len(a) / SR, os.path.getsize(path) // 1024))


def cut(a, t0, t1, fin=0.02, fout=0.08):
    s = a[int(t0 * SR):int(t1 * SR)].copy()
    n0, n1 = int(fin * SR), int(fout * SR)
    s[:n0] *= np.linspace(0.0, 1.0, n0)
    s[-n1:] *= np.linspace(1.0, 0.0, n1)
    return s


def eq(a, fn):
    """filtr w dziedzinie częstotliwości: fn(f) -> wzmocnienie"""
    sp = np.fft.rfft(a)
    f = np.fft.rfftfreq(len(a), 1.0 / SR)
    return np.fft.irfft(sp * fn(f), len(a))


def lowpass(a, hz, order=2.0):
    return eq(a, lambda f: 1.0 / np.sqrt(1.0 + (f / hz) ** (2.0 * order)))


def highpass(a, hz, order=2.0):
    return eq(a, lambda f: 1.0 / np.sqrt(1.0 + (hz / np.maximum(f, 1e-6)) ** (2.0 * order)))


def reverb(a, secs, wet, seed=1, dark=2500.0):
    """pogłos pomieszczenia: splot z gasnącym szumem"""
    rng = np.random.default_rng(seed)
    n = int(secs * SR)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0.0, 6.9, n))
    ir = lowpass(ir, dark)
    ir /= np.sqrt(np.sum(ir ** 2))
    L = len(a) + n
    y = np.fft.irfft(np.fft.rfft(a, L) * np.fft.rfft(ir, L), L)
    out = np.zeros(L)
    out[:len(a)] += a
    return out + y * wet


def mix(parts, total):
    out = np.zeros(int(total * SR))
    for (t, s, g) in parts:
        i = int(t * SR)
        s = s[:max(0, len(out) - i)]
        out[i:i + len(s)] += s * g
    return out


def loop_cut(a, t0, t1, xf=0.06):
    """pętla bez trzasku: koniec przenika w początek"""
    n = int(xf * SR)
    s = a[int(t0 * SR):int(t1 * SR) + n].copy()
    k = np.linspace(0.0, 1.0, n)
    s[:n] = s[:n] * k + s[-n:] * (1.0 - k)
    return s[:-n]


def stretch(a, k):
    """zmiana tempa razem z wysokością (jak wolniejsza taśma)"""
    idx = np.arange(0, len(a) - 1, k)
    return np.interp(idx, np.arange(len(a)), a)


# ---------------------------------------------------------------- syrena
wail = load('159753')            # nagranie syreny w terenie: zawodzenie 700–1700 Hz, okres ok. 4,7 s
yelp = load('223824')            # ta sama rodzina sygnałów: zawodzenie, a od 12,2 s szybki „yelp”
# dwa pełne okresy zawodzenia (od dołka do dołka) — dołki wypadają przy 4,45 s i 13,85 s
save('syrena_wail.wav', highpass(loop_cut(wail, 4.45, 14.25), 250.0), 0.8)
save('syrena_yelp.wav', highpass(loop_cut(yelp, 12.42, 16.86), 250.0), 0.8)

# ---------------------------------------------------------------- impreza: okrzyki grupy
crowd = load('637468')
cheer = load('182571')
woo = load('341488')
os.makedirs(os.path.join(SFX, 'party'), exist_ok=True)
save('party/wiwat_1.wav', cut(woo, 0.0, 1.28, 0.005, 0.12))                         # pojedyncze „łuuu-huu!”
save('party/wiwat_2.wav', cut(crowd, 12.45, 14.75, 0.12, 0.5))                      # grupa: piski i okrzyki
save('party/wiwat_3.wav', cut(cheer, 0.18, 2.9, 0.05, 0.7))                         # krótki wiwat
save('party/wiwat_4.wav', cut(crowd, 28.75, 31.0, 0.1, 0.6))                        # ryk radości całej sali
save('party/wiwat_5.wav', cut(crowd, 9.1, 11.0, 0.15, 0.5))                         # rozbawiony gwar z gwizdami
save('party/tlum.wav', loop_cut(crowd, 0.4, 8.4, 0.5), 0.7)                         # tło: bawiący się tłum, w pętli

# ---------------------------------------------------------------- drzwi
pound = load('250539')           # pojedyncze uderzenia pięścią co 1,16 s, coraz mocniejsze
series = load('426618')          # seria pięciu szybkich, ciężkich uderzeń
for i, t in enumerate((4.66, 9.32, 11.64, 12.8)):
    save('lomot_%d.wav' % (i + 1), reverb(cut(pound, t - 0.04, t + 0.75, 0.005, 0.3), 0.5, 0.25, 10 + i))
save('lomot_seria.wav', reverb(cut(series, 0.0, 2.15, 0.005, 0.2), 0.6, 0.3, 20))
# pukanie do drzwi mieszkania: trzy lekkie stuknięcia z najcichszego uderzenia, wyższe i krótsze
k1 = highpass(cut(pound, 1.12, 1.42, 0.003, 0.18), 220.0)
k1 = stretch(k1, 1.35)
puk = mix([(0.0, k1, 1.0), (0.27, k1, 0.85), (0.52, k1, 0.95)], 1.0)
save('pukanie.wav', reverb(puk, 0.35, 0.18, 30), 0.7)

# ---------------------------------------------------------------- bieg kilku osób korytarzem (zza drzwi)
grp = load('710765')             # kilka osób przebiega obok: 4,6 s, najgłośniej w 3. sekundzie
kor = load('519640')             # jedna osoba biegnie korytarzem; mija mikrofon w 17,7 s
g1 = cut(grp, 0.0, 4.55, 0.2, 0.5)
k = cut(kor, 13.3, 18.6, 0.4, 0.5)
k /= np.max(np.abs(k))
g1 /= np.max(np.abs(g1))
lay = mix([(0.0, g1, 0.9), (0.5, k, 0.55), (1.35, stretch(g1, 0.93), 0.8), (2.4, stretch(g1, 1.06), 0.6)], 7.6)
# ciężkie buty: więcej dołu; przez ścianę: mniej góry; korytarz: pogłos
lay = lay + lowpass(lay, 180.0) * 1.2
lay = lowpass(lay, 2100.0, 1.5)
lay = reverb(lay, 0.9, 0.45, 40, 1800.0)
n = len(lay)
env = np.ones(n)
env[:int(1.2 * SR)] = np.linspace(0.15, 1.0, int(1.2 * SR)) ** 1.5      # nadbiegają z głębi
env[-int(1.0 * SR):] = np.linspace(1.0, 0.0, int(1.0 * SR))
save('bieg_korytarz.wav', lay * env, 0.85)
