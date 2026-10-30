"""Les thèmes musicaux du socle, entièrement composés et synthétisés ici (aucun échantillon extérieur,
donc aucun droit à suivre). Deux styles, deux familles de timbres :

- **La ville** (« ville ») : un jazz-funk de grande ville des années 1980, rythmé, qui avance. Boîte à
  rythmes à caisse claire réverbérée, basse au doigt avec ses claquées à l'octave, piano électrique
  en contretemps, cuivres de synthé, cordes, et un chant de synthé qui glisse d'une note à l'autre. Il
  est rangé en trois couches qui tournent ensemble (ville_fond, ville_cuivres, ville_chant) : le fond
  joue toujours, les cuivres et les cordes s'ajoutent quand le joueur a gagné 1 000 crédits, le chant
  à 10 000 (Sfx.COUCHES). La musique de la ville grandit avec la partie.
- **Le calme** (« titre », « environs ») : de la musique de feu de camp, acoustique et lente. Guitare
  folk en arpèges sur une caisse de bois, banjo en roulements, harmonica qui respire et monte un peu
  sur ses notes, sifflet, contrebasse, nappe d'air. « titre » est une valse en mi mineur pour l'écran
  titre ; « environs », en ré majeur, pour le bois, le moulin et les rochers.
- **Les grands espaces** (« grands_espaces ») : épique et ouvert. Quelques notes de piano dans le
  vide, puis les cordes se lèvent, le cor chante, et tout l'orchestre (timbales, cuivres, violons)
  reprend le thème plus haut avant de redescendre. Ré majeur, 72 à la noire, 107 s.
- **Les salons** (« salon ») : une sarabande baroque pour les salons huppés, en ré mineur, l'appui
  sur le deuxième temps ; clavecin et violoncelle, puis les violons ornés, les altos à la tierce.

Ce qui évite le côté mécanique : chaque note bouge un peu dans le temps et dans la force (plus pour la
guitare que pour la boîte à rythmes), les morceaux ont des parties (on entre seul, les instruments
arrivent, le thème passe de l'un à l'autre, des breaks à la fin des parties), les timbres s'ouvrent et
se ferment au fil de la note (une somme d'harmoniques dont la brillance suit une enveloppe), le chant
et l'harmonica glissent entre les notes avec un vibrato qui arrive tard, et tout passe dans une
réverbération de salle. Les niveaux de chaque instrument sont posés par leur intensité mesurée, pas à
l'oreille, et la boucle reste sans couture : tout ce qui dépasse la fin, réverbération comprise,
revient au début.

    python3 tools/musiques.py               # écrit tous les thèmes dans assets/audio/musique/ (ffmpeg requis)
    python3 tools/musiques.py titre         # un seul thème
    python3 tools/musiques.py ville --sortie=/tmp/essai/    # ailleurs, plus le mélange complet (ville.ogg)
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
QUALITE = "0"


def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def db(x):
    return 10.0 ** (x / 20.0)


def rms(x):
    return float(np.sqrt(np.mean(x ** 2)) + 1e-12)


# --- La table de mixage -------------------------------------------------------------------------

class Piste:
    """Une boucle stéréo de `mesures` mesures de `temps` temps à `bpm`, faite de bus (un par instrument),
    chacun avec son envoi vers la réverbération. Ce qui dépasse la fin revient au début."""

    def __init__(self, bpm, mesures, graine, temps=4, swing=0.0):
        self.beat = 60.0 / bpm
        self.temps = temps
        self.bar = temps * self.beat
        self.mesures = mesures
        self.n = int(round(mesures * self.bar * SR))
        self.swing = swing
        self.rng = np.random.default_rng(graine)
        self.bus = {}

    def at(self, bar, beat):
        """La position en secondes d'un temps ; les doubles croches paires en retard de `swing`."""
        frac = (beat * 4.0) % 2.0
        retard = self.swing if abs(frac - 1.0) < 1e-6 else 0.0
        return bar * self.bar + (beat + retard / 4.0) * self.beat

    def add(self, nom, sig, start, pan=0.0, gain=1.0, jeu=0.0, force=0.0):
        """Pose un son sur le bus `nom`. `jeu` : l'écart de temps humain (en secondes, au hasard autour
        de 0) ; `force` : l'écart de force (fraction)."""
        if nom not in self.bus:
            self.bus[nom] = np.zeros((2, self.n))
        if jeu:
            start += self.rng.normal(0.0, jeu)
        if force:
            gain *= max(0.2, 1.0 + self.rng.normal(0.0, force))
        i = int(round(start * SR)) % self.n
        idx = (np.arange(len(sig)) + i) % self.n
        b = self.bus[nom]
        np.add.at(b[0], idx, sig * gain * np.sqrt(0.5 * (1.0 - pan)))
        np.add.at(b[1], idx, sig * gain * np.sqrt(0.5 * (1.0 + pan)))

    def stereo(self, nom, sig, start, gain=1.0):
        """Pose un son déjà stéréo (2, n) sur un bus."""
        if nom not in self.bus:
            self.bus[nom] = np.zeros((2, self.n))
        i = int(round(start * SR)) % self.n
        idx = (np.arange(sig.shape[1]) + i) % self.n
        for c in range(2):
            np.add.at(self.bus[nom][c], idx, sig[c] * gain)


def mixer(piste, niveaux, salle, traitements=None, arrondi=(2500.0, -8.0, 11000.0)):
    """Le mélange d'une piste : chaque bus ramené à son niveau (dB RMS mesuré sur la boucle, comme une
    table qu'on règle au vumètre), traité s'il le faut, puis envoyé à sec et dans la réverbération."""
    sec = np.zeros((2, piste.n))
    envoi = np.zeros((2, piste.n))
    for nom, b in piste.bus.items():
        if nom not in niveaux:
            raise KeyError("bus sans niveau : " + nom)
        niveau, part = niveaux[nom]
        if traitements and nom in traitements:
            b = traitements[nom](b)
        b = b * (db(niveau) / rms(b))
        sec += b
        envoi += b * part
    # Rien sous 42 Hz : le grave ne fait que gonfler, surtout dans des haut-parleurs de téléphone.
    return arrondir(filtre(sec + reverberation(envoi, salle), haut=42.0, pente=3), *arrondi)


def arrondir(x, coude=2500.0, plancher=-8.0, toit=11000.0):
    """Ce qui rend l'oreille tranquille : l'aigu descend en pente douce à partir de `coude` Hz jusqu'à
    `plancher` dB (une étagère, comme un vieil enregistrement ou une bande), et plus rien ne pique au-delà
    de `toit` Hz. Le médium, où vivent les mélodies, n'est pas touché."""
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1.0 / SR)
    s = db(plancher)
    g = s + (1.0 - s) / np.sqrt(1.0 + (f / coude) ** 2)
    g /= np.sqrt(1.0 + (f / toit) ** 4)
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * g, n, axis=-1)


def gain_maitre(mix, cible=-18.0):
    """Le gain qui porte un mélange à `cible` dB RMS (le niveau de l'ancienne boucle de la ville, que
    Sfx.MUSIQUE_DB suppose)."""
    return db(cible) / rms(mix)


def maitre(mix, gain):
    """Une saturation très douce, qui ne fait que tenir les crêtes (plus poussée, elle ajoute des
    harmoniques qui durcissent l'aigu), au même gain pour toutes les couches d'un morceau."""
    return np.tanh(mix * gain * 0.7) / 0.7


# --- Les effets (circulaires : la boucle reste sans couture) -------------------------------------

def filtre(x, bas=None, haut=None, pente=2):
    """Passe-bas à `bas` Hz et passe-haut à `haut` Hz, par la transformée de Fourier, sur toute la
    longueur (circulaire). x : (n,) ou (2, n)."""
    n = x.shape[-1]
    spec = np.fft.rfft(x, axis=-1)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = np.ones_like(f)
    if bas:
        g /= np.sqrt(1.0 + (f / bas) ** (2 * pente))
    if haut:
        g /= np.sqrt(1.0 + (haut / np.maximum(f, 1e-3)) ** (2 * pente))
    return np.fft.irfft(spec * g, n, axis=-1)


def convoluer(x, rep):
    """Convolution circulaire d'un signal (2, n) par une réponse (2, m) ou (m,)."""
    n = x.shape[-1]
    rep = np.atleast_2d(rep)
    if rep.shape[0] == 1:
        rep = np.vstack([rep, rep])
    r = np.zeros((2, n))
    m = min(n, rep.shape[1])
    r[:, :m] = rep[:, :m]
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * np.fft.rfft(r, axis=-1), n, axis=-1)


def reverberation(x, salle):
    """Une salle : premières réflexions, puis une queue de bruit qui décroît et s'assombrit.
    salle = (durée de la queue en s, brillance en Hz, pré-délai en s)."""
    duree, brillance, predelai = salle
    rng = np.random.default_rng(12)
    m = int((duree * 1.3 + predelai) * SR)
    t = np.arange(m) / SR
    rep = np.zeros((2, m))
    for c in range(2):
        bruit = rng.normal(0.0, 1.0, m)
        clair = filtre(bruit, bas=brillance * 0.6)
        sombre = filtre(bruit, bas=brillance * 0.18)
        k = np.exp(-t / (duree * 0.2))
        queue = (clair * k + sombre * (1.0 - k)) * np.exp(-6.9 * t / duree)
        queue *= np.minimum(np.maximum(t - predelai, 0.0) / 0.02, 1.0)
        rep[c] = queue
        for d, g in [(0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.22)]:
            j = int((d + (0.003 * c)) * SR)
            rep[c, j] += g * 30.0
    rep /= np.sqrt(np.sum(rep ** 2) / 2.0)
    return convoluer(x, rep)


