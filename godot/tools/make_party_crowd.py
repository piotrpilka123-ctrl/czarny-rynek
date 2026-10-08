"""Naturalne stereo imprezy z istniejącego nagrania kyles (Freesound 637468, CC0).
Nie zmienia muzyki. Uruchom Pythonem Blendera (numpy) lub innym Pythonem z numpy.
"""
from pathlib import Path
import subprocess, tempfile, wave
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
with tempfile.TemporaryDirectory() as tmp:
    decoded = Path(tmp) / 'crowd.wav'
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', f'LEI16@{RATE}', '-c', '2',
                    str(ROOT / 'tools/audio_src/freesound_637468.mp3'), str(decoded)], check=True)
    with wave.open(str(decoded)) as src:
        channels = src.getnchannels()
        samples = np.frombuffer(src.readframes(src.getnframes()), dtype='<i2').reshape(-1, channels).astype(float) / 32768
    samples = samples[int(0.4 * RATE):int(32.0 * RATE)].copy()
    # Zostaw bas utworowi; tłum ma wypełniać salę, bez ostrego syczenia.
    freq = np.fft.rfftfreq(len(samples), 1 / RATE)
    eq = (freq / np.maximum(freq + 180, 1)) * (1 / np.sqrt(1 + (freq / 7500)**4))
    samples = np.fft.irfft(np.fft.rfft(samples, axis=0) * eq[:, None], n=len(samples), axis=0)
    rms = np.sqrt(np.mean(samples**2))
    samples *= min(0.14 / max(rms, 1e-6), 0.85 / max(np.max(np.abs(samples)), 1e-6))
    for seconds, start in [(0.25, True), (0.8, False)]:
        length = int(seconds * RATE)
        if start:
            samples[:length] *= np.linspace(0, 1, length)[:, None]
        else:
            samples[-length:] *= np.linspace(1, 0, length)[:, None]
    target = ROOT / 'assets/sfx/party/impreza_stereo.wav'
    with wave.open(str(target), 'wb') as out:
        out.setnchannels(channels); out.setsampwidth(2); out.setframerate(RATE)
        out.writeframes((np.clip(samples, -1, 1) * 32767).astype('<i2').tobytes())
    print(f'{target.name}: {len(samples)/RATE:.1f} s, {channels} kanały, {target.stat().st_size} bajtów')
