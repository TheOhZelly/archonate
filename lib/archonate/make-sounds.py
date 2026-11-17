"""Synthesise each rice's sounds into rices/<rice>/assets/sounds/*.oga.

    python3 make-sounds.py [rice ...]

Events: notify, unlock, lock, wrong (bad password), shot (screenshot),
hello (the rice's desktop starting: login or switching to it).
All synthesised here (plucked strings, synths, FM bells, glass partials),
nothing sampled, so they're ours to keep. Quiet by design: peaks ~-12 dBFS.
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 48000
HYPR = Path.home() / ".config/hypr"


# ---- building blocks -----------------------------------------------------------
def t_(dur):
    return np.arange(int(SR * dur)) / SR


def note(n):
    """MIDI note -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def env(dur, attack=0.004, decay=0.3, sustain=0.0, release=None):
    """Exponential attack/decay envelope over dur seconds."""
    t = t_(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4))
    e = a * d
    if release:
        e *= np.clip((dur - t) / release, 0, 1)
    return e


def sine(f, dur, phase=0.0):
    return np.sin(2 * np.pi * f * t_(dur) + phase)


def saw(f, dur, n=24):
    t = t_(dur)
    return sum((-1) ** (k + 1) * np.sin(2 * np.pi * k * f * t) / k for k in range(1, n + 1) if k * f < SR / 2) * 0.6


def square(f, dur, n=15):
    t = t_(dur)
    return sum(np.sin(2 * np.pi * k * f * t) / k for k in range(1, n + 1, 2) if k * f < SR / 2) * 0.8


def fm(fc, ratio, index, dur, idx_decay=0.25):
    t = t_(dur)
    mod = index * np.exp(-t / idx_decay) * np.sin(2 * np.pi * fc * ratio * t)
    return np.sin(2 * np.pi * fc * t + mod)


def pluck(f, dur, damp=0.996, bright=0.5):
    """Karplus-Strong plucked string."""
    n = int(SR * dur)
    period = max(2, int(SR / f))
    rng = np.random.default_rng(int(f * 10))
    buf = rng.uniform(-1, 1, period) * (0.5 + bright / 2)
    out = np.empty(n)
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = damp * 0.5 * (buf[j] + buf[(j + 1) % period])
    return out


def bell(f, dur, ratios=(1, 2.756, 5.404, 8.933), decay=0.6):
    """Inharmonic partials: glass / bowl / bell."""
    t = t_(dur)
    out = np.zeros_like(t)
    for i, r in enumerate(ratios):
        out += np.sin(2 * np.pi * f * r * t) * np.exp(-t / (decay / (1 + i * 0.9))) / (1 + i)
    return out


def noise(dur, seed=1):
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be an array (a sweep)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def echo(x, delay=0.18, fb=0.35, taps=4):
    d = int(SR * delay)
    out = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        out[d * k:d * k + len(x)] += x * fb ** k
    return out


def at(*parts):
    """Mix (start_seconds, signal) parts."""
    end = max(int(s * SR) + len(sig) for s, sig in parts)
    out = np.zeros(end)
    for s, sig in parts:
        i = int(s * SR)
        out[i:i + len(sig)] += sig
    return out


