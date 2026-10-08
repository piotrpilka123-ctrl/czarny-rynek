#!/usr/bin/env python3
"""Tło żyjącego miasta z nagrań (Freesound, wszystkie CC0 — źródła w tools/audio_src/, lista w LICENCJE.md).
Potrzebne pliki (podglądy mp3 ze strony nagrania):
  freesound_705049.mp3 — felix.blume, „Small city ambience with traffic, motors, horn, siren, slight passerby hubbub”
  freesound_165567.mp3 — philippe b, „countryside at night with a dog barking afar”
  freesound_798842.mp3 — WhisperingEarth, „Morning Birds in a Quiet Urban Garden”
Wynik w assets/sfx/miasto/: dzien.wav (pętla ruchu ulicznego), ptaki.wav (pętla porannych ptaków), pies_1…3.wav
(szczekanie w oddali, nocą). Gra sama z nich korzysta, gdy pliki istnieją (Sfx._city_tick); bez nich gra dawne tło.

Nagrań nie da się tu odsłuchać, więc fragmenty wybiera pomiar: do pętli najspokojniejszy odcinek (bez klaksonu
i syreny), do psa — najgłośniejsze krótkie zdarzenia na tle ciszy.
Potrzebuje numpy — uruchamiać Pythonem Blendera:
  /Applications/Blender.app/Contents/Resources/4.5/python/bin/python3.11 tools/make_miasto.py
  … tools/make_miasto.py --test     # sprawdzenie doboru fragmentów na sztucznych danych, bez plików"""
import os, sys, subprocess, wave, tempfile
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'audio_src')
OUT = os.path.join(ROOT, 'assets', 'sfx', 'miasto')
SR = 44100
_tmp = tempfile.mkdtemp()


def load(fid):
    out = os.path.join(_tmp, fid + '.wav')
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@%d' % SR, '-c', '1', os.path.join(SRC, 'freesound_%s.mp3' % fid), out], check=True)
    w = wave.open(out)
    a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    w.close()
    return a


