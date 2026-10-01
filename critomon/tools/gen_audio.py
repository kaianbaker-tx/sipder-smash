"""Make every Crito Mon sound effect and the chiptune songs.

Run: python3 tools/gen_audio.py   (needs numpy, scipy and soundfile)
Writes assets/sounds/*.wav and assets/music/*.ogg
"""
import os
import numpy as np
from scipy import signal
from scipy.io import wavfile
import soundfile as sf

SR = 22050
HERE = os.path.dirname(__file__)
SND = os.path.join(HERE, "..", "assets", "sounds")
MUS = os.path.join(HERE, "..", "assets", "music")
os.makedirs(SND, exist_ok=True)
os.makedirs(MUS, exist_ok=True)
rng = np.random.default_rng(5)


# ------------------------------------------------------------------ basics

def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.1, curve=4.0):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(0.0, t - a) * curve / max(d, 1e-4))


def adsr(n, a=0.01, dcy=0.05, s=0.7, r=0.05):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(dcy, 1e-4)))
    rel = np.clip((dur - t) / max(r, 1e-4), 0, 1)
    return e * rel


def freq(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def square(f, d, duty=0.5):
    ph = np.cumsum(np.full(int(SR * d), f) if np.isscalar(f) else f) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def tri(f, d):
    ph = np.cumsum(np.full(int(SR * d), f) if np.isscalar(f) else f) / SR
    return 2 * np.abs(2 * (ph % 1.0) - 1) - 1


def sine(f, d):
    ph = np.cumsum(np.full(int(SR * d), f) if np.isscalar(f) else f) / SR
    return np.sin(2 * np.pi * ph)


def sweep(f0, f1, d):
    t = t_(d)
    return f0 * (f1 / f0) ** (t / d)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lp(x, f, o=2):
    b, a = signal.butter(o, min(f / (SR / 2), 0.99), btype="low")
    return signal.lfilter(b, a, x)


def hp(x, f, o=2):
    b, a = signal.butter(o, f / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, o=2):
    b, a = signal.butter(o, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype="band")
    return signal.lfilter(b, a, x)


def cat(*xs):
    return np.concatenate(xs)


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


def silence(d):
    return np.zeros(int(SR * d))


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x, peak=0.85):
    x = norm(x, peak)
    f = min(64, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    wavfile.write(os.path.join(SND, name + ".wav"), SR, (x * 32767).astype(np.int16))


def tone(note, d, kind="sq", duty=0.5, a=0.005, dcy=0.08, s=0.6):
    f = freq(note)
    w = square(f, d, duty) if kind == "sq" else (tri(f, d) if kind == "tri" else sine(f, d))
    return w * adsr(len(w), a, dcy, s, min(0.04, d * 0.3))


def arp(notes, step, kind="sq", duty=0.5):
    return cat(*[tone(n, step, kind, duty) for n in notes])


# ------------------------------------------------------------------ sounds

def sfx():
    save("blip", tone(84, 0.045, duty=0.25) * 0.5)
    save("select", cat(tone(79, 0.05, duty=0.25), tone(86, 0.08, duty=0.25)))
    save("back", cat(tone(84, 0.05, duty=0.25), tone(77, 0.08, duty=0.25)))
    save("bump", sine(sweep(160, 70, 0.12), 0.12) * env(int(SR * 0.12), 0.002, 0.05))
    d = 0.35
    save("door", mix(lp(noise(d), 900) * env(int(SR * d), 0.005, 0.08) * 0.7, sine(sweep(220, 110, d), d) * env(int(SR * d), 0.005, 0.12) * 0.6))
    save("step", lp(noise(0.06), 1400) * env(int(SR * 0.06), 0.002, 0.02))
    save("grass", bp(noise(0.22), 1500, 6000) * env(int(SR * 0.22), 0.03, 0.08) * (0.6 + 0.4 * np.sin(t_(0.22) * 90)))
    save("alert", cat(square(sweep(700, 1400, 0.08), 0.08, 0.25), silence(0.03), square(sweep(900, 1800, 0.12), 0.12, 0.25)) * 0.6)
    d = 0.9
    save("battle", mix(square(sweep(200, 1200, d), d, 0.3) * env(int(SR * d), 0.02, 0.6, 2.0) * 0.5,
                       hp(noise(d), 2000) * env(int(SR * d), 0.3, 0.3) * 0.4,
                       arp([72, 76, 79, 84, 88], 0.06) * 0.6))
    d = 0.18
    save("hit", mix(lp(noise(d), 3000) * env(int(SR * d), 0.001, 0.04), sine(sweep(300, 60, d), d) * env(int(SR * d), 0.001, 0.07)))
    d = 0.32
    save("hit_super", mix(hp(noise(d), 800) * env(int(SR * d), 0.001, 0.07), sine(sweep(500, 50, d), d) * env(int(SR * d), 0.001, 0.12),
                          square(sweep(1200, 300, 0.1), 0.1, 0.25) * 0.4))
    d = 0.14
    save("hit_weak", lp(noise(d), 900) * env(int(SR * d), 0.001, 0.04) * 0.6)
    d = 0.7
    save("faint", square(sweep(700, 110, d), d, 0.4) * env(int(SR * d), 0.01, 0.5, 1.5) * 0.6)
    save("levelup", cat(arp([72, 76, 79, 84], 0.07), tone(88, 0.3, dcy=0.2)))
    d = 0.35
    save("throw", bp(noise(d), 600, 4000) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 2)
    save("pop", mix(sine(sweep(400, 1500, 0.1), 0.1) * env(int(SR * 0.1), 0.002, 0.05), hp(noise(0.05), 3000) * 0.3))
    save("wobble", cat(lp(noise(0.03), 3000) * 0.6, sine(sweep(300, 220, 0.18), 0.18) * env(int(SR * 0.18), 0.002, 0.08) * 0.8))
    save("caught", cat(arp([79, 84, 88], 0.09), tone(91, 0.4, dcy=0.3), silence(0.02)) + 0)
    save("heal", mix(arp([72, 76, 79, 84, 79, 84, 88, 91], 0.1, "tri"), arp([60, 64, 67, 72], 0.2, "tri") * 0.5))
    d = 0.1
    save("drop", mix(hp(noise(d), 1500) * env(int(SR * d), 0.001, 0.02), sine(1900, d) * env(int(SR * d), 0.001, 0.03) * 0.4, sine(sweep(260, 180, d), d) * env(int(SR * d), 0.001, 0.05)))
    save("win", cat(arp([72, 76, 79], 0.1), tone(84, 0.2), tone(79, 0.1), tone(84, 0.5, dcy=0.3)))
    save("lose", cat(tone(72, 0.2, "tri"), tone(71, 0.2, "tri"), tone(70, 0.2, "tri"), tone(69, 0.6, "tri", dcy=0.4)))
    # a creature cry: a chirpy two-part "pii-kaa" with wobble (pitched per species in game)
    d1, d2 = 0.16, 0.3
    f1 = sweep(900, 1300, d1) * (1 + 0.04 * np.sin(t_(d1) * 60))
    f2 = sweep(1250, 700, d2) * (1 + 0.06 * np.sin(t_(d2) * 45))
    c1 = (square(f1, d1, 0.3) * 0.6 + sine(f1 * 2, d1) * 0.3) * adsr(int(SR * d1), 0.01, 0.05, 0.8, 0.03)
    c2 = (square(f2, d2, 0.35) * 0.6 + sine(f2 * 2, d2) * 0.3) * adsr(int(SR * d2), 0.01, 0.1, 0.7, 0.1)
    save("cry", lp(cat(c1, silence(0.03), c2), 5000))
    d = 0.45
    save("shout", lp(square(110 * (1 + 0.08 * np.sin(t_(d) * 40)), d, 0.3), 1500) * adsr(int(SR * d), 0.02, 0.1, 0.8, 0.1))
    d = 0.6
    save("buff", mix(*[sine(sweep(600 * k, 1600 * k, d), d) * env(int(SR * d), 0.05, 0.4) * 0.3 for k in (1, 1.5, 2)]))
    d = 0.55
    save("fire", mix(lp(noise(d), 1800) * env(int(SR * d), 0.02, 0.3) * 0.8, (rng.uniform(0, 1, int(SR * d)) > 0.995) * 1.0 * 0.6))
    wat = silence(0.55)
    for i in range(6):
        s = int(SR * (0.05 + i * 0.08))
        b = sine(sweep(300 + i * 60, 900 + i * 90, 0.07), 0.07) * env(int(SR * 0.07), 0.003, 0.03)
        wat[s:s + len(b)] += b
    save("water", wat)
    lf = silence(0.5)
    for i in range(4):
        s = int(SR * i * 0.1)
        b = bp(noise(0.1), 2000, 7000) * np.sin(np.linspace(0, np.pi, int(SR * 0.1)))
        lf[s:s + len(b)] += b
    save("leaf", lf)
    d = 0.5
    save("zap", mix(square(55 * (1 + 0.5 * (rng.uniform(0, 1, int(SR * d)) > 0.9)), d, 0.5) * env(int(SR * d), 0.005, 0.3) * 0.5,
                    hp(noise(d), 3000) * (rng.uniform(0, 1, int(SR * d)) > 0.7) * env(int(SR * d), 0.005, 0.3)))
    d = 0.5
    rk = lp(noise(d), 400) * env(int(SR * d), 0.005, 0.3)
    for i in range(3):
        s = int(SR * i * 0.12)
        b = sine(sweep(140, 60, 0.1), 0.1) * env(int(SR * 0.1), 0.001, 0.05)
        rk[s:s + len(b)] += b
    save("rock", rk)
    d = 0.7
    save("wind", bp(noise(d), 400, 2500) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 1.5)
    save("item", cat(arp([76, 79, 84], 0.08), tone(88, 0.25, dcy=0.2)))
    save("flee", cat(*[lp(noise(0.05), 1500) * env(int(SR * 0.05), 0.002, 0.02) for _ in range(4)], bp(noise(0.3), 500, 3000) * np.linspace(1, 0, int(SR * 0.3))))


# ------------------------------------------------------------------ music

N = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def n(s):
    """'C5' -> midi number, 'r' -> None."""
    if s == "r":
        return None
    name = s[:-1]
    return 12 * (int(s[-1]) + 1) + N[name]


def parse(seq):
    """'E5:1 G5:1 A5:2' -> [(midi, beats)]"""
    out = []
    for tok in seq.split():
        s, b = tok.split(":")
        out.append((n(s), float(b)))
    return out


def render_voice(notes, bpm, kind="sq", duty=0.5, vol=1.0, staccato=0.9, vib=0.0):
    beat = 60.0 / bpm
    parts = []
    for m, b in notes:
        d = b * beat
        if m is None:
            parts.append(silence(d))
            continue
        f = freq(m)
        on = d * staccato
        tt = t_(on)
        ff = f * (1 + vib * np.sin(tt * 2 * np.pi * 5.5) * np.clip(tt * 3, 0, 1))
        if kind == "sq":
            w = square(ff, on, duty)
        elif kind == "tri":
            w = tri(ff, on)
        else:
            w = sine(ff, on)
        w = w * adsr(len(w), 0.006, 0.12, 0.65, 0.03)
        parts.append(cat(w, silence(d - on)))
    return cat(*parts) * vol


def chord_track(chords, bpm, beats_per=4, pattern="arp", octave=4, vol=0.25):
    """chords: list of root names like 'C', 'Am', 'G7' (one per bar)."""
    beat = 60.0 / bpm
    parts = []
    for c in chords:
        minor = c.endswith("m")
        root = n(c.rstrip("m") + str(octave))
        tri_ = [root, root + (3 if minor else 4), root + 7]
        if pattern == "arp":
            seq = [tri_[0], tri_[1], tri_[2], tri_[1]] * int(beats_per // 2)
            for m in seq:
                parts.append(render_voice([(m, 0.5)], bpm, "sq", 0.25, 1.0, 0.7))
        else:
            d = beats_per * beat
            w = sum(tri(freq(m), d) for m in tri_) / 3
            parts.append(w * adsr(len(w), 0.05, 0.4, 0.6, 0.1))
    return cat(*parts) * vol


def bass_track(chords, bpm, beats_per=4, style="walk", vol=0.5):
    parts = []
    for c in chords:
        root = n(c.rstrip("m") + "2")
        if style == "drive":
            seq = [(root, 0.5), (root + 12, 0.5)] * int(beats_per)
        else:
            seq = [(root, 1), (root + 7, 1), (root + 12, 1), (root + 7, 1)][:int(beats_per)]
        parts.append(render_voice(seq, bpm, "tri", vol=1.0, staccato=0.85))
    return cat(*parts) * vol


def drums(bars, bpm, beats_per=4, style="pop", vol=0.35):
    beat = 60.0 / bpm
    total = int(SR * bars * beats_per * beat)
    out = np.zeros(total)

    def put(x, at):
        s = int(SR * at)
        e = min(total, s + len(x))
        out[s:e] += x[:e - s]
    kick = sine(sweep(150, 45, 0.12), 0.12) * env(int(SR * 0.12), 0.001, 0.06)
    snare = hp(noise(0.12), 1200) * env(int(SR * 0.12), 0.001, 0.05) * 0.7
    hat = hp(noise(0.03), 6000) * env(int(SR * 0.03), 0.001, 0.01) * 0.35
    for b in range(bars):
        for k in range(int(beats_per)):
            t0 = (b * beats_per + k) * beat
            if style in ("pop", "fast"):
                if k % 2 == 0:
                    put(kick, t0)
                else:
                    put(snare, t0)
                put(hat, t0 + beat * 0.5)
                if style == "fast":
                    put(hat, t0)
                    put(kick, t0 + beat * 0.5) if k == 3 else None
            elif style == "soft":
                if k == 0:
                    put(kick * 0.6, t0)
                put(hat * 0.6, t0 + beat * 0.5)
    return out * vol


def song(name, bpm, melody, chords, beats_per=4, lead="sq", duty=0.5, drum="pop", bass="walk", pad="arp", loops=2, vib=0.004, harmony=None):
    mel = render_voice(parse(melody), bpm, lead, duty, 0.55, 0.88, vib)
    parts = [mel, chord_track(chords, bpm, beats_per, pad), bass_track(chords, bpm, beats_per, bass)]
    if harmony:
        parts.append(render_voice(parse(harmony), bpm, "sq", 0.125, 0.25, 0.8))
    if drum:
        parts.append(drums(len(chords), bpm, beats_per, drum))
    one = mix(*parts)
    one = np.tile(one, loops)
    one = lp(one, 7000)
    one = norm(one, 0.8)
    sf.write(os.path.join(MUS, name + ".ogg"), one.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("song", name, round(len(one) / SR, 1), "s")


def music():
    song("town", 104,
         "E5:1 G5:1 A5:2 G5:1 E5:1 D5:2 C5:1 D5:1 E5:1 G5:1 D5:4 "
         "E5:1 G5:1 A5:2 C6:1 B5:1 A5:2 G5:1 E5:1 D5:1 E5:1 C5:4 "
         "A4:1 C5:1 D5:1 E5:1 F5:2 E5:2 D5:1 E5:1 D5:1 C5:1 B4:2 G4:2 "
         "A4:1 C5:1 D5:1 E5:1 G5:2 A5:1 G5:1 E5:1 D5:1 E5:1 D5:1 C5:4",
         ["C", "G", "Am", "G", "C", "F", "G", "C", "F", "C", "G", "Em", "F", "C", "G", "C"], drum="soft", loops=2)
    song("route", 132,
         "G4:0.5 B4:0.5 D5:1 D5:0.5 E5:0.5 D5:1 B4:0.5 G4:0.5 A4:1 B4:2 "
         "C5:0.5 C5:0.5 E5:1 D5:0.5 C5:0.5 B4:1 A4:1 B4:1 A4:2 "
         "G4:0.5 B4:0.5 D5:1 G5:1 F#5:1 E5:0.5 D5:0.5 E5:1 D5:2 "
         "C5:1 E5:1 D5:1 B4:1 G4:4 "
         "E5:1 E5:0.5 F#5:0.5 G5:2 D5:1 D5:0.5 E5:0.5 F#5:2 "
         "C5:1 C5:0.5 D5:0.5 E5:1 C5:1 B4:1 G4:1 A4:2 "
         "E5:1 E5:0.5 F#5:0.5 G5:1 B5:1 A5:1 G5:1 F#5:2 "
         "G5:1 D5:1 B4:1 A4:1 G4:4",
         ["G", "Em", "C", "D", "G", "C", "D", "G", "C", "D", "Am", "D", "C", "D", "Em", "G"], drum="pop", loops=2)
    song("lab", 92,
         "F5:1 A5:1 C6:2 Bb5:1 A5:1 G5:2 A5:1 G5:1 F5:1 E5:1 F5:4 "
         "D5:1 F5:1 A5:2 G5:1 F5:1 E5:2 F5:1 G5:1 A5:1 C6:1 F5:4",
         ["F", "C", "Dm", "F", "Dm", "C", "Bb", "F"], lead="tri", drum="soft", pad="arp", loops=3, vib=0.006)
    song("battle", 160,
         "A4:0.5 C5:0.5 E5:0.5 A5:0.5 G5:1 E5:1 F5:0.5 E5:0.5 D5:0.5 C5:0.5 D5:2 "
         "E5:0.5 D5:0.5 C5:0.5 B4:0.5 C5:1 A4:1 B4:0.5 C5:0.5 D5:0.5 E5:0.5 G#4:2 "
         "A4:0.5 C5:0.5 E5:0.5 A5:0.5 B5:1 C6:1 B5:0.5 A5:0.5 G5:0.5 F5:0.5 E5:2 "
         "F5:1 E5:1 D5:1 B4:1 A4:2 E5:1 A5:1",
         ["Am", "Dm", "Am", "E", "Am", "G", "Dm", "E"], duty=0.25, drum="fast", bass="drive", loops=3)
    song("rival", 170,
         "D5:0.5 F5:0.5 A5:0.5 D6:0.5 C6:1 A5:1 Bb5:0.5 A5:0.5 G5:0.5 F5:0.5 G5:2 "
         "A5:0.5 G5:0.5 F5:0.5 E5:0.5 F5:1 D5:1 E5:0.5 F5:0.5 G5:0.5 A5:0.5 C#5:2 "
         "D5:0.5 F5:0.5 A5:0.5 D6:0.5 E6:1 F6:1 E6:0.5 D6:0.5 C6:0.5 Bb5:0.5 A5:2 "
         "Bb5:1 A5:1 G5:1 E5:1 D5:2 A5:1 D6:1",
         ["Dm", "Gm", "Dm", "A", "Dm", "C", "Gm", "A"], duty=0.25, drum="fast", bass="drive", loops=3)
    song("title", 118,
         "C5:2 G5:2 F5:1 E5:1 D5:2 E5:1 F5:1 G5:1 A5:1 G5:4 "
         "A5:2 F5:2 G5:1 E5:1 C5:2 D5:1 E5:1 F5:1 D5:1 C5:4",
         ["C", "F", "C", "G", "F", "C", "G", "C"], drum="pop", loops=2, vib=0.006)
    song("c4", 112,
         "D5:0.5 r:0.5 F5:0.5 A5:0.5 G5:1 E5:1 D5:0.5 r:0.5 F5:0.5 A5:0.5 C6:2 "
         "B5:0.5 r:0.5 A5:0.5 G5:0.5 F5:1 E5:1 D5:0.5 E5:0.5 F5:0.5 E5:0.5 D5:2",
         ["Dm", "G", "Dm", "Am"], duty=0.25, drum="soft", pad="arp", loops=4)
    # a short win fanfare (does not loop)
    bpm = 140
    mel = render_voice(parse("C5:0.5 E5:0.5 G5:0.5 C6:1.5 G5:0.5 C6:3"), bpm, "sq", 0.5, 0.6)
    har = render_voice(parse("E4:0.5 G4:0.5 C5:0.5 E5:1.5 E5:0.5 E5:3"), bpm, "sq", 0.25, 0.3)
    bs = render_voice(parse("C3:1.5 G2:1.5 C3:3"), bpm, "tri", 0.5, 0.6)
    fan = norm(mix(mel, har, bs), 0.8)
    sf.write(os.path.join(MUS, "victory.ogg"), fan.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("song victory", round(len(fan) / SR, 1), "s")


if __name__ == "__main__":
    sfx()
    music()