def caisse(x, modes, amorti=0.06):
    """Une caisse de résonance (guitare, banjo) : quelques modes amortis ajoutés au son direct."""
    m = int(0.25 * SR)
    t = np.arange(m) / SR
    rep = np.zeros(m)
    rep[0] = 1.0
    for f, g in modes:
        rep += np.sin(2 * np.pi * f * t) * np.exp(-t / amorti) * g * 0.02
    return convoluer(x, rep)


# --- Les timbres --------------------------------------------------------------------------------

def additif(freq, n, brillance, harm=14, impair=1.0, poids=1.0):
    """Une somme d'harmoniques sur une fréquence qui peut varier (tableau ou nombre), dont la brillance
    (tableau ou nombre : le rang où les harmoniques s'éteignent) peut varier aussi : c'est un filtre qui
    s'ouvre et se ferme. `impair` > 1 renforce les harmoniques impairs (anche, carré)."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    b = np.broadcast_to(np.asarray(brillance, dtype=float), (n,))
    s = np.zeros(n)
    fmax = float(np.max(freq))
    for k in range(1, harm + 1):
        if k * fmax > 16000:
            break
        w = (1.0 / k ** poids) * np.exp(-(k - 1) / np.maximum(b, 0.05))
        if k % 2 == 1 and k > 1:
            w = w * impair
        s += np.sin(k * phase) * w
    return s


def enveloppe(n, attaque, chute, tenue, duree, relache):
    t = np.arange(n) / SR
    env = np.minimum(t / max(attaque, 1e-4), 1.0)
    env *= tenue + (1.0 - tenue) * np.exp(-np.maximum(t - attaque, 0.0) / max(chute, 1e-4))
    env *= np.clip(1.0 - (t - duree) / max(relache, 1e-4), 0.0, 1.0)
    return env


def rhodes(note, dur, vel=1.0):
    """Le piano électrique : deux opérateurs FM, la frappe plus brillante quand on joue fort."""
    t = np.arange(int((dur + 1.2) * SR)) / SR
    f = hz(note)
    index = (0.45 + 1.1 * vel) * np.exp(-t * 6.0) + 0.2
    corps = np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * f * t) * index)
    lame = np.sin(2 * np.pi * f * 7.0 * t) * np.exp(-t * 28.0) * 0.035 * vel
    env = np.minimum(t / 0.005, 1.0) * np.exp(-t * 0.9) * np.clip(1.0 - (t - dur) / 0.25, 0.0, 1.0)
    return (corps + lame) * env * (0.4 + 0.6 * vel)


def basse_doigt(note, dur, vel=1.0, claque=False):
    n = int((dur + 0.12) * SR)
    t = np.arange(n) / SR
    b = (2.5 if not claque else 9.0) * np.exp(-t * (9.0 if not claque else 5.0)) + 1.2
    s = additif(hz(note), n, b * (0.6 + 0.6 * vel), harm=12, poids=1.0)
    env = enveloppe(n, 0.004, 0.25, 0.55, dur, 0.06)
    return np.tanh(s * 1.4) * env * vel


def cuivres(notes, dur, rng, vel=1.0):
    """Un coup de cuivres de synthé : des scies désaccordées dont le filtre claque puis se referme."""
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    b = 1.5 + 6.5 * np.minimum(t / 0.03, 1.0) * np.exp(-t * 7.0) + 2.0
    s = np.zeros(n)
    for note in notes:
        for d in (-0.08, 0.07):
            f = hz(note) * (1.0 + d / 100.0) * (1.0 + 0.004 * np.exp(-t * 30.0))
            s += additif(f, n, b * vel, harm=14, poids=1.15)
    env = enveloppe(n, 0.012, 0.12, 0.6, dur, 0.12)
    return s * env / len(notes)


def cordes(notes, dur, rng):
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for note in notes:
        for d in (-0.15, 0.0, 0.13):
            vib = 1.0 + 0.0025 * np.sin(2 * np.pi * (4.8 + rng.uniform(-0.4, 0.4)) * t + rng.uniform(0, 6.28))
            s += additif(hz(note) * (1.0 + d / 100.0) * vib, n, 3.5, harm=10, poids=1.1)
    env = enveloppe(n, 0.6, 1.0, 1.0, dur, 0.9)
    return s * env / len(notes)


def chant(notes, n_total, rng, timbre="synthe"):
    """Une voix qui chante d'une note à l'autre : une seule fréquence qui glisse quand les notes se
    touchent, un vibrato qui arrive tard, une brillance qui suit le souffle. notes = [(début s, durée s,
    note, force)] rangées dans l'ordre, sur une phrase qui commence à 0. Rend (signal, longueur)."""
    notes = [(max(0.0, d), l, note, force) for d, l, note, force in notes]
    fin = max(d + l for d, l, _, _ in notes) + 0.6
    n = int(fin * SR)
    t = np.arange(n) / SR
    freq = np.full(n, hz(notes[0][2]))
    amp = np.zeros(n)
    vib = np.zeros(n)
    souffle = np.zeros(n)
    precedente = None
    for (d, l, note, force) in notes:
        i0, i1 = int(d * SR), min(n, int((d + l) * SR))
        f = hz(note)
        lie = precedente is not None and d - (precedente[0] + precedente[1]) < 0.06
        if timbre == "harmonica":
            depart = f * 2.0 ** (-0.45 / 12.0)
            glisse = 0.09
        else:
            depart = hz(precedente[2]) if lie else f * 2.0 ** (-0.15 / 12.0)
            glisse = 0.06 if lie else 0.03
        g = int(glisse * SR)
        seg = np.arange(i1 - i0)
        freq[i0:i1] = f + (depart - f) * np.exp(-seg / max(g / 3.0, 1.0))
        freq[i1:] = f
        att = 0.012 if lie else {"synthe": 0.02, "archet": 0.14, "cor": 0.09}.get(timbre, 0.05)
        rel = {"synthe": 0.08, "archet": 0.35, "cor": 0.25}.get(timbre, 0.12)
        e = enveloppe(n - i0, att, 0.4, 0.82, l, rel) * force
        amp[i0:] = np.maximum(amp[i0:], e)
        retard = 0.22 if timbre != "harmonica" else 0.3
        vib[i0:i1] = np.clip((seg / SR - retard) / 0.4, 0.0, 1.0) * (1.0 if l > 0.35 else 0.0)
        souffle[i0:i0 + int(0.08 * SR)] += np.linspace(1.0, 0.0, len(souffle[i0:i0 + int(0.08 * SR)])) * force
        precedente = (d, l, note)
    vit = 5.4 + 0.3 * np.sin(2 * np.pi * 0.21 * t)
    if timbre == "synthe":
        freq = freq * (1.0 + 0.0055 * vib * np.sin(2 * np.pi * np.cumsum(vit) / SR))
        s = additif(freq, n, 2.0 + 5.0 * amp, harm=12, poids=1.15, impair=1.15)
        s = s + 0.3 * additif(freq * 2.0 ** (0.07 / 12.0), n, 2.0 + 4.0 * amp, harm=10, poids=1.0)
    elif timbre == "harmonica":
        freq = freq * (1.0 + 0.004 * vib * np.sin(2 * np.pi * np.cumsum(vit) / SR))
        amp = amp * (1.0 + 0.18 * vib * np.sin(2 * np.pi * np.cumsum(vit) / SR))
        s = additif(freq, n, 1.8 + 3.5 * amp, harm=10, poids=1.0, impair=1.35)
        bruit = filtre(rng.normal(0, 1, n), bas=2800, haut=900)
        s = s + bruit * (0.05 * amp + 0.25 * souffle)
    elif timbre == "cor":
        # Le cor : rond quand il joue doux, cuivré quand il force (la brillance suit le souffle).
        freq = freq * (1.0 + 0.0025 * vib * np.sin(2 * np.pi * np.cumsum(vit) / SR))
        s = additif(freq, n, 0.8 + 4.5 * amp ** 2, harm=12, poids=1.3)
        s = s + filtre(rng.normal(0, 1, n), bas=2500, haut=400) * 0.12 * souffle
    elif timbre == "archet":
        # Les cordes frottées : un pupitre de trois, chacun son vibrato, et le frottement de l'archet.
        s = np.zeros(n)
        for k, (d, v) in enumerate([(-0.06, 5.1), (0.0, 5.6), (0.07, 6.0)]):
            ph = np.cumsum(v + 0.25 * np.sin(2 * np.pi * (0.17 + 0.05 * k) * t)) / SR
            fk = freq * (1.0 + d / 100.0) * (1.0 + 0.004 * vib * np.sin(2 * np.pi * ph + k))
            s += additif(fk, n, 2.5 + 2.5 * amp, harm=12, poids=1.1)
        s = s / 3.0 + filtre(rng.normal(0, 1, n), bas=4500, haut=1800) * 0.02 * amp
    else:  # sifflet
        freq = freq * (1.0 + 0.006 * vib * np.sin(2 * np.pi * np.cumsum(vit) / SR))
        s = additif(freq, n, 0.35, harm=3, poids=1.0)
        bruit = filtre(rng.normal(0, 1, n), bas=4500, haut=2000)
        s = s + bruit * (0.06 * amp + 0.15 * souffle)
    return s * amp


