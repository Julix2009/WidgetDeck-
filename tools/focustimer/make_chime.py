#!/usr/bin/env python3
"""Makes the sound of the focus timer (qml/widgets/focustimer/chime.wav): a soft two-note bell, 1.3 s, mono 16 bit 44.1 kHz.
Own work, generated from nothing but sine waves (no recording, no sample, no foreign audio): python3 tools/focustimer/make_chime.py
The result is deterministic (the same file every time)."""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "qml", "widgets", "focustimer", "chime.wav")


def bell(freq, start, length, gain):
    """one struck-bell note: a fundamental plus two partials, a short attack and an exponential decay."""
    n = int(length * RATE)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.006) * math.exp(-t * 4.2)
        v = math.sin(2 * math.pi * freq * t) + 0.38 * math.sin(2 * math.pi * freq * 2.01 * t) * math.exp(-t * 3.0) + 0.16 * math.sin(2 * math.pi * freq * 3.02 * t) * math.exp(-t * 5.0)
        out[i] = gain * env * v
    return start, out


def main():
    total = int(1.35 * RATE)
    mix = [0.0] * total
    for start, note in (bell(784.0, 0.0, 1.35, 0.42), bell(1046.5, 0.22, 1.12, 0.36)):         # G5, then C6
        off = int(start * RATE)
        for i, v in enumerate(note):
            if off + i < total:
                mix[off + i] += v
    peak = max(abs(v) for v in mix) or 1.0
    fade = int(0.03 * RATE)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        frames = bytearray()
        for i, v in enumerate(mix):
            g = min(1.0, (total - i) / fade) if i > total - fade else 1.0
            frames += struct.pack("<h", int(max(-1.0, min(1.0, v / peak * 0.8 * g)) * 32767))
        w.writeframes(bytes(frames))
    print("wrote", os.path.normpath(OUT), os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
