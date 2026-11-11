"""Offline synthesized space effects (assets/audio/generated): the ship's
cannon, the brood's spit and heavy acid, small and big explosions, and the
boss hazards' lightning crack and ground slam. Mono 48 kHz PCM, peak -2 dBFS,
the same finish as the imported SFX (8 ms fade in, 12 ms fade out).

    python3 tools/make_space_sfx.py
"""
import os
import wave

import numpy as np

RATE = 48000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "generated")
rng = np.random.default_rng(4242)


def t_of(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x, hz):
    """One-pole low-pass; `hz` may be a per-sample array (a sweeping filter)."""
    a = 1.0 - np.exp(-2.0 * np.pi * np.broadcast_to(np.asarray(hz, float), x.shape) / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, hz):
    return x - lowpass(x, hz)


def sweep(f0, f1, seconds, curve=2.0):
    t = t_of(seconds)
    k = (t / seconds) ** curve
    freq = f0 + (f1 - f0) * k
    return np.sin(2.0 * np.pi * np.cumsum(freq) / RATE)


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(seconds * RATE))


def env(seconds, attack, decay):
    t = t_of(seconds)
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)


def cannon():
    d = 0.32
    t = t_of(d)
    zap = sweep(2400, 260, d, 0.45)
    body = np.sign(zap) * 0.35 + zap * 0.65
    body = lowpass(body, 5200) * env(d, 0.002, 0.07)
    thump = sweep(120, 45, d, 1.0) * env(d, 0.001, 0.045) * 0.9
    click = highpass(noise(d), 2500) * env(d, 0.0005, 0.006) * 0.6
    tail = lowpass(noise(d), 1800) * env(d, 0.01, 0.09) * 0.25
    return body + thump + click + tail


def brood_spit():
    d = 0.42
    t = t_of(d)
    n = noise(d)
    formant = 900 + 1400 * np.exp(-t / 0.05)
    wet = lowpass(highpass(n, 300), formant) * env(d, 0.003, 0.08) * 1.6
    gurgle = np.sin(2 * np.pi * np.cumsum(180 + 60 * np.sin(2 * np.pi * 38 * t)) / RATE) * env(d, 0.004, 0.06) * 0.5
    pop = sweep(380, 90, d, 0.6) * env(d, 0.001, 0.03) * 0.6
    return wet + gurgle + pop


def brood_heavy():
    d = 0.95
    t = t_of(d)
    boom = sweep(70, 32, d, 0.8) * env(d, 0.004, 0.22)
    glop = lowpass(noise(d), 600 + 900 * np.exp(-t / 0.08)) * env(d, 0.006, 0.18) * 1.8
    bubble = np.sin(2 * np.pi * np.cumsum(140 + 70 * np.sin(2 * np.pi * 21 * t)) / RATE) * env(d, 0.02, 0.2) * 0.35
    return boom + glop + bubble


def explosion(d, rumble_hz, decay, crackle):
    t = t_of(d)
    n = noise(d)
    blast = lowpass(n, 300 + 5000 * np.exp(-t / 0.06)) * env(d, 0.002, decay) * 1.8
    rumble = sweep(rumble_hz, rumble_hz * 0.45, d, 0.7) * env(d, 0.005, decay * 1.3) * 0.9
    sparks = highpass(n, 3000) * (rng.uniform(0, 1, len(t)) > 0.996) * env(d, 0.05, decay * 0.8) * crackle * 6.0
    sparks = lowpass(sparks, 7000)
    return blast + rumble + sparks


def strike():
    d = 1.0
    t = t_of(d)
    n = noise(d)
    crack = highpass(n, 1500) * env(d, 0.0005, 0.018) * 1.4
    sizzle = highpass(n, 2500) * (rng.uniform(0, 1, len(t)) > 0.985) * env(d, 0.01, 0.12) * 1.5
    boom = lowpass(n, 220) * env(d, 0.01, 0.3) * 2.2
    low = sweep(60, 35, d, 1.0) * env(d, 0.01, 0.25) * 0.6
    return crack + sizzle + boom + low


def slam():
    d = 0.75
    t = t_of(d)
    thump = sweep(95, 38, d, 0.6) * env(d, 0.001, 0.12) * 1.1
    grit = lowpass(noise(d), 900 + 2500 * np.exp(-t / 0.03)) * env(d, 0.002, 0.16) * 1.3
    return thump + grit


def finish(x):
    x = x - np.mean(x)
    x = x / np.max(np.abs(x)) * (10 ** (-2.0 / 20.0))
    fade_in = int(0.008 * RATE)
    fade_out = int(0.012 * RATE)
    x[:fade_in] *= np.linspace(0, 1, fade_in)
    x[-fade_out:] *= np.linspace(1, 0, fade_out)
    return x


def write(name, x):
    path = os.path.join(OUT, name + ".wav")
    data = (finish(x) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(path, round(len(data) / RATE, 2), "s")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("ship_cannon", cannon())
    write("brood_spit", brood_spit())
    write("brood_heavy", brood_heavy())
    write("explosion_small", explosion(1.3, 70, 0.25, 0.6))
    write("explosion_big", explosion(2.8, 48, 0.6, 1.0))
    write("hazard_strike", strike())
    write("hazard_slam", slam())
