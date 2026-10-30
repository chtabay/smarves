"""Les thèmes musicaux du socle, entièrement synthétisés ici (aucun échantillon extérieur, donc aucun
droit à suivre), de la même famille que la boucle de la ville (tools/musique_ville.py) : jazz léger,
piano électrique, basse ronde. Chaque thème est une boucle sans couture, rangée dans
assets/audio/musique/<thème>.ogg et jouée par Sfx.musique(<thème>) (scripts/sfx.gd).

    python3 tools/musiques.py               # écrit tous les thèmes (ffmpeg requis)
    python3 tools/musiques.py titre         # un seul thème
    python3 tools/musiques.py environs --sortie=/tmp/environs.ogg

- titre : l'écran titre et les menus. 72 à la noire, douze mesures ; nappe de piano électrique en
  accords tenus, contrebasse en blanches, balais à peine posés, une phrase de vibraphone. On attend
  que la soirée commence.
- environs : le bois de Saint-Pierre, le Moulin des Dames, Passelourdin. 84 à la noire, seize mesures ;
  guitare à cordes nylon en arpèges, nappe douce, basse, un shaker discret. Plus d'air qu'en ville.

Les boucles sont encodées en Vorbis q2 (environ 64 kbit/s en stéréo) : moitié moins lourdes que
la ville, sans différence audible à -15 dB sous les bruitages, et légères pour le téléphone.
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
QUALITE = "2"


def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


class Boucle:
    """Une piste stéréo de `mesures` mesures à `bpm` ; ce qui dépasse la fin revient au début."""

    def __init__(self, bpm, mesures, graine, swing=0.0):
        self.beat = 60.0 / bpm
        self.bar = 4 * self.beat
        self.n = int(round(mesures * self.bar * SR))
        self.left = np.zeros(self.n)
        self.right = np.zeros(self.n)
        self.swing = swing
        self.rng = np.random.default_rng(graine)

    def at(self, bar, beat):
        """La position en secondes d'un temps, croches swinguées."""
        frac = beat % 1.0
        return bar * self.bar + (beat + (self.swing if abs(frac - 0.5) < 1e-6 else 0.0)) * self.beat

    def add(self, sig, start, pan=0.0, gain=1.0):
        i = int(round(start * SR)) % self.n
        idx = (np.arange(len(sig)) + i) % self.n
        np.add.at(self.left, idx, sig * gain * np.sqrt(0.5 * (1.0 - pan)))
        np.add.at(self.right, idx, sig * gain * np.sqrt(0.5 * (1.0 + pan)))

    def mix(self, chaleur=1.3, crete=0.7):
        m = np.stack([self.left, self.right], axis=1)
        m = np.tanh(m * chaleur) / chaleur
        return m * (crete / np.max(np.abs(m)))


