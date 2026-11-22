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
    elif key == "flag_hr":                  # Croatian flag: red, white, blue + chequered shield
        d.rectangle((0, 0, S, S / 3), fill=(255, 0, 0)); d.rectangle((0, S / 3, S, 2 * S / 3), fill=WHITE)
        d.rectangle((0, 2 * S / 3, S, S), fill=(23, 23, 150))
        x0, y0, c = S / 2 - 60, S / 2 - 85, 24
        for r in range(6):
            for k in range(5):
                d.rectangle((x0 + k * c, y0 + r * c, x0 + (k + 1) * c, y0 + (r + 1) * c), fill=(255, 0, 0) if (r + k) % 2 == 0 else WHITE)
        d.pieslice((x0, y0 + 4 * c, x0 + 5 * c, y0 + 8 * c), 0, 180, fill=(255, 0, 0))
        d.rectangle((x0, y0, x0 + 5 * c, y0 + 6 * c), outline=(255, 0, 0), width=3)
    elif key == "hitna_sign":
        d.rectangle((0, 0, S, S), fill=(200, 16, 30))
        d.rectangle((S / 2 - 45, 90, S / 2 + 45, S - 90), fill=WHITE); d.rectangle((90, S / 2 - 45, S - 90, S / 2 + 45), fill=WHITE)
    elif key == "gate":
        d.rectangle((0, 0, S, S), fill=(18, 24, 34))
        _center_text(d, "IZLAZ  GATE", S * 0.3, 70, (250, 200, 40), cond=True)
        _center_text(d, "A1 - A6", S * 0.65, 110, WHITE)
    elif key == "police_logo":              # PU Osijek wall emblem: blue shield, chequer, POLICIJA
        d.rectangle((0, 0, S, S), fill=(18, 40, 96))
        d.polygon([(S / 2, 40), (S - 80, 90), (S - 95, 300), (S / 2, 440), (95, 300), (80, 90)], fill=(240, 240, 240))
        d.polygon([(S / 2, 60), (S - 100, 105), (S - 112, 292), (S / 2, 415), (112, 292), (100, 105)], fill=(18, 40, 96))
        x0, y0, c = S / 2 - 70, 120, 28
        for r in range(5):
            for k in range(5):
                d.rectangle((x0 + k * c, y0 + r * c, x0 + (k + 1) * c, y0 + (r + 1) * c), fill=(220, 0, 0) if (r + k) % 2 == 0 else WHITE)
        _center_text(d, "POLICIJA", 330, 54, WHITE, cond=True)
        _center_text(d, "PU OSJEČKO-BARANJSKA", 478, 30, WHITE, cond=True)
    elif key == "pu_plate":                 # plate next to the door
        d.rectangle((0, 0, S, S), fill=(18, 40, 96))
        d.rectangle((10, 10, S - 10, S - 10), outline=(230, 230, 230), width=6)
        _center_text(d, "REPUBLIKA HRVATSKA", 90, 34, WHITE, cond=True)
        _center_text(d, "MUP", 175, 80, WHITE)
        _center_text(d, "POLICIJSKA UPRAVA", 290, 40, WHITE, cond=True)
        _center_text(d, "OSJEČKO-BARANJSKA", 350, 40, WHITE, cond=True)
        _center_text(d, "I. POLICIJSKA POSTAJA", 430, 36, (250, 200, 40), cond=True)
    elif key == "notice":                   # notice board / wanted posters
        d.rectangle((0, 0, S, S), fill=(150, 110, 70))
        for k, (x, y, w, h) in enumerate(((30, 40, 140, 190), (190, 40, 140, 190), (350, 40, 130, 190), (40, 270, 200, 200), (270, 270, 210, 200))):
            d.rectangle((x, y, x + w, y + h), fill=(240, 236, 225))
            if k < 3:
                _center_text(d, "TRAŽI SE", y + 22, 22, (180, 0, 0), cond=True, cx=x + w / 2)
                d.rectangle((x + 30, y + 45, x + w - 30, y + 140), fill=(120, 120, 120))
                d.ellipse((x + w / 2 - 22, y + 55, x + w / 2 + 22, y + 99), fill=(80, 80, 80))
            else:
                for l in range(7):
                    d.rectangle((x + 15, y + 25 + l * 24, x + w - 15 - (l % 3) * 20, y + 33 + l * 24), fill=(60, 60, 70))
    elif key == "osijek_map":               # city map on the wall
        d.rectangle((0, 0, S, S), fill=(214, 220, 206))
        d.rectangle((0, 300, S, 360), fill=(90, 150, 200))
        for x in range(40, S, 95):
            d.rectangle((x, 0, x + 12, 300), fill=(250, 250, 250))
        for y in (60, 150, 240):
            d.rectangle((0, y, S, y + 10), fill=(250, 250, 250))
        d.rectangle((0, 190, S, 210), fill=(250, 220, 120))
        d.ellipse((150, 380, 190, 420), fill=(200, 0, 0))
        _center_text(d, "OSIJEK", 470, 48, (30, 30, 40))
    elif key == "bulet":                    # Bulet e-scooter sticker: green, white BULET + bullet icon
        d.rectangle((0, 0, S, S), fill=(28, 186, 110))
        _center_text(d, "BULET", S * 0.42, 150, WHITE)
        d.rounded_rectangle((150, 330, 330, 380), radius=25, fill=WHITE)
        d.polygon([(330, 330), (380, 355), (330, 380)], fill=WHITE)
    elif key == "bulet_plate":              # wide plate (2.5 : 1) - drawn wide, squeezed into the square texture
        wide = Image.new("RGB", (1280, 512), (28, 186, 110))
        dw = ImageDraw.Draw(wide)
        f = _font(330)
        b = dw.textbbox((0, 0), "BULET", font=f)
        dw.text((640 - (b[2] - b[0]) / 2 - b[0], 256 - (b[3] - b[1]) / 2 - b[1]), "BULET", font=f, fill=WHITE)
        return wide.resize((S, S))
    elif key == "bulet_stand":              # station sign
        d.rectangle((0, 0, S, S), fill=(28, 186, 110))
        _center_text(d, "BULET", S * 0.3, 140, WHITE)
        _center_text(d, "E-ROMOBILI", S * 0.55, 70, WHITE, cond=True)
        _center_text(d, "E = NAJAM", S * 0.78, 60, (20, 40, 30), cond=True)
    elif key == "gunshop":                  # shop sign
        d.rectangle((0, 0, S, S), fill=(24, 24, 28))
        d.rectangle((10, 10, S - 10, S - 10), outline=(230, 170, 40), width=10)
        _center_text(d, "ORUŽARNICA", S * 0.42, 64, (240, 190, 60), cond=True)
        _center_text(d, "LOV · SPORT", S * 0.66, 46, WHITE, cond=True)
    elif key == "clothes":                  # v1.0.36 clothing shop sign
        d.rectangle((0, 0, S, S), fill=(250, 246, 240))
        d.rectangle((12, 12, S - 12, S - 12), outline=(20, 20, 24), width=8)
        _center_text(d, "STIL", S * 0.4, 170, (20, 20, 24))
        _center_text(d, "MODA · ODJEĆA", S * 0.72, 50, (190, 40, 90), cond=True)
    elif key == "tech":                     # v1.0.36 electronics shop sign
        d.rectangle((0, 0, S, S), fill=(14, 20, 34))
        _center_text(d, "VOLT", S * 0.4, 170, (60, 200, 255))
        _center_text(d, "ELEKTRONIKA", S * 0.72, 56, WHITE, cond=True)
    elif key == "tram_stop":                # v1.0.38 GPP tram stop sign (Osijek city transport)
        d.rectangle((0, 0, S, S), fill=(250, 250, 248))
        d.rectangle((0, 0, S, 150), fill=(0, 90, 170))
        _center_text(d, "GPP", 75, 110, WHITE)
        d.ellipse((156, 180, 356, 380), fill=(240, 190, 0))
        _center_text(d, "T", 282, 150, (0, 60, 130))
        _center_text(d, "TRAMVAJ 2", 440, 62, (0, 60, 130), cond=True)
    elif key == "mall_logo":                # v1.0.39 DRAVA CENTAR shopping mall (wide 2.5 : 1)
        wide = Image.new("RGB", (1280, 512), (18, 30, 52))
        dw = ImageDraw.Draw(wide)
        dw.ellipse((60, 106, 360, 406), fill=(30, 170, 220))
        dw.polygon([(110, 300), (210, 200), (310, 300)], fill=WHITE)
        for txt, y, size, fill in (("DRAVA", 190, 190, WHITE), ("CENTAR", 380, 120, (30, 170, 220))):
            f = _font(size)
            dw.text((420, y - size * 0.6), txt, font=f, fill=fill)
        return wide.resize((S, S))
    elif key.startswith("shop_"):           # v1.0.39 shop names inside the mall (wide 3 : 1)
        name, bg, fg = {"stil": ("STIL", (250, 246, 240), (190, 40, 90)), "volt": ("VOLT", (14, 20, 34), (60, 200, 255)),
                        "kava": ("KAVA DRAVA", (60, 34, 20), (245, 220, 180)), "sport": ("SPORT CENTAR", (220, 60, 20), WHITE),
                        "knjige": ("KNJIŽARA", (30, 70, 50), (240, 230, 200)), "igracke": ("IGRAČKE", (250, 200, 30), (200, 30, 60)),
                        "market": ("MARKET", (200, 20, 30), WHITE), "ljekarna": ("LJEKARNA", (20, 150, 70), WHITE)}[key[5:]]
        wide = Image.new("RGB", (1536, 512), bg)
        dw = ImageDraw.Draw(wide)
        size = 260 if len(name) < 8 else 190
        f = _font(size)
        b = dw.textbbox((0, 0), name, font=f)
        dw.text((768 - (b[2] - b[0]) / 2 - b[0], 256 - (b[3] - b[1]) / 2 - b[1]), name, font=f, fill=fg)
        if key == "shop_ljekarna":
            dw.rectangle((90, 196, 210, 316), fill=WHITE); dw.rectangle((130, 156, 170, 356), fill=WHITE); dw.rectangle((50, 236, 250, 276), fill=WHITE)
        return wide.resize((S, S))
    elif key.startswith("ad_"):             # v1.0.36 billboards (2 : 1, drawn wide, squeezed into the square texture)
        return _billboard(key[3:])
    return img