def corde(note, dur, rng, vel=1.0, clair=0.5, perte=0.996, pince=0.15):
    """Une corde pincée (Karplus-Strong), calculée période par période. `clair` : la part de bruit
    brillant au départ ; `pince` : où l'on pince la corde (un creux dans le spectre) ; `perte` : la
    tenue (plus près de 1, plus long)."""
    f = hz(note)
    p = max(2, int(round(SR / f)))
    n = int((dur + 0.8) * SR)
    blocs = n // p + 2
    y = np.empty(blocs * p)
    bloc = rng.uniform(-1.0, 1.0, p)
    bloc -= bloc.mean()
    lisse = 0.5 * (bloc + np.roll(bloc, 1))
    bloc = clair * bloc + (1.0 - clair) * lisse
    bloc = bloc - np.roll(bloc, max(1, int(p * pince)))
    perte = perte ** (220.0 / f)
    for k in range(blocs):
        y[k * p:(k + 1) * p] = bloc
        bloc = perte * (0.5 * bloc + 0.5 * np.roll(bloc, 1))
    y = y[:n]
    t = np.arange(n) / SR
    env = np.minimum(t / 0.0015, 1.0) * np.clip(1.0 - (t - dur) / 0.35, 0.0, 1.0)
    return y * env * vel


def contrebasse(note, dur, vel=1.0):
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    s = additif(hz(note), n, 1.0 + 2.5 * np.exp(-t * 6.0), harm=8, poids=1.2)
    env = enveloppe(n, 0.012, 0.35, 0.45, dur, 0.15)
    return np.tanh(s * 1.2) * env * vel


def air(notes, dur, rng):
    """Une nappe d'air : un chœur de sinus très doux et du souffle filtré."""
    n = int((dur + 2.0) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for note in notes:
        for d in (-0.1, 0.12):
            s += np.sin(2 * np.pi * hz(note) * (1 + d / 100) * t + rng.uniform(0, 6.28))
    s += filtre(rng.normal(0, 1, n), bas=1800, haut=500) * 0.25
    env = enveloppe(n, 1.8, 1.0, 1.0, dur, 2.0)
    return s * env / len(notes)


def piano(note, dur, rng, vel=1.0):
    """Un piano : des partiels légèrement étirés (la raideur de la corde), les aigus qui s'éteignent
    vite, le marteau plus brillant quand on joue fort."""
    n = int((dur + 2.5) * SR)
    t = np.arange(n) / SR
    f0 = hz(note)
    s = np.zeros(n)
    for k in range(1, 13):
        fk = f0 * k * np.sqrt(1.0 + 0.0004 * k * k)
        if fk > 15000:
            break
        poids = (1.0 / k ** (1.4 - 0.5 * vel)) * (0.6 if k % 7 == 0 else 1.0)
        s += np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * poids * np.exp(-t * (0.6 + 0.35 * k) * (f0 / 440.0) ** 0.3)
    marteau = filtre(rng.normal(0, 1, n), bas=2000 + 2000 * vel, haut=300) * np.exp(-t * 120.0) * 0.1
    env = np.minimum(t / 0.004, 1.0) * np.clip(1.0 - (t - dur) / 0.4, 0.0, 1.0)
    return (s + marteau) * env * vel


def timbale(note, rng, vel=1.0, roulement=0.0):
    """Une timbale, frappée ou roulée (`roulement` : la durée du roulement, en s)."""
    n = int((roulement + 1.8) * SR)
    t = np.arange(n) / SR
    f = hz(note)
    peau = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.5 * t) + 0.25 * np.sin(2 * np.pi * f * 1.99 * t))
    if roulement:
        env = np.minimum(t / roulement, 1.0) ** 2 * np.exp(-np.maximum(t - roulement, 0) * 3.0)
        env *= 1.0 + 0.3 * np.sin(2 * np.pi * 14.0 * t)
        frappe = filtre(rng.normal(0, 1, n), bas=900) * env * 0.4
    else:
        env = np.exp(-t * 2.8)
        frappe = filtre(rng.normal(0, 1, n), bas=1200) * np.exp(-t * 40.0) * 0.8
    return (peau * env + frappe) * vel


def souffle_cymbale(dur, rng, vel=1.0):
    """Une cymbale frottée qui monte jusqu'au temps fort."""
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    env = np.minimum(t / dur, 1.0) ** 3 * np.exp(-np.maximum(t - dur, 0) * 2.5)
    return filtre(rng.normal(0, 1, n), haut=2500, bas=7000) * env * vel


def clavecin(note, dur, rng, vel=1.0):
    """Un clavecin : la corde pincée par un bec, très claire, et sa corde à l'octave (le quatre-pieds)."""
    a = corde(note, dur, rng, vel, clair=0.7, perte=0.993, pince=0.1)
    b = corde(note + 12, dur, rng, vel * 0.25, clair=0.6, perte=0.99, pince=0.12)
    m = min(len(a), len(b))
    return a[:m] + b[:m]


# La batterie électronique.

def grosse_caisse(rng, vel=1.0):
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 46.0 + 95.0 * np.exp(-t * 32.0)
    corps = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    clic = filtre(rng.normal(0, 1, n), bas=1800) * np.exp(-t * 300.0) * 0.35
    return np.tanh((corps + clic) * 1.5) * vel


