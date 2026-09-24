"""Synthesize Spider Smash sound effects and hip-hop music loops.

Run: python3 tools/gen_audio.py   (needs numpy + scipy)
Writes WAV files into assets/sounds and assets/music.
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy import signal

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
rng = np.random.default_rng(11)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, curve=4.0):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(0.0, t - a) * curve / max(d, 1e-4))
    return e


def chirp(f0, f1, dur, kind="exp"):
    t = t_(dur)
    if kind == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype="band")
    return signal.lfilter(b, a, x)


def lp(x, f, order=2):
    b, a = signal.butter(order, min(f / (SR / 2), 0.99), btype="low")
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def sweep_lp(x, f0, f1):
    """Time-varying low-pass (block-wise)."""
    out = np.zeros_like(x)
    blk = 256
    zi = None
    for i in range(0, len(x), blk):
        f = f0 * (f1 / f0) ** (i / max(1, len(x)))
        b, a = signal.butter(2, min(f / (SR / 2), 0.99), btype="low")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        seg, zi = signal.lfilter(b, a, x[i:i + blk], zi=zi)
        out[i:i + blk] = seg
    return out


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(name, x, folder="sounds", peak=0.9):
    x = norm(x, peak)
    # tiny fade to avoid clicks
    f = min(64, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    path = os.path.join(ROOT, folder, name + ".wav")
    wavfile.write(path, SR, (x * 32767).astype(np.int16))
    print("wrote", path, round(len(x) / SR, 2), "s")


# ---------------------------------------------------------------- effects

def sfx():
    # THWIP: bright falling chirp plus a sticky noise click
    d = 0.16
    x = chirp(3200, 500, d) * env(int(SR * d), 0.002, 0.05, 3)
    x += hp(noise(d), 2000) * env(int(SR * d), 0.001, 0.02, 5) * 0.6
    save("thwip", x)

    # ZIP: rising whoosh with a thwip on top
    d = 0.45
    n = bp(noise(d), 600, 5000)
    e = np.sin(np.linspace(0, np.pi, int(SR * d))) ** 1.5
    x = n * e * 0.7 + np.pad(chirp(3000, 700, 0.12) * env(int(SR * 0.12), 0.002, 0.04, 3), (0, int(SR * d) - int(SR * 0.12)))
    x += chirp(300, 1400, d) * e * 0.15
    save("zip", x)

    # WHOOSH
    d = 0.28
    x = bp(noise(d), 400, 2500) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 2
    save("whoosh", x, peak=0.6)

    # PUNCH: low thump + crack
    d = 0.22
    x = chirp(160, 45, d) * env(int(SR * d), 0.002, 0.08, 3)
    x += bp(noise(d), 800, 6000) * env(int(SR * d), 0.001, 0.015, 4) * 0.8
    x = np.tanh(x * 2.5)
    save("punch", x)

    # PUNCH BIG: layered boom + crunch
    d = 0.55
    boom = chirp(120, 30, d) * env(int(SR * d), 0.003, 0.25, 3)
    crunch = np.tanh(bp(noise(d), 300, 4000) * 6) * env(int(SR * d), 0.001, 0.06, 4)
    crack = hp(noise(d), 3000) * env(int(SR * d), 0.0005, 0.01, 4)
    x = np.tanh((boom * 1.2 + crunch * 0.6 + crack * 0.5) * 2.0)
    save("punch_big", x)

    # FLIP: airy rising swish
    d = 0.3
    x = bp(noise(d), 1000, 6000) * np.sin(np.linspace(0, np.pi, int(SR * d))) * 0.6
    x += chirp(500, 1500, d) * np.sin(np.linspace(0, np.pi, int(SR * d))) * 0.15
    save("flip", x, peak=0.55)

    # LAND HARD: big thud + debris
    d = 0.7
    x = chirp(90, 28, d) * env(int(SR * d), 0.002, 0.3, 3)
    x += lp(noise(d), 900) * env(int(SR * d), 0.001, 0.15, 3) * 1.5
    x += bp(noise(d), 2000, 7000) * env(int(SR * d), 0.02, 0.2, 5) * 0.2
    save("land_hard", np.tanh(x * 1.8))

    # STICK: sticky thup
    d = 0.12
    x = chirp(600, 200, d) * env(int(SR * d), 0.001, 0.04, 3) + bp(noise(d), 300, 1500) * env(int(SR * d), 0.001, 0.03, 4) * 0.6
    save("stick", x, peak=0.6)

    # HURT: descending buzzy "bwow"
    d = 0.35
    t = t_(d)
    f = 520 * (0.4 ** (t / d))
    x = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.005, 0.2, 2)
    x = lp(x, 2500)
    save("hurt", x, peak=0.7)

    # SPLASH
    d = 0.9
    x = sweep_lp(noise(d), 6000, 300) * env(int(SR * d), 0.005, 0.4, 3)
    for k in range(10):
        s = int(rng.uniform(0.05, 0.7) * SR)
        bd = 0.06
        b = chirp(rng.uniform(400, 900), rng.uniform(1200, 2000), bd) * env(int(SR * bd), 0.002, 0.04, 3) * 0.3
        x[s:s + len(b)] += b[:len(x) - s]
    save("splash", x)

    # SPLAT
    d = 0.2
    x = lp(noise(d), 1800) * env(int(SR * d), 0.001, 0.07, 3) + chirp(300, 120, d) * env(int(SR * d), 0.001, 0.05, 3) * 0.5
    save("splat", x, peak=0.7)

    # EXPLODE
    d = 1.1
    x = sweep_lp(noise(d), 5000, 200) * env(int(SR * d), 0.002, 0.5, 3)
    x += chirp(80, 25, d) * env(int(SR * d), 0.002, 0.4, 3) * 1.2
    for k in range(25):
        s = int(rng.uniform(0.02, 0.8) * SR)
        c = hp(noise(0.01), 2000) * 0.4
        x[s:s + len(c)] += c[:len(x) - s]
    save("explode", np.tanh(x * 1.5))

    # UI
    d = 0.05
    save("click", chirp(1800, 1200, d) * env(int(SR * d), 0.001, 0.02, 3), peak=0.5)
    d = 0.22
    a = np.concatenate([np.sin(2 * np.pi * 880 * t_(0.08)), np.sin(2 * np.pi * 1320 * t_(0.14))])
    save("select", signal.square(np.arange(len(a)) / SR * 2 * np.pi * 0) * 0 + a * env(len(a), 0.002, 0.15, 2), peak=0.5)

    # GLITCH: bit-crushed random blips
    d = 0.5
    x = np.zeros(int(SR * d))
    pos = 0
    while pos < len(x):
        ln = int(rng.uniform(0.01, 0.05) * SR)
        f = rng.choice([220, 330, 440, 660, 880, 1320, 1760])
        seg = signal.square(2 * np.pi * f * np.arange(ln) / SR)
        x[pos:pos + ln] = seg[:len(x) - pos] * rng.uniform(0.3, 1.0)
        pos += ln
    x = np.round(x * 4) / 4
    save("glitch", x * env(len(x), 0.001, 0.4, 2), peak=0.5)

    # ALARM: two-tone siren
    d = 1.2
    t = t_(d)
    f = np.where((t * 4).astype(int) % 2 == 0, 740, 988)
    x = signal.square(2 * np.pi * np.cumsum(f) / SR) * 0.5
    x = lp(x, 3000) * env(len(t), 0.01, 1.2, 1)
    save("alarm", x, peak=0.5)

    # WIN jingle: C E G C' arpeggio then chord
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for n in notes:
        tt = t_(0.14)
        parts.append((signal.square(2 * np.pi * n * tt) * 0.4 + np.sin(2 * np.pi * n * tt)) * env(len(tt), 0.003, 0.12, 2))
    tt = t_(1.0)
    chord = sum(np.sin(2 * np.pi * n * tt) + 0.3 * signal.square(2 * np.pi * n * tt) for n in [523.25, 659.25, 783.99, 1046.5]) * env(len(tt), 0.005, 0.9, 2)
    save("win", np.concatenate(parts + [chord]), peak=0.6)

    # CHAPTER stab: big minor chord hit with a tail
    tt = t_(1.4)
    ch = sum(signal.sawtooth(2 * np.pi * f * tt) for f in [110, 220, 261.63, 329.63, 440]) * env(len(tt), 0.004, 0.8, 2.5)
    ch = lp(ch, 2500) + chirp(80, 30, 1.4) * env(len(tt), 0.002, 0.5, 3) * 1.5
    save("chapter", np.tanh(ch * 0.8), peak=0.7)

    # BOSS ROAR: low growl with vibrato and distortion
    d = 1.6
    t = t_(d)
    f = 70 + 12 * np.sin(2 * np.pi * 7 * t) + 40 * np.exp(-t * 2)
    x = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) + lp(noise(d), 600) * 0.8
    x = np.tanh(x * 3) * env(len(t), 0.05, 1.4, 1.5)
    x = lp(x, 1500)
    save("boss_roar", x, peak=0.8)

    # CHEER: crowd-ish swell of filtered noise with little "woo" chirps
    d = 1.5
    x = bp(noise(d), 500, 3000) * np.sin(np.linspace(0, np.pi, int(SR * d))) * 0.6
    for k in range(14):
        s = int(rng.uniform(0.0, 1.1) * SR)
        cd = rng.uniform(0.2, 0.35)
        f0 = rng.uniform(500, 900)
        c = chirp(f0, f0 * rng.uniform(1.3, 1.8), cd) * np.sin(np.linspace(0, np.pi, int(SR * cd))) * 0.2
        x[s:s + len(c)] += c[:len(x) - s]
    save("cheer", x, peak=0.6)

    # WIND: seamless 2 s loop of rushing air
    d = 2.0
    n = noise(d + 0.5)
    x = bp(n, 250, 2200)[int(0.5 * SR):]
    t = t_(d)
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.5 * t)
    f = int(0.2 * SR)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    x = x[:len(x) - f]
    save("wind", x, peak=0.5)

    # STEP: soft sneaker footstep
    d = 0.09
    x = lp(noise(d), 1400) * env(int(SR * d), 0.001, 0.025, 4) + chirp(180, 90, d) * env(int(SR * d), 0.001, 0.03, 4) * 0.6
    save("step", x, peak=0.5)

    # HONK: a two-tone taxi horn
    d = 0.45
    t = t_(d)
    x = (signal.square(2 * np.pi * 415 * t) + signal.square(2 * np.pi * 523 * t)) * 0.5
    x = lp(x, 2500) * np.minimum(1, t / 0.01) * np.minimum(1, (d - t) / 0.05)
    save("honk", x, peak=0.6)


# ---------------------------------------------------------------- music

def kick(amp=1.0):
    d = 0.4
    x = chirp(140, 42, d) * env(int(SR * d), 0.002, 0.22, 3)
    x += hp(noise(d), 3000) * env(int(SR * d), 0.0005, 0.005, 4) * 0.3
    return np.tanh(x * 1.5) * amp


def snare(amp=1.0):
    d = 0.3
    x = bp(noise(d), 1200, 7000) * env(int(SR * d), 0.001, 0.12, 3)
    x += np.sin(2 * np.pi * 190 * t_(d)) * env(int(SR * d), 0.001, 0.06, 3) * 0.7
    return x * amp


def clap(amp=1.0):
    d = 0.25
    x = np.zeros(int(SR * d))
    for off in [0, 0.012, 0.024]:
        s = int(off * SR)
        n = bp(noise(d), 900, 5000) * env(int(SR * d), 0.001, 0.05, 4)
        x[s:] += n[:len(x) - s]
    return x * amp * 0.6


def hat(amp=1.0, open_=False):
    d = 0.25 if open_ else 0.06
    x = hp(noise(d), 7000) * env(int(SR * d), 0.0005, d * 0.6, 3)
    return x * amp


def vinyl(dur):
    x = lp(noise(dur), 3000) * 0.01
    for k in range(int(dur * 8)):
        s = rng.integers(0, int(dur * SR) - 50)
        x[s:s + 20] += rng.uniform(-0.25, 0.25) * np.exp(-np.arange(20) / 4)
    return x


def place(buf, x, at):
    s = int(at * SR)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(x))
    buf[s:e] += x[:e - s]


def note_f(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def bass_note(f, dur, kind="sub"):
    t = t_(dur)
    if kind == "808":
        ff = f * (1 + 0.8 * np.exp(-t * 30))
        x = np.sin(2 * np.pi * np.cumsum(ff) / SR)
        x = np.tanh(x * 2.2) * env(len(t), 0.003, dur * 0.9, 1.5)
    else:
        x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
        x *= env(len(t), 0.005, dur * 0.8, 1.2)
    return x


def pluck(f, dur, bright=3000):
    t = t_(dur)
    x = signal.sawtooth(2 * np.pi * f * t) * 0.6 + signal.square(2 * np.pi * f * 1.005 * t) * 0.4
    x = sweep_lp(x, bright, 300) * env(len(t), 0.002, dur * 0.6, 2.5)
    return x


def rhodes(f, dur):
    t = t_(dur)
    mod = np.sin(2 * np.pi * f * 2 * t) * 1.2 * np.exp(-t * 3)
    x = np.sin(2 * np.pi * f * t + mod) * env(len(t), 0.004, dur, 1.3)
    return x


def pad(freqs, dur):
    t = t_(dur)
    x = sum(signal.sawtooth(2 * np.pi * f * t) + signal.sawtooth(2 * np.pi * f * 1.007 * t) for f in freqs)
    x = lp(x, 1400) * np.minimum(1, t / 0.4) * np.minimum(1, (dur - t) / 0.4)
    return x / len(freqs)


def beat_city():
    bpm = 90
    beat = 60 / bpm
    bars = 16
    dur = bars * 4 * beat
    mix = np.zeros(int(SR * dur) + SR)
    drums = np.zeros_like(mix)
    swing = 0.06
    # chord roots: A section Am F C G (x2), B section Dm Am F E (x2)
    roots = [57, 53, 48, 55] * 2 + [50, 57, 53, 52] * 2
    chords = {57: [57, 60, 64], 53: [53, 57, 60], 48: [48, 52, 55], 55: [55, 59, 62], 50: [50, 53, 57], 52: [52, 56, 59]}
    for bar in range(bars):
        b0 = bar * 4 * beat
        # boom-bap kick pattern
        for k in [0, 1.5, 2.5] if bar % 2 == 0 else [0, 1.75, 2.5, 3.5]:
            place(drums, kick(), b0 + k * beat)
        for s in [1, 3]:
            place(drums, snare(0.55) + np.pad(clap(0.5), (0, len(snare()) - len(clap()))), b0 + s * beat)
        for h in range(8):
            off = h * beat / 2 + (swing if h % 2 else 0)
            place(drums, hat(0.35 if h % 2 else 0.5, open_=(h == 7 and bar % 4 == 3)), b0 + off)
        # bass: root on 1, octave pop on the and of 2
        r = roots[bar]
        place(mix, bass_note(note_f(r - 12), beat * 1.4) * 0.9, b0)
        place(mix, bass_note(note_f(r - 12), beat * 0.45) * 0.7, b0 + 1.5 * beat)
        place(mix, bass_note(note_f(r), beat * 0.4) * 0.45, b0 + 2.5 * beat)
        place(mix, bass_note(note_f(r - 12), beat * 0.9) * 0.8, b0 + 3 * beat)
        # rhodes chords on the off-beats
        for c in [0.5, 2.0]:
            ch = sum(rhodes(note_f(n + 12), beat * 1.2) for n in chords[r]) * 0.18
            place(mix, ch, b0 + c * beat)
        # pluck hook (Spider-Verse-y minor riff)
        hook = [(0, 76), (0.5, 74), (0.75, 72), (1.5, 69), (2.5, 72), (3.0, 74), (3.25, 76)]
        if bar % 2 == 1:
            hook = [(0, 79), (0.5, 76), (1.0, 74), (1.5, 72), (2.0, 74), (3.0, 69)]
        if bar >= 8:
            # B section: a call-and-response riff an octave up
            hook = [(0, 81), (0.25, 79), (0.5, 76), (1.5, 74), (2.0, 76), (2.75, 81)] if bar % 2 == 0 else [(0.5, 84), (1.0, 81), (1.5, 79), (2.5, 76), (3.0, 74)]
        for (o, n) in hook:
            place(mix, pluck(note_f(n), beat * 0.45, 2600) * 0.16, b0 + o * beat)
        # record scratch every 4 bars
        if bar % 4 == 3:
            sd = beat * 0.5
            t = t_(sd)
            scr = bp(noise(sd), 800, 4000) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * np.sin(np.linspace(0, np.pi, len(t)))
            place(mix, scr * 0.35, b0 + 3.5 * beat)
    out = mix + drums * 0.9 + np.pad(vinyl(dur), (0, len(mix) - int(SR * dur)))
    out = out[:int(SR * dur)]
    save("city_beat", np.tanh(out * 0.9), folder="music", peak=0.85)


def beat_boss():
    bpm = 140
    beat = 60 / bpm
    bars = 16
    dur = bars * 4 * beat
    mix = np.zeros(int(SR * dur) + SR)
    roots = [45, 45, 46, 43] * 2 + [41, 43, 45, 44] * 2  # A A Bb G, then F G A G#
    for bar in range(bars):
        b0 = bar * 4 * beat
        for k in [0, 0.75, 2.5, 3.0] if bar % 2 == 0 else [0, 1.5, 2.25, 3.5]:
            place(mix, kick(1.0), b0 + k * beat)
        for s in [1, 3]:
            place(mix, snare(0.9), b0 + s * beat)
            place(mix, clap(0.9), b0 + s * beat)
        # trap hats with rolls
        h = 0.0
        while h < 4:
            step = 0.25 if not (bar % 2 == 1 and h >= 3) else 1 / 12
            place(mix, hat(0.3), b0 + h * beat)
            h += step
        r = roots[bar]
        place(mix, bass_note(note_f(r - 12), beat * 1.8, "808") * 1.1, b0)
        place(mix, bass_note(note_f(r - 12), beat * 1.0, "808") * 0.9, b0 + 2.5 * beat)
        # stabby dark synth
        for o in [0, 0.75, 1.5, 2.0, 3.0]:
            ch = sum(pluck(note_f(n), beat * 0.35, 4000) for n in [r + 24, r + 27, r + 31]) * 0.09
            place(mix, ch, b0 + o * beat)
        # siren lead on bars 4 and 8
        if bar % 4 == 3:
            sd = beat * 4
            t = t_(sd)
            f = note_f(r + 36) * (1 + 0.03 * np.sin(2 * np.pi * 5 * t))
            lead = signal.square(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.02, sd, 0.8)
            place(mix, lp(lead, 3000) * 0.08, b0)
    out = mix[:int(SR * dur)]
    save("boss_beat", np.tanh(out * 0.85), folder="music", peak=0.85)


def beat_title():
    bpm = 80
    beat = 60 / bpm
    bars = 4
    dur = bars * 4 * beat
    mix = np.zeros(int(SR * dur) + SR)
    chords = [[57, 60, 64, 67], [53, 57, 60, 64], [50, 53, 57, 60], [52, 56, 59, 62]]
    for bar in range(bars):
        b0 = bar * 4 * beat
        place(mix, kick(0.8), b0)
        place(mix, kick(0.6), b0 + 2.5 * beat)
        place(mix, snare(0.5), b0 + beat)
        place(mix, snare(0.5), b0 + 3 * beat)
        for h in range(8):
            place(mix, hat(0.25 if h % 2 else 0.35), b0 + h * beat / 2 + (0.05 if h % 2 else 0))
        ch = sum(rhodes(note_f(n), beat * 3.8) for n in chords[bar]) * 0.2
        place(mix, ch, b0)
        place(mix, pad([note_f(n) for n in chords[bar]], beat * 4) * 0.25, b0)
        place(mix, bass_note(note_f(chords[bar][0] - 12), beat * 3) * 0.7, b0)
    out = mix[:int(SR * dur)] + vinyl(dur) * 2
    save("title_beat", np.tanh(out), folder="music", peak=0.8)


if __name__ == "__main__":
    sfx()
    beat_city()
    beat_boss()
    beat_title()
