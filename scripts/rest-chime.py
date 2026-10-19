#!/usr/bin/env python3
"""Writes the rest-over chime (`RestSound`), synthesised here so it has no licence to track.

Two bell-like notes a fifth apart (A5 then E6), each a sine with two softer harmonics and an
exponential decay, mono 16-bit 44.1 kHz, peaking at -6 dBFS.

    python3 scripts/rest-chime.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44_100
LENGTH = 0.9  # seconds
OUT = Path(__file__).resolve().parent.parent / (
    "app/packages/notifications_repository/assets/sounds/rest_chime.wav"
)


def note(t, start, freq):
    t -= start
    if t < 0:
        return 0.0
    attack = min(t / 0.005, 1.0)  # 5 ms, so it does not click
    decay = math.exp(-t / 0.22)
    tone = sum(
        weight * math.sin(2 * math.pi * freq * harmonic * t)
        for harmonic, weight in ((1, 1.0), (2, 0.3), (3, 0.1))
    )
    return attack * decay * tone


samples = []
count = int(RATE * LENGTH)
for i in range(count):
    t = i / RATE
    fade = min((count - i) / (RATE * 0.05), 1.0)  # the last 50 ms to silence
    samples.append(fade * (note(t, 0.0, 880.0) + note(t, 0.16, 1318.51)))

peak = max(abs(s) for s in samples)
scale = 0.5 * 32767 / peak  # -6 dBFS
OUT.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT), "wb") as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(b"".join(struct.pack("<h", round(s * scale)) for s in samples))
print(OUT)