def caisse_claire(rng, vel=1.0):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    ton = (np.sin(2 * np.pi * 185 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t * 28.0)
    timbre = filtre(rng.normal(0, 1, n), bas=5000, haut=1200) * np.exp(-t * 16.0)
    return (ton * 0.6 + timbre) * vel


def charleston(rng, ouvert=False, vel=1.0):
    n = int((0.32 if ouvert else 0.06) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0):
        s += np.sign(np.sin(2 * np.pi * f * 1.9 * t + rng.uniform(0, 6.28)))
    s = filtre(s + rng.normal(0, 0.6, n), haut=5000, bas=9000)
    # Une attaque de 3 ms : la baguette effleure plutôt qu'elle ne claque.
    return s * np.minimum(t / 0.003, 1.0) * np.exp(-t * (9.0 if ouvert else 60.0)) * vel


def clap(rng, vel=1.0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    env = np.zeros(n)
    for d in (0.0, 0.009, 0.018):
        env += np.exp(-np.maximum(t - d, 0) * 120.0) * (t >= d)
    env += np.exp(-np.maximum(t - 0.026, 0) * 18.0) * (t >= 0.026) * 0.6
    return filtre(rng.normal(0, 1, n), bas=3200, haut=800) * env * vel


def tom(note, rng, vel=1.0):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = hz(note) * (1.0 + 0.5 * np.exp(-t * 25.0))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.0) * vel


def shaker(rng, vel=1.0):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    return filtre(rng.normal(0, 1, n), haut=3500, bas=7500) * np.minimum(t / 0.02, 1) * np.exp(-t * 40) * vel


def pas(rng, vel=1.0):
    """Un pied qui bat la mesure sur un plancher."""
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    corps = np.sin(2 * np.pi * np.cumsum(70 + 40 * np.exp(-t * 40)) / SR) * np.exp(-t * 14)
    bois = filtre(rng.normal(0, 1, n), bas=1200, haut=200) * np.exp(-t * 40)
    return (corps + bois * 0.6) * vel


# --- La ville : un jazz-funk de grande ville ---------------------------------------------------

# Les voicings du piano (sans fondamentale, elle est à la basse) et la basse de chaque demi-mesure.
FMAJ9 = [57, 60, 64, 67]
EM7 = [55, 59, 62, 64]
A13 = [55, 59, 61, 66]
DM9 = [53, 57, 60, 64]
CM9 = [55, 58, 62, 63]
F13 = [57, 62, 63, 67]
BBMAJ9 = [57, 60, 62, 65]
AM7 = [55, 60, 64, 67]
D9 = [54, 57, 60, 64]
GM9 = [53, 57, 58, 62]
C11 = [58, 62, 65, 69]
C13 = [58, 64, 67, 69]
C_BB = [55, 60, 64, 67]
GM7 = [58, 62, 65, 69]
C9 = [58, 62, 64, 67]
F_A = [60, 64, 65, 69]
BB69 = [55, 58, 62, 65]

# (accord, basse) par demi-mesure.
COUPLET = [(FMAJ9, 41), (FMAJ9, 41), (EM7, 40), (A13, 45), (DM9, 38), (DM9, 38), (CM9, 36), (F13, 41),
           (BBMAJ9, 46), (BBMAJ9, 46), (AM7, 45), (D9, 38), (GM9, 43), (GM9, 43), (C11, 36), (C13, 36)]
REFRAIN = [(BBMAJ9, 46), (BBMAJ9, 46), (C_BB, 46), (C_BB, 46), (AM7, 45), (AM7, 45), (DM9, 38), (DM9, 38),
           (GM7, 43), (GM7, 43), (C9, 36), (C9, 36), (F_A, 45), (F_A, 45), (BB69, 46), (C11, 36)]

# Le chant : (temps, durée, note) par mesure.
CHANT_COUPLET = [
    [(1.5, .5, 69), (2, .5, 72), (2.5, 1.5, 76)],
    [(0, .5, 74), (.5, .5, 72), (1, 1, 74), (2.5, .5, 73), (3, 1, 76)],
    [(.5, .5, 77), (1, .5, 76), (1.5, .5, 74), (2, 2, 76)],
    [(0, .5, 75), (.5, .5, 74), (1, 1, 72), (2.5, .5, 70), (3, 1, 74)],
    [(1.5, .5, 69), (2, .5, 72), (2.5, 1.5, 77)],
    [(0, .5, 76), (.5, .5, 74), (1, 1, 72), (2.5, .5, 78), (3, 1, 74)],
    [(.5, 1, 77), (1.5, .5, 74), (2, 1, 70), (3, 1, 69)],
    [(0, 2, 72), (2.5, .5, 70), (3, .5, 67), (3.5, .5, 64)],
]
CHANT_REFRAIN = [
    [(0, 1.5, 81), (1.5, .5, 79), (2, 1, 77), (3, 1, 76)],
    [(0, .5, 77), (.5, 1.5, 79), (2.5, .5, 76), (3, 1, 72)],
    [(0, 1, 76), (1, .5, 79), (1.5, 1.5, 81), (3, 1, 79)],
    [(0, 2.5, 77), (3, .5, 76), (3.5, .5, 74)],
    [(0, 1, 74), (1, .5, 77), (1.5, 1, 82), (2.5, 1.5, 81)],
    [(0, 1, 79), (1, 1, 76), (2, .5, 74), (2.5, 1.5, 76)],
    [(0, 1.5, 77), (1.5, .5, 76), (2, 1, 72), (3, 1, 69)],
    [(0, 1, 70), (1, 1, 74), (2, 2, 79)],
]
# La reprise du refrain : la même mélodie, ornée, plus haut à la fin.
CHANT_REPRISE = [list(m) for m in CHANT_REFRAIN]
CHANT_REPRISE[3] = [(0, 1, 77), (1, .5, 79), (1.5, .5, 77), (2, 1, 76), (3, .5, 77), (3.5, .5, 79)]
CHANT_REPRISE[7] = [(0, .5, 81), (.5, .5, 82), (1, 1, 84), (2, .5, 82), (2.5, .5, 81), (3, 1, 79)]

# La basse : (double croche, durée en doubles croches, intervalle, force, claquée).
GROOVE = [(0, 2, 0, 1.0, False), (3, 1, 0, 0.55, False), (4, 1, 12, 0.85, True), (6, 1, 7, 0.75, False)]
GROOVE_B = [(0, 3, 0, 1.0, False), (3, 1, 12, 0.8, True), (5, 1, 10, 0.6, False), (6, 2, 7, 0.75, False)]


def ville():
    """Trois couches qui tournent ensemble : (fond, cuivres, chant), 32 mesures à 106."""
    graine = 1987
    couches = [Piste(106.0, 32, graine + k, swing=0.06) for k in range(3)]
    fond, plus, voix = couches
    rng = fond.rng

    def grille(bar):
        partie = bar // 8
        return (COUPLET if partie < 2 else REFRAIN), bar % 8

    for bar in range(32):
        g, m = grille(bar)
        partie = bar // 8
        fin_de_partie = m == 7
        # La batterie : grosse caisse qui syncope, caisse claire sur 2 et 4 (et ses fantômes), charleston
        # en doubles croches accentuées, ouvert sur le « et » du 4 une mesure sur deux.
        kicks = [0, 6, 10] if m % 2 == 0 else [0, 3, 8, 10]
        if fin_de_partie:
            kicks = [0, 6, 8]
        for s in kicks:
            fond.add("gc", grosse_caisse(rng, 1.0 if s == 0 else 0.85), fond.at(bar, s / 4), jeu=0.002, force=0.05)
        for s in (4, 12):
            fond.add("cc", caisse_claire(rng), fond.at(bar, s / 4), pan=0.05, jeu=0.003, force=0.04)
            fond.add("clap", clap(rng), fond.at(bar, s / 4) + 0.004, pan=-0.1, jeu=0.002)
        for s in (7, 15) if m % 2 else (9,):
            if not (fin_de_partie and s > 11):
                fond.add("cc", caisse_claire(rng, 0.18), fond.at(bar, s / 4), pan=0.05, jeu=0.006, force=0.3)
        for s in range(16):
            if fin_de_partie and s >= 12:
                break
            ouvert = s == 14 and m % 2 == 1
            vel = 1.0 if s % 4 == 0 else (0.75 if s % 2 == 0 else 0.45)
            fond.add("hh", charleston(rng, ouvert, vel), fond.at(bar, s / 4), pan=0.3, jeu=0.003, force=0.12)
        if fin_de_partie:
            # Le break : quatre toms qui descendent, et la caisse claire qui relance.
            for k, (s, note) in enumerate([(12, 50), (13, 47), (14, 43), (15, 40)]):
                fond.add("toms", tom(note, rng), fond.at(bar, s / 4), pan=0.4 - 0.25 * k, jeu=0.003, force=0.08)
        # La basse : un motif par demi-mesure, l'approche chromatique de la fondamentale suivante.
        for demi in range(2):
            accord, racine = g[m * 2 + demi]
            suivante = g[(m * 2 + demi + 1) % 16][1] if not (m == 7 and demi == 1) else \
                (REFRAIN if partie in (1, 2) else COUPLET)[0][1]
            motif = GROOVE if (bar + demi) % 2 == 0 else GROOVE_B
            for s, l, iv, vel, cl in motif:
                fond.add("basse", basse_doigt(racine + iv, l * fond.beat / 4, vel, cl),
                         fond.at(bar, (demi * 8 + s) / 4), jeu=0.004, force=0.06)
            if suivante != racine and not fin_de_partie:
                approche = suivante + (1 if suivante < racine else -1)
                fond.add("basse", basse_doigt(approche, fond.beat / 4, 0.6), fond.at(bar, (demi * 8 + 7) / 4), jeu=0.004)
        # Le piano électrique : des accords en contretemps, la voix du haut plus douce.
        for demi in range(2):
            accord, _ = g[m * 2 + demi]
            coups = [(0, 3, 0.85), (3, 2, 0.6), (6, 2, 0.7)] if demi == 0 else [(2, 2, 0.7), (6, 2, 0.6)]
            if fin_de_partie and demi == 1:
                coups = [(2, 6, 0.8)]
            for s, l, vel in coups:
                for k, note in enumerate(accord):
                    fond.add("ep", rhodes(note, l * fond.beat / 4, vel * (0.8 if k == 3 else 1.0)),
                             fond.at(bar, (demi * 8 + s) / 4) + k * 0.004, pan=-0.35 + 0.18 * k, jeu=0.006, force=0.08)
        # La couche des cuivres et des cordes, à partir de la deuxième partie.
        if partie >= 1:
            accord, _ = g[m * 2]
            haut = [n + 12 for n in accord[1:]]
            if partie == 1:
                for s in (6, 14) if m % 2 == 0 else (6,):
                    plus.add("cuivres", cuivres(haut, 0.16, rng, 0.9), plus.at(bar, s / 4), pan=0.15, jeu=0.004, force=0.06)
            else:
                plus.add("cordes", cordes([n + 12 for n in accord], plus.bar * 0.98, rng), plus.at(bar, 0), pan=-0.1)
                if m % 2 == 1:
                    plus.add("cuivres", cuivres(haut, 0.14, rng, 1.0), plus.at(bar, 10 / 4), pan=0.15, jeu=0.004)
                    plus.add("cuivres", cuivres(haut, 0.32, rng, 1.0), plus.at(bar, 14 / 4), pan=0.15, jeu=0.004)
            if fin_de_partie:
                # Le riff qui ferme une partie, avec les toms.
                for s, iv, l in [(12, 0, 0.12), (13, 2, 0.12), (14, 3, 0.12), (15, 5, 0.3)]:
                    plus.add("cuivres", cuivres([n + iv for n in haut], l, rng, 1.0), plus.at(bar, s / 4), pan=0.15, jeu=0.003)
            plus.add("conga", tom(62 if m % 2 else 65, rng, 0.6), plus.at(bar, 3 / 4), pan=-0.5, jeu=0.005, force=0.2)
            plus.add("conga", tom(58, rng, 0.5), plus.at(bar, 11 / 4), pan=-0.5, jeu=0.005, force=0.2)
    # Le chant, une phrase par partie : le couplet (deuxième partie), le refrain, puis sa reprise.
    for partie, phrases in [(1, CHANT_COUPLET), (2, CHANT_REFRAIN), (3, CHANT_REPRISE)]:
        notes = []
        for m, mesure in enumerate(phrases):
            for beat, l, note in mesure:
                d = voix.at(m, beat) + voix.rng.normal(0.0, 0.008)
                notes.append((d, l * voix.beat * 0.95, note, 0.8 + 0.2 * voix.rng.random()))
        voix.add("chant", chant(notes, 0, voix.rng, "synthe"), voix.at(partie * 8, 0), pan=0.0)
        if partie == 3:
            # La reprise est doublée à l'octave, très bas.
            voix.add("chant_oct", chant([(d, l, n - 12, f) for d, l, n, f in notes], 0, voix.rng, "synthe"),
                     voix.at(partie * 8, 0), pan=0.0)
    niveaux = {
        "gc": (-17.0, 0.05), "cc": (-21.0, 0.45), "clap": (-27.0, 0.4), "hh": (-28.0, 0.08),
        "toms": (-27.0, 0.25), "basse": (-17.0, 0.0), "ep": (-20.0, 0.2),
        "cuivres": (-24.0, 0.25), "cordes": (-27.0, 0.35), "conga": (-31.0, 0.2),
        "chant": (-20.0, 0.3), "chant_oct": (-30.0, 0.3),
    }
    salle = (1.6, 7000.0, 0.02)
    mixes = [mixer(p, niveaux, salle) for p in couches]
    total = mixes[0] + mixes[1] + mixes[2]
    gain = gain_maitre(total)
    return {"ville_fond": maitre(mixes[0], gain), "ville_cuivres": maitre(mixes[1], gain),
            "ville_chant": maitre(mixes[2], gain), "ville": maitre(total, gain)}


# --- Le calme : de la musique de feu de camp ---------------------------------------------------

def arpege_guitare(p, bar, accord, motif, vel=1.0):
    """La guitare en arpèges, le pouce sur les basses : motif = [(temps, corde)]. Chaque note a son
    retard et sa force, et la corde d'avant sonne encore."""
    for beat, k in motif:
        note = accord[min(k, len(accord) - 1)]
        v = vel * (1.0 if k == 0 else 0.7) * (1.0 if beat % 1.0 == 0 else 0.85)
        p.add("guitare", corde(note, p.beat * 2.5, p.rng, v, clair=0.45, perte=0.9975, pince=0.18),
              p.at(bar, beat), pan=-0.35 + 0.11 * k, jeu=0.012, force=0.12)


def roulement_banjo(p, bar, haut, motif, vel=1.0):
    for beat, k in motif:
        note = haut[k]
        p.add("banjo", corde(note, p.beat * 0.9, p.rng, vel * (0.9 if beat % 1 else 1.0), clair=0.65, perte=0.985, pince=0.12),
              p.at(bar, beat), pan=0.35, jeu=0.006, force=0.1)


def titre():
    """L'écran titre : une valse en mi mineur, 32 mesures à 84. La guitare entre seule, le banjo et
    la contrebasse la rejoignent, puis l'harmonica chante, et l'air monte à la fin."""
    p = Piste(84.0, 32, graine=1971, temps=3)
    EM = [40, 47, 52, 55, 59, 64]
    EM_D = [38, 47, 52, 55, 59, 64]
    CMAJ7 = [36, 48, 52, 55, 59, 64]
    G_B = [35, 47, 50, 55, 59, 62]
    AM7 = [33, 45, 52, 55, 60, 64]
    C = [36, 48, 52, 55, 60, 64]
    D = [38, 45, 50, 57, 62, 66]
    DSUS = [38, 45, 50, 57, 62, 67]
    G = [31, 47, 50, 55, 59, 67]
    ASUS2 = [33, 45, 52, 57, 59, 64]
    A = [
        EM, EM_D, CMAJ7, G_B, AM7, C, D, DSUS,
        EM, EM_D, CMAJ7, G_B, AM7, C, D, DSUS,
        C, G_B, AM7, EM, C, G, ASUS2, D,
        EM, EM_D, CMAJ7, G_B, AM7, C, D, DSUS,
    ]
    MOTIF = [(0, 0), (0.5, 4), (1, 2), (1.5, 5), (2, 3), (2.5, 4)]
    MOTIF_B = [(0, 0), (0.5, 3), (1, 4), (1.5, 5), (2, 1), (2.5, 4)]
    HARMONICA = [
        [(0, 1.5, 67), (1.5, .5, 69), (2, 1, 71)], [(0, 2, 74), (2, 1, 71)], [(0, 1, 72), (1, 1, 71), (2, 1, 69)],
        [(0, 3, 67)], [(0, 1, 64), (1, 1, 67), (2, 1, 72)], [(0, 2, 71), (2, .5, 69), (2.5, .5, 67)],
        [(0, 3, 69)], [(0, 1, 66), (1, 2, 69)],
        [(0, 1, 71), (1, 1, 74), (2, 1, 76)], [(0, 2, 79), (2, 1, 78)], [(0, 1, 76), (1, 1, 74), (2, 1, 71)],
        [(0, 3, 74)], [(0, 1, 72), (1, .5, 71), (1.5, .5, 69), (2, 1, 67)], [(0, 2, 64), (2, 1, 67)],
        [(0, 1.5, 66), (1.5, 1.5, 69)], [(0, 1.5, 67), (1.5, 1.5, 66)],
    ]
    for bar, accord in enumerate(A):
        partie = bar // 8
        motif = MOTIF if bar % 2 == 0 else MOTIF_B
        if bar == 7 or bar == 31:
            motif = [(0, 0), (0.5, 4), (1, 5), (2, 3)]
        arpege_guitare(p, bar, accord, motif, 0.85 if partie == 0 else 1.0)
        if partie >= 1:
            # La contrebasse : la fondamentale sur le un, la quinte sur le trois, parfois une approche.
            p.add("basse", contrebasse(accord[0] + 12, p.beat * 1.6, 0.9), p.at(bar, 0), jeu=0.01, force=0.08)
            p.add("basse", contrebasse(accord[0] + 19 if accord[0] + 19 < 60 else accord[0] + 7, p.beat * 0.9, 0.7),
                  p.at(bar, 2), jeu=0.01, force=0.1)
            p.add("pied", pas(p.rng, 0.8), p.at(bar, 0), jeu=0.008, force=0.15)
        if partie in (1, 3) and bar not in (15, 31):
            haut = [accord[-3] + 12, accord[-2] + 12, accord[-1] + 12, 79]
            roulement_banjo(p, bar, haut, [(0, 2), (0.5, 1), (1, 3), (1.5, 2), (2, 1), (2.5, 3)], 0.8)
        if partie == 3:
            p.add("air", air([n + 12 for n in accord[2:5]], p.bar, p.rng), p.at(bar, 0))
    # L'harmonica : la troisième partie, puis la dernière, qui monte.
    notes = []
    for m, mesure in enumerate(HARMONICA):
        for beat, l, note in mesure:
            notes.append((p.at(16 + m, beat) - p.at(16, 0) + p.rng.normal(0, 0.015),
                          l * p.beat * 0.97, note, 0.75 + 0.25 * p.rng.random()))
    p.add("harmonica", chant(notes, 0, p.rng, "harmonica"), p.at(16, 0), pan=0.1)
    niveaux = {"guitare": (-17.0, 0.25), "banjo": (-25.0, 0.3), "basse": (-23.0, 0.1), "pied": (-32.0, 0.15),
               "harmonica": (-19.0, 0.35), "air": (-31.0, 0.6)}
    traitements = {
        "guitare": lambda b: caisse(filtre(b, bas=7000, haut=110), [(98, 0.5), (196, 0.6), (240, 0.5), (410, 0.4)], 0.05),
        "banjo": lambda b: caisse(filtre(b, haut=180), [(310, 1.0), (620, 0.7), (1240, 0.5)], 0.02),
    }
    mix = mixer(p, niveaux, (2.4, 5500.0, 0.03), traitements)
    return {"titre": maitre(mix, gain_maitre(mix))}


def environs():
    """Les environs : le chemin du bois, en ré majeur, 24 mesures à 92. Guitare et banjo, le sifflet qui
    mène, l'harmonica qui répond, un pied sur le plancher et un shaker."""
    p = Piste(92.0, 24, graine=1984, temps=4, swing=0.1)
    D_ = [38, 45, 50, 57, 62, 66]
    G_D = [38, 43, 50, 55, 59, 67]
    BM = [35, 42, 47, 54, 59, 62]
    G = [31, 43, 50, 55, 59, 67]
    A = [33, 45, 52, 57, 61, 64]
    ASUS = [33, 45, 52, 57, 62, 64]
    D_FS = [30, 42, 50, 57, 62, 66]
    EM = [28, 40, 47, 52, 55, 59]
    EM7 = [28, 40, 47, 50, 55, 59]
    GRILLE = [D_, D_, G_D, D_, BM, G, A, A,
              G, D_FS, EM, A, G, D_FS, EM7, ASUS,
              BM, G, D_, A, BM, G, ASUS, A]
    SIFFLET = [
        [(0, 1, 71), (1, 1, 74), (2, 2, 79)], [(0, 1.5, 78), (1.5, .5, 76), (2, 2, 74)],
        [(0, 1, 76), (1, 1, 79), (2, 1, 78), (3, 1, 76)], [(0, 3, 73), (3, 1, 76)],
        [(0, 1, 74), (1, 1, 71), (2, 2, 67)], [(0, 1, 69), (1, 1, 74), (2, 2, 78)],
        [(0, 2, 76), (2, 1, 74), (3, 1, 73)], [(0, 2, 74), (2, 2, 73)],
    ]
    HARMONICA = [
        [(0, 1, 66), (1, 1, 69), (2, 2, 71)], [(0, 2, 74), (2, 1, 71), (3, 1, 69)],
        [(0, 3, 66), (3, 1, 69)], [(0, 2, 64), (2, 2, 61)],
        [(0, 1, 62), (1, 1, 66), (2, 2, 71)], [(0, 1.5, 74), (1.5, .5, 73), (2, 2, 71)],
        [(0, 4, 69)], [(0, 2, 73), (2, 2, 76)],
    ]
    for bar, accord in enumerate(GRILLE):
        partie = bar // 8
        # La guitare : un battement folk, basse sur 1 et 3, accords grattés en croches swinguées.
        for beat in (0, 2):
            k = 0 if beat == 0 else 1
            p.add("guitare", corde(accord[k] + (12 if accord[k] < 36 else 0), p.beat * 1.5, p.rng, 1.0, 0.4, 0.997, 0.2),
                  p.at(bar, beat), pan=-0.3, jeu=0.01, force=0.1)
        for beat, sens, vel in [(1, 1, 0.8), (1.5, -1, 0.5), (2.5, -1, 0.45), (3, 1, 0.75), (3.5, -1, 0.5)]:
            cordes_grattees = accord[2:] if sens > 0 else accord[:2:-1]
            for j, note in enumerate(cordes_grattees):
                p.add("guitare", corde(note, p.beat * 0.6, p.rng, vel * 0.6, 0.5, 0.996, 0.25),
                      p.at(bar, beat) + j * 0.007, pan=-0.3 + 0.05 * j, jeu=0.008, force=0.1)
        # Le banjo, en roulements vers l'avant, dès la première partie mais plus présent ensuite.
        haut = [accord[-3] + 12, accord[-2] + 12, accord[-1] + 12, 79]
        roll = [(0, 2), (0.5, 1), (1, 3), (1.5, 2), (2, 1), (2.5, 3), (3, 2), (3.5, 0)]
        if bar % 8 == 7:
            roll = roll[:5]
        roulement_banjo(p, bar, haut, roll, 0.7 if partie == 0 else 0.9)
        # La contrebasse et le pied, le shaker à partir de la deuxième partie.
        racine = accord[0] + (12 if accord[0] < 36 else 0)
        p.add("basse", contrebasse(racine, p.beat * 1.7, 0.9), p.at(bar, 0), jeu=0.008, force=0.08)
        p.add("basse", contrebasse(racine + 7 if racine + 7 < 52 else racine - 5, p.beat * 1.5, 0.75), p.at(bar, 2), jeu=0.008)
        for beat in (0, 2):
            p.add("pied", pas(p.rng, 1.0 if beat == 0 else 0.8), p.at(bar, beat), jeu=0.008, force=0.1)
        if partie >= 1:
            for e in range(8):
                p.add("shaker", shaker(p.rng, 1.0 if e % 2 else 0.6), p.at(bar, e * 0.5), pan=0.5, jeu=0.006, force=0.15)
    for debut, phrase, timbre in [(8, SIFFLET, "sifflet"), (16, HARMONICA, "harmonica")]:
        notes = []
        for m, mesure in enumerate(phrase):
            for beat, l, note in mesure:
                notes.append((p.at(debut + m, beat) - p.at(debut, 0) + p.rng.normal(0, 0.012), l * p.beat * 0.95,
                              note, 0.75 + 0.25 * p.rng.random()))
        p.add(timbre, chant(notes, 0, p.rng, timbre), p.at(debut, 0), pan=0.12)
    niveaux = {"guitare": (-18.0, 0.2), "banjo": (-21.0, 0.25), "basse": (-22.0, 0.05), "pied": (-29.0, 0.1),
               "shaker": (-32.0, 0.1), "sifflet": (-21.0, 0.4), "harmonica": (-20.0, 0.35)}
    traitements = {
        "guitare": lambda b: caisse(filtre(b, bas=7500, haut=110), [(98, 0.5), (196, 0.6), (240, 0.5), (410, 0.4)], 0.05),
        "banjo": lambda b: caisse(filtre(b, haut=180), [(310, 1.0), (620, 0.7), (1240, 0.5)], 0.02),
    }
    mix = mixer(p, niveaux, (1.8, 6000.0, 0.025), traitements)
    return {"environs": maitre(mix, gain_maitre(mix))}


# --- Les grands espaces : une plaine, un ciel, une chevauchée ---------------------------------

def phrase(p, mesures, depart, transpose=0, jeu=0.012):
    """Les notes d'une mélodie écrite par mesure [(temps, durée, note)], à partir de la mesure `depart`,
    en secondes depuis le début de la phrase."""
    notes = []
    for m, mesure in enumerate(mesures):
        for beat, l, note in mesure:
            notes.append((p.at(depart + m, beat) - p.at(depart, 0) + p.rng.normal(0, jeu), l * p.beat * 0.97,
                          note + transpose, 0.8 + 0.2 * p.rng.random()))
    return notes


def grands_espaces():
    """Les grands espaces : ré majeur, 32 mesures à 72. Le piano seul, quelques notes dans le vide ; les
    cordes se lèvent et le cor chante ; tout l'orchestre, timbales et cuivres, reprend le thème plus
    haut ; puis tout redescend vers le piano."""
    p = Piste(72.0, 32, graine=1986)
    D = [50, 57, 62, 66, 69]
    D_FS = [42, 57, 62, 66, 69]
    G = [43, 55, 59, 62, 66]
    EM7 = [40, 55, 59, 62, 67]
    BM = [47, 54, 59, 62, 66]
    ASUS = [45, 57, 62, 64, 69]
    A = [45, 57, 61, 64, 69]
    GMAJ7_A = [45, 55, 59, 62, 66]
    GRILLE = [D, D_FS, G, EM7, BM, G, ASUS, A] * 2 + [BM, G, D, A, BM, G, GMAJ7_A, A] + [D, D_FS, G, EM7, BM, G, ASUS, A]
    PIANO = [
        [(0.5, 74), (2, 81)], [(1, 78), (3.5, 76)], [(0, 79), (1.5, 74)], [(2, 71)],
        [(0.5, 78), (1, 74), (2.5, 73)], [(1, 79)], [(0, 81), (0.5, 76), (3, 74)], [(2, 69), (2.5, 73)],
    ]
    COR = [
        [(0, 2, 62), (2, 1, 66), (3, 1, 69)], [(0, 3, 74), (3, 1, 73)], [(0, 2, 71), (2, 2, 67)],
        [(0, 3, 69), (3, 1, 66)], [(0, 2, 66), (2, 1, 69), (3, 1, 71)], [(0, 3, 74), (3, 1, 76)],
        [(0, 4, 74)], [(0, 2, 73), (2, 2, 69)],
    ]
    SOMMET = [
        [(0, 1, 74), (1, 1, 78), (2, 2, 81)], [(0, 3, 79), (3, 1, 78)], [(0, 2, 74), (2, 1, 76), (3, 1, 78)],
        [(0, 4, 76)], [(0, 1, 78), (1, 1, 81), (2, 2, 86)], [(0, 2, 83), (2, 1, 81), (3, 1, 79)],
        [(0, 3, 81), (3, 1, 79)], [(0, 2, 78), (2, 2, 76)],
    ]
    for bar, accord in enumerate(GRILLE):
        partie = bar // 8
        m = bar % 8
        # Le piano : quelques notes posées, du silence autour ; à la reprise, plus bas et plus rares.
        if partie in (0, 3):
            for beat, note in PIANO[m]:
                if partie == 3 and m % 2 == 1 and beat > 1:
                    continue
                p.add("piano", piano(note - (12 if partie == 3 and m < 4 else 0), p.beat * 1.5, p.rng, 0.55 + 0.25 * p.rng.random()),
                      p.at(bar, beat), pan=0.15 * np.sin(note), jeu=0.02, force=0.1)
            if m % 2 == 0:
                p.add("piano", piano(accord[0] - 12 if accord[0] > 45 else accord[0], p.bar * 1.6, p.rng, 0.45), p.at(bar, 0), pan=-0.2, jeu=0.015)
            p.add("air", air(accord[1:4], p.bar, p.rng), p.at(bar, 0))
        if partie == 1:
            # Le piano en arpèges lents sous le cor.
            for k, beat in enumerate((0, 1, 2, 3)):
                p.add("piano", piano(accord[1 + k % 4], p.beat * 1.8, p.rng, 0.45), p.at(bar, beat + 0.5), pan=0.2, jeu=0.015, force=0.1)
        # Les cordes : une nappe qui se lève dans la deuxième partie, pleine dans la troisième.
        if partie in (1, 2) or (partie == 3 and m < 2):
            vel = 0.55 if partie == 1 else 1.0
            for k, note in enumerate(accord[1:]):
                notes = [(0.0, p.bar * 0.98, note, vel)]
                p.add("cordes", chant(notes, 0, p.rng, "archet"), p.at(bar, 0), pan=-0.4 + 0.25 * k, jeu=0.01)
            p.add("violoncelles", chant([(0.0, p.bar * 0.98, accord[0] if accord[0] < 48 else accord[0] - 12, vel)], 0, p.rng, "archet"),
                  p.at(bar, 0), pan=0.3)
        if partie == 2:
            # Les cuivres en accords tenus, les timbales sur le un, et le roulement qui ramène le sommet.
            for k, note in enumerate(accord[2:5]):
                p.add("cuivres", chant([(0.0, p.bar * 0.9, note, 0.9)], 0, p.rng, "cor"), p.at(bar, 0), pan=-0.2 + 0.2 * k, jeu=0.008)
            p.add("timbales", timbale(38 if accord[0] in (50, 42, 38) else 45, p.rng), p.at(bar, 0), jeu=0.004)
            if m in (3, 7):
                p.add("timbales", timbale(45, p.rng, 0.7, roulement=p.beat * 1.8), p.at(bar, 2), jeu=0.004)
        if bar == 15:
            p.add("cymbale", souffle_cymbale(p.bar, p.rng), p.at(bar, 0))
            p.add("timbales", timbale(45, p.rng, 0.9, roulement=p.bar * 0.95), p.at(bar, 0))
    p.add("cor", chant(phrase(p, COR, 8), 0, p.rng, "cor"), p.at(8, 0), pan=0.1)
    # Le sommet : cor et violons à l'unisson, dans le médium. Une octave plus haut, les violons sifflaient.
    p.add("cor", chant(phrase(p, SOMMET, 16, -12), 0, p.rng, "cor"), p.at(16, 0), pan=0.1)
    p.add("violons", chant(phrase(p, SOMMET, 16, -12, 0.008), 0, p.rng, "archet"), p.at(16, 0), pan=-0.15)
    niveaux = {"piano": (-19.0, 0.5), "air": (-35.0, 0.7), "cordes": (-21.0, 0.5), "violoncelles": (-24.0, 0.45),
               "cuivres": (-23.0, 0.5), "timbales": (-22.0, 0.45), "cymbale": (-30.0, 0.6),
               "cor": (-19.0, 0.5), "violons": (-19.0, 0.5)}
    # Une grande salle mais sombre, et l'aigu plus tôt couché que dans les autres thèmes.
    mix = mixer(p, niveaux, (3.2, 3500.0, 0.04), arrondi=(1600.0, -13.0, 7500.0))
    return {"grands_espaces": maitre(mix, gain_maitre(mix))}


# --- Les salons : une sarabande ----------------------------------------------------------------

def salon():
    """Les salons huppés : une sarabande en ré mineur, 24 mesures à 3 temps, 63 à la noire, l'appui sur
    le deuxième temps. Le clavecin et le violoncelle exposent le thème ; les violons le reprennent,
    ornés, le clavecin en accords ; la seconde partie passe en fa majeur, les altos à la tierce, et
    revient en ré mineur."""
    p = Piste(63.0, 24, graine=1720, temps=3)
    # (accord du clavecin, basse sur le un, basse sur le deux) par mesure.
    A = [([62, 65, 69], 50, 45), ([61, 64, 69], 49, 45), ([60, 65, 69], 48, 45), ([62, 65, 70], 46, 43),
         ([61, 64, 69], 45, 40), ([62, 65, 69], 50, 41), ([62, 64, 67], 43, 45), ([62, 65, 69], 38, 50)]
    B = [([60, 65, 69], 41, 48), ([60, 64, 67], 40, 43), ([62, 65, 69], 50, 45), ([61, 64, 69], 45, 49),
         ([62, 65, 70], 46, 41), ([62, 67, 70], 43, 46), ([61, 64, 67], 45, 33), ([62, 65, 69], 38, 50)]
    THEME = [
        [(0, 1, 69), (1, 1.5, 74), (2.5, .5, 72)], [(0, 1, 73), (1, 1.5, 76), (2.5, .5, 74)],
        [(0, 1, 72), (1, 1.5, 77), (2.5, .5, 76)], [(0, 1, 74), (1, 2, 70)],
        [(0, 1, 73), (1, 1.5, 76), (2.5, .5, 74)], [(0, 1, 77), (1, 1.5, 81), (2.5, .5, 79)],
        [(0, 1, 77), (1, 1, 76), (2, 1, 73)], [(0, 3, 74)],
    ]
    # La reprise ornée : un pincé sur le deuxième temps, et un trille à la cadence.
    ORNE = [list(m) for m in THEME]
    ORNE[1] = [(0, 1, 73), (1, .25, 76), (1.25, .25, 77), (1.5, 1, 76), (2.5, .5, 74)]
    ORNE[3] = [(0, .5, 74), (.5, .5, 72), (1, 2, 70)]
    ORNE[6] = [(0, 1, 77), (1, .25, 76), (1.25, .25, 77), (1.5, .25, 76), (1.75, .25, 77), (2, 1, 73)]
    SECONDE = [
        [(0, 1, 72), (1, 1.5, 77), (2.5, .5, 76)], [(0, 1, 79), (1, 1.5, 76), (2.5, .5, 72)],
        [(0, 1, 77), (1, 1.5, 74), (2.5, .5, 72)], [(0, 1, 73), (1, 2, 76)],
        [(0, 1, 74), (1, 1.5, 77), (2.5, .5, 74)], [(0, 1, 70), (1, 1.5, 74), (2.5, .5, 79)],
        [(0, 1, 77), (1, .5, 76), (1.5, .5, 74), (2, 1, 73)], [(0, 3, 74)],
    ]
    TIERCE = {72: 69, 77: 74, 76: 72, 79: 76, 74: 70, 73: 69, 70: 67}
    for bar in range(24):
        partie = bar // 8
        accord, b1, b2 = (A if partie < 2 else B)[bar % 8]
        # Le violoncelle : une blanche sur le un, une noire sur le deux (l'appui de la sarabande).
        p.add("violoncelle", chant([(0.0, p.beat * 1.9, b1, 0.9), (p.beat * 2, p.beat * 0.95, b2, 0.7)], 0, p.rng, "archet"),
              p.at(bar, 0), pan=0.3, jeu=0.01)
        # Le clavecin : l'accord égrené sur le un, et de nouveau, plus fort, sur le deux.
        for beat, vel in ((0, 0.7), (1, 0.9)):
            if partie == 0 and beat == 1 and bar % 2 == 1:
                continue
            for k, note in enumerate(accord):
                p.add("clavecin", clavecin(note, p.beat * 0.9, p.rng, vel), p.at(bar, beat) + k * 0.025, pan=-0.3 + 0.1 * k, jeu=0.004, force=0.08)
    # Le thème : au clavecin d'abord (dessus, une octave plus haut), puis aux violons, puis la seconde partie.
    for m, mesure in enumerate(THEME):
        for beat, l, note in mesure:
            p.add("clavecin", clavecin(note, l * p.beat, p.rng, 0.95), p.at(m, beat), pan=-0.1, jeu=0.006, force=0.08)
    p.add("violons", chant(phrase(p, ORNE, 8, 0, 0.01), 0, p.rng, "archet"), p.at(8, 0), pan=-0.25)
    p.add("violons", chant(phrase(p, SECONDE, 16, 0, 0.01), 0, p.rng, "archet"), p.at(16, 0), pan=-0.25)
    altos = [[(b, l, TIERCE.get(n, n - 3)) for b, l, n in mesure] for mesure in SECONDE]
    p.add("altos", chant(phrase(p, altos, 16, 0, 0.012), 0, p.rng, "archet"), p.at(16, 0), pan=0.2)
    niveaux = {"violoncelle": (-21.0, 0.35), "clavecin": (-20.0, 0.3), "violons": (-19.0, 0.4), "altos": (-25.0, 0.4)}
    traitements = {"clavecin": lambda b: caisse(filtre(b, haut=90), [(210, 0.8), (460, 0.6), (930, 0.4)], 0.03)}
    mix = mixer(p, niveaux, (2.2, 7000.0, 0.03), traitements)
    return {"salon": maitre(mix, gain_maitre(mix))}


# --- La filature : de la city pop de détective, la nuit en ville ----------------------------------

def caisse_porte(rng, vel=1.0):
    """La caisse claire des années 80 : une grosse réverbération coupée net par une porte de bruit."""
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    ton = (np.sin(2 * np.pi * 182 * t) + 0.4 * np.sin(2 * np.pi * 310 * t)) * np.exp(-t * 22.0)
    bruit = filtre(rng.normal(0, 1, n), bas=3800, haut=350) * np.exp(-t * 7.0)
    porte = np.clip((0.2 - t) / 0.025, 0.0, 1.0)
    return (ton * 0.7 + bruit) * porte * vel


def cloche(note, dur, vel=1.0):
    """Une cloche de synthé FM, ronde : un modulateur au triple qui s'éteint vite."""
    t = np.arange(int((dur + 1.5) * SR)) / SR
    f = hz(note)
    index = (0.8 + 0.8 * vel) * np.exp(-t * 9.0)
    s = np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * f * 3.0 * t) * index)
    env = np.minimum(t / 0.004, 1.0) * np.exp(-t * 2.2) * np.clip(1.0 - (t - dur) / 0.4, 0.0, 1.0)
    return s * env * vel


