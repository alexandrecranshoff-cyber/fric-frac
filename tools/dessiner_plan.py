#!/usr/bin/env python3
"""Redessine le plan de la villa à partir de data/villa.json, pour le contrôler à l'œil.

Usage : python3 tools/dessiner_plan.py [sortie.svg]   (par défaut docs/plan_villa.svg)
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
villa = json.loads((ROOT / "data" / "villa.json").read_text(encoding="utf-8"))
rows = villa["lignes"]
W = 44.0                      # largeur d'un hexagone
R = W / math.sqrt(3)          # rayon (centre vers pointe)
MX, MY = 60, 96               # marges

FLOOR = {"bleu": "#cfe6e2", "parquet": "#f0dd6a", "blanc": "#efeee2", "rose": "#f6cdb0",
         "carrelage": "#e9e6c4", "creme": "#f3e3b0"}
FILL = {"#": "#b9774d", "=": "#2f6b3a", ".": "#a9cf4a", ",": "#c9cda3", "~": "#e8d9a0", "_": "#e8d9a0",
        "/": "#d9c28a", "D": "#f29a1f", "E": "#d8402a", "F": "#58b7e0"}
OUTSIDE = ".,~_/"


def center(c, r):
    return (MX + W * (c + (0.5 if r % 2 else 0.0)), MY + 1.5 * R * r)


def corners(c, r):
    x, y = center(c, r)
    # pointe en haut : sommets dans l'ordre N, NE, SE, S, SO, NO
    return [(x + R * math.sin(math.radians(a)), y - R * math.cos(math.radians(a))) for a in range(0, 360, 60)]


def cell(c, r):
    if 0 <= r < len(rows) and 0 <= c < len(rows[r]):
        return rows[r][c]
    return " "


def neighbors(c, r):
    # ordre : NE, E, SE, SO, O, NO, pour que le voisin i partage l'arête entre les sommets i et i+1
    if r % 2:
        return [(c + 1, r - 1), (c + 1, r), (c + 1, r + 1), (c, r + 1), (c - 1, r), (c, r - 1)]
    return [(c, r - 1), (c + 1, r), (c, r + 1), (c - 1, r + 1), (c - 1, r), (c - 1, r - 1)]


def zone(ch):
    if ch in OUTSIDE:
        return "dehors"
    return ch if ch in villa["pieces"] else None


links = {tuple(o["case"]): o for o in villa["ouvertures"]}
trees = {tuple(t) for t in villa["arbres"]}
out = []
width = MX * 2 + W * 26
height = MY + 1.5 * R * 24 + 150
out.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.0f} {height:.0f}" font-family="Verdana, sans-serif">')
out.append(f'<rect width="{width:.0f}" height="{height:.0f}" fill="#fbfaf5"/>')
out.append(f'<text x="{MX - W / 2:.0f}" y="32" font-size="22" font-weight="bold">Fric-Frac : plan de la villa relevé sur le plateau</text>')

walls = []
for r, row in enumerate(rows):
    for c, ch in enumerate(row):
        if ch == " ":
            continue
        pts = corners(c, r)
        fill = FILL.get(ch) or FLOOR[villa["pieces"][ch]["sol"]]
        poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        out.append(f'<polygon points="{poly}" fill="{fill}" stroke="#5b5b4a" stroke-width="0.6"/>')
        x, y = center(c, r)
        if (c, r) in trees:
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{R * 0.62:.1f}" fill="#3f9a4a" opacity="0.85"/>')
        label = {"D": "P", "E": "P", "F": "F"}.get(ch)
        if label:
            out.append(f'<text x="{x:.1f}" y="{y + 5:.1f}" font-size="14" font-weight="bold" text-anchor="middle" fill="#fff">{label}</text>')
        # murs : entre deux cases qui ne communiquent pas
        for i, (nc, nr) in enumerate(neighbors(c, r)):
            other = cell(nc, nr)
            if (nc, nr) < (c, r) and other != " ":
                continue          # arête déjà traitée depuis l'autre case
            a, b = (c, r), (nc, nr)
            za, zb = zone(ch), zone(other)
            wall = False
            if a in links or b in links:
                if a in links and b in links:
                    wall = True
                else:
                    op, z = (links[a], zb) if a in links else (links[b], za)
                    wall = z is not None and z not in op["relie"]
            elif za and zb and za != zb:
                wall = True
            if wall:
                p, q = pts[i], pts[(i + 1) % 6]
                walls.append(f'<line x1="{p[0]:.1f}" y1="{p[1]:.1f}" x2="{q[0]:.1f}" y2="{q[1]:.1f}"/>')
out.append('<g stroke="#111" stroke-width="5" stroke-linecap="round">' + "".join(walls) + "</g>")

# lettres des pièces, une fois par pièce, sur la case la plus centrale
for room in villa["pieces"]:
    cells = [(c, r) for r, row in enumerate(rows) for c, ch in enumerate(row) if ch == room]
    xs = [center(*p) for p in cells]
    gx = sum(p[0] for p in xs) / len(xs)
    gy = sum(p[1] for p in xs) / len(xs)
    best = min(cells, key=lambda p: (center(*p)[0] - gx) ** 2 + (center(*p)[1] - gy) ** 2)
    if room == "h":
        best = (13, 15)
    x, y = center(*best)
    out.append(f'<text x="{x:.1f}" y="{y + 9:.1f}" font-size="27" font-style="italic" font-weight="bold" text-anchor="middle" fill="#333" opacity="0.7">{room}</text>')

# gardes et chiffres de direction
STEP_EVEN = {"nord_ouest": (-1, -1), "nord_est": (0, -1), "est": (1, 0), "sud_est": (0, 1), "sud_ouest": (-1, 1), "ouest": (-1, 0)}
STEP_ODD = {"nord_ouest": (0, -1), "nord_est": (1, -1), "est": (1, 0), "sud_est": (1, 1), "sud_ouest": (0, 1), "ouest": (-1, 0)}
for name, g in villa["gardes"].items():
    c, r = g["case"]
    x, y = center(c, r)
    out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{R * 0.7:.1f}" fill="#1f5fae"/>')
    out.append(f'<text x="{x:.1f}" y="{y + 6:.1f}" font-size="17" font-weight="bold" text-anchor="middle" fill="#fff">{name}</text>')
    for face, d in g["directions"].items():
        dc, dr = (STEP_ODD if r % 2 else STEP_EVEN)[d]
        x, y = center(c + dc, r + dr)
        out.append(f'<text x="{x:.1f}" y="{y + 5:.1f}" font-size="14" font-weight="bold" text-anchor="middle" fill="#1f5fae">{face}</text>')

# repères de colonnes et de lignes
for c in range(26):
    x, _ = center(c, 0)
    out.append(f'<text x="{x:.1f}" y="{MY - R - 6:.1f}" font-size="10" text-anchor="middle" fill="#777">{c}</text>')
for r in range(25):
    _, y = center(0, r)
    out.append(f'<text x="{MX - W * 0.5 - 10:.1f}" y="{y + 4:.1f}" font-size="10" text-anchor="end" fill="#777">{r}</text>')

# légende
ly = MY + 1.5 * R * 24 + R + 34
legend = [("#f29a1f", "P : porte intérieure"), ("#d8402a", "P : porte extérieure"), ("#58b7e0", "F : fenêtre"),
          ("#a9cf4a", "jardin"), ("#3f9a4a", "arbre"), ("#c9cda3", "cour pavée"), ("#e8d9a0", "terrasse et perron"),
          ("#d9c28a", "escalier"), ("#b9774d", "mur d'enceinte"), ("#2f6b3a", "grille"), ("#1f5fae", "garde et ses 6 directions")]
x = MX
for i, (color, text) in enumerate(legend):
    if i == 6:
        x, ly = MX, ly + 30
    out.append(f'<rect x="{x}" y="{ly - 14}" width="18" height="18" fill="{color}" stroke="#555" stroke-width="0.6"/>')
    out.append(f'<text x="{x + 24}" y="{ly}" font-size="13">{text}</text>')
    x += 46 + 8.2 * len(text)
out.append(f'<text x="{MX}" y="{ly + 34}" font-size="13">Trait noir épais : mur. Lettres minuscules a à m : les treize pièces. A et B : les gardes. Une porte ou une fenêtre occupe une case entière, à cheval sur le mur.</text>')
out.append("</svg>")

target = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "plan_villa.svg"
target.write_text("\n".join(out) + "\n", encoding="utf-8")
print("écrit :", target)
