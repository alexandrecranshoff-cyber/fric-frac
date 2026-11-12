#!/usr/bin/env python3
"""Fabrique les matières de la maquette (sols, murs, feuillage) dans assets/textures/.

Toutes les images se répètent sans raccord visible. Rien n'est tiré d'une photo : tout est calculé,
avec des graines fixes, donc relancer l'outil redonne exactement les mêmes fichiers.

Usage : python3 tools/generer_textures.py     (demande numpy et Pillow)
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"


def noise(size, beta, seed):
    """Bruit qui se répète : spectre aléatoire en 1/f^beta. Plus beta est grand, plus les taches sont larges."""
    rng = np.random.default_rng(seed)
    fx = np.fft.fftfreq(size)[:, None]
    fy = np.fft.fftfreq(size)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spectrum = (rng.normal(size=(size, size)) + 1j * rng.normal(size=(size, size))) / f ** beta
    spectrum[0, 0] = 0.0
    field = np.real(np.fft.ifft2(spectrum))
    field -= field.min()
    return field / field.max()


def rgb(hexa):
    return np.array([int(hexa[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def mix(a, b, t):
    return a + (b - a) * t[..., None]


def save(name, image):
    data = (np.clip(image, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(data, "RGB").save(OUT / f"{name}.png", optimize=True)
    print(f"{name}.png  {data.shape[1]}x{data.shape[0]}")


def grass(size=512):
    # Peu de grandes taches : l'image se répète sur tout le jardin, elles se verraient.
    patches = noise(size, 1.5, 1)
    blades = noise(size, 0.7, 2)
    dry = noise(size, 1.2, 3)
    image = mix(rgb("57783a"), rgb("7c9a4e"), patches)
    image = mix(image, rgb("a3a868"), np.clip(dry - 0.6, 0, 1) * 1.2)
    return image * (0.8 + 0.4 * blades)[..., None]


def gravel(size=512):
    base = mix(rgb("b9ad8f"), rgb("d6ccb0"), noise(size, 1.6, 11))
    grains = noise(size, 0.35, 12)
    image = base * (0.8 + 0.4 * grains)[..., None]
    stones = np.clip(noise(size, 0.7, 13) - 0.66, 0, 1) * 3.0
    return mix(image, rgb("8f8672"), np.clip(stones, 0, 1))


def cells(size, count, seed):
    """Découpe en pavés irréguliers qui se répètent : pour chaque point, sa pierre et sa distance au joint."""
    rng = np.random.default_rng(seed)
    # Une pierre par case d'un quadrillage, déplacée au hasard dans sa case : des dalles de tailles voisines.
    side = int(round(count ** 0.5))
    count = side * side
    grid = np.stack(np.meshgrid(np.arange(side), np.arange(side)), axis=-1).reshape(-1, 2)
    points = (grid + 0.15 + 0.7 * rng.random((count, 2))) * size / side
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    best = np.full((size, size), 1e9)
    second = np.full((size, size), 1e9)
    owner = np.zeros((size, size), dtype=np.int64)
    for i, (px, py) in enumerate(points):
        dx = np.abs(xs - px)
        dy = np.abs(ys - py)
        d = np.hypot(np.minimum(dx, size - dx), np.minimum(dy, size - dy))
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        owner = np.where(closer, i, owner)
        best = np.where(closer, d, best)
    return owner, second - best, rng.random(count)


def paving(size=512):
    owner, edge, tint = cells(size, 36, 21)
    stone = mix(rgb("cdbf9b"), rgb("e6dcc0"), tint[owner])
    stone *= (0.9 + 0.2 * noise(size, 1.2, 22))[..., None]
    joint = np.clip(1.0 - edge / 4.0, 0, 1) ** 2
    return mix(stone, rgb("8d8266"), joint)


def parquet(size=512, planks=16):
    rng = np.random.default_rng(31)
    width = size // planks
    image = np.zeros((size, size, 3))
    grain = noise(size, 1.4, 32)
    for row in range(planks):
        y0 = row * width
        cuts = np.sort(rng.choice(np.arange(8, size - 8, 8), size=3, replace=False))
        starts = np.concatenate(([0], cuts))
        ends = np.concatenate((cuts, [size]))
        shift = int(rng.integers(0, size))
        for start, end in zip(starts, ends):
            color = mix(rgb("a8742f"), rgb("d6a655"), np.array(rng.random()))
            xs = (np.arange(start, end) + shift) % size
            # veines : le bruit étiré dans le sens de la lame
            veins = grain[(y0 + np.arange(width))[:, None] // 1, (xs // 6 * 6)[None, :] % size]
            image[y0:y0 + width, xs] = color * (0.88 + 0.24 * veins)[..., None]
            image[y0:y0 + width, xs[:2]] *= 0.62
        image[y0:y0 + 2, :] *= 0.6
    return image


def tiles(size=512, count=2):
    """Carrelage de vestibule : grandes dalles crème à pans coupés, petits cabochons sombres aux angles."""
    step = size / count
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    u = (xs % step) - step / 2
    v = (ys % step) - step / 2
    marble = noise(size, 1.8, 41)
    image = mix(rgb("e9e2cc"), rgb("f6f1e2"), marble)
    corner = (np.abs(np.abs(u) - step / 2) + np.abs(np.abs(v) - step / 2)) / step
    image = mix(image, rgb("5f5750") * (0.85 + 0.3 * marble)[..., None], (corner < 0.16).astype(float))
    grout = (np.minimum(np.abs(np.abs(u) - step / 2), np.abs(np.abs(v) - step / 2)) < 2.0) | (np.abs(corner - 0.16) < 0.008)
    return mix(image, rgb("b7ad94"), grout.astype(float) * 0.9)


def carpet(size=256):
    weave = noise(size, 0.5, 51)
    pile = noise(size, 1.8, 52)
    value = 0.86 + 0.1 * weave + 0.06 * pile
    return np.repeat(value[..., None], 3, axis=2)


def plaster(size=256):
    value = 0.9 + 0.07 * noise(size, 1.3, 61) + 0.04 * noise(size, 0.4, 62)
    return np.repeat(value[..., None], 3, axis=2)


def brick(size=512, rows=14, per_row=6):
    rng = np.random.default_rng(71)
    height = size / rows
    width = size / per_row
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    row = np.floor(ys / height).astype(int)
    shifted = xs + (row % 2) * width / 2
    col = np.floor(shifted / width).astype(int) % per_row
    tint = rng.random((rows, per_row))[row % rows, col]
    image = mix(rgb("9a5234"), rgb("c47a50"), tint)
    image = mix(image, rgb("7d4630"), (tint > 0.86).astype(float))
    image *= (0.86 + 0.28 * noise(size, 0.8, 72))[..., None]
    mortar = (np.minimum(ys % height, height - ys % height) < 2.2) | (np.minimum(shifted % width, width - shifted % width) < 2.2)
    return mix(image, rgb("cfc4ad"), mortar.astype(float))


def stone(size=256):
    image = mix(rgb("cfc6ae"), rgb("ece5d0"), noise(size, 1.9, 81))
    return image * (0.93 + 0.14 * noise(size, 0.6, 82))[..., None]


def wood(size=256):
    grain = noise(size, 1.6, 91)
    stretched = grain[(np.arange(size) // 24 * 24)[:, None] % size, np.arange(size)[None, :]]
    value = 0.78 + 0.3 * stretched + 0.06 * noise(size, 0.5, 92)
    return np.repeat(value[..., None], 3, axis=2)


def foliage(size=256):
    clumps = noise(size, 1.5, 101)
    leaves = noise(size, 0.6, 102)
    image = mix(rgb("2f5230"), rgb("56803f"), clumps)
    image = mix(image, rgb("7f9c52"), np.clip(leaves - 0.6, 0, 1) * 2.0)
    return image * (0.8 + 0.4 * leaves)[..., None]


def asphalt(size=256):
    value = 0.3 + 0.1 * noise(size, 0.4, 111) + 0.06 * noise(size, 1.8, 112)
    return np.stack([value, value, value * 1.04], axis=2)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    save("herbe", grass())
    save("gravier", gravel())
    save("dallage", paving())
    save("parquet", parquet())
    save("carrelage", tiles())
    save("moquette", carpet())
    save("crepi", plaster())
    save("brique", brick())
    save("pierre", stone())
    save("bois", wood())
    save("feuillage", foliage())
    save("asphalte", asphalt())