# Les accords (sans fondamentale, elle est à la basse) et leur basse.
FI_AM9 = ([55, 59, 60, 64], 45)
FI_FMAJ9 = ([57, 60, 64, 67], 41)
FI_G6 = ([55, 59, 62, 64], 43)
FI_DM9 = ([53, 57, 60, 64], 38)
FI_E7SUS = ([52, 57, 59, 62], 40)
FI_E7 = ([56, 59, 62, 67], 40)
FI_EM9 = ([55, 59, 62, 66], 40)
FI_AM7 = ([55, 60, 64, 67], 45)
FI_G9 = ([53, 57, 59, 64], 43)
FI_CMAJ7 = ([52, 55, 59, 62], 48)
FI_FS7 = ([54, 58, 61, 64], 42)


def _plus(accord, k):
    return ([n + k for n in accord[0]], accord[1] + k)


# Une grille par demi-mesure : l'intro (4), le couplet (8), la montée (4), le refrain (8), le refrain
# un ton plus haut (8), dont la dernière mesure ramène au la mineur du début.
_REF = [FI_FMAJ9, FI_FMAJ9, FI_G9, FI_G9, FI_EM9, FI_EM9, FI_AM7, FI_AM7,
        FI_DM9, FI_DM9, FI_G9, FI_G9, FI_CMAJ7, FI_CMAJ7]