def passe_bas(x, fc):
    """Un passe-bas circulaire (par la transformée de Fourier) : sans couture pour une boucle."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec *= 1.0 / np.sqrt(1.0 + (f / fc) ** 4)
    return np.fft.irfft(spec, len(x))


# --- Les instruments ----------------------------------------------------------------------------

def rhodes(note, dur, vel=1.0, attaque=0.004, brillance=1.6):
    t = np.arange(int((dur + 1.4) * SR)) / SR
    f = hz(note)
    index = brillance * np.exp(-t * 6.0) + 0.22
    body = np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * f * t) * index)
    tine = np.sin(2 * np.pi * f * 7.0 * t) * np.exp(-t * 18.0) * 0.06
    env = np.minimum(t / attaque, 1.0) * np.exp(-t * 0.9)
    release = np.clip(1.0 - (t - dur) / 0.5, 0.0, 1.0)
    trem = 1.0 + 0.1 * np.sin(2 * np.pi * 4.2 * t)
    return (body + tine) * env * release * trem * vel


def contrebasse(note, dur, vel=1.0):
    t = np.arange(int((dur + 0.3) * SR)) / SR
    f = hz(note)
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) * np.exp(-t * 4.0) \
        + 0.1 * np.sin(6 * np.pi * f * t) * np.exp(-t * 8.0)
    s = np.tanh(s * 1.2)
    env = np.minimum(t / 0.01, 1.0) * np.exp(-t * 1.6) * np.clip(1.0 - (t - dur) / 0.15, 0.0, 1.0)
    return s * env * vel


def vibes(note, vel=1.0):
    t = np.arange(int(2.6 * SR)) / SR
    f = hz(note)
    s = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 6.0)
    env = np.minimum(t / 0.002, 1.0) * np.exp(-t * 1.5) * (1.0 + 0.25 * np.sin(2 * np.pi * 5.0 * t))
    return s * env * vel


def nylon(note, dur, rng, vel=1.0):
    """Une corde pincée (Karplus-Strong), calculée période par période pour rester rapide."""
    f = hz(note)
    p = max(2, int(round(SR / f)))
    n = int((dur + 0.6) * SR)
    blocs = n // p + 2
    y = np.empty(blocs * p)
    bloc = rng.uniform(-1.0, 1.0, p)
    bloc = bloc - bloc.mean()
    # Un pincé un peu feutré : le bruit de départ adouci.
    bloc = 0.5 * (bloc + np.roll(bloc, 1))
    perte = 0.996 ** (440.0 / f)
    for b in range(blocs):
        y[b * p:(b + 1) * p] = bloc
        bloc = perte * 0.5 * (bloc + np.roll(bloc, 1))
    y = y[:n]
    t = np.arange(n) / SR
    env = np.minimum(t / 0.002, 1.0) * np.clip(1.0 - (t - dur) / 0.4, 0.0, 1.0)
    return y * env * vel


def nappe(notes, dur, rng, vel=1.0):
    """Une nappe tenue : quelques sinus légèrement désaccordés par note, montée et descente lentes."""
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for note in notes:
        f = hz(note)
        for d in (-0.12, 0.0, 0.11):
            s += np.sin(2 * np.pi * f * (1.0 + d / 100.0) * t + rng.uniform(0, 2 * np.pi))
        s += 0.15 * np.sin(2 * np.pi * f * 2.0 * t)
    env = np.minimum(t / 1.2, 1.0) * np.clip(1.0 - (t - dur) / 1.5, 0.0, 1.0)
    return s * env * vel / max(1, len(notes))


def balai(rng, dur=0.3, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    bruit = rng.uniform(-1, 1, n)
    bruit = bruit - np.convolve(bruit, np.ones(8) / 8.0, mode="same")
    env = np.sin(np.pi * np.minimum(t / dur, 1.0)) ** 2
    return bruit * env * vel


def shaker(rng, vel=1.0):
    n = int(0.07 * SR)
    t = np.arange(n) / SR
    bruit = rng.uniform(-1, 1, n)
    bruit = bruit - np.convolve(bruit, np.ones(4) / 4.0, mode="same")
    return bruit * np.minimum(t / 0.01, 1.0) * np.exp(-t * 60.0) * vel


def grosse_caisse(vel=1.0):
    t = np.arange(int(0.4 * SR)) / SR
    f = 48.0 + 50.0 * np.exp(-t * 28.0)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8.0) * vel


# --- Les thèmes ---------------------------------------------------------------------------------

def titre():
    """L'écran titre : ré mineur dorien, accords tenus, une soirée qui n'a pas encore commencé."""
    b = Boucle(72.0, 12, graine=1971, swing=0.1)
    DM9 = [50, 53, 57, 60, 64]
    G13 = [43, 53, 57, 59, 64]
    CMAJ9 = [48, 52, 55, 59, 62]
    AM9 = [45, 48, 52, 55, 59]
    BBMAJ7 = [46, 50, 53, 57, 62]
    A7S = [45, 49, 55, 58, 65]
    grille = [DM9, G13, DM9, G13, CMAJ9, AM9, BBMAJ7, A7S, DM9, G13, BBMAJ7, A7S]
    basses = [38, 43, 38, 43, 36, 45, 46, 45, 38, 43, 46, 45]
    for bar, accord in enumerate(grille):
        # Le piano : l'accord posé une fois, légèrement égrené, puis repris doucement au troisième temps.
        for k, note in enumerate(accord[1:] if accord[0] < 47 else accord):
            b.add(rhodes(note + 12 if note < 52 else note, 2.6 * b.beat, 0.9, attaque=0.02, brillance=1.0),
                  b.at(bar, 0.0) + k * 0.018, pan=-0.3 + 0.15 * k, gain=0.05)
        for k, note in enumerate(accord[2:]):
            b.add(rhodes(note, 1.2 * b.beat, 0.55, attaque=0.02, brillance=0.8),
                  b.at(bar, 2.5) + k * 0.012, pan=0.2, gain=0.045)
        # La contrebasse : la fondamentale, puis la quinte ou l'approche de l'accord suivant.
        racine = basses[bar]
        suivante = basses[(bar + 1) % len(basses)]
        b.add(contrebasse(racine, 1.8 * b.beat), b.at(bar, 0.0), gain=0.34)
        b.add(contrebasse(racine + 7 if bar % 2 == 0 else suivante + 1, 1.5 * b.beat, 0.8), b.at(bar, 2.0), gain=0.3)
        # Les balais : un frottement par temps, à peine, et une grosse caisse feutrée sur le un.
        for beat in range(4):
            b.add(balai(b.rng, 0.35 if beat % 2 else 0.5, 1.0 if beat % 2 else 0.7), b.at(bar, beat), pan=0.35, gain=0.03)
        b.add(grosse_caisse(), b.at(bar, 0.0), gain=0.18)
    # Le vibraphone : une phrase dans la deuxième moitié, et sa réponse à la fin.
    for bar, notes in [(4, [(0.5, 76), (1.5, 74), (2.0, 72), (3.0, 69)]), (5, [(1.0, 71), (2.5, 72)]),
                       (9, [(0.5, 77), (1.0, 76), (2.0, 74), (3.5, 72)]), (11, [(0.5, 73), (2.0, 76)])]:
        for beat, note in notes:
            b.add(vibes(note), b.at(bar, beat), pan=0.4, gain=0.055)
    b.left = passe_bas(b.left, 7000.0)
    b.right = passe_bas(b.right, 7000.0)
    return b


def environs():
    """Les environs : sol majeur, arpèges de guitare, plus d'air et presque pas de batterie."""
    b = Boucle(84.0, 16, graine=1984, swing=0.08)
    GMAJ9 = [43, 50, 54, 57, 59]
    CMAJ7 = [48, 52, 55, 59, 64]
    AM7 = [45, 52, 55, 60, 64]
    D9SUS = [50, 55, 57, 60, 64]
    EM9 = [40, 47, 54, 55, 59]
    grille = [GMAJ9, GMAJ9, CMAJ7, CMAJ7, AM7, AM7, D9SUS, D9SUS,
              EM9, EM9, CMAJ7, CMAJ7, AM7, D9SUS, GMAJ9, D9SUS]
    # Les arpèges : basse, puis les cordes du haut en croches, un motif qui tourne sur deux mesures.
    motif = [(0.0, 0), (0.5, 2), (1.0, 3), (1.5, 4), (2.0, 2), (2.5, 3), (3.0, 1), (3.5, 4)]
    motif_b = [(0.0, 0), (0.5, 3), (1.0, 2), (1.5, 4), (2.0, 3), (3.0, 2), (3.5, 1)]
    for bar, accord in enumerate(grille):
        m = motif if bar % 2 == 0 else motif_b
        for beat, k in m:
            note = accord[k] + (12 if k == 0 and accord[0] < 44 else 0)
            vel = 1.0 if beat == 0.0 else (0.7 if beat % 1.0 else 0.82)
            b.add(nylon(note, 1.6 * b.beat, b.rng, vel), b.at(bar, beat), pan=-0.3 + 0.12 * k, gain=0.11)
        # La basse, ronde, sur le un et le trois.
        racine = accord[0] - 12 if accord[0] > 44 else accord[0]
        b.add(contrebasse(racine, 1.7 * b.beat), b.at(bar, 0.0), gain=0.3)
        b.add(contrebasse(racine + 7, 0.9 * b.beat, 0.75), b.at(bar, 2.5), gain=0.26)
        # Le shaker, deux mesures sur quatre, très bas.
        if bar % 4 in (2, 3):
            for e in range(8):
                b.add(shaker(b.rng, 1.0 if e % 2 else 0.6), b.at(bar, e * 0.5), pan=0.45, gain=0.035)
    # La nappe : une note de plus haut, longue, toutes les deux mesures.
    for bar in range(0, 16, 2):
        accord = grille[bar]
        b.add(nappe([n + 12 for n in accord[2:]], 2 * b.bar - 0.5, b.rng, 1.0), b.at(bar, 0.0), gain=0.05)
    # Le vibraphone, deux phrases en sol pentatonique.
    for bar, notes in [(5, [(0.5, 74), (1.5, 76), (2.5, 79), (3.5, 76)]), (6, [(1.0, 74)]),
                       (13, [(0.5, 83), (1.0, 81), (2.0, 79), (3.0, 76)]), (15, [(1.0, 74), (2.5, 78)])]:
        for beat, note in notes:
            b.add(vibes(note, 0.9), b.at(bar, beat), pan=0.35, gain=0.05)
    b.left = passe_bas(b.left, 8000.0)
    b.right = passe_bas(b.right, 8000.0)
    return b


THEMES = {"titre": titre, "environs": environs}


def ecrire(nom, sortie):
    b = THEMES[nom]()
    mix = b.mix()
    os.makedirs(os.path.dirname(sortie), exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, nom + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((mix * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", QUALITE, sortie],
                       check=True)
    print("%s : %.1f s, %d Ko" % (sortie, b.n / SR, os.path.getsize(sortie) // 1024))


def main():
    noms = [a for a in sys.argv[1:] if not a.startswith("--")] or list(THEMES)
    sortie = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--sortie=")), "")
    dossier = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "musique"))
    for nom in noms:
        if nom not in THEMES:
            sys.exit("thème inconnu : %s (thèmes : %s)" % (nom, ", ".join(THEMES)))
        ecrire(nom, sortie if sortie and len(noms) == 1 else os.path.join(dossier, nom + ".ogg"))


if __name__ == "__main__":
    main()
