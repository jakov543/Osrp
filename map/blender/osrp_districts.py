"""
OSRP v1.0.40 - Veliki Osijek: new districts around the old city (about 10x the area).

The old city (x -550..550, y -800..345 + Vila) stays as it is. Around it this builds, fully procedural:
  * Drava extended east and west, quay walls, 3 new car bridges
  * arterial roads (Europska avenija + Vukovarska extended, south bypass, ring roads, north grid)
  * SJENJAK (west): tall apartment towers    * JUG 2 (east): 5-8 floor slabs
  * INDUSTRIJSKA ZONA (far east + south): warehouses, silos, yards
  * RETFALA (north-west): family houses with gardens  * PODRAVLJE (north): mid-rise blocks
  * ŠUMA (north-east): forest  * POLJA (south-west): fields with tree lines
Geometry is merged per 100 m tile and material, so the export stays fast and each chunk streams on its own.
"""
import math
import random

XW, XE, YS, YN = -1300.0, 2500.0, -1900.0, 1700.0
TILE = 200.0
RIV0, RIV1 = 175.0, 265.0                         # Drava banks (y)
CORE = (-550.0, 550.0, -800.0, 345.0)
VILA = (290.0, 430.0, 345.0, 440.0)
EXCL = [CORE, VILA]

_BOX = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def _inside(x, y, r, pad=0.0):
    return r[0] - pad <= x <= r[1] + pad and r[2] - pad <= y <= r[3] + pad


def _overlaps(x0, x1, y0, y1, r, pad=0.0):
    return x1 > r[0] - pad and x0 < r[1] + pad and y1 > r[2] - pad and y0 < r[3] + pad


def _blocked(x0, x1, y0, y1, pad=2.0):
    if any(_overlaps(x0, x1, y0, y1, r, pad) for r in EXCL):
        return True
    return y1 > RIV0 - 6 and y0 < RIV1 + 6


class Tiles:
    """collects boxes / quads / roofs per (100 m tile, material) and makes one mesh each"""

    def __init__(self):
        self.parts = {}

    def _bucket(self, x, y, mat):
        key = (math.floor(x / TILE), math.floor(y / TILE), mat.name)
        if key not in self.parts:
            self.parts[key] = ([], [], mat)
        return self.parts[key]

    def box(self, mat, cx, cy, bz, sx, sy, sz):
        vs, fs, _ = self._bucket(cx, cy, mat)
        b = len(vs)
        for z in (bz, bz + sz):
            for (x, y) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)):
                vs.append((cx + x, cy + y, z))
        fs.extend(tuple(b + i for i in f) for f in _BOX)

    def quad(self, mat, x0, y0, x1, y1, z):
        vs, fs, _ = self._bucket((x0 + x1) / 2, (y0 + y1) / 2, mat)
        b = len(vs)
        vs.extend([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)])
        fs.append((b, b + 1, b + 2, b + 3))

    def vquad(self, mat, pts):
        """any 4-point face (pts in order, normal by right-hand rule)"""
        cx = sum(p[0] for p in pts) / 4
        cy = sum(p[1] for p in pts) / 4
        vs, fs, _ = self._bucket(cx, cy, mat)
        b = len(vs)
        vs.extend(pts)
        fs.append((b, b + 1, b + 2, b + 3))

    def roof(self, mat, cx, cy, z, w, d, h, along_x=True):
        """gable roof, ridge along x (or y)"""
        vs, fs, _ = self._bucket(cx, cy, mat)
        b = len(vs)
        w2, d2 = w / 2 + 0.3, d / 2 + 0.3
        if along_x:
            vs.extend([(cx - w2, cy - d2, z), (cx + w2, cy - d2, z), (cx + w2, cy + d2, z), (cx - w2, cy + d2, z), (cx - w2, cy, z + h), (cx + w2, cy, z + h)])
        else:
            vs.extend([(cx - w2, cy - d2, z), (cx + w2, cy - d2, z), (cx + w2, cy + d2, z), (cx - w2, cy + d2, z), (cx, cy - d2, z + h), (cx, cy + d2, z + h)])
        if along_x:
            fs.extend([(b, b + 1, b + 5, b + 4), (b + 3, b + 4, b + 5, b + 2), (b, b + 4, b + 3), (b + 1, b + 2, b + 5), (b, b + 3, b + 2, b + 1)])
        else:
            fs.extend([(b + 1, b + 2, b + 5, b + 4), (b, b + 4, b + 5, b + 3), (b, b + 1, b + 4), (b + 3, b + 5, b + 2), (b, b + 3, b + 2, b + 1)])

    def emit(self, g):
        """one object per tile with several material slots"""
        import bpy
        tiles = {}
        for (tx, ty, mname), (vs, fs, mat) in self.parts.items():
            if fs:
                tiles.setdefault((tx, ty), []).append((vs, fs, mat))
        for (tx, ty), parts in tiles.items():
            verts, faces, mids, mats = [], [], [], []
            for vs, fs, mat in parts:
                b = len(verts)
                verts.extend(vs)
                faces.extend(tuple(b + i for i in f) for f in fs)
                mids.extend([len(mats)] * len(fs))
                mats.append(mat)
            name = f"osrp_okrug_{tx}_{ty}"
            me = bpy.data.meshes.new(name)
            me.from_pydata(verts, [], faces)
            me.update()
            for m in mats:
                me.materials.append(m)
            me.polygons.foreach_set("material_index", mids)
            obj = bpy.data.objects.new(name, me)
            g["col"].objects.link(obj)
        return len(tiles)