FI_GRILLE = ([FI_AM9, FI_AM9, FI_FMAJ9, FI_FMAJ9, FI_DM9, FI_DM9, FI_E7SUS, FI_E7]
             + [FI_AM9] * 4 + [FI_FMAJ9, FI_FMAJ9, FI_G6, FI_G6] + [FI_AM9] * 4 + [FI_DM9, FI_DM9, FI_E7SUS, FI_E7]
             + [FI_FMAJ9, FI_FMAJ9, FI_G6, FI_G6, FI_EM9, FI_AM7, FI_DM9, FI_E7]
             + _REF + [FI_FS7, FI_FS7]
             + [_plus(a, 2) for a in _REF] + [FI_E7SUS, FI_E7])
FI_COUPLET = [
    [(0.5, .5, 69), (1, 1, 72), (2, .5, 71), (2.5, 1.5, 69)], [(0, 1, 67), (1, .5, 69), (1.5, 2.5, 64)],
    [(0.5, .5, 65), (1, 1, 69), (2, .5, 72), (2.5, 1, 74), (3.5, .5, 72)], [(0, 2, 71), (2, .5, 67), (2.5, 1.5, 69)],
    [(0.5, .5, 69), (1, 1, 72), (2, .5, 74), (2.5, 1.5, 76)], [(0, 1, 74), (1, .5, 72), (1.5, 2.5, 71)],
    [(0, 1.5, 69), (1.5, .5, 72), (2, 1, 74), (3, 1, 77)], [(0, 2.5, 76), (2.5, .5, 74), (3, 1, 71)],
]
FI_MONTEE = [
    [(0, .5, 72), (.5, .5, 74), (1, 1, 76), (2, 2, 77)], [(0, .5, 74), (.5, .5, 76), (1, 1, 77), (2, 2, 79)],
    [(0, 1, 79), (1, 1, 76), (2, 1, 81), (3, 1, 79)], [(0, 2, 77), (2, 1, 76), (3, 1, 80)],
]
FI_REFRAIN = [
    [(0, 1.5, 81), (1.5, .5, 79), (2, 2, 77)], [(0, .5, 79), (.5, 1, 77), (1.5, .5, 76), (2, 2, 74)],
    [(0, 1.5, 79), (1.5, .5, 76), (2, 1, 74), (3, 1, 71)], [(0, 3, 72), (3, .5, 74), (3.5, .5, 76)],
    [(0, 1.5, 77), (1.5, .5, 76), (2, 1, 74), (3, 1, 72)], [(0, .5, 74), (.5, 1.5, 71), (2, 1, 74), (3, 1, 77)],
    [(0, 2, 76), (2, .5, 74), (2.5, 1.5, 71)],
]
# Les basses de synthé en croches : la fondamentale, l'octave qui rebondit, et une double qui pousse.
FI_BASSE = [(0, 2, 0, 1.0), (2, 2, 12, 0.7), (4, 2, 0, 0.85), (6, 1, 0, 0.6), (7, 1, 12, 0.7)]


