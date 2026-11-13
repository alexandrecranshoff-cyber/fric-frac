#!/usr/bin/env python3
"""Fait un son du jeu (OGG Vorbis) à partir d'un fichier audio Higgsfield, avec ffmpeg.

  1. retire le silence du début et de la fin (seuil -62 dB) ;
  2. met le son au volume voulu en LUFS (volume perçu), pic limité à -1 dB, pour que bruitages et musiques
     se tiennent entre eux sans réglage dans le jeu ;
  3. si demandé (boucle=oui), fond la fin dans le début sur `fondu` secondes : la piste repart sans
     coupure quand le jeu la reprend au début. Sinon, fondu de sortie très court contre les clics.

Écrit assets/audio/<dossier>/<nom>.ogg (dossier : bruitages ou musiques).

Usage : python3 tools/preparer_son.py son.mp3 dossier/nom [volume=-18] [boucle=non] [fondu=3.0] [debut=0]
        [fin=0] [silence=oui]
  debut, fin : secondes à couper au début et avant la fin (fin=0 garde tout).
"""
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
DEFAULTS = {"volume": "-18", "boucle": "non", "fondu": "3.0", "debut": "0", "fin": "0", "silence": "oui"}
RATE = 44100


def ffmpeg(*args: str) -> str:
	return subprocess.run(["ffmpeg", "-v", "error", "-nostats", "-y", *args], check=True, capture_output=True,
		text=True).stderr


def loudness(path: Path) -> float:
	"""Volume perçu intégré (LUFS) d'un fichier, mesuré par ffmpeg. Le silence ajouté au bout ne compte pas
	(la mesure écarte ce qui est sous -70 LUFS) mais permet de mesurer un son de moins d'une demi-seconde."""
	log = subprocess.run(["ffmpeg", "-nostats", "-i", str(path), "-af", "apad=pad_dur=3,loudnorm=print_format=json", "-f", "null",
		"-"], capture_output=True, text=True).stderr
	return float(json.loads(log[log.rindex("{"):])["input_i"])


def main() -> None:
	args = sys.argv[1:]
	if len(args) < 2:
		sys.exit(__doc__)
	source, name = args[0], args[1]
	settings = dict(DEFAULTS)
	for item in args[2:]:
		key, value = item.split("=", 1)
		if key not in settings:
			sys.exit("Réglage inconnu : " + key)
		settings[key] = value
	loop = settings["boucle"] == "oui"
	target = OUT / f"{name}.ogg"
	target.parent.mkdir(parents=True, exist_ok=True)

	with tempfile.TemporaryDirectory() as tmp:
		raw = Path(tmp) / "brut.wav"
		filters = []
		if float(settings["debut"]) > 0 or float(settings["fin"]) > 0:
			duration = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of",
				"csv=p=0", source], capture_output=True, text=True, check=True).stdout)
			end = duration - float(settings["fin"])
			filters.append(f"atrim={float(settings['debut'])}:{end},asetpts=PTS-STARTPTS")
		if settings["silence"] == "oui" and not loop:
			# Silence retiré au début, puis à la fin (en retournant le son).
			cut = "silenceremove=start_periods=1:start_threshold=-62dB:start_silence=0.02"
			filters += [cut, "areverse", cut, "areverse"]
		chain = ["-af", ",".join(filters)] if filters else []
		ffmpeg("-i", source, *chain, "-ac", "2", "-ar", str(RATE), str(raw))

		with wave.open(str(raw)) as w:
			samples = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).reshape(-1, 2).astype(np.float64)
		samples /= 32768.0
		if loop:
			# La fin, en fondu sortant, se pose sur le début en fondu entrant ; la piste commence après ce début.
			n = int(float(settings["fondu"]) * RATE)
			ramp = np.linspace(0.0, 1.0, n)[:, None]
			fade_in = np.sqrt(ramp)
			fade_out = np.sqrt(1.0 - ramp)
			tail = samples[-n:] * fade_out + samples[:n] * fade_in
			samples = np.concatenate([samples[n:-n], tail])
		else:
			n = min(int(0.03 * RATE), len(samples) // 4)
			samples[-n:] *= np.linspace(1.0, 0.0, n)[:, None]
		mixed = Path(tmp) / "mixe.wav"
		with wave.open(str(mixed), "wb") as w:
			w.setnchannels(2)
			w.setsampwidth(2)
			w.setframerate(RATE)
			w.writeframes((np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16).tobytes())

		gain = float(settings["volume"]) - loudness(mixed)
		ffmpeg("-i", str(mixed), "-af", f"volume={gain:.2f}dB,alimiter=limit=0.89:level=false", "-c:a", "libvorbis",
			"-q:a", "5", str(target))
	print(f"{name} : {len(samples) / RATE:.2f} s, {'boucle' if loop else 'son'}, gain {gain:+.1f} dB, "
		f"volume final {loudness(target):.1f} LUFS")


main()
