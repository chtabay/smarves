"""La musique de la ville : une boucle acid jazz légère, entièrement synthétisée ici (aucun échantillon
extérieur, donc aucun droit à suivre). Piano électrique en accords de neuvième, basse ronde
syncopée, batterie feutrée au balai, quelques notes de vibraphone ; seize mesures à 96 à la noire,
bouclées sans couture.

    python3 tools/musique_ville.py            # écrit assets/audio/musique/ville.ogg (ffmpeg requis)
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
BPM = 96.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
N = int(round(BARS * BAR * SR))
SWING = 0.12  # retard des croches impaires, en fraction de noire

rng = np.random.default_rng(1977)
left = np.zeros(N)
right = np.zeros(N)


def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def add(sig, start, pan=0.0, gain=1.0):
    """Pose un son à `start` secondes ; ce qui dépasse la fin revient au début (boucle sans couture)."""
    i = int(round(start * SR)) % N
    idx = (np.arange(len(sig)) + i) % N
    np.add.at(left, idx, sig * gain * np.sqrt(0.5 * (1.0 - pan)))
    np.add.at(right, idx, sig * gain * np.sqrt(0.5 * (1.0 + pan)))


def swung(beat):
    """Une position en noires, croches swinguées."""
    frac = beat % 1.0
    return beat + (SWING if abs(frac - 0.5) < 1e-6 else 0.0)


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for k in range(len(x)):
        acc += (x[k] - acc) * a
        y[k] = acc
    return y


# --- Les instruments ----------------------------------------------------------------------------

def rhodes(note, dur, vel=1.0):
    t = np.arange(int((dur + 1.2) * SR)) / SR
    f = hz(note)
    index = 1.6 * np.exp(-t * 6.0) + 0.25
    mod = np.sin(2 * np.pi * f * t) * index
    body = np.sin(2 * np.pi * f * t + mod)
    tine = np.sin(2 * np.pi * f * 7.0 * t) * np.exp(-t * 18.0) * 0.08
    env = np.minimum(t / 0.004, 1.0) * np.exp(-t * 1.1)
    release = np.clip(1.0 - (t - dur) / 0.35, 0.0, 1.0)
    trem = 1.0 + 0.12 * np.sin(2 * np.pi * 4.6 * t)
    return (body + tine) * env * release * trem * vel


def bass(note, dur, vel=1.0):
    t = np.arange(int((dur + 0.15) * SR)) / SR
    f = hz(note)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) + 0.08 * np.sin(6 * np.pi * f * t)
    s = np.tanh(s * 1.3)
    env = np.minimum(t / 0.006, 1.0) * np.exp(-t * 2.2) * np.clip(1.0 - (t - dur) / 0.08, 0.0, 1.0)
    return s * env * vel


def vibes(note, vel=1.0):
    t = np.arange(int(2.2 * SR)) / SR
    f = hz(note)
    s = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 6.0)
    env = np.minimum(t / 0.002, 1.0) * np.exp(-t * 1.8) * (1.0 + 0.25 * np.sin(2 * np.pi * 5.5 * t))
    return s * env * vel


def kick(vel=1.0):
    t = np.arange(int(0.35 * SR)) / SR
    f = 52.0 + 70.0 * np.exp(-t * 30.0)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-t * 9.0) * vel


def brush(dur=0.18, vel=1.0, bright=0.5):
    n = int(dur * SR)
    noise = rng.uniform(-1, 1, n)
    hp = noise - lowpass(noise, bright)
    t = np.arange(n) / SR
    return hp * np.exp(-t * (6.0 / dur)) * vel


def rim(vel=1.0):
    t = np.arange(int(0.08 * SR)) / SR
    tone = np.sin(2 * np.pi * 820 * t) * np.exp(-t * 60)
    click = rng.uniform(-1, 1, len(t)) * np.exp(-t * 120)
    return (tone * 0.6 + click * 0.4) * vel


# --- La grille : la min9 / ré 9 en dorien, un pont plus coloré -----------------------------------

AM9 = [57, 60, 64, 67, 71]
D9 = [50, 54, 57, 60, 64]
FMAJ9 = [53, 57, 60, 64, 67]
EM9 = [52, 55, 59, 62, 66]
DM9 = [50, 53, 57, 60, 64]
E7S9 = [52, 56, 59, 62, 67]
GRILLE = [AM9, AM9, D9, D9, AM9, AM9, D9, D9, FMAJ9, FMAJ9, EM9, EM9, DM9, DM9, E7S9, E7S9]
BASSES = [45, 45, 38, 38, 45, 45, 38, 38, 41, 41, 40, 40, 38, 38, 40, 40]

# Le piano : des accords posés en contretemps, voix du haut un peu plus douce.
COMP = [(0.0, 1.2, 0.9), (1.5, 0.4, 0.6), (2.5, 1.3, 0.75)]
COMP_B = [(0.5, 0.8, 0.7), (2.0, 0.4, 0.5), (3.5, 0.4, 0.6)]
# La basse : (temps, durée en noires, intervalle depuis la fondamentale).
GROOVE = [(0.0, 0.75, 0), (1.0 - 0.25, 0.25, 0), (1.5, 0.5, 7), (2.5, 0.5, 12), (3.0, 0.4, 10), (3.5, 0.4, 7)]

for bar in range(BARS):
    t0 = bar * BAR
    chord = GRILLE[bar]
    comp = COMP if bar % 2 == 0 else COMP_B
    for beat, dur, vel in comp:
        for k, note in enumerate(chord):
            add(rhodes(note, dur * BEAT, vel * (0.8 if k == len(chord) - 1 else 1.0)),
                t0 + swung(beat) * BEAT + k * 0.006, pan=-0.25 + 0.12 * k, gain=0.055)
    root = BASSES[bar]
    for beat, dur, iv in GROOVE:
        add(bass(root + iv, dur * BEAT, 1.0 if iv == 0 else 0.8), t0 + swung(beat) * BEAT, gain=0.32)
    # Batterie feutrée : grosse caisse sur le 1 et le « et » du 2, cercle sur 2 et 4, balais swingués.
    for beat in (0.0, 1.5) + ((3.75,) if bar % 4 == 3 else ()):
        add(kick(), t0 + beat * BEAT, gain=0.35)
    for beat in (1.0, 3.0):
        add(rim(), t0 + beat * BEAT, pan=0.15, gain=0.10)
    for e in range(8):
        beat = e * 0.5
        add(brush(0.12 if e % 2 else 0.2, 1.0 if e % 2 == 0 else 0.7), t0 + swung(beat) * BEAT,
            pan=0.35, gain=0.045)

# Le vibraphone : deux petites phrases en la mineur pentatonique, une par moitié de la boucle.
PHRASES = [
    (5, [(0.5, 76), (1.0, 79), (2.0, 76), (2.5, 74), (3.5, 72)]),
    (6, [(1.0, 69), (2.5, 72)]),
    (13, [(0.0, 77), (0.5, 76), (1.5, 74), (2.5, 72), (3.0, 71)]),
    (15, [(0.5, 68), (1.5, 71), (2.5, 74)]),
]
for bar, notes in PHRASES:
    for beat, note in notes:
        add(vibes(note), bar * BAR + swung(beat) * BEAT, pan=0.4, gain=0.06)

# Un peu de chaleur : légère saturation, puis normalisation à -3 dBFS.
mix = np.stack([left, right], axis=1)
mix = np.tanh(mix * 1.4) / 1.4
mix *= 0.7 / np.max(np.abs(mix))


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "musique", "ville.ogg")
    out = os.path.normpath(sys.argv[1] if len(sys.argv) > 1 else out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "ville.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((mix * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", out],
                       check=True)
    print("%s : %.1f s, %d mesures à %d à la noire" % (out, N / SR, BARS, BPM))


if __name__ == "__main__":
    main()
