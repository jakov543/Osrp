"""
OSRP v1.0.27 - Croatian traffic sign faces (drawn like the real ones from the Croatian road sign rules) +
shop signs. draw(key) -> PIL RGB image 512x512. Used by osijek_export_gta.py for materials "osrp_signtex_<key>".
"""
import math
from PIL import Image, ImageDraw, ImageFont

S = 512
RED, BLUE, YELLOW, WHITE, BLACK = (200, 16, 30), (0, 72, 160), (250, 196, 0), (250, 250, 248), (16, 16, 16)
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_C = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"


def _font(size, cond=False):
    try:
        return ImageFont.truetype(FONT_C if cond else FONT_B, size)
    except OSError:
        return ImageFont.load_default()


def _center_text(d, text, cy, size, fill, cond=False, cx=S / 2):
    f = _font(size, cond)
    b = d.textbbox((0, 0), text, font=f)
    d.text((cx - (b[2] - b[0]) / 2 - b[0], cy - (b[3] - b[1]) / 2 - b[1]), text, font=f, fill=fill)


def _poly(n, r, rot=0.0, cx=S / 2, cy=S / 2):
    return [(cx + r * math.cos(rot + i * 2 * math.pi / n), cy + r * math.sin(rot + i * 2 * math.pi / n)) for i in range(n)]


def _pedestrian(d, cx, cy, s, fill=BLACK):
    """walking person"""
    d.ellipse((cx - 0.09 * s, cy - 0.50 * s, cx + 0.09 * s, cy - 0.32 * s), fill=fill)
    w = int(0.075 * s)
    d.line([(cx, cy - 0.30 * s), (cx - 0.02 * s, cy + 0.05 * s)], fill=fill, width=w)              # body
    d.line([(cx - 0.02 * s, cy + 0.05 * s), (cx - 0.20 * s, cy + 0.42 * s)], fill=fill, width=w)   # legs
    d.line([(cx - 0.02 * s, cy + 0.05 * s), (cx + 0.16 * s, cy + 0.42 * s)], fill=fill, width=w)
    d.line([(cx, cy - 0.22 * s), (cx - 0.20 * s, cy - 0.02 * s)], fill=fill, width=int(w * 0.8))    # arms
    d.line([(cx, cy - 0.22 * s), (cx + 0.17 * s, cy - 0.05 * s)], fill=fill, width=int(w * 0.8))


def draw(key):
    img = Image.new("RGB", (S, S), WHITE)
    d = ImageDraw.Draw(img)
    if key == "stop":                       # B02 STOP - red octagon, white border, white STOP
        d.rectangle((0, 0, S, S), fill=RED)
        d.polygon(_poly(8, S * 0.47, math.pi / 8), outline=WHITE, width=16)
        _center_text(d, "STOP", S / 2, 135, WHITE, cond=True)
    elif key == "crossing":                 # C02 pedestrian crossing - blue square, white triangle, person on zebra
        d.rectangle((0, 0, S, S), fill=BLUE)
        d.rectangle((14, 14, S - 14, S - 14), outline=WHITE, width=10)
        d.polygon([(S / 2, 60), (S - 60, S - 70), (60, S - 70)], fill=WHITE)
        for k in range(5):
            x0 = 120 + k * 58
            d.polygon([(x0, S - 95), (x0 + 34, S - 95), (x0 + 24, S - 115), (x0 - 10, S - 115)], fill=BLACK)
        _pedestrian(d, S / 2, S * 0.57, 260)
    elif key == "priority":                 # B05 priority road - white square on point with yellow centre
        d.rectangle((0, 0, S, S), fill=WHITE)
        d.polygon(_poly(4, S * 0.47, 0), outline=BLACK, width=6)
        d.polygon(_poly(4, S * 0.30, 0), fill=YELLOW, outline=BLACK, width=4)
    elif key == "noentry":                  # B09 no entry - red circle, white bar
        d.rectangle((0, 0, S, S), fill=RED)
        d.ellipse((10, 10, S - 10, S - 10), outline=WHITE, width=10)
        d.rectangle((90, S / 2 - 45, S - 90, S / 2 + 45), fill=WHITE)
    elif key == "speed50":                  # B31 speed limit - white circle, red ring, 50
        d.ellipse((6, 6, S - 6, S - 6), fill=RED)
        d.ellipse((70, 70, S - 70, S - 70), fill=WHITE)
        _center_text(d, "50", S / 2, 190, BLACK)
    elif key == "works":                    # A23 road works - white triangle with red edge, worker with shovel
        d.rectangle((0, 0, S, S), fill=RED)
        d.polygon([(S / 2, 70), (S - 50, S - 60), (50, S - 60)], fill=WHITE)
        cx, cy = S / 2 + 10, S * 0.62
        d.ellipse((cx - 22, cy - 120, cx + 22, cy - 76), fill=BLACK)
        d.line([(cx, cy - 70), (cx - 30, cy + 10)], fill=BLACK, width=26)
        d.line([(cx - 30, cy + 10), (cx - 70, cy + 80)], fill=BLACK, width=24)
        d.line([(cx - 30, cy + 10), (cx + 15, cy + 80)], fill=BLACK, width=24)
        d.line([(cx - 5, cy - 55), (cx + 60, cy - 10)], fill=BLACK, width=16)
        d.line([(cx + 60, cy - 10), (cx + 95, cy + 70)], fill=BLACK, width=10)            # shovel
        d.polygon([(cx + 80, cy + 60), (cx + 120, cy + 55), (cx + 115, cy + 85)], fill=BLACK)
        d.polygon([(cx - 140, cy + 85), (cx - 70, cy + 40), (cx - 40, cy + 85)], fill=BLACK)  # heap
    elif key == "closed":                   # road closed board
        d.rectangle((0, 0, S, S), fill=RED)
        d.rectangle((16, 16, S - 16, S - 16), fill=WHITE)
        _center_text(d, "CESTA", S * 0.36, 120, RED)
        _center_text(d, "ZATVORENA", S * 0.66, 76, RED, cond=True)
    elif key == "detour":                   # yellow detour board
        d.rectangle((0, 0, S, S), fill=YELLOW)
        d.rectangle((12, 12, S - 12, S - 12), outline=BLACK, width=8)
        _center_text(d, "OBILAZAK", S * 0.32, 90, BLACK, cond=True)
        d.polygon([(110, S * 0.62), (330, S * 0.62), (330, S * 0.52), (430, S * 0.7), (330, S * 0.88), (330, S * 0.78), (110, S * 0.78)], fill=BLACK)
    elif key == "street":                   # blue street name plate
        d.rectangle((0, 0, S, S), fill=BLUE)
        d.rectangle((14, 14, S - 14, S - 14), outline=WHITE, width=8)
        _center_text(d, "OSIJEK", S / 2, 120, WHITE)
    elif key == "gunshop":                  # shop sign
        d.rectangle((0, 0, S, S), fill=(24, 24, 28))
        d.rectangle((10, 10, S - 10, S - 10), outline=(230, 170, 40), width=10)
        _center_text(d, "ORUŽARNICA", S * 0.42, 64, (240, 190, 60), cond=True)
        _center_text(d, "LOV · SPORT", S * 0.66, 46, WHITE, cond=True)
    return img


KEYS = ["stop", "crossing", "priority", "noentry", "speed50", "works", "closed", "detour", "street", "gunshop"]
