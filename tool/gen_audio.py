"""Generates the two audio assets. Regenerate with `python tool/gen_audio.py`.

Nothing is downloaded and nothing is shipped as a binary we cannot rebuild: the
tick is a one-second loop with the transient at t=0 (see design rule 4 — one
looped one-second sample, not a player per tick), the bell is a single strike.
"""
import math, struct, wave, os, random

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print(name, os.path.getsize(path), 'bytes')


def wall_clock_tick():
    """A dry wooden escapement click, then 1 s of silence — loops seamlessly."""
    n = SR
    out = [0.0] * n
    rng = random.Random(7)
    body = int(SR * 0.028)
    for i in range(body):
        t = i / SR
        env = math.exp(-t * 155)
        noise = rng.uniform(-1, 1) * 0.55
        wood = math.sin(2 * math.pi * 1850 * t) * 0.30 + math.sin(2 * math.pi * 920 * t) * 0.18
        out[i] = (noise + wood) * env * 0.42
    return out


def bell():
    """One strike. Inharmonic partials, long decay, ~2.4 s."""
    n = int(SR * 2.4)
    out = [0.0] * n
    partials = [(1.0, 0.55, 1.6), (2.02, 0.28, 1.9), (2.98, 0.16, 2.4),
                (4.11, 0.10, 3.1), (5.43, 0.06, 3.8)]
    f0 = 622.25  # D#5 — sits above a room of voices without shrieking
    for i in range(n):
        t = i / SR
        s = 0.0
        for mult, amp, decay in partials:
            s += math.sin(2 * math.pi * f0 * mult * t) * amp * math.exp(-t * decay)
        strike = math.exp(-t * 90) * 0.25 if t < 0.05 else 0.0
        out[i] = (s + strike) * 0.5
    # fade the tail to true zero so the file cannot click on stop
    fade = int(SR * 0.15)
    for i in range(fade):
        out[n - fade + i] *= 1 - i / fade
    return out


write('tick.wav', wall_clock_tick())
write('bell.wav', bell())