def filature():
    """La filature : city pop de détective, la nuit, en la mineur, 32 mesures à 116. L'intro tient la
    nappe et la basse ; le couplet pose la batterie et le synthé qui chante bas ; la montée grimpe ; le
    refrain prend la grille qui retombe sur elle-même (fa, sol, mi, la) ; et il revient un ton plus haut
    avant de redescendre au début."""
    p = Piste(116.0, 32, graine=1987)
    rng = p.rng
    for bar in range(32):
        partie = 0 if bar < 4 else 1 if bar < 12 else 2 if bar < 16 else 3
        fin = bar in (3, 11, 15, 23, 31)
        # La basse, qui pousse dès l'intro (en rondes) puis en croches.
        for demi in range(2):
            accord, racine = FI_GRILLE[bar * 2 + demi]
            if partie == 0 and bar < 2:
                if demi == 0:
                    p.add("basse", basse_doigt(racine, p.bar * 0.95, 0.8), p.at(bar, 0), jeu=0.003)
                continue
            for s, l, iv, vel in FI_BASSE:
                if fin and demi == 1 and s >= 4:
                    break
                p.add("basse", basse_doigt(racine + iv, l * p.beat / 2 * 0.9, vel), p.at(bar, demi * 2 + s / 4),
                      jeu=0.003, force=0.05)
            # La nappe : des cordes de synthé, tenues, qui changent avec l'accord.
            p.add("nappe", cordes(accord, p.bar / 2 * 0.98, rng), p.at(bar, demi * 2), pan=0.0)
            # Le piano électrique en contretemps, à partir du couplet.
            if partie >= 1:
                coups = [(1, 0.7), (3, 0.55)] if demi == 0 else [(1, 0.6), (2.5, 0.5)]
                for b, vel in coups:
                    for k, note in enumerate(accord):
                        p.add("ep", rhodes(note, p.beat * 0.4, vel), p.at(bar, demi * 2 + b / 2) + k * 0.005,
                              pan=-0.4 + 0.2 * k, jeu=0.005, force=0.08)
        # La batterie : la grosse caisse sur le un et le trois (et le « et » du deux qui relance), la caisse
        # coupée sur deux et quatre, le charleston en croches ; dans l'intro, la grosse caisse seule.
        if bar >= 2:
            kicks = [0, 2] if partie == 0 else ([0, 1.5, 2] if bar % 2 else [0, 2, 3.5])
            for b in kicks:
                p.add("gc", grosse_caisse(rng, 0.95 if b in (0, 2) else 0.75), p.at(bar, b), jeu=0.002, force=0.04)
        if partie >= 1:
            for b in (1, 3):
                if not (fin and b == 3):
                    p.add("cc", caisse_porte(rng), p.at(bar, b), pan=0.05, jeu=0.002, force=0.04)
            for k in range(8):
                if fin and k >= 6:
                    break
                p.add("hh", charleston(rng, k % 2 == 1 and bar % 4 == 3 and k == 7, 0.8 if k % 2 == 0 else 0.5),
                      p.at(bar, k / 2), pan=0.3, jeu=0.003, force=0.1)
        if partie >= 2:
            for k in range(16):
                p.add("shaker", shaker(rng, 0.6 if k % 2 else 0.9), p.at(bar, k / 4), pan=-0.35, jeu=0.003, force=0.15)
        if fin and bar > 3:
            # Le roulement de toms qui ouvre la partie suivante.
            for k, (b, note) in enumerate([(3, 52), (3.25, 49), (3.5, 45), (3.75, 41)]):
                p.add("toms", tom(note, rng), p.at(bar, b), pan=0.4 - 0.25 * k, jeu=0.002, force=0.06)
        # La cloche : un arpège qui monte dans l'intro et au refrain, une mesure sur deux.
        if partie in (0, 3) and bar % 2 == 0:
            accord, _ = FI_GRILLE[bar * 2]
            for k, note in enumerate(accord + [accord[1] + 12]):
                p.add("cloche", cloche(note + 12, p.beat * 0.5, 0.7), p.at(bar, k * 0.5), pan=0.4 - 0.15 * k, jeu=0.004, force=0.1)
    # Le chant du synthé : le couplet, la montée, le refrain, puis le refrain un ton plus haut.
    refrain_fs = FI_REFRAIN + [[(0, 2, 70), (2, 1, 73), (3, 1, 76)]]
    refrain_ret = [[(b, l, n + 2) for b, l, n in m] for m in FI_REFRAIN] + [[(0, 2, 68), (2, 1, 71), (3, 1, 76)]]
    for depart, mesures in [(4, FI_COUPLET), (12, FI_MONTEE), (16, refrain_fs), (24, refrain_ret)]:
        notes = phrase(p, mesures, depart, 0, 0.008)
        p.add("synthe", chant(notes, 0, rng, "synthe"), p.at(depart, 0), pan=0.0)
        if depart >= 16:
            # Au refrain, le synthé est doublé à l'octave en dessous, et les violons le soutiennent.
            p.add("synthe_oct", chant([(d, l, n - 12, f) for d, l, n, f in notes], 0, rng, "synthe"), p.at(depart, 0))
            p.add("violons", chant([(d, l, n - 12, f * 0.8) for d, l, n, f in notes], 0, rng, "archet"), p.at(depart, 0), pan=-0.3)
    niveaux = {"basse": (-16.0, 0.0), "nappe": (-27.0, 0.4), "ep": (-23.0, 0.2), "gc": (-17.0, 0.05),
               "cc": (-20.0, 0.12), "hh": (-30.0, 0.08), "shaker": (-34.0, 0.1), "toms": (-25.0, 0.2),
               "cloche": (-28.0, 0.45), "synthe": (-19.0, 0.3), "synthe_oct": (-28.0, 0.3), "violons": (-27.0, 0.4)}
    mix = mixer(p, niveaux, (1.8, 5000.0, 0.025))
    return {"filature": maitre(mix, gain_maitre(mix))}