def save(name, a, peak):
    a = np.asarray(a, dtype=np.float64)
    a = a / (np.max(np.abs(a)) + 1e-9) * peak
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    w = wave.open(path, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((np.clip(a, -1, 1) * 32767.0).astype(np.int16).tobytes())
    w.close()
    print('%-14s %6.2f s  %5d KB' % (name, len(a) / SR, os.path.getsize(path) // 1024))


def eq(a, fn):
    sp = np.fft.rfft(a)
    f = np.fft.rfftfreq(len(a), 1.0 / SR)
    return np.fft.irfft(sp * fn(f), len(a))


def lowpass(a, hz, order=2.0):
    return eq(a, lambda f: 1.0 / np.sqrt(1.0 + (f / hz) ** (2.0 * order)))


def highpass(a, hz, order=2.0):
    return eq(a, lambda f: 1.0 / np.sqrt(1.0 + (hz / np.maximum(f, 1e-6)) ** (2.0 * order)))


def envelope(a, win=0.25):
    """głośność (RMS) w kolejnych oknach długości `win` sekund"""
    n = int(win * SR)
    m = len(a) // n
    return np.sqrt(np.mean(a[:m * n].reshape(m, n) ** 2, axis=1) + 1e-12)


def steady_window(a, secs, win=0.25, step=1.0):
    """początek (s) najspokojniejszego odcinka długości `secs`: mała zmienność głośności i żadnych pojedynczych
    głośnych zdarzeń (klakson, syrena, trzaśnięcie), a początek i koniec podobnie głośne — pętla nie „skacze”"""
    env = envelope(a, win)
    k = int(secs / win)
    if len(env) <= k:
        return 0.0
    best, best_t = 1e9, 0.0
    hop = max(1, int(step / win))
    edge = max(1, int(2.0 / win))
    for i in range(0, len(env) - k, hop):
        e = env[i:i + k]
        mean = np.mean(e)
        score = np.std(e) / mean + 0.5 * (np.max(e) / mean - 1.0) + abs(np.mean(e[:edge]) - np.mean(e[-edge:])) / mean
        if score < best:
            best, best_t = score, i * win
    return best_t


def loud_events(a, count, secs, gap=6.0, win=0.1):
    """początki (s) `count` odcinków długości `secs` wokół najgłośniejszych krótkich zdarzeń, co najmniej `gap` s od siebie"""
    env = envelope(a, win)
    base = np.median(env)
    order = np.argsort(env)[::-1]
    out = []
    for i in order:
        t = i * win
        if env[i] < base * 1.8:
            break
        if all(abs(t - u) >= gap for u in out):
            out.append(t)
        if len(out) >= count:
            break
    return [max(0.0, min(len(a) / SR - secs, t - secs * 0.3)) for t in sorted(out)]


def loop_cut(a, t0, secs, xf=2.0):
    """pętla bez szwu: koniec przenika w początek na długości `xf` sekund (równa moc, bez dołka głośności)"""
    n = int(xf * SR)
    s = a[int(t0 * SR):int((t0 + secs) * SR) + n].copy()
    k = np.linspace(0.0, 1.0, n)
    s[:n] = s[:n] * np.sqrt(k) + s[-n:] * np.sqrt(1.0 - k)
    return s[:-n]


def cut(a, t0, secs, fin=0.4, fout=1.2):
    s = a[int(t0 * SR):int((t0 + secs) * SR)].copy()
    n0, n1 = int(fin * SR), int(fout * SR)
    s[:n0] *= np.linspace(0.0, 1.0, n0)
    s[-n1:] *= np.linspace(1.0, 0.0, n1) ** 2
    return s


def selftest():
    rng = np.random.default_rng(3)
    a = rng.standard_normal(SR * 60) * 0.05
    a[SR * 10:SR * 12] += rng.standard_normal(SR * 2) * 0.6          # „klakson” w 10. sekundzie
    a[SR * 40:SR * 41] += rng.standard_normal(SR) * 0.5              # „syrena” w 40. sekundzie
    t = steady_window(a, 20.0)
    ok1 = 12.0 <= t <= 20.0
    ev = loud_events(a, 2, 4.0)
    ok2 = len(ev) == 2 and abs(ev[0] + 1.2 - 10.0) < 2.5 and abs(ev[1] + 1.2 - 40.0) < 1.5
    lp = loop_cut(a, t, 20.0)
    ok3 = abs(len(lp) / SR - 20.0) < 0.01 and abs(lp[0] - a[int((t + 20.0) * SR)]) < 1e-6
    hp = highpass(np.sin(np.arange(SR) / SR * 2 * np.pi * 50.0), 800.0)
    ok4 = np.max(np.abs(hp[2000:-2000])) < 0.02
    for name, ok in (('spokojny odcinek omija głośne zdarzenia (%.1f s)' % t, ok1), ('najgłośniejsze zdarzenia: %s' % [round(x, 1) for x in ev], ok2),
                     ('pętla ma zadaną długość i zaczyna się tam, gdzie kończy', ok3), ('filtr górnoprzepustowy tłumi dudnienie', ok4)):
        print('%s  %s' % ('ok  ' if ok else 'BŁĄD', name))
    return ok1 and ok2 and ok3 and ok4


def main():
    need = ['705049', '165567', '798842']
    missing = [f for f in need if not os.path.exists(os.path.join(SRC, 'freesound_%s.mp3' % f))]
    if missing:
        print('Brak nagrań w tools/audio_src/: ' + ', '.join('freesound_%s.mp3' % f for f in missing))
        return 1
    city = load('705049')
    t = steady_window(city, 48.0)
    print('miasto: spokojny odcinek od %.1f s' % t)
    save('dzien.wav', lowpass(highpass(loop_cut(city, t, 48.0), 60.0), 9000.0), 0.5)
    birds = highpass(load('798842'), 900.0)                 # sam śpiew, bez pomruku miasta
    tb = steady_window(birds, min(28.0, len(birds) / SR - 3.0))
    print('ptaki: odcinek od %.1f s' % tb)
    save('ptaki.wav', loop_cut(birds, tb, min(28.0, len(birds) / SR - 3.0 - tb)), 0.6)
    night = highpass(load('165567'), 200.0)
    ev = loud_events(night, 3, 4.5)
    print('pies: zdarzenia w %s s' % [round(x, 1) for x in ev])
    for i, t0 in enumerate(ev):
        save('pies_%d.wav' % (i + 1), lowpass(cut(night, t0, 4.5), 3500.0), 0.7)
    return 0


if __name__ == '__main__':
    sys.exit((0 if selftest() else 1) if '--test' in sys.argv else main())