def finish(x, peak=0.25):
    x = x - np.mean(x)
    fade = min(len(x) // 4, int(SR * 0.012))
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    m = np.max(np.abs(x)) or 1
    return x / m * peak


# ---- the rices ---------------------------------------------------------------
def kyoto():
    """Koto plucks, a temple bowl, a wood block. Pentatonic, soft."""
    k = lambda n, d=1.2: pluck(note(n), d, 0.997, 0.4) * env(d, 0.002, 0.5)
    block = lambda: at((0, highpass(noise(0.08, 3), 400) * env(0.08, 0.001, 0.012) * 0.6), (0, sine(880, 0.08) * env(0.08, 0.001, 0.03)))
    return {
        "notify": at((0, k(74)), (0.13, k(79))),
        "unlock": at((0, bell(note(62), 2.2, (1, 2.71, 4.95), 1.1) * 0.8), (0.05, k(69, 1.4) * 0.5)),
        "lock": at((0, k(79)), (0.14, k(74)), (0.28, k(69, 1.6))),
        "wrong": at((0, k(62, 0.6)), (0.09, k(63, 0.7))),
        "shot": block(),
        "hello": at((0, k(62)), (0.12, k(67)), (0.24, k(69)), (0.36, k(74, 1.8)), (0.1, bell(note(50), 2.0, (1, 2.71), 1.2) * 0.3)),
    }


def outrun():
    """Detuned saws through a filter sweep, with echo. Minor, neon."""
    def syn(n, d=0.35, cut=(4000, 900)):
        x = saw(note(n), d) + saw(note(n) * 1.006, d)
        return lowpass(x, np.linspace(cut[0], cut[1], len(x))) * env(d, 0.005, d / 2.5)
    laser = lambda: np.sin(2 * np.pi * np.cumsum(np.geomspace(2400, 300, int(SR * 0.22))) / SR) * env(0.22, 0.001, 0.08)
    return {
        "notify": echo(at((0, syn(76)), (0.09, syn(83))), 0.16, 0.4),
        "unlock": echo(at((0, syn(64)), (0.08, syn(68)), (0.16, syn(71)), (0.24, syn(76, 0.6))), 0.14, 0.35),
        "lock": echo(at((0, syn(76)), (0.1, syn(71)), (0.2, syn(64, 0.6))), 0.14, 0.35),
        "wrong": at((0, syn(52, 0.3, (1500, 400))), (0.12, syn(51, 0.35, (1500, 400)))),
        "shot": echo(laser(), 0.11, 0.3, 3),
        "hello": echo(at((0, syn(52, 1.4, (300, 5000))), (0, syn(59, 1.4, (300, 5000))), (0, syn(64, 1.4, (300, 5000))), (0.35, syn(76, 0.5))), 0.2, 0.3),
    }


def ashen():
    """Terminal beeps and relay clicks. Hard, short, mono."""
    beep = lambda f, d=0.06: lowpass(square(f, d), 6000) * env(d, 0.001, d, 0.6, 0.004)
    click = lambda s=5: highpass(noise(0.02, s), 1500) * env(0.02, 0.0005, 0.004)
    return {
        "notify": at((0, beep(1320)), (0.09, beep(1320))),
        "unlock": at((0, beep(880, 0.04)), (0.06, beep(1175, 0.04)), (0.12, beep(1760, 0.07))),
        "lock": at((0, beep(1760, 0.04)), (0.06, beep(1175, 0.04)), (0.12, beep(880, 0.07))),
        "wrong": beep(220, 0.28),
        "shot": at((0, click(5)), (0.035, click(9))),
        "hello": at(*[(i * 0.03, beep(f, 0.03)) for i, f in enumerate((600, 900, 750, 1200, 1050, 1500, 1320, 1760))]),
    }


def mono():
    """Barely-there sine ticks. Clean, quiet, no colour."""
    tick = lambda f, d=0.12: sine(f, d) * env(d, 0.002, 0.04)
    return {
        "notify": at((0, tick(1568)), (0.07, tick(2093, 0.18))),
        "unlock": at((0, tick(1047, 0.25)), (0, tick(1568, 0.25) * 0.6)),
        "lock": at((0, tick(1568, 0.25)), (0, tick(1047, 0.25) * 0.6)),
        "wrong": tick(330, 0.2),
        "shot": highpass(noise(0.015, 2), 2500) * env(0.015, 0.0005, 0.003),
        "hello": at((0, tick(1047, 0.6) * 0.8), (0, sine(2093, 0.6) * env(0.6, 0.002, 0.15) * 0.3)),
    }


def cupertino():
    """Glass: bell partials with a little shimmer. Bright, polished."""
    g = lambda n, d=1.0: bell(note(n), d, (1, 2.0, 3.01, 4.17), 0.35)
    whoosh = lambda: lowpass(noise(0.35, 7), np.linspace(400, 6000, int(SR * 0.35))) * env(0.35, 0.18, 0.06) * 0.5
    shutter = lambda s: lowpass(highpass(noise(0.03, s), 800), 7000) * env(0.03, 0.0008, 0.008)
    return {
        "notify": at((0, g(84)), (0.11, g(91, 1.2))),
        "unlock": at((0, whoosh()), (0.22, g(84, 1.2)), (0.22, g(88, 1.2) * 0.6)),
        "lock": at((0, g(88, 0.6) * 0.6), (0, g(81, 0.9))),
        "wrong": at((0, g(64, 0.25)), (0.1, g(64, 0.25)), (0.2, g(64, 0.3))),
        "shot": at((0, shutter(11)), (0.07, shutter(13) * 0.8)),
        "hello": at((0, g(72, 2.0)), (0.08, g(79, 2.0) * 0.8), (0.16, g(84, 2.0) * 0.7), (0.24, g(88, 2.2) * 0.6)),
    }


def archonate():
    """FM bells: crisp, digital, neutral enough for every style."""
    b = lambda n, d=0.9, r=1.4, i=3.0: fm(note(n), r, i, d, 0.12) * env(d, 0.002, d / 3.5)
    tick = lambda: at((0, highpass(noise(0.025, 4), 2000) * env(0.025, 0.0005, 0.006)), (0, b(96, 0.06, 2.0, 1.0) * 0.4))
    return {
        "notify": at((0, b(81)), (0.08, b(88, 1.0))),
        "unlock": at((0, b(76, 0.5)), (0.07, b(83, 0.5)), (0.14, b(88, 1.1))),
        "lock": at((0, b(88, 0.5)), (0.07, b(83, 0.5)), (0.14, b(76, 1.1))),
        "wrong": at((0, b(57, 0.35, 1.0, 6)), (0.11, b(56, 0.4, 1.0, 6))),
        "shot": tick(),
        "hello": at((0, b(64, 1.8, 1.0, 2)), (0, b(71, 1.8, 1.0, 2) * 0.7), (0.3, b(88, 1.2))),
    }


RICES = {"kyoto": kyoto, "outrun": outrun, "ashen": ashen, "mono": mono, "cupertino": cupertino, "archonateold": archonate, "archonate": archonate}


def write(sig, path):
    pcm = (finish(sig) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(path)], check=True)


# Only the rices on this machine (the spares aren't shipped)
for rice in sys.argv[1:] or [r for r in RICES if (HYPR / "rices" / r / "theme.lua").is_file()]:
    out = HYPR / "rices" / rice / "assets/sounds"
    out.mkdir(parents=True, exist_ok=True)
    for name, sig in RICES[rice]().items():
        write(sig, out / f"{name}.oga")
    print(rice, sorted(p.stem for p in out.glob("*.oga")))