def build(g):
    rnd = random.Random(2026)
    mat = g["material"]
    T = Tiles()
    M_ROAD, M_WALK, M_GRASS, M_LINE, M_BASE, M_STONE = g["M_ROAD"], g["M_WALK"], g["M_GRASS"], g["M_LINE"], g["M_BASE"], g["M_STONE"]
    M_CURB = g.get("M_CURB", M_WALK)
    M_PARK = mat("osrp_park_grass_okrug", (0.05, 0.11, 0.035))
    M_SOIL = mat("osrp_soil_polje", (0.20, 0.14, 0.08))
    M_CROP = mat("osrp_grass_polje_zito", (0.30, 0.26, 0.08))
    M_CONC = mat("osrp_apron_industrija", (0.48, 0.47, 0.45))
    M_ROOFTILE = g["M_ROOF"] if "M_ROOF" in g else mat("osrp_roof_tiles_okrug", (0.45, 0.16, 0.10))
    M_FLATROOF = mat("osrp_flatroof_okrug", (0.22, 0.22, 0.24))
    M_SHED = mat("osrp_hangar_metal_okrug", (0.62, 0.64, 0.66), rough=0.4, metal=0.7)
    M_SHED_B = mat("osrp_hangar_metal_okrug_plavi", (0.20, 0.34, 0.55), rough=0.4, metal=0.7)
    M_SILO = mat("osrp_hangar_metal_silos", (0.78, 0.78, 0.76), rough=0.4, metal=0.7)
    M_FENCE = mat("osrp_fence_okrug", (0.30, 0.30, 0.32), metal=0.6)
    M_RIVERBED = mat("osrp_soil_dno_rijeke", (0.16, 0.13, 0.09))
    FLATS = [mat(f"osrp_flats_{k}", c) for k, c in enumerate(((0.86, 0.82, 0.70), (0.80, 0.84, 0.86), (0.88, 0.76, 0.62), (0.74, 0.80, 0.72), (0.90, 0.88, 0.84)))]
    HOUSE = [mat(f"osrp_plaster_kuca_okrug_{k}", c) for k, c in enumerate(((0.92, 0.88, 0.78), (0.86, 0.80, 0.66), (0.94, 0.94, 0.90), (0.80, 0.70, 0.58)))]
    MAPRECTS, TREES, SIGNS, LANDMARKS = g["MAPRECTS"], g["TREES"], g["SIGNS"], g["LANDMARKS"]
    NW = [mat("osrp_nightwin_warm", (1.0, 0.74, 0.38)), mat("osrp_nightwin_soft", (1.0, 0.86, 0.6)), mat("osrp_nightwin_cool", (0.78, 0.86, 1.0))]

    def lit(cx, cy, w, d, floors, p=0.35, fh=3.0):
        """v1.0.41: windows that light up at night (only drawn at night in GTA), on all 4 facades"""
        for side in range(4):
            L = w if side < 2 else d
            for k in range(int(L // 3)):
                for f in range(floors):
                    if rnd.random() > p:
                        continue
                    m = NW[0] if rnd.random() < 0.6 else rnd.choice(NW)
                    a, b = -L / 2 + k * 3 + 0.75, -L / 2 + k * 3 + 2.25
                    z0, z1 = f * fh + 0.75, f * fh + 2.1
                    if side == 0:      # -Y facade
                        y = cy - d / 2 - 0.04
                        T.vquad(m, [(cx + a, y, z0), (cx + b, y, z0), (cx + b, y, z1), (cx + a, y, z1)])
                    elif side == 1:    # +Y
                        y = cy + d / 2 + 0.04
                        T.vquad(m, [(cx + b, y, z0), (cx + a, y, z0), (cx + a, y, z1), (cx + b, y, z1)])
                    elif side == 2:    # +X
                        x = cx + w / 2 + 0.04
                        T.vquad(m, [(x, cy + a, z0), (x, cy + b, z0), (x, cy + b, z1), (x, cy + a, z1)])
                    else:              # -X
                        x = cx - w / 2 - 0.04
                        T.vquad(m, [(x, cy + b, z0), (x, cy + a, z0), (x, cy + a, z1), (x, cy + b, z1)])

    BED_Z = g.get("BED_Z", -20.0)

    def tree(x, y, s=1.0):
        TREES.append((round(x, 2), round(y, 2), round(s, 2), "okrug"))

    # ------------------------------------------------------------ roads (axis aligned)
    ROADS = []                                   # (x0, y0, x1, y1, width)

    def road(x0, y0, x1, y1, w):
        ROADS.append((min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1), w))

    for xa, xb in ((XW + 40, -550), (550, XE - 40)):
        road(xa, 0, xb, 0, 16)                   # Europska avenija
        road(xa, -350, xb, -350, 10)             # Vukovarska
    road(XW + 40, -1000, XE - 40, -1000, 20)     # Južna obilaznica (south bypass)
    road(XW + 50, -1000, XW + 50, RIV0 - 6, 12)  # west ring
    road(XW + 50, RIV1 + 6, XW + 50, YN - 60, 12)
    road(XE - 50, YS + 60, XE - 50, YN - 60, 12)  # east ring
    road(XW + 50, YN - 60, XE - 50, YN - 60, 12)  # north ring
    road(XW + 40, YS + 60, XE - 50, YS + 60, 12)  # far south road
    for x in (-1000, 900, 1700):                 # N-S through roads with Drava bridges
        road(x, YS + 60, x, YN - 60, 12)
    for x in (-700, 1300, 2100):
        road(x, -1000, x, RIV0 - 6, 10)
    for x in (-400, 200, 1300, 2100):
        road(x, RIV1 + 6, x, YN - 60, 10)
    for y in (-700,):
        road(XW + 50, y, -550, y, 10)
        road(550, y, XE - 50, y, 10)
    for y in (500, 800, 1100, 1400):
        road(XW + 50, y, XE - 50, y, 10)
    for y in (-1400,):
        road(XW + 40, y, XE - 50, y, 10)
    for x in (-300, 400):
        road(x, YS + 60, x, -1000, 10)

    def on_river(y0, y1):
        return y1 > RIV0 - 4 and y0 < RIV1 + 4

    for (x0, y0, x1, y1, w) in ROADS:
        horiz = (y1 - y0) < 1
        L = (x1 - x0) if horiz else (y1 - y0)
        n = max(1, int(math.ceil(L / 50.0)))
        for k in range(n):
            if horiz:
                a, b = x0 + L * k / n, x0 + L * (k + 1) / n
                if any(_overlaps(a, b, y0 - w / 2, y0 + w / 2, r, -1) for r in EXCL):
                    continue
                T.quad(M_ROAD, a, y0 - w / 2, b, y0 + w / 2, 0.10)
                for j in range(int((b - a) // 9)):
                    xx = a + 3 + j * 9
                    T.quad(M_LINE, xx, y0 - 0.08, xx + 4, y0 + 0.08, 0.115)
            else:
                a, b = y0 + L * k / n, y0 + L * (k + 1) / n
                if any(_overlaps(x0 - w / 2, x0 + w / 2, a, b, r, -1) for r in EXCL):
                    continue
                if on_river(a, b):                   # bridge deck over the Drava
                    T.box(M_STONE, x0, (a + b) / 2, -0.8, w + 3, b - a, 0.88)
                    T.quad(M_ROAD, x0 - w / 2, a, x0 + w / 2, b, 0.105)
                    for sx in (-1, 1):
                        T.box(M_FENCE, x0 + sx * (w / 2 + 1.2), (a + b) / 2, 0.1, 0.15, b - a, 1.1)
                    continue
                T.quad(M_ROAD, x0 - w / 2, a, x0 + w / 2, b, 0.105)
                for j in range(int((b - a) // 9)):
                    yy = a + 3 + j * 9
                    T.quad(M_LINE, x0 - 0.08, yy, x0 + 0.08, yy + 4, 0.12)
        if horiz:
            MAPRECTS.append(("road", (x0 + x1) / 2, y0, x1 - x0, w))
        else:
            MAPRECTS.append(("road", x0, (y0 + y1) / 2, w, y1 - y0))
    for x in (-1000, 900, 1700):                 # bridge piers
        for yy in (RIV0 + 30, RIV1 - 30):
            T.box(M_STONE, x, yy, BED_Z, 6, 4, -BED_Z - 0.8)
    LANDMARKS.extend([("Most Sjenjak", -1000, 220), ("Most Jug 2", 900, 220), ("Istočni most", 1700, 220)])

    # street lights along the arterials (GTA lamp props from SIGNS)
    for (x0, y0, x1, y1, w) in ROADS:
        horiz = (y1 - y0) < 1
        L = (x1 - x0) if horiz else (y1 - y0)
        for k in range(int(L // 60)):
            t = 30 + k * 60
            px_, py_ = (x0 + t, y0 + w / 2 + 1.0) if horiz else (x0 + w / 2 + 1.0, y0 + t)
            if _blocked(px_ - 1, px_ + 1, py_ - 1, py_ + 1, 3) and not (RIV0 - 6 < py_ < RIV1 + 6 and not horiz):
                continue
            if not horiz and RIV0 - 6 < py_ < RIV1 + 6:
                continue
            SIGNS.append(("ulicna_lampa", round(px_, 2), round(py_, 2), 90.0 if horiz else 0.0))

    # ------------------------------------------------------------ ground (per tile), base slab, river, quay walls
    xs = [XW + i * TILE for i in range(int((XE - XW) / TILE))]
    ys = [YS + i * TILE for i in range(int((YN - YS) / TILE))]
    for x0 in xs:
        for y0 in ys:
            x1, y1 = x0 + TILE, y0 + TILE
            # split around the river and the old city by cutting the tile into 10 m cells only where needed
            if not (_overlaps(x0, x1, y0, y1, CORE) or _overlaps(x0, x1, y0, y1, VILA) or (y1 > RIV0 and y0 < RIV1)):
                T.quad(M_GRASS, x0, y0, x1, y1, 0.0)
                T.box(M_BASE, (x0 + x1) / 2, (y0 + y1) / 2, -2.0, TILE, TILE, 1.97)
                continue
            n10 = int(TILE // 10)                    # v1.0.42: whole tile (was only the first 100 m -> holes by the river)
            for cx in range(n10):
                for cy in range(n10):
                    a, b = x0 + cx * 10, y0 + cy * 10
                    free = [(b, b + 10)]                     # cells are aligned in x, so only clip in y
                    cuts = [(RIV0, RIV1)] + [(r[2], r[3]) for r in EXCL if a + 10 > r[0] + 0.01 and a < r[1] - 0.01]
                    for (c0, c1) in cuts:
                        nxt = []
                        for (f0, f1) in free:
                            if c1 <= f0 or c0 >= f1:
                                nxt.append((f0, f1))
                                continue
                            if c0 > f0:
                                nxt.append((f0, c0))
                            if c1 < f1:
                                nxt.append((c1, f1))
                        free = nxt
                    for (f0, f1) in free:
                        if f1 - f0 < 0.01:
                            continue
                        T.quad(M_GRASS, a, f0, a + 10, f1, 0.0)
                        T.box(M_BASE, a + 5, (f0 + f1) / 2, -2.0, 10, f1 - f0, 1.97)
    for (a, b) in ((XW, CORE[0]), (CORE[1], XE)):          # Drava east + west of the old city
        for x in range(int(a), int(b), 100):
            xe = min(b, x + 100)
            for yy in (RIV0 - 1.5, RIV1 + 1.5):
                T.box(M_STONE, (x + xe) / 2, yy, BED_Z, xe - x, 3, -BED_Z + 0.05)
        MAPRECTS.append(("water", (a + b) / 2, (RIV0 + RIV1) / 2, b - a, RIV1 - RIV0))
        for x in range(int(a), int(b), 100):                 # v1.0.42: river bed under the water (no void under the Drava)
            xe = min(b, x + 100)
            T.quad(M_RIVERBED, x, RIV0, xe, RIV1, BED_Z)
    for (x, y, sx, sy) in ((XW - 1.5, 0, 3, YN - YS), (XE + 1.5, 0, 3, YN - YS), (0, YS - 1.5, XE - XW, 3), (0, YN + 1.5, XE - XW, 3)):
        cxw = (XW + XE) / 2 if sx > 3 else x
        cyw = (YS + YN) / 2 if sy > 3 else y
        L = sx if sx > 3 else sy
        for k in range(int(L // 100) + 1):
            if sx > 3:
                a = XW + k * 100
                if a >= XE:
                    break
                T.box(M_STONE, a + 50, cyw, BED_Z, 100, 3, -BED_Z + 0.05)
            else:
                a = YS + k * 100
                if a >= YN:
                    break
                if a + 100 > RIV0 and a < RIV1:
                    continue
                T.box(M_STONE, cxw, a + 50, BED_Z, 3, 100, -BED_Z + 0.05)
    for (x0, x1, y0, y1) in ((XW, CORE[0], YS, RIV0), (CORE[1], XE, YS, RIV0), (CORE[0], CORE[1], YS, CORE[2]),
                             (XW, XE, RIV1, YN)):
        MAPRECTS.insert(0, ("land", (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0))

    # ------------------------------------------------------------ blocks between the roads
    def lots(x0, x1, y0, y1):
        """cut a region into blocks along the road grid; returns block rects (inside the road edges)"""
        xcuts = sorted({x0, x1} | {r[0] for r in ROADS if r[0] == r[2] and x0 < r[0] < x1 and r[1] <= y0 + 1 and r[3] >= y1 - 1})
        ycuts = sorted({y0, y1} | {r[1] for r in ROADS if r[1] == r[3] and y0 < r[1] < y1 and r[0] <= x0 + 1 and r[2] >= x1 - 1})
        out = []
        for i in range(len(xcuts) - 1):
            for j in range(len(ycuts) - 1):
                out.append((xcuts[i] + 9, xcuts[i + 1] - 9, ycuts[j] + 9, ycuts[j + 1] - 9))
        return out

    def sidewalk_ring(b):
        x0, x1, y0, y1 = b
        for (cx, cy, sx, sy) in (((x0 + x1) / 2, y0 + 1.5, x1 - x0, 3), ((x0 + x1) / 2, y1 - 1.5, x1 - x0, 3),
                                 (x0 + 1.5, (y0 + y1) / 2, 3, y1 - y0 - 6), (x1 - 1.5, (y0 + y1) / 2, 3, y1 - y0 - 6)):
            n = max(1, int(math.ceil(max(sx, sy) / 60)))
            for k in range(n):
                if sx >= sy:
                    a = x0 + (x1 - x0) * k / n
                    T.box(M_WALK, a + (x1 - x0) / n / 2, cy, 0.0, (x1 - x0) / n, sy, 0.15)
                else:
                    a = y0 + 3 + (y1 - y0 - 6) * k / n
                    T.box(M_WALK, cx, a + (y1 - y0 - 6) / n / 2, 0.0, sx, (y1 - y0 - 6) / n, 0.15)

    def fill(b, kind):
        MAPRECTS.append((kind, (b[0] + b[1]) / 2, (b[2] + b[3]) / 2, b[1] - b[0], b[3] - b[2]))

    def tower_block(b):                          # Sjenjak: 10-14 floor towers on a green lot + car parks
        x0, x1, y0, y1 = b
        fill(b, "park")
        T.quad(M_PARK, x0 + 3, y0 + 3, x1 - 3, y1 - 3, 0.02)
        x = x0 + 22
        while x < x1 - 20:
            y = y0 + 24
            while y < y1 - 22:
                if rnd.random() < 0.82:
                    fl = rnd.randint(10, 14)
                    m = rnd.choice(FLATS)
                    T.box(m, x, y, 0.0, 18, 18, fl * 3.0)
                    lit(x, y, 18, 18, fl, 0.32)
                    T.box(M_FLATROOF, x, y, fl * 3.0, 18.6, 18.6, 0.5)
                    T.box(M_FLATROOF, x + 4, y - 3, fl * 3.0 + 0.5, 4, 4, 2.5)          # lift room on the roof
                    MAPRECTS.append(("bld", x, y, 18, 18))
                    T.quad(M_ROAD, x - 14, y - 22, x + 14, y - 13, 0.06)                # car park in front
                else:
                    for k in range(5):
                        tree(x + rnd.uniform(-10, 10), y + rnd.uniform(-10, 10), rnd.uniform(0.8, 1.2))
                y += 44
            x += 42

    def slab_block(b):                           # Jug 2 / Podravlje: long 5-8 floor slabs
        x0, x1, y0, y1 = b
        fill(b, "park")
        T.quad(M_PARK, x0 + 3, y0 + 3, x1 - 3, y1 - 3, 0.02)
        y = y0 + 18
        while y < y1 - 14:
            x = x0 + 12
            while x < x1 - 30:
                w = min(rnd.choice((48, 60, 72)), x1 - 12 - x)
                if w > 28:
                    fl = rnd.randint(5, 8)
                    m = rnd.choice(FLATS)
                    T.box(m, x + w / 2, y, 0.0, w, 13, fl * 3.0)
                    lit(x + w / 2, y, w, 13, fl, 0.32)
                    T.box(M_FLATROOF, x + w / 2, y, fl * 3.0, w + 0.6, 13.6, 0.45)
                    for k in range(int(w // 16)):                              # stair cores sticking out of the roof
                        T.box(M_FLATROOF, x + 8 + k * 16, y, fl * 3.0 + 0.45, 3.5, 5, 2.4)
                    MAPRECTS.append(("bld", x + w / 2, y, w, 13))
                    for k in range(int(w // 12)):
                        tree(x + 6 + k * 12, y + 11, rnd.uniform(0.8, 1.1))
                x += w + 14
            y += 34

    def house_block(b):                          # Retfala: family houses with front yards, fences, gable roofs, back gardens
        x0, x1, y0, y1 = b
        fill(b, "park")
        rows = [(-1, y0), (1, y1)]                  # s_ = side of the street (-1 = street below the houses, +1 = above)
        yl = y0 + 58
        while yl < y1 - 45:                         # inner lanes with houses on both sides
            T.quad(M_ROAD, x0 + 3, yl - 3, x1 - 3, yl + 3, 0.06)
            MAPRECTS.append(("road", (x0 + x1) / 2, yl, x1 - x0 - 6, 6))
            rows += [(-1, yl + 3), (1, yl - 3)]
            yl += 58
        for s_, edge in rows:
            x = x0 + 8
            while x < x1 - 14:
                w, d = rnd.choice(((9, 10), (10, 11), (11, 9), (12, 10)))
                fl = rnd.choice((1, 1, 2))
                hy = edge - s_ * (3 + 5 + d / 2)          # 3 m sidewalk + 5 m front yard
                T.box(rnd.choice(HOUSE), x + w / 2, hy, 0.0, w, d, fl * 3.0)
                lit(x + w / 2, hy, w, d, fl, 0.4)
                T.roof(M_ROOFTILE, x + w / 2, hy, fl * 3.0, w, d, rnd.uniform(2.2, 3.0), along_x=True)
                T.box(M_FENCE, x + w / 2 - 1.5, edge - s_ * 3.6, 0.0, w + 4, 0.1, 1.0)          # street fence, gate gap at the drive
                T.quad(M_CONC, x + w + 0.6, min(edge - s_ * 3, hy), x + w + 3.6, max(edge - s_ * 3, hy), 0.03)
                if rnd.random() < 0.75:
                    tree(x + w / 2 + rnd.uniform(-2, 2), hy - s_ * (d / 2 + 6), rnd.uniform(0.7, 1.1))
                MAPRECTS.append(("bld", x + w / 2, hy, w, d))
                x += w + 9

    def industry_block(b):                       # warehouses, silos, yards
        x0, x1, y0, y1 = b
        fill(b, "yard")
        T.quad(M_CONC, x0 + 3, y0 + 3, x1 - 3, y1 - 3, 0.03)
        x, w = x0 + 8, 40
        while x < x1 - 30:
            y = y0 + 8
            while y < y1 - 25:
                w = min(rnd.choice((40, 55, 70, 85)), x1 - 8 - x)
                d = min(rnd.choice((30, 40, 50)), y1 - 8 - y)
                if w < 25 or d < 20:
                    break
                if rnd.random() < 0.15:                                 # silo group
                    for k in range(3):
                        for s in range(8):
                            a = s * math.pi / 4
                            T.box(M_SILO, x + 8 + k * 12 + math.cos(a) * 4.2, y + 10 + math.sin(a) * 4.2, 0.0, 3.4, 3.4, 22)
                        T.box(M_FLATROOF, x + 8 + k * 12, y + 10, 22, 9, 9, 0.6)
                        MAPRECTS.append(("bld", x + 8 + k * 12, y + 10, 9, 9))
                else:
                    h = rnd.choice((8, 10, 12))
                    m = rnd.choice((M_SHED, M_SHED, M_SHED_B))
                    T.box(m, x + w / 2, y + d / 2, 0.0, w, d, h)
                    lit(x + w / 2, y + d / 2, w, d, 1, 0.12, fh=4.0)
                    T.roof(M_SHED, x + w / 2, y + d / 2, h, w, d, 2.0, along_x=w >= d)
                    for k in range(int(w // 14)):                       # loading doors
                        T.box(M_FLATROOF, x + 6 + k * 14, y - 0.05, 0.0, 4.5, 0.2, 5.0)
                    MAPRECTS.append(("bld", x + w / 2, y + d / 2, w, d))
                y += d + 14
            x += w + 14
        for k in range(0, int(x1 - x0), 6):                             # fence round the yard
            pass
        T.box(M_FENCE, (x0 + x1) / 2, y0 + 3.2, 0.0, x1 - x0 - 6, 0.08, 2.2)
        T.box(M_FENCE, (x0 + x1) / 2, y1 - 3.2, 0.0, x1 - x0 - 6, 0.08, 2.2)

    def field_block(b):                          # fields with tree lines, a farm house now and then
        x0, x1, y0, y1 = b
        fill(b, "field")
        stripes = max(1, int((x1 - x0) // 60))
        for k in range(stripes):
            a, c = x0 + (x1 - x0) * k / stripes, x0 + (x1 - x0) * (k + 1) / stripes
            T.quad(rnd.choice((M_SOIL, M_CROP, M_PARK)), a + 1, y0 + 4, c - 1, y1 - 4, 0.02)
        for yy in (y0 + 6, y1 - 6):
            for k in range(int((x1 - x0) // 14)):
                tree(x0 + 7 + k * 14, yy, rnd.uniform(0.9, 1.3))
        if rnd.random() < 0.5:
            fx, fy = x0 + 30, y0 + 30
            T.box(rnd.choice(HOUSE), fx, fy, 0.0, 12, 9, 3.0)
            T.roof(M_ROOFTILE, fx, fy, 3.0, 12, 9, 3.0)
            T.box(M_SHED, fx + 22, fy, 0.0, 18, 12, 6.0)
            T.roof(M_SHED, fx + 22, fy, 6.0, 18, 12, 1.5)
            MAPRECTS.append(("bld", fx, fy, 12, 9))

    def forest_block(b):
        x0, x1, y0, y1 = b
        T.quad(M_PARK, x0 + 3, y0 + 3, x1 - 3, y1 - 3, 0.02)
        for k in range(int((x1 - x0) * (y1 - y0) / 260)):
            tree(rnd.uniform(x0 + 5, x1 - 5), rnd.uniform(y0 + 5, y1 - 5), rnd.uniform(0.9, 1.5))
        MAPRECTS.append(("park", (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0))

    REGIONS = [
        ("SJENJAK", (XW + 50, -550, -1000, RIV0 - 6), tower_block),
        ("JUG 2", (550, 1700, -1000, RIV0 - 6), slab_block),
        ("INDUSTRIJSKA ZONA ISTOK", (1700, XE - 50, -1000, RIV0 - 6), industry_block),
        ("JUŽNA INDUSTRIJSKA ZONA", (400, XE - 50, YS + 60, -1000), industry_block),
        ("POLJA", (XW + 40, 400, YS + 60, -1000), field_block),
        ("RETFALA", (XW + 50, 200, RIV1 + 6, YN - 60), house_block),
        ("PODRAVLJE", (200, 1700, RIV1 + 6, YN - 60), slab_block),
        ("ŠUMA", (1700, XE - 50, RIV1 + 6, YN - 60), forest_block),
        ("AERODROM JUG", (-550, 550, -1000, -800), field_block),
    ]
    nb = 0
    for name, (x0, x1, y0, y1), fn in REGIONS:
        for b in lots(x0, x1, y0, y1):
            if b[1] - b[0] < 30 or b[3] - b[2] < 30:
                continue
            parts = [b]
            for r in EXCL:                       # cut away the old city / Vila, keep the free pieces
                nxt = []
                for (a0, a1, c0, c1) in parts:
                    if not _overlaps(a0, a1, c0, c1, r, 4):
                        nxt.append((a0, a1, c0, c1))
                        continue
                    for piece in ((a0, r[0] - 6, c0, c1), (r[1] + 6, a1, c0, c1),
                                  (max(a0, r[0] - 6), min(a1, r[1] + 6), r[3] + 6, c1), (max(a0, r[0] - 6), min(a1, r[1] + 6), c0, r[2] - 6)):
                        if piece[1] - piece[0] >= 30 and piece[3] - piece[2] >= 30:
                            nxt.append(piece)
                parts = nxt
            for p_ in parts:
                if p_[3] > RIV0 - 6 and p_[2] < RIV1 + 6:
                    continue
                sidewalk_ring(p_)
                fn(p_)
                nb += 1
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        LANDMARKS.append((name.title() if name.isupper() else name, cx, cy))
    g["DISTRICTS"] = [(n, (r[0] + r[1]) / 2, (r[2] + r[3]) / 2) for n, r, _ in REGIONS]

    # ------------------------------------------------------------ v1.0.41 bike lanes along both Drava banks, joined to the old ones
    M_BIKE = g.get("M_BIKE", M_ROAD)
    BS, BN = g.get("BIKE_S", 157.5), g.get("BIKE_N", 308.25)
    BIKE_S2, BIKE_N2 = RIV0 - 10.0, RIV1 + 7.0
    for (a, b) in ((XW + 60, -556.0), (556.0, XE - 60)):
        for yy in (BIKE_S2, BIKE_N2):
            for k in range(int(math.ceil((b - a) / 100))):
                x0_, x1_ = a + k * 100, min(b, a + (k + 1) * 100)
                T.box(M_BIKE, (x0_ + x1_) / 2, yy, 0.0, x1_ - x0_, 2.6, 0.14)
                for j in range(int((x1_ - x0_) // 5)):
                    T.quad(M_LINE, x0_ + j * 5 + 1, yy - 0.06, x0_ + j * 5 + 3, yy + 0.06, 0.145)
            g["BIKEROUTES"].append((a, yy, b, yy))
            MAPRECTS.append(("bike", (a + b) / 2, yy, b - a, 2.6))
    for sx in (-1, 1):                                     # connectors from the old lanes
        T.box(M_BIKE, sx * 552.0, BS, 0.0, 8.0, 2.6, 0.14)
        T.box(M_BIKE, sx * 554.7, (BS + BIKE_S2) / 2, 0.0, 2.6, abs(BIKE_S2 - BS) + 2.6, 0.14)
        T.box(M_BIKE, sx * 552.0, BN, 0.0, 8.0, 2.6, 0.14)
        T.box(M_BIKE, sx * 554.7, (BN + BIKE_N2) / 2, 0.0, 2.6, abs(BN - BIKE_N2) + 2.6, 0.14)

    # ------------------------------------------------------------ v1.0.41 lit windows in the old city at night (on the window glass)
    glass = g.get("M_GLASS")
    if glass is not None:
        nlit = 0
        for o in list(g["col"].objects):
            if o.type != "MESH" or not any(m == glass for m in o.data.materials):
                continue
            mw = o.matrix_world
            for poly in o.data.polygons:
                if o.data.materials[poly.material_index] != glass or len(poly.vertices) != 4:
                    continue
                n = (mw.to_3x3() @ poly.normal).normalized()
                if abs(n.z) > 0.2 or poly.area < 0.5 or rnd.random() > 0.38:
                    continue
                pts = [mw @ o.data.vertices[i].co for i in poly.vertices]
                c = sum(pts, pts[0] * 0) / 4
                pts = [tuple(c + (p - c) * 0.9 + n * 0.035) for p in pts]
                T.vquad(NW[0] if rnd.random() < 0.6 else rnd.choice(NW), pts)
                nlit += 1
        print(f"[OSRP] night windows in the old city: {nlit}")

    # ------------------------------------------------------------ v1.0.41 road network for the traffic (nodes = crossings, edges = street pieces)
    H, V = [], []                                          # (y, x0, x1, w) / (x, y0, y1, w)
    for y, w in ((-350, 10), (-180, 10), (0, 16), (125, 10)):
        H.append((y, -550.0, 550.0, w))
    for x in (-450, -300, -150, 0, 150, 300, 450):
        V.append((x, -350.0, 125.0, 10))
    for (x0, y0, x1, y1, w) in ROADS:
        if (y1 - y0) < 1:
            H.append((y0, x0, x1, w))
        else:
            V.append((x0, y0, x1 if False else y1, w))
    nodes, index, edges = [], {}, []

    def nid(x, y):
        k = (round(x * 2) / 2, round(y * 2) / 2)
        if k not in index:
            index[k] = len(nodes)
            nodes.append([k[0], k[1]])
        return index[k]

    def speed(w):
        return 19.0 if w >= 20 else (13.5 if w >= 16 else 11.0)

    for (y, x0, x1, w) in H:
        xs_ = {x0, x1} | {v[0] for v in V if x0 - 1 <= v[0] <= x1 + 1 and v[1] - 1 <= y <= v[2] + 1}
        xs_ = sorted(xs_)
        for a, b in zip(xs_, xs_[1:]):
            if b - a > 2:
                edges.append([nid(a, y), nid(b, y), w, speed(w)])
    for (x, y0, y1, w) in V:
        ys_ = {y0, y1} | {h[0] for h in H if y0 - 1 <= h[0] <= y1 + 1 and h[1] - 1 <= x <= h[2] + 1}
        ys_ = sorted(ys_)
        for a, b in zip(ys_, ys_[1:]):
            if b - a > 2:
                edges.append([nid(x, a), nid(x, b), w, speed(w)])
    g["ROADNET"] = {"nodes": nodes, "edges": edges}
    print(f"[OSRP] road network: {len(nodes)} crossings, {len(edges)} street pieces")
    meshes = T.emit(g)
    print(f"[OSRP] Veliki Osijek: {nb} new blocks, {len(ROADS)} roads, {meshes} district meshes")
