#!/usr/bin/env python3
"""Draw the Osijek map pictures for the in-game minimap and the big map (F7).

usage: python3 tools/make_minimap.py <export dir> <osrp_osijek/html dir>
writes map.png (minimap, no names), map_big.png (with street names) and map.json (picture <-> city coordinates)
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

PPM = 2.0                                # pixels per metre
X0, X1, Y0, Y1 = -590.0, 590.0, -800.0, 380.0

COLORS = {                               # GTA radar style
    "sea": (52, 96, 128), "land": (70, 76, 82), "water": (58, 108, 142), "park": (66, 96, 64),
    "square": (98, 104, 110), "walk": (104, 110, 116), "road": (156, 162, 168), "bld": (118, 124, 132), "bike": (150, 72, 62),
}
ORDER = ["land", "water", "park", "square", "walk", "road", "bike", "bld"]

ROWS = [(0, "Europska avenija"), (-180, "Kapucinska ulica"), (-350, "Vukovarska ulica"), (125, "Šetalište kardinala Šepera"),
        (164, "Promenada uz Dravu")]
COLS = [(-450, "Ulica svetog Roka"), (-300, "Šamačka ulica"), (-150, "Radićeva ulica"), (0, "Županijska ulica"),
        (150, "Ulica Hrvatske Republike"), (300, "Ulica Franje Kuhača"), (450, "Divaltova ulica")]
AREAS = [(-330, -440, "KBC OSIJEK"), (200, -520, "ZRAČNA LUKA OSIJEK"), (225, 75, "TVRĐA"), (-222, 64, "GRADSKI PARK"),
         (0, 220, "DRAVA"), (-300, 300, "COPACABANA"), (-430, -90, "GORNJI GRAD"), (420, -90, "DONJI GRAD")]


def px(x, y):
    return (x - X0) * PPM, (Y1 - y) * PPM


def font(size, bold=True):
    for f in ("/usr/share/fonts/truetype/google-fonts/ofl/montserrat/Montserrat[wght].ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(f):
            try:
                ft = ImageFont.truetype(f, size)
                if "Montserrat" in f:
                    try:
                        ft.set_variation_by_name("Bold" if bold else "SemiBold")
                    except Exception:
                        pass
                return ft
            except Exception:
                pass
    return ImageFont.load_default()


def draw_map(life, names):
    w, h = int((X1 - X0) * PPM), int((Y1 - Y0) * PPM)
    img = Image.new("RGB", (w, h), COLORS["sea"])
    d = ImageDraw.Draw(img)
    rects = life["MAPRECTS"]
    for kind in ORDER:
        for r in rects:
            if r[0] != kind:
                continue
            _, cx, cy, rw, rh = r
            a = px(cx - rw / 2, cy + rh / 2)
            b = px(cx + rw / 2, cy - rh / 2)
            if kind == "bld":
                d.rectangle([a, b], fill=COLORS["bld"], outline=(96, 102, 110), width=2)
            else:
                d.rectangle([a, b], fill=COLORS.get(kind, COLORS["land"]))
    trees = os.path.join(SRC, "osijek_trees.json")
    if os.path.exists(trees):
        for t in json.load(open(trees)):
            x, y = px(t["x"], t["y"])
            r = 3.2 * PPM
            d.ellipse([x - r, y - r, x + r, y + r], fill=(56, 88, 52))
    # runway centre line + threshold
    for k in range(-8, 9):
        a, b = px(k * 50 - 14, -665 + 0.6), px(k * 50 + 14, -665 - 0.6)
        d.rectangle([a, b], fill=(235, 235, 235))
    if names:
        f = font(15)
        for y, name in ROWS:
            for x in (-375, 75, 375):
                tx, ty = px(x, y)
                d.text((tx, ty), name, font=f, fill=(250, 250, 250), anchor="mm", stroke_width=3, stroke_fill=(40, 44, 48))
        for x, name in COLS:
            txt = Image.new("RGBA", (420, 40), (0, 0, 0, 0))
            ImageDraw.Draw(txt).text((210, 20), name, font=f, fill=(250, 250, 250, 255), anchor="mm", stroke_width=3, stroke_fill=(40, 44, 48, 255))
            txt = txt.rotate(90, expand=True)
            for y in (-265, -95, 65):
                tx, ty = px(x, y)
                img.paste(txt, (int(tx - txt.width / 2), int(ty - txt.height / 2)), txt)
        fa = font(26)
        for x, y, name in AREAS:
            tx, ty = px(x, y)
            d.text((tx, ty), name, font=fa, fill=(255, 226, 150), anchor="mm", stroke_width=4, stroke_fill=(30, 34, 38))
    return img


SRC = "."


def main(src, dst):
    global SRC
    SRC = src
    life = json.load(open(os.path.join(src, "osijek_life.json"), encoding="utf-8"))
    os.makedirs(dst, exist_ok=True)
    draw_map(life, False).save(os.path.join(dst, "map.png"), optimize=True)
    draw_map(life, True).save(os.path.join(dst, "map_big.png"), optimize=True)
    meta = {"x0": X0, "y1": Y1, "ppm": PPM, "w": int((X1 - X0) * PPM), "h": int((Y1 - Y0) * PPM),
            "landmarks": life.get("LANDMARKS", [])}
    json.dump(meta, open(os.path.join(dst, "map.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print("map.png / map_big.png", meta["w"], "x", meta["h"], "px,", os.path.getsize(os.path.join(dst, "map.png")) // 1024, "KB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