def _billboard(k):
    W, H = 1024, 512
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    def grad(c0, c1):
        for y in range(H):
            t = y / H
            d.line([(0, y), (W, y)], fill=tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3)))
    def txt(t, y, size, fill, x=None, cond=False):
        f = _font(size, cond)
        b = d.textbbox((0, 0), t, font=f)
        xx = (W - (b[2] - b[0])) / 2 - b[0] if x is None else x
        d.text((xx, y - (b[3] - b[1]) / 2 - b[1]), t, font=f, fill=fill)
    if k == "bulet":
        grad((22, 170, 100), (10, 90, 60))
        txt("BULET", 170, 200, WHITE)
        txt("E-romobili po cijelom Osijeku", 320, 54, WHITE, cond=True)
        d.rounded_rectangle((330, 390, 694, 460), radius=35, fill=WHITE)
        txt("$2 + $1/min", 425, 46, (16, 120, 70), cond=True)
    elif k == "volt":
        grad((10, 16, 34), (30, 50, 110))
        txt("VOLT", 150, 190, (70, 210, 255), x=60)
        txt("MOBITELI · RADIO · TABLETI", 300, 48, WHITE, cond=True, x=60)
        d.rounded_rectangle((860, 110, 980, 380), radius=22, fill=(20, 22, 28), outline=(70, 210, 255), width=6)
        d.rectangle((876, 140, 964, 345), fill=(60, 120, 220))
        txt("Odmah do oružarnice", 420, 40, (180, 200, 230), cond=True, x=60)
    elif k == "stil":
        grad((250, 236, 240), (230, 190, 210))
        txt("STIL", 160, 210, (20, 20, 24))
        txt("NOVA KOLEKCIJA", 310, 66, (190, 40, 90), cond=True)
        txt("-30% na sve jakne", 410, 52, (20, 20, 24), cond=True)
    elif k == "osijek":
        grad((0, 72, 160), (0, 40, 100))
        for i in range(6):                  # chequer strip
            for j in range(2):
                d.rectangle((40 + i * 40, 40 + j * 40, 80 + i * 40, 80 + j * 40), fill=RED if (i + j) % 2 == 0 else WHITE)
        txt("DOBRODOŠLI", 190, 120, WHITE)
        txt("U OSIJEK", 330, 140, YELLOW)
        txt("Grad na Dravi", 445, 44, WHITE, cond=True)
    elif k == "kava":
        grad((70, 40, 24), (30, 16, 10))
        txt("KAVA DRAVA", 170, 130, (245, 220, 180))
        txt("Svježe pržena, svako jutro", 300, 54, WHITE, cond=True)
        d.ellipse((440, 360, 584, 470), fill=WHITE)
        d.ellipse((460, 372, 564, 420), fill=(90, 50, 24))
    return im.resize((S, S))


KEYS = ["bulet", "bulet_stand", "police_logo", "pu_plate", "notice", "osijek_map", "flag_hr", "hitna_sign", "gate", "stop", "crossing", "priority", "noentry", "speed50", "works", "closed", "detour", "street", "gunshop", "clothes", "tech", "ad_bulet", "ad_volt", "ad_stil", "ad_osijek", "ad_kava", "tram_stop", "mall_logo", "shop_stil", "shop_volt", "shop_kava", "shop_sport", "shop_knjige", "shop_igracke", "shop_market", "shop_ljekarna"]