THEMES = {"ville": ville, "titre": titre, "environs": environs, "grands_espaces": grands_espaces, "salon": salon,
          "filature": filature}
# Ce que le jeu emporte : le mélange complet de la ville ne sert qu'à l'écoute.
DANS_LE_JEU = {"ville_fond", "ville_cuivres", "ville_chant", "titre", "environs", "grands_espaces", "salon", "filature"}


def ecrire(nom, mix, sortie):
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, nom + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(mix.T, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", QUALITE, sortie],
                       check=True)
    print("%s : %.1f s, %d Ko, %.1f dB RMS" % (sortie, mix.shape[1] / SR, os.path.getsize(sortie) // 1024,
                                              20 * np.log10(rms(mix))))


def main():
    noms = [a for a in sys.argv[1:] if not a.startswith("--")] or list(THEMES)
    dossier = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--sortie=")), "")
    dans_le_jeu = not dossier
    dossier = dossier or os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "musique"))
    os.makedirs(dossier, exist_ok=True)
    for nom in noms:
        if nom not in THEMES:
            sys.exit("thème inconnu : %s (thèmes : %s)" % (nom, ", ".join(THEMES)))
        for fichier, mix in THEMES[nom]().items():
            if dans_le_jeu and fichier not in DANS_LE_JEU:
                continue
            ecrire(fichier, mix, os.path.join(dossier, fichier + ".ogg"))


if __name__ == "__main__":
    main()
