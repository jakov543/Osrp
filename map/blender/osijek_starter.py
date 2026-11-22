"""
OSRP - Osijek starter map for Blender (V1.0.20)

How to use:
  1. Open Blender (4.x), go to the "Scripting" tab.
  2. Open this file and press "Run Script".
  3. Collection "OSRP_Osijek" is created:
     - Drava river with stone banks and the promenade (lindens, benches, lamps)
     - Europska avenija: 4 lanes, dashed lines, curbs, street lights on both sides
     - city blocks: buildings with rows of windows and pitched tile roofs
     - Tvrđa square with the red-brick cathedral and its spire
     - a city park with trees and paths, the pedestrian bridge
     - v1.0.4: sidewalks + curbs on all streets, zebra crossings, clean intersections,
       Holy Trinity column + fountain in Tvrđa, flower beds, bus stops
  4. Follow map/BLENDER-MAP.md to convert it with Sollumz and put it in FiveM.

All sizes are in meters (GTA V uses meters too). Lamp heads use an emission
material, so they glow in night renders (Cycles/EEVEE).
"""
import bpy
import math
import random

random.seed(31000)  # Osijek postal code - same city every time

COL_NAME = "OSRP_Osijek"


# ---------------------------------------------------------------- helpers
def get_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def clear_collection(col):
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def material(name, rgb, rough=0.8, metal=0.0, emit=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emit > 0:
            key = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
            bsdf.inputs[key].default_value = (*rgb, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit
    mat.diffuse_color = (*rgb, 1.0)
    return mat


def _link(col, obj, mat):
    if mat:
        obj.data.materials.append(mat)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def _mesh_obj(col, name, verts, faces, mat):
    """create an object straight from vertex data (much faster than bpy.ops in a big scene)"""
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    col.objects.link(obj)
    if mat:
        me.materials.append(mat)
    return obj


_BOX_FACES = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


GRID = 100.0   # must match CHUNK in osijek_export_gta.py


def _cuts(c, half):
    """split [c-half, c+half] at multiples of GRID -> list of (centre, half)"""
    a0, a1 = c - half, c + half
    pts = [a0] + [k * GRID for k in range(math.floor(a0 / GRID) + 1, math.ceil(a1 / GRID)) if a0 < k * GRID < a1] + [a1]
    return [((p + q) / 2, (q - p) / 2) for p, q in zip(pts, pts[1:]) if q - p > 1e-3]


def box(col, name, loc, size, mat, rot_z=0.0):
    """loc = center of the bottom face, size = full (x, y, z) in meters.
    v1.0.13: long axis-aligned boxes are cut at the 100 m chunk lines, so every piece streams with its own chunk
    (a 1100 m road in one chunk vanished at the city edges)"""
    if rot_z == 0.0 and (size[0] > GRID or size[1] > GRID):
        for i, (cx, hx) in enumerate(_cuts(loc[0], size[0] / 2)):
            for j, (cy, hy) in enumerate(_cuts(loc[1], size[1] / 2)):
                _box(col, f"{name}_{i}_{j}", (cx, cy, loc[2]), (hx * 2, hy * 2, size[2]), mat)
        return None
    return _box(col, name, loc, size, mat, rot_z)


def _box(col, name, loc, size, mat, rot_z=0.0):
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2]
    c, s_ = math.cos(rot_z), math.sin(rot_z)
    verts = []
    for z in (0.0, sz):
        for (x, y) in ((-sx, -sy), (sx, -sy), (sx, sy), (-sx, sy)):
            verts.append((loc[0] + x * c - y * s_, loc[1] + x * s_ + y * c, loc[2] + z))
    return _mesh_obj(col, name, verts, _BOX_FACES, mat)


def plane(col, name, loc, size, mat):
    if size[0] > GRID or size[1] > GRID:
        for i, (cx, hx) in enumerate(_cuts(loc[0], size[0] / 2)):
            for j, (cy, hy) in enumerate(_cuts(loc[1], size[1] / 2)):
                _plane(col, f"{name}_{i}_{j}", (cx, cy, loc[2]), (hx * 2, hy * 2), mat)
        return None
    return _plane(col, name, loc, size, mat)


def _plane(col, name, loc, size, mat):
    sx, sy = size[0] / 2, size[1] / 2
    verts = [(loc[0] - sx, loc[1] - sy, loc[2]), (loc[0] + sx, loc[1] - sy, loc[2]),
             (loc[0] + sx, loc[1] + sy, loc[2]), (loc[0] - sx, loc[1] + sy, loc[2])]
    return _mesh_obj(col, name, verts, [(0, 1, 2, 3)], mat)


def cylinder(col, name, loc, radius, height, mat, verts=10):
    vs = []
    for z in (0.0, height):
        for k in range(verts):
            a = k / verts * math.tau
            vs.append((loc[0] + math.cos(a) * radius, loc[1] + math.sin(a) * radius, loc[2] + z))
    faces = [tuple(range(verts - 1, -1, -1)), tuple(range(verts, 2 * verts))]
    faces += [(k, (k + 1) % verts, verts + (k + 1) % verts, verts + k) for k in range(verts)]
    return _mesh_obj(col, name, vs, faces, mat)


def blob(col, name, loc, radius, mat, squash=1.0):
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    for v in bm.verts:
        v.co.z *= squash
        v.co.x += loc[0]; v.co.y += loc[1]; v.co.z += loc[2]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    col.objects.link(obj)
    if mat:
        me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = True
    return obj


def pyramid(col, name, loc, base, height, mat):
    """4-sided spire; base = half diagonal (like the old cone radius), rotated 45 deg"""
    r = base
    pts = [(loc[0] + r * math.cos(a), loc[1] + r * math.sin(a), loc[2]) for a in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4)]
    verts = pts + [(loc[0], loc[1], loc[2] + height)]
    faces = [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    return _mesh_obj(col, name, verts, faces, mat)


def gable_roof(col, name, cx, cy, z, w, d, h, mat, rot_z=0.0):
    """pitched (gable) roof: ridge runs along local x, overhang 0.4 m"""
    w2, d2 = w / 2 + 0.4, d / 2 + 0.4
    verts = [(-w2, -d2, 0), (w2, -d2, 0), (w2, d2, 0), (-w2, d2, 0), (-w2, 0, h), (w2, 0, h)]
    faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = (cx, cy, z)
    obj.rotation_euler = (0, 0, rot_z)
    col.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def windows(col, name, cx, face_y, z0, width, floors, floor_h, mat, facing):
    """all windows of one facade in one mesh: glass + a stone sill under each window"""
    cols = max(1, int((width - 2) // 3.2))
    step = (width - 2) / cols
    x0 = cx - (width - 2) / 2 + step / 2
    verts, faces = [], []

    def add_box(bx, by, bz, sx, sy, sz):
        base = len(verts)
        for z in (bz, bz + sz):
            for (x, y) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)):
                verts.append((bx + x, by + y, z))
        faces.extend(tuple(base + i for i in f) for f in _BOX_FACES)

    for f in range(floors):
        for c in range(cols):
            x = x0 + c * step
            z = z0 + 1.0 + f * floor_h
            add_box(x, face_y + 0.06 * facing, z, 1.3, 0.12, 1.6)            # glass
            add_box(x, face_y + 0.12 * facing, z - 0.12, 1.55, 0.24, 0.12)   # sill
    return _mesh_obj(col, name, verts, faces, mat)


# ---------------------------------------------------------------- materials
M_GRASS = material("osrp_grass", (0.075, 0.13, 0.04))
M_PARK = material("osrp_park_grass", (0.085, 0.155, 0.05))
M_ROAD = material("osrp_asphalt", (0.06, 0.06, 0.07), rough=0.95)
M_LINE = material("osrp_road_line", (0.92, 0.92, 0.88))
M_WALK = material("osrp_pavement", (0.50, 0.49, 0.46))
M_CURB = material("osrp_curb", (0.62, 0.61, 0.58))
M_PATH = material("osrp_gravel_path", (0.62, 0.55, 0.42))
M_STONE = material("osrp_river_stone", (0.40, 0.38, 0.35))
M_COBBLE = material("osrp_cobble", (0.47, 0.44, 0.40))
M_IRON = material("osrp_manhole", (0.16, 0.16, 0.16), rough=0.6, metal=0.6)
M_WATER = material("osrp_drava_water", (0.07, 0.20, 0.23), rough=0.05)
M_BRICK = material("osrp_red_brick", (0.45, 0.14, 0.09))
M_ROOF = material("osrp_roof_tiles", (0.42, 0.13, 0.07))
M_SPIRE = material("osrp_spire", (0.30, 0.09, 0.06))
M_GLASS = material("osrp_window_glass", (0.08, 0.11, 0.15), rough=0.1, metal=0.3)
M_PLASTER = [
    material("osrp_plaster_yellow", (0.86, 0.73, 0.42)),
    material("osrp_plaster_white", (0.88, 0.86, 0.82)),
    material("osrp_plaster_peach", (0.88, 0.62, 0.48)),
    material("osrp_plaster_green", (0.60, 0.70, 0.55)),
    material("osrp_plaster_grey", (0.62, 0.62, 0.64)),
]
M_POLE = material("osrp_lamp_pole", (0.10, 0.11, 0.12), rough=0.4, metal=0.8)
M_LAMP = material("osrp_lamp_light", (1.0, 0.82, 0.55), emit=25.0)
M_STEEL = material("osrp_bridge_steel", (0.75, 0.77, 0.80), rough=0.3, metal=1.0)
M_TRUNK = material("osrp_tree_trunk", (0.22, 0.15, 0.09))
M_LEAVES = [
    material("osrp_leaves_dark", (0.10, 0.25, 0.07)),
    material("osrp_leaves_mid", (0.15, 0.33, 0.09)),
    material("osrp_leaves_light", (0.24, 0.42, 0.12)),
]
M_WOOD = material("osrp_bench_wood", (0.40, 0.25, 0.12))
M_FLOWERS = [material("osrp_flowers_red", (0.75, 0.10, 0.12)), material("osrp_flowers_pink", (0.85, 0.40, 0.60)),
             material("osrp_flowers_yellow", (0.95, 0.78, 0.15))]
M_SOIL = material("osrp_soil", (0.22, 0.15, 0.10))
M_WHITE_STONE = material("osrp_white_stone", (0.82, 0.80, 0.74))
M_GOLD = material("osrp_gold", (0.85, 0.65, 0.20), rough=0.3, metal=1.0)
M_GLASS_STOP = material("osrp_busstop_glass", (0.55, 0.70, 0.75), rough=0.05)


# ---------------------------------------------------------------- props
def street_light(col, i, x, y, facing):
    """facing = +1 arm points to +y, -1 arm points to -y"""
    cylinder(col, f"osrp_lampa_stup_{i}", (x, y, 0), 0.12, 7.0, M_POLE, verts=8)
    box(col, f"osrp_lampa_ruka_{i}", (x, y + facing * 0.8, 6.85), (0.12, 1.7, 0.12), M_POLE)
    box(col, f"osrp_lampa_svjetlo_{i}", (x, y + facing * 1.55, 6.65), (0.45, 0.7, 0.2), M_LAMP)


TREES = []   # (x, y, scale, kind) - the GTA export swaps these for real GTA V tree props


def tree(col, i, x, y, scale=1.0):
    TREES.append((round(x, 2), round(y, 2), round(scale, 2), str(i).split("_")[0]))
    h = random.uniform(3.2, 4.5) * scale
    cylinder(col, f"osrp_drvo_deblo_{i}", (x, y, 0), 0.22 * scale, h, M_TRUNK, verts=8)
    for k in range(3):
        r = random.uniform(1.6, 2.4) * scale
        ox, oy = random.uniform(-0.9, 0.9) * scale, random.uniform(-0.9, 0.9) * scale
        oz = h + random.uniform(0.2, 1.8) * scale
        blob(col, f"osrp_drvo_krosnja_{i}_{k}", (x + ox, y + oy, oz), r, random.choice(M_LEAVES), squash=0.85)


BENCHES = []   # (x, y, heading) - NPCs sit here


def bench(col, i, x, y, back=1):
    """bench along x; back=+1 backrest on the +y side (you sit facing -y), back=-1 the other way"""
    # v1.0.18: a real GTA bench is placed here in-game (heading = the way you look when you sit)
    BENCHES.append((round(x, 2), round(y, 2), 180.0 if back == 1 else 0.0))


# ---------------------------------------------------------------- build
col = get_collection(COL_NAME)
clear_collection(col)

MAP_W = 1100                 # v1.0.11: bigger city (7 cross streets, 3 rows of blocks)
RIVER_Y, RIVER_W = 220, 90
ROAD_W = 16                      # Europska avenija: 4 lanes
SIDE_ROAD_W = 10

# Ground
plane(col, "osrp_ground_south", (0, -105, 0), (MAP_W, 530), M_GRASS)
SOUTH_END = -780                      # v1.0.14: land goes south to the hospital and the airport
plane(col, "osrp_ground_jug_prosirenje", (0, (-370 + SOUTH_END) / 2, 0), (MAP_W, -370 - SOUTH_END), M_GRASS)
plane(col, "osrp_ground_north", (0, RIVER_Y + RIVER_W / 2 + 40, 0), (MAP_W, 80), M_GRASS)

# Drava + stone banks
# v1.0.12: no fake water plane - the river bed is open, so the real GTA sea water fills the Drava
# (the city sits 3 m above sea level, see osrp_osijek Config.Origin). Stone walls go down into the water.
box(col, "osrp_obala_jug", (0, RIVER_Y - RIVER_W / 2 - 1.5, -12), (MAP_W, 3, 12.05), M_STONE)
box(col, "osrp_obala_sjever", (0, RIVER_Y + RIVER_W / 2 + 1.5, -12), (MAP_W, 3, 12.05), M_STONE)
# outer quay walls: the city stands 3 m above the GTA sea, these walls go down into the water so it is not a floating plate
S0, S1 = SOUTH_END, -105 + 265            # south land band (y)
N0, N1 = RIVER_Y + RIVER_W / 2, RIVER_Y + RIVER_W / 2 + 80
box(col, "osrp_rub_jug", (0, S0 - 1.5, -12), (MAP_W + 6, 3, 12.05), M_STONE)
box(col, "osrp_rub_sjever", (0, N1 + 1.5, -12), (MAP_W + 6, 3, 12.05), M_STONE)
for sx in (-1, 1):
    box(col, f"osrp_rub_istok_jug_{sx}", (sx * (MAP_W / 2 + 1.5), (S0 + S1) / 2, -12), (3, S1 - S0, 12.05), M_STONE)
    box(col, f"osrp_rub_istok_sjever_{sx}", (sx * (MAP_W / 2 + 1.5), (N0 + N1) / 2, -12), (3, N1 - N0, 12.05), M_STONE)

# v1.0.19: stone stairs from the quays down to the Drava, railing along the quays, floating marina with boats
WATER_Z = -8.0                         # GTA sea level in city coordinates (city is 8 m above the sea)
STEP_H, STEP_RUN, STAIR_W, PARAPET = 0.25, 0.36, 3.2, 0.4
M_FLOAT = material("osrp_white_stone_float", (0.80, 0.80, 0.78))


def boxes_mesh(name, boxes, mat):
    """many boxes in one object: (cx, cy, bottom_z, sx, sy, sz)"""
    verts, faces = [], []
    for (bx, by, bz, sx, sy, sz) in boxes:
        base = len(verts)
        for z in (bz, bz + sz):
            for (x, y) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)):
                verts.append((bx + x, by + y, z))
        faces.extend(tuple(base + i for i in f) for f in _BOX_FACES)
    return _mesh_obj(col, name, verts, faces, mat)


STAIRS = []                            # (x0, bank) - also used for the railing openings


def river_stairs(name, x0, bank):
    """bank = -1 south wall (inner face y = RIVER_Y - RIVER_W/2), +1 north wall. Steps go down along +x, parapet on the water side."""
    face = RIVER_Y + bank * RIVER_W / 2
    walk_c = face - bank * (STAIR_W - PARAPET) / 2           # centre of the walkable part (next to the quay wall)
    par_c = face - bank * (STAIR_W - PARAPET / 2)             # parapet on the water side
    n = int(round((0 - (WATER_Z + 0.35)) / STEP_H))
    steps, par = [], []
    for k in range(n):
        top = -(k + 1) * STEP_H
        x = x0 + k * STEP_RUN + STEP_RUN / 2
        steps.append((x, walk_c, WATER_Z - 3, STEP_RUN, STAIR_W - PARAPET, top - (WATER_Z - 3)))
        par.append((x, par_c, WATER_Z - 3, STEP_RUN, PARAPET, top + 0.95 - (WATER_Z - 3)))
    end_x = x0 + n * STEP_RUN
    land = WATER_Z + 0.35
    steps.append((end_x + 2.5, face - bank * STAIR_W / 2, WATER_Z - 3, 5, STAIR_W, land - (WATER_Z - 3)))   # landing at the water
    boxes_mesh(f"{name}_stube", steps, M_STONE)
    boxes_mesh(f"{name}_parapet", par, M_CURB)
    for dx in (1.0, 4.0):     # mooring bollards on the landing edge
        cylinder(col, f"{name}_bitva_{dx}", (end_x + dx, face - bank * (STAIR_W - 0.3), land), 0.16, 0.45, M_IRON, verts=8)
    STAIRS.append((x0, bank))
    return end_x, face


for k, (x0, bank) in enumerate(((-200, -1), (100, -1), (400, -1), (-330, 1), (0, 1), (300, 1))):
    river_stairs(f"osrp_drava_stube_{k}", x0, bank)

# railing along both quays (posts + 2 rails), open at every staircase and at the footbridge
for bank in (-1, 1):
    ry = RIVER_Y + bank * (RIVER_W / 2 + 0.25)
    gaps = [(x0 - 0.4, x0 + 2.9) for (x0, b) in STAIRS if b == bank] + [(-83.5, -76.5)]
    gaps.sort()
    segs, cur = [], -MAP_W / 2 + 1
    for g0, g1 in gaps:
        segs.append((cur, g0))
        cur = g1
    segs.append((cur, MAP_W / 2 - 1))
    per_chunk = {}
    for a_, b_ in segs:
        # cut each piece at the 100 m chunk lines
        cuts = [a_] + [c * 100.0 for c in range(math.ceil(a_ / 100), math.floor(b_ / 100) + 1) if a_ < c * 100.0 < b_] + [b_]
        for p0, p1 in zip(cuts, cuts[1:]):
            lst = per_chunk.setdefault(math.floor((p0 + p1) / 2 / 100), [])
            for z in (0.55, 1.05):
                lst.append(((p0 + p1) / 2, ry, z, p1 - p0, 0.06, 0.06))
            x = p0
            while x <= p1:
                lst.append((x, ry, 0.05, 0.07, 0.07, 1.06))
                x += 3.0
    for ck, lst in per_chunk.items():
        boxes_mesh(f"osrp_drava_ograda_{bank}_{ck}", lst, M_POLE)

# marina: floating pontoon on the south side, reached from the staircase at x = 100
SX0 = 100
s_end = SX0 + int(round((0 - (WATER_Z + 0.35)) / STEP_H)) * STEP_RUN + 5      # end of the landing
QF = RIVER_Y - RIVER_W / 2                                                    # south quay face
DECK = WATER_Z + 0.4                                                          # deck top, 40 cm above the water
deck, floats = [], []


def pontoon(x0, x1, y0, y1):
    deck.append(((x0 + x1) / 2, (y0 + y1) / 2, DECK - 0.15, x1 - x0, y1 - y0, 0.15))
    floats.append(((x0 + x1) / 2, (y0 + y1) / 2, WATER_Z - 0.35, x1 - x0 - 0.3, y1 - y0 - 0.3, DECK - 0.15 - (WATER_Z - 0.35)))


MX1 = 205
PY0, PY1 = QF + STAIR_W, QF + STAIR_W + 3.0           # main pontoon along the quay
pontoon(s_end, s_end + 4, QF + 0.2, PY1)               # walkway from the landing
pontoon(s_end + 4, MX1, PY0, PY1)
BOATS = []
fingers = list(range(int(s_end) + 12, MX1 - 2, 14))
for k, x in enumerate(fingers):
    pontoon(x - 0.7, x + 0.7, PY1, PY1 + 10)
    for dy in (3.0, 9.0):
        cylinder(col, f"osrp_marina_bitva_{k}_{dy}", (x + 0.45, PY1 + dy, DECK), 0.12, 0.35, M_IRON, verts=8)
    cylinder(col, f"osrp_marina_kolac_{k}", (x, PY1 + 10.4, WATER_Z - 4), 0.2, 4.0 + DECK - WATER_Z + 1.0, M_WOOD, verts=8)
    if k < len(fingers) - 1:      # one boat in each berth, lengthwise between two fingers, bow to the river
        BOATS.append((x + 7.0, PY1 + 5.5, 0.0, ("dinghy", "jetmax", "suntrap", "tropic", "squalo", "speeder")[k % 6]))
boxes_mesh("osrp_marina_paluba", deck, M_WOOD)
boxes_mesh("osrp_marina_plovci", floats, M_FLOAT)
for k, x in enumerate(range(int(s_end) + 10, MX1, 24)):     # lamps on the pontoon
    cylinder(col, f"osrp_marina_lampa_stup_{k}", (x, PY1 - 0.3, DECK), 0.06, 2.6, M_POLE, verts=6)
    box(col, f"osrp_marina_lampa_{k}", (x, PY1 - 0.3, DECK + 2.6), (0.3, 0.3, 0.25), M_LAMP)
# jet skis at the north staircase by the beach
BOATS += [(-306, RIVER_Y + RIVER_W / 2 - STAIR_W - 3.5, 270.0, "seashark"), (-296, RIVER_Y + RIVER_W / 2 - STAIR_W - 3.5, 270.0, "seashark")]

# Promenade (south bank)
PROM_Y = RIVER_Y - RIVER_W / 2 - 11
plane(col, "osrp_promenada", (0, PROM_Y, 0.12), (MAP_W, 16), M_WALK)

# Europska avenija (y = 0): asphalt, dashed lines, curbs, sidewalks
plane(col, "osrp_europska_avenija", (0, 0, 0.1), (MAP_W, ROAD_W), M_ROAD)
CROSS_X = [-450, -300, -150, 0, 150, 300, 450]


def clear_of_cross_early(x, gap):
    return all(abs(x - cx) >= gap for cx in CROSS_X)


def open_segments_gap(x0, x1, gap_half):
    cuts, segs, start = sorted(CROSS_X), [], x0
    for cx in cuts:
        if cx - gap_half > start:
            segs.append((start, cx - gap_half))
        start = max(start, cx + gap_half)
    if start < x1:
        segs.append((start, x1))
    return segs


# v1.0.13 road markings: double solid centre line, dashed lane lines, solid edge lines (gaps at intersections)
for k, (a, b) in enumerate(open_segments_gap(-MAP_W / 2, MAP_W / 2, SIDE_ROAD_W / 2 + 6)):
    for off in (-0.18, 0.18):
        box(col, f"osrp_crta_sred_{k}_{off}", ((a + b) / 2, off, 0.1), (b - a, 0.14, 0.02), M_LINE)
    for side in (-1, 1):
        box(col, f"osrp_crta_rub_{k}_{side}", ((a + b) / 2, side * (ROAD_W / 2 - 0.45), 0.1), (b - a, 0.16, 0.02), M_LINE)
        xx = a + 3
        n = 0
        while xx + 3 < b:
            box(col, f"osrp_crta_traka_{k}_{side}_{n}", (xx + 1.5, side * 3.9, 0.1), (3.0, 0.13, 0.02), M_LINE)
            xx += 9; n += 1
def open_segments(x0, x1, gap_half):
    """x ranges between the cross streets, so curbs/sidewalks leave the intersections open for cars"""
    cuts = sorted(CROSS_X)
    segs, start = [], x0
    for cx in cuts:
        a, b = cx - gap_half, cx + gap_half
        if a > start:
            segs.append((start, a))
        start = max(start, b)
    if start < x1:
        segs.append((start, x1))
    return segs


for side in (-1, 1):
    y_edge = side * (ROAD_W / 2)
    for k, (a, b) in enumerate(open_segments(-MAP_W / 2, MAP_W / 2, SIDE_ROAD_W / 2)):
        box(col, f"osrp_rubnik_{side}_{k}", ((a + b) / 2, y_edge + side * 0.15, 0.1), (b - a, 0.3, 0.18), M_CURB)
        box(col, f"osrp_plocnik_av_{side}_{k}", ((a + b) / 2, y_edge + side * 4.15, 0.1), (b - a, 7.7, 0.16), M_WALK)   # up to the houses

# Side streets
plane(col, "osrp_ulica_jug", (0, -180, 0.1), (MAP_W, SIDE_ROAD_W), M_ROAD)
plane(col, "osrp_ulica_jug2", (0, -350, 0.1), (MAP_W, SIDE_ROAD_W), M_ROAD)
plane(col, "osrp_ulica_rijeka", (0, 125, 0.1), (MAP_W, SIDE_ROAD_W), M_ROAD)
for i, x in enumerate(CROSS_X):
    # two separate pieces so the cross street never overlaps the avenue or the side streets (no flicker)
    y_s0, y_s1 = -180 + SIDE_ROAD_W / 2, -ROAD_W / 2
    y_n0, y_n1 = ROAD_W / 2, 125 - SIDE_ROAD_W / 2
    plane(col, f"osrp_ulica_poprecna_{i}_j", (x, (y_s0 + y_s1) / 2, 0.1), (SIDE_ROAD_W, y_s1 - y_s0), M_ROAD)
    plane(col, f"osrp_ulica_poprecna_{i}_s", (x, (y_n0 + y_n1) / 2, 0.1), (SIDE_ROAD_W, y_n1 - y_n0), M_ROAD)
    y_j0, y_j1 = -350 + SIDE_ROAD_W / 2, -180 - SIDE_ROAD_W / 2
    plane(col, f"osrp_ulica_poprecna_{i}_j2", (x, (y_j0 + y_j1) / 2, 0.1), (SIDE_ROAD_W, y_j1 - y_j0), M_ROAD)
    # sidewalks + curbs on both sides of every cross street (not across the avenue)
    for side in (-1, 1):
        xe = x + side * SIDE_ROAD_W / 2
        for (ya, yb, tag) in ((-345, -185, "j2"), (-175, -ROAD_W / 2 - 6.3, "j"), (ROAD_W / 2 + 6.3, 120, "s")):
            box(col, f"osrp_rubnik_p_{i}_{side}_{tag}", (xe + side * 0.15, (ya + yb) / 2, 0.1), (0.3, yb - ya, 0.18), M_CURB)
            box(col, f"osrp_plocnik_p_{i}_{side}_{tag}", (xe + side * 1.55, (ya + yb) / 2, 0.1), (2.5, yb - ya, 0.16), M_WALK)
        # dashed centre line
        for k, yy in enumerate(range(-340, 120, 10)):
            if abs(yy) < ROAD_W / 2 + 7 or abs(yy + 180) < 8:
                continue
            box(col, f"osrp_crta_p_{i}_{k}_{side}", (x, yy, 0.1), (0.15, 4, 0.02), M_LINE) if side == 1 else None
    # zebra crossings over the avenue (both sides of the intersection)
    for zs in (-1, 1):
        zx = x + zs * (SIDE_ROAD_W / 2 + 2.5)
        for k in range(8):
            box(col, f"osrp_zebra_av_{i}_{zs}_{k}", (zx, -ROAD_W / 2 + 1 + k * 2, 0.1), (3.0, 0.9, 0.02), M_LINE)
    # zebra crossings over the cross street
    for zs in (-1, 1):
        zy = zs * (ROAD_W / 2 + 9)
        for k in range(5):
            box(col, f"osrp_zebra_p_{i}_{zs}_{k}", (x - SIDE_ROAD_W / 2 + 1 + k * 2, zy, 0.1), (0.9, 3.0, 0.02), M_LINE)

# curbs along the side streets (south street and river street)
DRIVEWAYS = [-370, -290, -250]        # v1.0.16: hospital lot entries + ambulance garage (south side of Vukovarska)


def cut_segments(segs, xs, half):
    out = []
    for a, b in segs:
        cur = a
        for x in sorted(xs):
            if x - half > cur and x - half < b:
                out.append((cur, x - half))
                cur = x + half
            elif x - half <= cur < x + half:
                cur = x + half
        if cur < b:
            out.append((cur, b))
    return out


for name, yc in (("jug2", -350), ("jug", -180), ("rijeka", 125)):
    for side in (-1, 1):
        segs = open_segments(-MAP_W / 2, MAP_W / 2, SIDE_ROAD_W / 2)
        if name == "jug2" and side == -1:
            segs = cut_segments(segs, DRIVEWAYS, 5.5)
        for k, (a, b) in enumerate(segs):
            box(col, f"osrp_rubnik_{name}_{side}_{k}", ((a + b) / 2, yc + side * (SIDE_ROAD_W / 2 + 0.15), 0.1), (b - a, 0.3, 0.18), M_CURB)
            # v1.0.13: sidewalk along the side street (between the cross-street sidewalks)
            sa, sb = a + 2.8, b - 2.8
            if sb > sa:
                box(col, f"osrp_plocnik_{name}_{side}_{k}", ((sa + sb) / 2, yc + side * (SIDE_ROAD_W / 2 + 1.55), 0.1), (sb - sa, 2.5, 0.16), M_WALK)
    # dashed centre line
    for k, (a, b) in enumerate(open_segments(-MAP_W / 2, MAP_W / 2, SIDE_ROAD_W / 2 + 4)):
        xx, n = a + 2, 0
        while xx + 3 < b:
            box(col, f"osrp_crta_{name}_{k}_{n}", (xx + 1.5, yc, 0.1), (3.0, 0.13, 0.02), M_LINE)
            xx += 7; n += 1

for k, x in enumerate(DRIVEWAYS):
    plane(col, f"osrp_prilaz_{k}", (x, -356.6, 0.1), (11, 3.2), M_ROAD)

# stop lines: cross streets before the avenue (right lane) and the avenue before each crossing
for i, x in enumerate(CROSS_X):
    box(col, f"osrp_stop_p_s_{i}", (x - SIDE_ROAD_W / 4, ROAD_W / 2 + 11.2, 0.1), (SIDE_ROAD_W / 2 - 0.3, 0.45, 0.02), M_LINE)
    box(col, f"osrp_stop_p_j_{i}", (x + SIDE_ROAD_W / 4, -ROAD_W / 2 - 11.2, 0.1), (SIDE_ROAD_W / 2 - 0.3, 0.45, 0.02), M_LINE)
    box(col, f"osrp_stop_av_w_{i}", (x - SIDE_ROAD_W / 2 - 4.6, -ROAD_W / 4, 0.1), (0.45, ROAD_W / 2 - 0.6, 0.02), M_LINE)
    box(col, f"osrp_stop_av_e_{i}", (x + SIDE_ROAD_W / 2 + 4.6, ROAD_W / 4, 0.1), (0.45, ROAD_W / 2 - 0.6, 0.02), M_LINE)

# manhole covers in the lanes and rain drains along the kerbs
mh = 0
for x in range(-520, 521, 45):
    if clear_of_cross_early(x, 14):
        cylinder(col, f"osrp_sahta_av_{mh}", (x, 2.0 if mh % 2 else -2.0, 0.1), 0.36, 0.025, M_IRON, verts=12); mh += 1
for yc in (-350, -180, 125):
    for x in range(-505, 506, 60):
        if clear_of_cross_early(x, 12):
            cylinder(col, f"osrp_sahta_{yc}_{mh}", (x, yc + 2.4, 0.1), 0.36, 0.025, M_IRON, verts=12); mh += 1
dr = 0
for x in range(-530, 531, 24):
    if clear_of_cross_early(x, 10):
        for side in (-1, 1):
            box(col, f"osrp_slivnik_{dr}_{side}", (x, side * (ROAD_W / 2 - 0.18), 0.1), (0.9, 0.36, 0.024), M_IRON)
        dr += 1

# Street lights: avenue both sides every 30 m, promenade every 25 m
li = 0
def clear_of_cross(x, gap):
    return all(abs(x - cx) >= gap for cx in CROSS_X)


for x in range(-540, 541, 30):
    if clear_of_cross(x, 8):
        street_light(col, li, x, ROAD_W / 2 + 1.2, -1); li += 1
    if clear_of_cross(x + 15, 8):
        street_light(col, li, x + 15, -ROAD_W / 2 - 1.2, 1); li += 1
for x in range(-535, 536, 25):
    street_light(col, li, x, PROM_Y + 6.5, 1); li += 1

# Tvrđa square + cathedral (east)
TV_X, TV_Y = 225, 62
plane(col, "osrp_tvrdja_trg", (TV_X, TV_Y, 0.14), (120, 95), M_COBBLE)
# Co-cathedral of St. Peter and Paul: neo-gothic red brick, 90+ m tower with spire
NAVE_Y = TV_Y + 16
box(col, "osrp_katedrala_brod", (TV_X, NAVE_Y, 0), (20, 52, 24), M_BRICK)
gable_roof(col, "osrp_katedrala_krov", TV_X, NAVE_Y, 24, 52, 20, 11, M_ROOF, rot_z=math.pi / 2)
for side in (-1, 1):   # side aisles with lean-to roofs, buttresses, tall pointed windows
    box(col, f"osrp_katedrala_lada_{side}", (TV_X + side * 14, NAVE_Y, 0), (8, 48, 13), M_BRICK)
    box(col, f"osrp_katedrala_lada_krov_{side}", (TV_X + side * 14, NAVE_Y, 13), (8.6, 48.6, 0.6), M_ROOF)
    for k in range(7):
        yy = NAVE_Y - 21 + k * 7
        box(col, f"osrp_katedrala_potporanj_{side}_{k}", (TV_X + side * 18.6, yy, 0), (1.4, 1.6, 15), M_BRICK)
        pyramid(col, f"osrp_katedrala_potporanj_vrh_{side}_{k}", (TV_X + side * 18.6, yy, 15), 1.1, 3.5, M_SPIRE)
        box(col, f"osrp_katedrala_prozor_{side}_{k}", (TV_X + side * 10.05, yy + 3.5, 14.5), (0.2, 1.8, 8.0), M_GLASS)
        box(col, f"osrp_katedrala_prozor_n_{side}_{k}", (TV_X + side * 18.05, yy + 3.5, 2.5), (0.2, 1.6, 7.5), M_GLASS)
# apse (rounded end)
cylinder(col, "osrp_katedrala_apsida", (TV_X, NAVE_Y + 26, 0), 10, 20, M_BRICK, verts=10)
pyramid(col, "osrp_katedrala_apsida_krov", (TV_X, NAVE_Y + 26, 20), 11, 7, M_ROOF)
# main tower with corner pinnacles, clock, rose window and the spire (total ~94 m)
T_Y = TV_Y - 16
box(col, "osrp_katedrala_toranj", (TV_X, T_Y, 0), (14, 14, 64), M_BRICK)
box(col, "osrp_katedrala_toranj_vijenac", (TV_X, T_Y, 64), (15.2, 15.2, 1.2), M_WHITE_STONE)
pyramid(col, "osrp_katedrala_vrh", (TV_X, T_Y, 65.2), 9.6, 29, M_SPIRE)
for k, (dx, dy) in enumerate(((-6, -6), (6, -6), (-6, 6), (6, 6))):
    box(col, f"osrp_katedrala_tornjic_{k}", (TV_X + dx, T_Y + dy, 65.2), (1.6, 1.6, 5), M_BRICK)
    pyramid(col, f"osrp_katedrala_tornjic_vrh_{k}", (TV_X + dx, T_Y + dy, 70.2), 1.3, 5, M_SPIRE)
for face in range(4):
    a_ = face * math.pi / 2
    fx, fy = math.sin(a_) * 7.05, -math.cos(a_) * 7.05
    box(col, f"osrp_katedrala_sat_{face}", (TV_X + fx, T_Y + fy, 52), (3.2 if face % 2 == 0 else 0.15, 0.15 if face % 2 == 0 else 3.2, 3.2), M_WHITE_STONE)
    box(col, f"osrp_katedrala_zvono_{face}", (TV_X + fx, T_Y + fy, 40), (2.2 if face % 2 == 0 else 0.15, 0.15 if face % 2 == 0 else 2.2, 8), M_GLASS)
box(col, "osrp_katedrala_rozeta", (TV_X, T_Y - 7.1, 22), (4.5, 0.2, 4.5), M_GLASS)
box(col, "osrp_katedrala_portal", (TV_X, T_Y - 7.1, 0.14), (3.6, 0.3, 6.5), M_WOOD)
for k, (dx, dy) in enumerate(((-12, 40), (12, 40))):
    box(col, f"osrp_katedrala_mali_toranj_{k}", (TV_X + dx, NAVE_Y + dy - 16, 0), (4, 4, 28), M_BRICK)
    pyramid(col, f"osrp_katedrala_mali_vrh_{k}", (TV_X + dx, NAVE_Y + dy - 16, 28), 3.2, 9, M_SPIRE)
for k in range(8):   # trees around the square (k=6 would stand in front of the Trinity column)
    if k in (2, 6):   # 2 = behind the apse, 6 = in front of the Trinity column
        continue
    a = k / 8 * math.tau
    tree(col, f"trg_{k}", TV_X + math.cos(a) * 50, TV_Y + math.sin(a) * 40, 1.1)

# City park (west, between avenue and river street)
PARK_X0, PARK_X1 = -300 + SIDE_ROAD_W / 2 + 3, -150 - SIDE_ROAD_W / 2 - 3
PARK_Y0, PARK_Y1 = 14, 118
PCX, PCY = (PARK_X0 + PARK_X1) / 2, (PARK_Y0 + PARK_Y1) / 2
plane(col, "osrp_park", (PCX, PCY, 0.13), (PARK_X1 - PARK_X0, PARK_Y1 - PARK_Y0), M_PARK)
plane(col, "osrp_park_staza_x", (PCX, PCY, 0.15), (PARK_X1 - PARK_X0, 4), M_PATH)
plane(col, "osrp_park_staza_y", (PCX, PCY, 0.16), (4, PARK_Y1 - PARK_Y0), M_PATH)
for k in range(26):
    x = random.uniform(PARK_X0 + 5, PARK_X1 - 5)
    y = random.uniform(PARK_Y0 + 5, PARK_Y1 - 5)
    if abs(x - PCX) < 5 or abs(y - PCY) < 5:
        continue
    tree(col, f"park_{k}", x, y, random.uniform(0.9, 1.4))

MAPRECTS = []    # (kind, cx, cy, w, h) - drawn on the GTA minimap / pause map by osrp_osijek
DOORS = []       # (x, y, z, heading) - real GTA V doors placed in-game by osrp_osijek
FURNITURE = []   # (kind, x, y, z, heading) - real GTA V furniture placed in-game
M_FLOOR = material("osrp_floor_wood", (0.45, 0.30, 0.17))
M_RIVER_PLINTH = material("osrp_plinth_stone", (0.48, 0.46, 0.43))
M_DOORFRAME = material("osrp_door_frame", (0.20, 0.14, 0.09))
M_CANOPY = material("osrp_canopy", (0.25, 0.27, 0.30), rough=0.5, metal=0.5)

DOOR_W, DOOR_H, WALL_T, FLOOR_H = 1.5, 2.9, 0.3, 3.6
FLOOR_Z = 0.26                         # v1.0.15: room floor = sidewalk height (no step / dip at the door)


def door_heading(facing):
    """GTA heading of something on the street face, looking out to the street (+y = 0 deg, -y = 180 deg)"""
    return 180.0 if facing == -1 else 0.0


def house_enterable(name, cx, cy, w, d, h, mat, facing):
    """ground floor you can walk into: walls, doorway, wooden floor, ceiling; upper floors solid"""
    y_front = cy + facing * d / 2          # street face
    y_back = cy - facing * d / 2
    fy = y_front - facing * WALL_T / 2     # centre line of the front wall
    by = y_back + facing * WALL_T / 2
    # front wall with a doorway in the middle
    left_w = (w - DOOR_W) / 2
    box(col, f"{name}_zid_l", (cx - w / 2 + left_w / 2, fy, 0), (left_w, WALL_T, FLOOR_H), mat)
    box(col, f"{name}_zid_d", (cx + w / 2 - left_w / 2, fy, 0), (left_w, WALL_T, FLOOR_H), mat)
    box(col, f"{name}_nadvratnik", (cx, fy, DOOR_H), (DOOR_W, WALL_T, FLOOR_H - DOOR_H), mat)
    # back + side walls
    box(col, f"{name}_zid_s", (cx, by, 0), (w, WALL_T, FLOOR_H), mat)
    for k, sx in enumerate((-1, 1)):
        box(col, f"{name}_zid_bok{k}", (cx + sx * (w / 2 - WALL_T / 2), cy, 0), (WALL_T, d - 2 * WALL_T, FLOOR_H), mat)
    # upper floors (solid) - its underside is the ceiling of the room
    box(col, f"{name}_katovi", (cx, cy, FLOOR_H), (w, d, h - FLOOR_H), mat)
    # wooden floor + entrance step + door frame
    box(col, f"{name}_pod", (cx, cy, 0), (w - 2 * WALL_T, d - 2 * WALL_T, FLOOR_Z), M_FLOOR)
    box(col, f"{name}_prag", (cx, fy, 0), (DOOR_W, WALL_T + 0.02, FLOOR_Z), M_WHITE_STONE)        # threshold in the doorway
    for k, sx in enumerate((-1, 1)):
        box(col, f"{name}_okvir{k}", (cx + sx * (DOOR_W / 2 + 0.06), y_front + facing * 0.04, 0), (0.12, 0.1, DOOR_H + 0.1), M_DOORFRAME)
    box(col, f"{name}_okvir_gore", (cx, y_front + facing * 0.04, DOOR_H), (DOOR_W + 0.24, 0.1, 0.12), M_DOORFRAME)
    box(col, f"{name}_nadstresnica", (cx, y_front + facing * 0.6, DOOR_H + 0.35), (DOOR_W + 1.0, 1.2, 0.08), M_CANOPY)
    # GTA door: hinge on the left edge of the doorway (seen from the street)
    heading = door_heading(facing)
    DOORS.append((round(cx - facing * DOOR_W / 2, 2), round(fy, 2), FLOOR_Z, heading))
    # GTA furniture inside (room interior)
    iy0, iy1 = sorted((fy - facing * WALL_T / 2, by + facing * WALL_T / 2))
    ix0, ix1 = cx - w / 2 + WALL_T, cx + w / 2 - WALL_T
    look_in = (heading + 180.0) % 360.0           # facing into the room
    back_inner = by + facing * (WALL_T / 2 + 0.6)
    FURNITURE.append(("sofa", round(cx, 2), round(back_inner, 2), FLOOR_Z, heading))   # back to the wall, facing the door
    FURNITURE.append(("stol", round(cx, 2), round((iy0 + iy1) / 2, 2), FLOOR_Z, 0.0))
    FURNITURE.append(("stolica", round(cx - 1.2, 2), round((iy0 + iy1) / 2, 2), FLOOR_Z, 90.0))
    FURNITURE.append(("stolica", round(cx + 1.2, 2), round((iy0 + iy1) / 2, 2), FLOOR_Z, 270.0))
    FURNITURE.append(("tv", round(ix0 + 0.4, 2), round((iy0 + iy1) / 2, 2), FLOOR_Z, 270.0))
    FURNITURE.append(("biljka", round(ix1 - 0.6, 2), round(back_inner, 2), FLOOR_Z, 0.0))
    FURNITURE.append(("biljka", round(ix0 + 0.6, 2), round(fy - facing * (WALL_T / 2 + 0.6), 2), FLOOR_Z, 0.0))


def fake_entrance(name, cx, y_front, facing):
    """closed front door look for buildings you can't enter"""
    box(col, f"{name}_vrata", (cx, y_front + facing * 0.03, 0.1), (DOOR_W, 0.08, DOOR_H - 0.3), M_DOORFRAME)
    box(col, f"{name}_nadstresnica", (cx, y_front + facing * 0.6, DOOR_H + 0.35), (DOOR_W + 1.0, 1.2, 0.08), M_CANOPY)


# City blocks: buildings with windows + pitched roofs (every 3rd one can be entered)
bid = 0
for bx in range(len(CROSS_X) - 1):
    for (y0, y1) in [(-342.2, -187.8), (-172.2, -16), (16, 117.2)]:
        x0 = CROSS_X[bx] + SIDE_ROAD_W / 2 + 3
        x1 = CROSS_X[bx + 1] - SIDE_ROAD_W / 2 - 3
        if x1 > TV_X - 60 and x0 < TV_X + 60 and y1 > 0:      # Tvrđa square
            continue
        if x0 >= PARK_X0 - 1 and x1 <= PARK_X1 + 1 and y1 > 0:  # park
            continue
        x = x0
        while x < x1 - 10:
            w = min(random.uniform(14, 22), x1 - x)
            d = random.uniform(14, 20)
            floors = random.choice([2, 3, 3, 4, 5, 6])
            floor_h = 3.3
            h = floors * floor_h + 1.0
            mat = random.choice(M_PLASTER)
            for side, yy, facing in (("a", y0, -1), ("b", y1 - d, 1)):
                cx, cy = x + w / 2, yy + d / 2
                street_face = yy if facing == -1 else yy + d
                MAPRECTS.append(("bld", round(cx, 1), round(cy, 1), round(w - 1, 1), round(d, 1)))
                box(col, f"osrp_vijenac_{bid}_{side}", (cx, cy, h - 0.45), (w - 0.6, d + 0.4, 0.45), M_WHITE_STONE)   # cornice
                if bid % 3 == 0:
                    house_enterable(f"osrp_kuca_{bid}_{side}", cx, cy, w - 1, d, h, mat, facing)
                    # windows only from the 1st floor up (the ground floor has the door)
                    if floors > 1:
                        windows(col, f"osrp_prozori_{bid}_{side}", cx, street_face, 0.8 + floor_h, w - 1, floors - 1, floor_h, M_GLASS, facing)
                else:
                    box(col, f"osrp_zgrada_{bid}_{side}", (cx, cy, 0), (w - 1, d, h), mat)
                    box(col, f"osrp_podnozje_{bid}_{side}", (cx, cy, 0), (w - 0.8, d + 0.2, 0.9), M_RIVER_PLINTH)   # stone base
                    windows(col, f"osrp_prozori_{bid}_{side}", cx, street_face, 0.8 + floor_h, w - 1, floors - 1, floor_h, M_GLASS, facing) if floors > 1 else None
                    fake_entrance(f"osrp_ulaz_{bid}_{side}", cx, street_face, facing)
                gable_roof(col, f"osrp_krov_{bid}_{side}", cx, cy, h, w - 1, d, random.uniform(3.5, 5.5), M_ROOF)
            bid += 1
            x += w
        # v1.0.13: courtyard trees behind the buildings (real GTA trees in-game)
        for k in range(int((x1 - x0) / 22)):
            tx = random.uniform(x0 + 6, x1 - 6)
            ty = random.uniform(y0 + 25, y1 - 25)
            tree(col, f"park_dvor_{bx}_{int(y0)}_{k}", tx, ty, random.uniform(0.9, 1.3))

# Pedestrian bridge over the Drava (Pješački most) - deck level with the banks, you can walk on it
BR_X = -80
DECK_TOP = 0.25
box(col, "osrp_most_paluba", (BR_X, RIVER_Y, DECK_TOP - 0.6), (5, RIVER_W + 8, 0.6), M_STEEL)
box(col, "osrp_most_hodnik", (BR_X, RIVER_Y, DECK_TOP - 0.02), (4.2, RIVER_W + 8, 0.04), M_FLOOR)
for k, yy in enumerate((RIVER_Y - RIVER_W / 2 + 5, RIVER_Y + RIVER_W / 2 - 5)):
    box(col, f"osrp_most_pilon_{k}", (BR_X - 3.2, yy, -12), (1.2, 1.2, 36), M_STEEL)
    box(col, f"osrp_most_pilon_{k}b", (BR_X + 3.2, yy, -12), (1.2, 1.2, 36), M_STEEL)
    box(col, f"osrp_most_greda_{k}", (BR_X, yy, 22.5), (7.6, 1.0, 1.0), M_STEEL)
for side in (-1, 1):
    box(col, f"osrp_most_ograda_{side}", (BR_X + side * 2.3, RIVER_Y, DECK_TOP), (0.1, RIVER_W + 8, 1.1), M_STEEL)
    box(col, f"osrp_most_rukohvat_{side}", (BR_X + side * 2.3, RIVER_Y, DECK_TOP + 1.05), (0.18, RIVER_W + 8, 0.08), M_STEEL)
    for k in range(13):   # suspension hangers
        t = k / 12
        yy = RIVER_Y - RIVER_W / 2 + 5 + t * (RIVER_W - 10)
        top = 22.5 - 18 * math.sin(t * math.pi)
        box(col, f"osrp_most_sajla_{side}_{k}", (BR_X + side * 2.6, yy, DECK_TOP + 1.1), (0.06, 0.06, max(0.4, top - DECK_TOP - 1.1)), M_STEEL)
    for k in range(48):   # main cable (stepped segments following the sag curve)
        t = (k + 0.5) / 48
        yy = RIVER_Y - RIVER_W / 2 + 5 + t * (RIVER_W - 10)
        box(col, f"osrp_most_kabel_{side}_{k}", (BR_X + side * 2.6, yy, 22.5 - 18 * math.sin(t * math.pi) - 0.15), (0.25, (RIVER_W - 10) / 48 * 1.9, 0.3), M_STEEL)

# Promenade: lindens with benches between them
for i, x in enumerate(range(-530, 531, 25)):
    tree(col, f"prom_{i}", x + 12, PROM_Y - 4, 1.0)
    if i % 2 == 0:
        bench(col, i, x + 12, PROM_Y + 1.5)

# Trees along the avenue sidewalks (between lamps)
for i, x in enumerate(range(-525, 526, 30)):
    if clear_of_cross(x, 10):
        tree(col, f"av_s_{i}", x, -ROAD_W / 2 - 5.2, 0.8)
    if clear_of_cross(x + 15, 10):
        tree(col, f"av_n_{i}", x + 15, ROAD_W / 2 + 5.2, 0.8)

# ---------------------------------------------------------------- landmarks & details
def flower_bed(i, x, y, w=3.0, d=1.2):
    box(col, f"osrp_cvjetnjak_rub_{i}", (x, y, 0), (w + 0.3, d + 0.3, 0.45), M_WHITE_STONE)
    box(col, f"osrp_cvjetnjak_zemlja_{i}", (x, y, 0.45), (w, d, 0.05), M_SOIL)
    for k in range(int(w * 3)):
        blob(col, f"osrp_cvijece_{i}_{k}", (x - w / 2 + 0.2 + k * (w - 0.4) / max(1, int(w * 3) - 1), y + random.uniform(-d / 3, d / 3), 0.6),
             random.uniform(0.18, 0.28), random.choice(M_FLOWERS), squash=0.7)


def bus_stop(i, x, y, facing):
    """shelter on the avenue sidewalk, open towards the road. facing=+1: road is at +y, facing=-1: road at -y"""
    back = y - facing * 0.9
    box(col, f"osrp_stanica_staklo_{i}", (x, back, 0.2), (4.0, 0.06, 2.3), M_GLASS_STOP)
    for k, dx in enumerate((-2, 2)):
        box(col, f"osrp_stanica_stup_{i}_{k}", (x + dx, back, 0.2), (0.1, 0.1, 2.5), M_POLE)
    box(col, f"osrp_stanica_krov_{i}", (x, y - facing * 0.2, 2.7), (4.4, 1.8, 0.12), M_POLE)
    bench(col, f"stanica_{i}", x, back + facing * 0.45, back=-facing)
    box(col, f"osrp_stanica_znak_{i}", (x + 2.6, y + facing * 0.6, 0.2), (0.08, 0.08, 2.6), M_POLE)
    box(col, f"osrp_stanica_ploca_{i}", (x + 2.6, y + facing * 0.6, 2.4), (0.05, 0.6, 0.6), M_LAMP)


# Holy Trinity column (Kužni pil) in Tvrđa
PIL_X, PIL_Y = TV_X, 30
box(col, "osrp_pil_baza", (PIL_X, PIL_Y, 0.14), (5, 5, 1.2), M_WHITE_STONE)
box(col, "osrp_pil_postolje", (PIL_X, PIL_Y, 1.34), (2.8, 2.8, 3.0), M_WHITE_STONE)
cylinder(col, "osrp_pil_stup", (PIL_X, PIL_Y, 4.34), 0.55, 9.0, M_WHITE_STONE, verts=16)
blob(col, "osrp_pil_kip", (PIL_X, PIL_Y, 14.2), 0.9, M_GOLD, squash=1.4)
for k, (dx, dy) in enumerate(((-5, 0), (5, 0), (0, -5), (0, 5))):
    flower_bed(f"pil_{k}", PIL_X + dx, PIL_Y + dy, 3.0 if dx else 1.2, 1.2 if dx else 3.0)

# Fountain on the square
FX, FY = TV_X - 32, 48
# v1.0.18: tiered stone fountain - octagonal basin with a wide rim you can sit on, two bowls, water jets in-game
M_FWATER = material("osrp_fountain_water", (0.10, 0.32, 0.38), rough=0.05)
cylinder(col, "osrp_fontana_dno", (FX, FY, 0.14), 5.6, 0.08, M_COBBLE, verts=32)
for k in range(8):                      # octagonal rim
    a = k * math.pi / 4
    rx, ry = FX + math.cos(a) * 5.0, FY + math.sin(a) * 5.0
    box(col, f"osrp_fontana_rub_{k}", (rx, ry, 0.14), (0.7, 4.2, 0.55), M_WHITE_STONE, rot_z=a)
    box(col, f"osrp_fontana_rub_vrh_{k}", (rx, ry, 0.69), (0.9, 4.3, 0.1), M_RIVER_PLINTH, rot_z=a)
cylinder(col, "osrp_fontana_voda", (FX, FY, 0.14), 4.7, 0.38, M_FWATER, verts=32)
cylinder(col, "osrp_fontana_stup", (FX, FY, 0.52), 0.55, 1.4, M_WHITE_STONE, verts=12)
cylinder(col, "osrp_fontana_zdjela1", (FX, FY, 1.9), 2.2, 0.35, M_WHITE_STONE, verts=24)
cylinder(col, "osrp_fontana_voda1", (FX, FY, 2.2), 1.95, 0.1, M_FWATER, verts=24)
cylinder(col, "osrp_fontana_stup2", (FX, FY, 2.3), 0.3, 1.2, M_WHITE_STONE, verts=12)
cylinder(col, "osrp_fontana_zdjela2", (FX, FY, 3.45), 1.1, 0.28, M_WHITE_STONE, verts=20)
cylinder(col, "osrp_fontana_voda2", (FX, FY, 3.68), 0.9, 0.08, M_FWATER, verts=20)
pyramid(col, "osrp_fontana_vrh", (FX, FY, 3.75), 0.25, 0.7, M_GOLD)
FOUNTAINS = [(FX, FY, 4.3), (FX, FY, 2.4)]

# Bus stops on Europska avenija
for i, x in enumerate((-375, -225, -75, 75, 375)):
    bus_stop(i, x, -ROAD_W / 2 - 3.6, 1)
    bus_stop(i + 10, x + 40, ROAD_W / 2 + 3.6, -1)

# Flower beds along the promenade
for i, x in enumerate(range(-500, 501, 50)):
    flower_bed(f"prom_{i}", x, PROM_Y - 0.5, 4.0, 1.2)



# =============================================================== v1.0.14: south expansion
M_APRON = material("osrp_apron_concrete", (0.56, 0.55, 0.52))
M_YLINE = material("osrp_road_line_yellow", (0.95, 0.72, 0.08))
M_HOSP = material("osrp_plaster_hospital", (0.90, 0.90, 0.88))
M_TERM = material("osrp_plaster_terminal", (0.72, 0.76, 0.80))
M_RED = material("osrp_sign_red", (0.80, 0.05, 0.05))
M_SAND = material("osrp_beach_sand", (0.78, 0.68, 0.48))
M_RWLIGHT = material("osrp_lamp_light_runway", (1.0, 0.85, 0.5), emit=25.0)
M_HANGAR = material("osrp_hangar_metal", (0.55, 0.58, 0.60), rough=0.4, metal=0.7)
SPECIAL = []        # (x, y, z or None, heading, model, livery) vehicles placed in-game (ambulances, planes, heli)
PLACES = {}         # named points used by the scripts (hospital door, EMS garage, ...)


def line(name, x, y, sx, sy, mat=None, z=0.1):
    box(col, name, (x, y, z), (sx, sy, 0.02), mat or M_LINE)




# ---------- v1.0.15: block letters (signs, runway numbers) ----------
FONT = {
    'O': [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    'S': [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
    'I': ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "#####"],
    'J': ["  ###", "   # ", "   # ", "   # ", "#  # ", "#  # ", " ##  "],
    'E': ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
    'K': ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"],
    'H': ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    'T': ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
    'N': ["#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #"],
    'A': [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    'B': ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "],
    'C': [" ####", "#    ", "#    ", "#    ", "#    ", "#    ", " ####"],
    'D': ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
    'L': ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
    '0': [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "],
    '2': [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"],
    '7': ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "],
    '9': [" ### ", "#   #", "#   #", " ####", "    #", "#   #", " ### "],
}


def block_text(name, text, origin, ps, right, up, mat, depth=0.08):
    """text out of boxes. origin = bottom-left as the reader sees it; right/up = axis unit vectors (x, y, z).
    up = (0, 0, 1) for a sign on a wall, up = (+-1, 0, 0) or (0, +-1, 0) for markings on the ground."""
    ox, oy, oz = origin
    k = 0
    for ci, ch in enumerate(text):
        g = FONT.get(ch)
        for r, row in enumerate(g or []):
            c = 0
            while c < 5:
                if row[c] != "#":
                    c += 1
                    continue
                c2 = c
                while c2 < 5 and row[c2] == "#":
                    c2 += 1
                n = c2 - c
                along = (ci * 6 + c + n / 2) * ps
                v = (6 - r) * ps
                if up[2] == 1:     # wall sign: box bottom at v
                    x = ox + right[0] * along
                    y = oy + right[1] * along
                    size = (n * ps if right[0] else depth, n * ps if right[1] else depth, ps)
                    box(col, f"{name}_{k}", (x, y, oz + v), size, mat)
                else:              # ground marking
                    x = ox + right[0] * along + up[0] * (v + ps / 2)
                    y = oy + right[1] * along + up[1] * (v + ps / 2)
                    size = (n * ps if right[0] else ps, n * ps if right[1] else ps, 0.02)
                    box(col, f"{name}_{k}", (x, y, oz), size, mat)
                k += 1
                c = c2


def text_width(text, ps):
    return (len(text) * 6 - 1) * ps

M_SIGN = material("osrp_lamp_light_sign", (0.85, 0.92, 1.0), emit=8.0)
M_SIGN_RED = material("osrp_lamp_light_red", (1.0, 0.08, 0.06), emit=10.0)
M_SIGN_BLUE = material("osrp_lamp_light_blue", (0.15, 0.35, 1.0), emit=10.0)

# ---------- KBC Osijek (hospital) on Vukovarska, west part ----------
HX, HY = -330, -402
plane(col, "osrp_kbc_parkiraliste", (HX, -369, 0.1), (130, 22), M_ROAD)
for k in range(20):
    line(f"osrp_kbc_mjesto_{k}", HX - 60 + k * 6.3, -373.5, 0.12, 5.0)
for k in range(4):   # ambulance bays (red)
    line(f"osrp_kbc_hitna_{k}", HX - 45 + k * 4.5, -373.5, 0.15, 5.0, M_RED)
# v1.0.16: you can walk into the lobby (40 x 18 m): reception, waiting area; upper floors solid
LOB_W, LOB_D, LOB_H = 40, 18, 4.5
M_HFLOOR = material("osrp_pavement_hospital", (0.82, 0.83, 0.84))
box(col, "osrp_kbc_katovi", (HX, HY, LOB_H), (110, 44, 24 - LOB_H), M_HOSP)
box(col, "osrp_kbc_prizemlje_l", (HX - 37.5, HY, 0), (35, 44, LOB_H), M_HOSP)
box(col, "osrp_kbc_prizemlje_d", (HX + 37.5, HY, 0), (35, 44, LOB_H), M_HOSP)
box(col, "osrp_kbc_prizemlje_s", (HX, HY + 22 - LOB_D - (44 - LOB_D) / 2, 0), (LOB_W, 44 - LOB_D, LOB_H), M_HOSP)
box(col, "osrp_kbc_pod", (HX, HY + 22 - LOB_D / 2, 0), (LOB_W, LOB_D, FLOOR_Z), M_HFLOOR)
for sx in (-1, 1):   # glass front with a 5 m open entrance in the middle
    box(col, f"osrp_kbc_staklo_{sx}", (HX + sx * 11.25, HY + 21.85, FLOOR_Z), (17.5, 0.3, LOB_H - FLOOR_Z), M_GLASS)
    box(col, f"osrp_kbc_podnozje_{sx}", (HX + sx * 37.5, HY + 22.1, 0), (35, 0.2, 1.0), M_RIVER_PLINTH)
box(col, "osrp_kbc_podnozje_z", (HX, HY - 22.1, 0), (110.4, 0.2, 1.0), M_RIVER_PLINTH)
box(col, "osrp_kbc_recepcija", (HX, HY + 9, FLOOR_Z), (9, 1.2, 1.1), M_WHITE_STONE)
box(col, "osrp_kbc_recepcija_ploca", (HX, HY + 9, FLOOR_Z + 1.1), (9.4, 1.5, 0.08), M_WOOD)
block_text("osrp_kbc_natpis_unutra", "HITNA", (HX + text_width("HITNA", 0.3) / 2, HY + 4.1, 2.6), 0.3, (-1, 0, 0), (0, 0, 1), M_SIGN_RED)
for k in range(4):   # waiting benches
    box(col, f"osrp_kbc_klupa_unutra_{k}", (HX - 15 + k * 10, HY + 16, FLOOR_Z), (6, 0.7, 0.45), M_WOOD)
INTERIOR_LIGHTS = [(HX + dx, HY + 13, LOB_H - 0.3) for dx in (-14, 0, 14)]
FURNITURE += [("automat", HX - 18.5, HY + 6, FLOOR_Z, 90.0), ("kava", HX - 18.5, HY + 8, FLOOR_Z, 90.0),
              ("biljka", HX + 18.5, HY + 20.5, FLOOR_Z, 0.0), ("biljka", HX - 18.5, HY + 20.5, FLOOR_Z, 0.0),
              ("tv", HX + 18.6, HY + 12, FLOOR_Z + 1.0, 270.0), ("krevet", HX + 15, HY + 6, FLOOR_Z, 0.0)]
STAFF = [("s_f_y_scrubs_01", HX, HY + 8.0, 0.0, "WORLD_HUMAN_CLIPBOARD"),
         ("s_m_m_doctor_01", HX + 10, HY + 12, 90.0, "WORLD_HUMAN_STAND_MOBILE"),
         ("s_m_m_paramedic_01", HX + 42, HY + 26, 180.0, "WORLD_HUMAN_SMOKING")]
windows(col, "osrp_kbc_prozori_s", HX, HY + 22, 0.8 + 0.4, 106, 6, 3.6, M_GLASS, 1)
windows(col, "osrp_kbc_prozori_j", HX, HY - 22, 0.8 + 0.4, 106, 6, 3.6, M_GLASS, -1)
box(col, "osrp_kbc_krilo", (HX - 40, HY - 40, 0), (30, 36, 15), M_HOSP)
windows(col, "osrp_kbc_krilo_prozori", HX - 40, HY - 58, 0.8, 28, 3, 3.6, M_GLASS, -1)
box(col, "osrp_kbc_krov", (HX, HY, 24), (111, 45, 0.4), M_STONE)
for k, (dx, dy, sx, sy) in enumerate(((0, 22.2, 111, 0.3), (0, -22.2, 111, 0.3), (55.3, 0, 0.3, 45), (-55.3, 0, 0.3, 45))):
    box(col, f"osrp_kbc_ograda_{k}", (HX + dx, HY + dy, 24.4), (sx, sy, 1.1), M_HOSP)
# entrance: glass doors, canopy on columns, red cross
box(col, "osrp_kbc_nadstresnica", (HX, HY + 26, 3.8), (18, 8, 0.45), M_CANOPY)
for dx in (-8, 8):
    cylinder(col, f"osrp_kbc_stup_{dx}", (HX + dx, HY + 29.5, 0.1), 0.25, 3.7, M_STEEL, verts=8)
box(col, "osrp_kbc_znak", (HX, HY + 22.15, 17.5), (6.5, 0.3, 6.5), M_WHITE_STONE)
box(col, "osrp_kbc_kriz_v", (HX, HY + 22.35, 18.4), (1.5, 0.3, 4.7), M_RED)
box(col, "osrp_kbc_kriz_h", (HX, HY + 22.35, 20.0), (4.7, 0.3, 1.5), M_RED)
# helipad on the roof
HELI = (HX + 35, HY, 24.4)
cylinder(col, "osrp_kbc_heliodrom", HELI, 10, 0.3, M_APRON, verts=24)
for k, (dx, sx, sy) in enumerate(((-2.4, 1.0, 7.0), (2.4, 1.0, 7.0), (0, 4.0, 1.0))):
    box(col, f"osrp_kbc_H_{k}", (HELI[0] + dx, HELI[1], HELI[2] + 0.3), (sx, sy, 0.03), M_LINE)
SPECIAL += [(HX - 45 + k * 4.5 + 2.25, -373.5, None, 0.0, "ambulance", 0) for k in range(3)]
SPECIAL.append((HELI[0], HELI[1], HELI[2] + 0.35, 90.0, "polmav", 1))   # air ambulance
# v1.0.15: name on the facade, emergency entrance (HITNA) with an ambulance canopy, ambulance garage
block_text("osrp_kbc_natpis", "KBC OSIJEK", (HX - 6, HY + 22.12, 21.2), 0.32, (-1, 0, 0), (0, 0, 1), M_SIGN)
ERX = HX + 42
box(col, "osrp_hitna_nadstresnica", (ERX, HY + 27, 4.4), (18, 10, 0.45), M_CANOPY)
for dx in (-8.5, 8.5):
    cylinder(col, f"osrp_hitna_stup_{dx}", (ERX + dx, HY + 31.5, 0.1), 0.25, 4.3, M_STEEL, verts=8)
box(col, "osrp_hitna_ulaz", (ERX, HY + 22.05, 0.1), (6, 0.25, 3.0), M_GLASS)
block_text("osrp_hitna_natpis", "HITNA", (ERX + text_width("HITNA", 0.36) / 2, HY + 22.12, 5.2), 0.36, (-1, 0, 0), (0, 0, 1), M_SIGN_RED)
GX, GY = -250, -398
box(col, "osrp_hitna_garaza", (GX, GY, 0), (26, 30, 7), M_HOSP)
box(col, "osrp_hitna_garaza_krov", (GX, GY, 7), (27, 31, 0.4), M_STONE)
for k in range(3):
    box(col, f"osrp_hitna_garaza_vrata_{k}", (GX - 8.5 + k * 8.5, GY + 15.05, 0.1), (6.5, 0.2, 5.2), M_CANOPY)
    line(f"osrp_hitna_garaza_crta_{k}", GX - 8.5 + k * 8.5, GY + 20, 0.15, 8, M_RED)
plane(col, "osrp_hitna_garaza_prilaz", (GX, (GY + 15 - 358) / 2, 0.1), (26, -358 - GY - 15), M_ROAD)
SPECIAL += [(GX - 8.5, GY + 21, None, 180.0, "ambulance", 0), (GX + 8.5, GY + 21, None, 180.0, "ambulance", 0)]
for k, (bx_, by_) in enumerate(((HX - 20, HY + 30), (HX + 20, HY + 30))):
    BENCHES.append((bx_, by_, 0.0))
PLACES["hospital_door"] = (HX, HY + 10.4)          # reception desk inside the lobby
PLACES["hospital_spawn"] = (HX, HY + 28.5)
PLACES["ems_garage"] = (HX + 50, -369.0)
PLACES["ambulance_start"] = (-290, -366.0)        # in front of the lot exit (driveway)

# ---------- Zračna luka Osijek (airport) ----------
RW_Y, RW_L, RW_W = -665, 1000, 45
plane(col, "osrp_pista", (0, RW_Y, 0.1), (RW_L, RW_W), M_ROAD)
for side in (-1, 1):
    line(f"osrp_pista_rub_{side}", 0, RW_Y + side * (RW_W / 2 - 1.2), RW_L - 4, 0.9)
for k in range(-8, 9):    # centre line dashes
    line(f"osrp_pista_sred_{k}", k * 50, RW_Y, 28, 0.9)
for end in (-1, 1):      # threshold stripes + aiming points
    for k in range(10):
        line(f"osrp_pista_prag_{end}_{k}", end * (RW_L / 2 - 22), RW_Y - 18 + k * 4, 30, 1.8)
    for side in (-1, 1):
        line(f"osrp_pista_cilj_{end}_{side}", end * (RW_L / 2 - 160), RW_Y + side * 7, 45, 6)
for k in range(21):      # edge lights
    for side in (-1, 1):
        box(col, f"osrp_pista_svjetlo_{k}_{side}", (-500 + k * 50, RW_Y + side * (RW_W / 2 + 1.5), 0.1), (0.4, 0.4, 0.35), M_RWLIGHT)
# taxiway + connectors (yellow centre lines)
TW_Y = -605
plane(col, "osrp_rulnica", (0, TW_Y, 0.1), (840, 18), M_ROAD)
line("osrp_rulnica_crta", 0, TW_Y, 836, 0.3, M_YLINE)
for k, x in enumerate((-410, 0, 410)):
    ya, yb = TW_Y - 9, RW_Y + RW_W / 2
    plane(col, f"osrp_rulnica_veza_{k}", (x, (ya + yb) / 2, 0.1), (18, ya - yb), M_ROAD)
    line(f"osrp_rulnica_veza_crta_{k}", x, (ya + yb) / 2, 0.3, ya - yb, M_YLINE)
# apron, stands, terminal, car park, access road
AP_X0, AP_X1, AP_Y0, AP_Y1 = 40, 360, TW_Y + 9, -460
plane(col, "osrp_platforma", ((AP_X0 + AP_X1) / 2, (AP_Y0 + AP_Y1) / 2, 0.1), (AP_X1 - AP_X0, AP_Y1 - AP_Y0), M_APRON)
for k, x in enumerate((110, 200, 290)):
    line(f"osrp_stajanka_{k}", x, (AP_Y0 + AP_Y1) / 2 - 10, 0.3, AP_Y1 - AP_Y0 - 30, M_YLINE, 0.1)
    line(f"osrp_stajanka_stop_{k}", x, AP_Y1 - 22, 6, 0.4, M_YLINE, 0.1)
SPECIAL += [(110, -505, None, 0.0, "luxor", 0), (200, -505, None, 0.0, "shamal", 0), (290, -505, None, 0.0, "miljet", 0)]
TX, TY = 200, -447
# v1.0.16: the terminal is a hall you can walk into (check-in, seats, departures board)
M_TFLOOR = material("osrp_pavement_terminal", (0.70, 0.70, 0.68))
box(col, "osrp_terminal_pod", (TX, TY, 0), (199.2, 25.2, FLOOR_Z), M_TFLOOR)
for sx in (-1, 1):
    box(col, f"osrp_terminal_zid_s_{sx}", (TX + sx * 52, TY + 12.8, 0), (96, 0.4, 12), M_TERM)        # north wall, 8 m door
    box(col, f"osrp_terminal_staklo_s_{sx}", (TX + sx * 19.5, TY + 13.15, FLOOR_Z), (31, 0.3, 4.2), M_GLASS)
    box(col, f"osrp_terminal_zid_bok_{sx}", (TX + sx * 99.8, TY, 0), (0.4, 26, 12), M_TERM)
    box(col, f"osrp_terminal_zid_j_{sx}", (TX + sx * 97.5, TY - 12.8, 0), (5, 0.4, 12), M_TERM)
box(col, "osrp_terminal_nadvratnik", (TX, TY + 12.8, 4.5), (8, 0.4, 7.5), M_TERM)
box(col, "osrp_terminal_staklo_j", (TX, TY - 12.85, 0.6), (190, 0.3, 9.5), M_GLASS)
box(col, "osrp_terminal_podnozje_j", (TX, TY - 12.8, 0), (190, 0.4, 0.6), M_TERM)
box(col, "osrp_terminal_vrh_j", (TX, TY - 12.8, 10.1), (190, 0.4, 1.9), M_TERM)
for k in range(6):   # check-in desks
    x = TX - 70 + k * 12
    box(col, f"osrp_checkin_{k}", (x, TY + 6, FLOOR_Z), (7, 1.2, 1.1), M_STEEL)
    box(col, f"osrp_checkin_traka_{k}", (x + 4.6, TY + 6.5, FLOOR_Z), (2.2, 2.2, 0.5), M_CANOPY)
for r in range(3):   # rows of seats at the gates
    for k in range(5):
        box(col, f"osrp_sjedala_{r}_{k}", (TX + 30 + k * 12, TY - 4 + r * 3.5, FLOOR_Z), (8, 0.7, 0.45), M_GLASS_STOP)
box(col, "osrp_ploca_odlasci", (TX - 40, TY + 12.45, 6.0), (16, 0.2, 3.4), M_CANOPY)
block_text("osrp_ploca_natpis", "ODLASCI", (TX - 40 - text_width("ODLASCI", 0.28) / 2, TY + 12.3, 8.2), 0.28, (1, 0, 0), (0, 0, 1), M_SIGN)
INTERIOR_LIGHTS += [(TX + dx, TY, 11.0) for dx in (-80, -40, 0, 40, 80)]
FURNITURE += [("automat", TX + 95, TY + 8, FLOOR_Z, 270.0), ("kava", TX + 95, TY + 5, FLOOR_Z, 270.0),
              ("biljka", TX - 95, TY + 10, FLOOR_Z, 0.0), ("biljka", TX + 95, TY - 10, FLOOR_Z, 0.0)]
STAFF += [("s_f_y_airhostess_01", TX - 70 + k * 12, TY + 7.3, 180.0, "WORLD_HUMAN_STAND_IMPATIENT") for k in (0, 2, 4)]
STAFF += [("s_m_m_security_01", TX + 4, TY + 10, 180.0, "WORLD_HUMAN_GUARD_STAND"), ("s_m_m_pilot_01", TX + 40, TY - 8, 0.0, "WORLD_HUMAN_STAND_MOBILE")]
PLACES["terminal_arrival"] = (TX + 10, TY - 6)
box(col, "osrp_terminal_plocnik", (TX, TY + 14.6, 0), (200, 3.2, FLOOR_Z), M_WALK)
# service road from the car park round the terminal to the apron
plane(col, "osrp_servisna_cesta", (312, -427.5, 0.1), (10, 65), M_ROAD)
plane(col, "osrp_servisna_veza", (298.5, -413, 0.1), (17, 10), M_ROAD)
box(col, "osrp_terminal_krov", (TX, TY, 12), (208, 34, 0.7), M_STEEL)
box(col, "osrp_terminal_natpis", (TX, TY + 13.3, 8), (40, 0.4, 2.6), M_GLASS_STOP)
plane(col, "osrp_terminal_parking", (TX, -413, 0.1), (180, 36), M_ROAD)
for k in range(28):
    line(f"osrp_terminal_mjesto_{k}", TX - 84 + k * 6.2, -421, 0.12, 5.0)
    line(f"osrp_terminal_mjesto2_{k}", TX - 84 + k * 6.2, -405, 0.12, 5.0)
plane(col, "osrp_cesta_aerodrom", (150, -376, 0.1), (10, 38), M_ROAD)
line("osrp_cesta_aerodrom_crta", 150, -376, 0.13, 34)
SIGNS_EXTRA = [("stop", 150 + 6, -358.5, 0.0)]
# control tower, hangars, windsock
cylinder(col, "osrp_toranj_stup", (390, -470, 0), 3.6, 30, M_TERM, verts=14)
cylinder(col, "osrp_toranj_kabina", (390, -470, 30), 6.2, 4.5, M_GLASS, verts=14)
cylinder(col, "osrp_toranj_krov", (390, -470, 34.5), 6.8, 0.7, M_STEEL, verts=14)
cylinder(col, "osrp_toranj_antena", (390, -470, 35.2), 0.12, 7, M_POLE, verts=6)
for k, hx in enumerate((-300, -170)):
    box(col, f"osrp_hangar_{k}", (hx, -540, 0), (100, 56, 13), M_HANGAR)
    gable_roof(col, f"osrp_hangar_krov_{k}", hx, -540, 13, 100, 56, 6, M_HANGAR)
    box(col, f"osrp_hangar_vrata_{k}", (hx, -568.1, 0.1), (84, 0.3, 11.5), M_CANOPY)
    plane(col, f"osrp_hangar_platforma_{k}", (hx, (-568 + TW_Y + 9) / 2, 0.1), (100, -568 - TW_Y - 9), M_APRON)
SPECIAL += [(-300, -578, None, 180.0, "cuban800", 0), (-170, -578, None, 180.0, "velum2", 0)]
cylinder(col, "osrp_vjetrokaz_stup", (480, -625, 0), 0.1, 6, M_POLE, verts=6)
box(col, "osrp_vjetrokaz", (481.4, -625, 5.2), (2.6, 0.7, 0.7), M_RED)
PLACES["airport"] = (TX, TY - 30)
PLACES["airport_entrance"] = (TX, TY + 20)

# ---------- v1.0.15 airport details ----------
# runway numbers (09 at the west end, 27 at the east end) read by landing pilots
NPS = 1.5
block_text("osrp_pista_br_09", "09", (-452, RW_Y + text_width("09", NPS) / 2, 0.1), NPS, (0, -1, 0), (1, 0, 0), M_LINE)
block_text("osrp_pista_br_27", "27", (452, RW_Y - text_width("27", NPS) / 2, 0.1), NPS, (0, 1, 0), (-1, 0, 0), M_LINE)
# approach lights beyond both runway ends + threshold lights
for end in (-1, 1):
    for k in range(7):
        x = end * (506 + k * 6)
        cylinder(col, f"osrp_prilaz_stup_{end}_{k}", (x, RW_Y, -6), 0.08, 6.4, M_POLE, verts=6)
        box(col, f"osrp_prilaz_svjetlo_{end}_{k}", (x, RW_Y, 0.4), (0.5, 0.5, 0.3), M_RWLIGHT)
    for k in range(-7, 8):
        box(col, f"osrp_prilaz_bar_{end}_{k}", (end * 524, RW_Y + k * 2.2, 0.4), (0.4, 0.4, 0.3), M_RWLIGHT)
        box(col, f"osrp_prag_svjetlo_{end}_{k}", (end * 499, RW_Y + k * 2.9, 0.1), (0.4, 0.4, 0.25), M_SIGN_RED if end == 1 else M_SIGN)
# blue taxiway edge lights
for x in range(-415, 416, 30):
    for side in (-1, 1):
        if side == 1 and 30 < x < 370:
            continue          # apron side
        box(col, f"osrp_rulnica_svjetlo_{x}_{side}", (x, TW_Y + side * 10, 0.1), (0.35, 0.35, 0.3), M_SIGN_BLUE)
# jet bridges from the terminal to the three stands
for k, x in enumerate((110, 200, 290)):
    box(col, f"osrp_most_avion_{k}", (x + 7, -474, 4.2), (3.2, 28, 3.0), M_TERM)
    box(col, f"osrp_most_avion_staklo_{k}", (x + 5.35, -474, 5.0), (0.1, 26, 1.2), M_GLASS)
    cylinder(col, f"osrp_most_avion_noga_{k}", (x + 7, -485, 0.1), 0.35, 4.1, M_STEEL, verts=8)
# apron floodlight masts
for k, (x, y) in enumerate(((45, -480), (355, -480), (45, -590), (355, -590), (200, -592))):
    cylinder(col, f"osrp_reflektor_stup_{k}", (x, y, 0.1), 0.35, 22, M_POLE, verts=8)
    box(col, f"osrp_reflektor_{k}", (x, y, 22), (3.2, 1.2, 1.0), M_LAMP)
# terminal: entrance canopy, OSIJEK signs on both sides
box(col, "osrp_terminal_ulaz", (TX, TY + 17, 4.6), (44, 8, 0.4), M_STEEL)
for dx in (-20, -7, 7, 20):
    cylinder(col, f"osrp_terminal_ulaz_stup_{dx}", (TX + dx, TY + 20.5, 0.1), 0.3, 4.5, M_STEEL, verts=8)
SPS = 0.5
block_text("osrp_terminal_natpis_s", "OSIJEK", (TX + text_width("OSIJEK", SPS) / 2, TY + 13.35, 7.6), SPS, (-1, 0, 0), (0, 0, 1), M_SIGN)
block_text("osrp_terminal_natpis_j", "OSIJEK", (TX - text_width("OSIJEK", SPS) / 2, TY - 13.45, 8.0), SPS, (1, 0, 0), (0, 0, 1), M_SIGN)
# cargo terminal + fuel tanks
box(col, "osrp_cargo", (-30, -540, 0), (60, 40, 10), M_HANGAR)
gable_roof(col, "osrp_cargo_krov", -30, -540, 10, 60, 40, 3, M_HANGAR)
for k, x in enumerate((-90, -75)):
    cylinder(col, f"osrp_gorivo_{k}", (x, -530, 0), 6, 8, M_HOSP, verts=16)
    cylinder(col, f"osrp_gorivo_krov_{k}", (x, -530, 8), 6.2, 0.4, M_STEEL, verts=16)
# airside fence (posts + rails)
for (xa, xb, fy) in ((-550, 30, -506), (370, 550, -463)):
    for x in range(int(xa), int(xb) + 1, 4):
        box(col, f"osrp_ograda_stup_{x}_{fy}", (x, fy, 0), (0.12, 0.12, 2.4), M_POLE)
    for z in (0.9, 2.2):
        box(col, f"osrp_ograda_zica_{fy}_{z}", ((xa + xb) / 2, fy, z), (xb - xa, 0.05, 0.08), M_POLE)
# GTA airport props (placed in-game, see Config.SignModels)
# v1.0.16 street furniture (GTA props): benches, bins, hydrants, news stands, bike racks, phone booths
STREETPROPS = []
for side in (-1, 1):
    h = 180.0 if side == 1 else 0.0
    for k, x in enumerate(range(-535, 536, 18)):
        if not clear_of_cross(x, 10):
            continue
        kind = ("kanta", "klupa", "kiosk", "bicikl", "kanta", "telefon", "posuda")[k % 7]
        if kind == "klupa":
            BENCHES.append((x + 4, side * 14.9, h))        # real bench you can sit on, looking at the street
        else:
            STREETPROPS.append((kind, x + 4, side * 14.9, h))
        if k % 4 == 0:
            STREETPROPS.append(("hidrant", x + 9, side * 8.9, h))
for yc in (-350, -180, 125):
    for side in (-1, 1):
        for k, x in enumerate(range(-520, 521, 40)):
            if clear_of_cross(x, 9) and not (yc == -350 and side == -1 and any(abs(x - d) < 9 for d in DRIVEWAYS)):
                kind = ("kanta", "hidrant", "klupa")[k % 3]
                if kind == "klupa":
                    BENCHES.append((x, yc + side * 6.9, 180.0 if side == 1 else 0.0))
                else:
                    STREETPROPS.append((kind, x, yc + side * 6.9, 0.0 if side == 1 else 180.0))
AIRPROPS = []
for x in (110, 200, 290):
    AIRPROPS += [("air_stair", x - 7, -500, 90.0), ("air_bagloader", x + 9, -512, 0.0), ("air_cart", x + 14, -470, 90.0)]
AIRPROPS += [("air_cargo", -30 + dx, -566, 0.0) for dx in (-15, -5, 5, 15)]
AIRPROPS += [("air_radar", 470, -560, 0.0), ("air_cone", 45, -600, 0.0), ("air_cone", 355, -600, 0.0)]

# ---------- Copacabana beach on the north bank ----------
BEACH_Y = RIVER_Y + RIVER_W / 2 + 15
plane(col, "osrp_plaza_pijesak", (-300, BEACH_Y, 0.12), (220, 26), M_SAND)
for k in range(9):
    bx_ = -390 + k * 22
    cylinder(col, f"osrp_plaza_suncobran_stup_{k}", (bx_, BEACH_Y + 2, 0.12), 0.05, 2.4, M_POLE, verts=6)
    cylinder(col, f"osrp_plaza_suncobran_{k}", (bx_, BEACH_Y + 2, 2.4), 1.6, 0.12, M_RED if k % 2 else M_WHITE_STONE, verts=10)
    for dx in (-1.1, 1.1):
        box(col, f"osrp_plaza_lezaljka_{k}_{dx}", (bx_ + dx, BEACH_Y, 0.12), (0.7, 1.9, 0.35), M_WOOD)
for k in range(10):
    tree(col, f"prom_plaza_{k}", -400 + k * 22 + 11, BEACH_Y + 17, 1.1)

# =============================================================== v1.0.20: promenade + bike paths along the Drava
M_BIKE = material("osrp_asphalt_bike", (0.36, 0.07, 0.05), rough=0.9)
BIKE_S = PROM_Y - 6.5                         # south bank: bike path on the river side of the street, inside the promenade
NP_Y = RIVER_Y + RIVER_W / 2 + 38             # north bank promenade (Šetalište) centre
BIKE_N = NP_Y + 5.25                          # north bike path
BIKEROUTES = []
for name, by in (("jug", BIKE_S), ("sjever", BIKE_N)):
    box(col, f"osrp_biciklisticka_{name}", (0, by, 0.12), (MAP_W - 4, 2.6, 0.02), M_BIKE)
    lines = []
    x = -MAP_W / 2 + 4
    while x < MAP_W / 2 - 6:
        lines.append((x + 1.0, by, 0.14, 2.0, 0.12, 0.012))
        x += 5.0
    for side in (-1, 1):
        lines.append((0, by + side * 1.22, 0.14, MAP_W - 6, 0.08, 0.012))
    # bicycle signs painted every 60 m
    for x in range(-500, 501, 60):
        lines += [(x - 0.45, by - 0.6, 0.14, 0.5, 0.06, 0.012), (x + 0.45, by - 0.6, 0.14, 0.5, 0.06, 0.012),
                  (x, by - 0.45, 0.14, 0.06, 0.3, 0.012)]
    boxes_mesh(f"osrp_biciklisticka_crte_{name}", lines, M_LINE)
    BIKEROUTES.append((-MAP_W / 2 + 6, by, MAP_W / 2 - 6, by))

# north bank: Šetalište (6 m walkway) + trees, lamps, benches looking at the river, path from the footbridge
box(col, "osrp_setaliste_sjever", (0, NP_Y, 0.0), (MAP_W - 2, 6.0, 0.12), M_WALK)
box(col, "osrp_most_staza_sjever", (BR_X, (RIVER_Y + RIVER_W / 2 + 4 + NP_Y - 3) / 2, 0.0), (4.0, NP_Y - 3 - (RIVER_Y + RIVER_W / 2 + 4), 0.12), M_WALK)
for k, x in enumerate(range(-530, 531, 30)):
    street_light(col, f"sjever_{k}", x, NP_Y - 3.6, 1)
    if abs(x - BR_X) > 6:
        tree(col, f"prom_sjever_{k}", x + 15, BIKE_N + 3.4, 1.0)
    if k % 2 == 0 and abs(x + 7 - BR_X) > 4:
        BENCHES.append((x + 7, NP_Y - 2.2, 180.0))
EXTRA_WALKS = [(-MAP_W / 2 + 10, NP_Y + 1, MAP_W / 2 - 10, NP_Y + 1)]

# bike rental (Bike Osijek) - bikes you can take with F
for k, (bx, by, h) in enumerate(((-300, BIKE_S - 3.6, 0.0), (150, BIKE_S - 3.6, 0.0), (-140, BIKE_N + 3.5, 180.0), (-180, BEACH_Y + 16, 180.0))):
    box(col, f"osrp_bicikli_ploca_{k}", (bx, by, 0.0), (8.0, 3.4, 0.14), M_WALK)
    box(col, f"osrp_bicikli_stalak_{k}", (bx, by + (1.3 if h == 0.0 else -1.3), 0.14), (7.2, 0.12, 0.75), M_STEEL)
    box(col, f"osrp_bicikli_znak_{k}", (bx - 3.6, by, 0.14), (0.15, 0.15, 2.2), M_POLE)
    box(col, f"osrp_bicikli_znak_ploca_{k}", (bx - 3.6, by, 2.2), (0.08, 1.2, 0.8), M_SIGN_BLUE)
    for j, m in enumerate(("cruiser", "scorcher", "bmx", "tribike")):
        SPECIAL.append((bx - 2.4 + j * 1.6, by, None, h, m, 0))
MAPRECTS += [("bike", 0, BIKE_S, MAP_W, 2.6), ("bike", 0, BIKE_N, MAP_W, 2.6), ("walk", 0, NP_Y, MAP_W, 6)]

# ---------------------------------------------------------------- city life data (used in-game by osrp_osijek)
HALF = MAP_W / 2
MAPRECTS[:0] = [
    ("land", 0, -105, MAP_W, 530), ("land", 0, RIVER_Y + RIVER_W / 2 + 40, MAP_W, 80),
    ("water", 0, RIVER_Y, MAP_W, RIVER_W), ("walk", 0, PROM_Y, MAP_W, 16),
    ("park", PCX, PCY, PARK_X1 - PARK_X0, PARK_Y1 - PARK_Y0), ("square", TV_X, TV_Y, 120, 95),
]
MAPRECTS += [("road", 0, 0, MAP_W, ROAD_W), ("road", 0, -180, MAP_W, SIDE_ROAD_W),
             ("road", 0, -350, MAP_W, SIDE_ROAD_W), ("road", 0, 125, MAP_W, SIDE_ROAD_W)]
MAPRECTS += [("road", x, -112.5, SIDE_ROAD_W, 475) for x in CROSS_X]
MAPRECTS += [("walk", 0, yc + sd * (SIDE_ROAD_W / 2 + 1.55), MAP_W, 2.5) for yc in (-350, -180, 125) for sd in (-1, 1)]
MAPRECTS[:0] = [("land", 0, (-370 + SOUTH_END) / 2, MAP_W, -370 - SOUTH_END)]
MAPRECTS += [
    ("road", 0, RW_Y, RW_L, RW_W), ("road", 0, TW_Y, 840, 18), ("square", (AP_X0 + AP_X1) / 2, (AP_Y0 + AP_Y1) / 2, AP_X1 - AP_X0, AP_Y1 - AP_Y0),
    ("bld", TX, TY, 200, 26), ("road", TX, -413, 180, 36), ("road", 150, -376, 10, 38),
    ("bld", -300, -540, 100, 56), ("bld", -170, -540, 100, 56), ("bld", 390, -470, 8, 8),
    ("road", HX, -369, 130, 22), ("bld", HX, HY, 110, 44), ("bld", HX - 40, HY - 40, 30, 36),
    ("walk", -300, BEACH_Y, 220, 26), ("bld", GX, GY, 26, 30), ("road", GX, (GY + 15 - 358) / 2, 26, -358 - GY - 15),
    ("bld", -30, -540, 60, 40), ("bld", -82, -530, 26, 12),
] + [("road", x, (TW_Y - 9 + RW_Y + RW_W / 2) / 2, 18, TW_Y - 9 - RW_Y - RW_W / 2) for x in (-410, 0, 410)]

LANDMARKS = [("Tvrđa - Konkatedrala", TV_X, TV_Y - 20), ("Trg Svetog Trojstva", PIL_X, PIL_Y),
             ("Gradski park", PCX, PCY), ("Pješački most", BR_X, RIVER_Y), ("Promenada uz Dravu", 0, PROM_Y),
             ("Europska avenija", -250, 0), ("KBC Osijek - Bolnica", HX, HY), ("Zračna luka Osijek", TX, TY),
             ("Kupalište Copacabana", -300, BEACH_Y)]

PARKING = []        # (x, y, heading) parked cars along the curbs of the cross streets
SIGNS = []          # (kind, x, y, heading)
for i, x in enumerate(CROSS_X):
    if abs(x) == 450:
        continue        # the outer streets carry the traffic loops
    for (ya, yb) in ((-340, -190), (-170, -30), (30, 115)):
        for yy in range(int(ya) + 6, int(yb) - 6, 7):
            if random.random() < 0.55:
                PARKING.append((x + SIDE_ROAD_W / 2 - 1.3, yy, 0.0))      # east kerb, facing north
            if random.random() < 0.55:
                PARKING.append((x - SIDE_ROAD_W / 2 + 1.3, yy, 180.0))    # west kerb, facing south
for x in CROSS_X:
    # stop signs where the cross streets meet the avenue, traffic lights on the avenue corners
    SIGNS.append(("stop", x + SIDE_ROAD_W / 2 + 0.9, -(ROAD_W / 2 + 7.5), 0.0))
    SIGNS.append(("stop", x - SIDE_ROAD_W / 2 - 0.9, ROAD_W / 2 + 7.5, 180.0))
    for sx, sy, h in ((1, -1, 90.0), (-1, 1, 270.0)):
        SIGNS.append(("semafor", x + sx * (SIDE_ROAD_W / 2 + 1.0), sy * (ROAD_W / 2 + 1.2), h))
    SIGNS.append(("stop", x - SIDE_ROAD_W / 2 - 0.9, -180 + SIDE_ROAD_W / 2 + 1.5, 180.0))
    SIGNS.append(("pjesacki", x + SIDE_ROAD_W / 2 + 0.9, -(ROAD_W / 2 + 12), 0.0))

# v1.0.18 bushes + grass clumps on the green areas (GTA plants)
GREEN = []
for bx in range(len(CROSS_X) - 1):
    for (y0, y1) in [(-342.2, -187.8), (-172.2, -16), (16, 117.2)]:
        x0, x1 = CROSS_X[bx] + 12, CROSS_X[bx + 1] - 12
        for k in range(5):
            GREEN.append(("grm" if k % 2 == 0 else "trava", random.uniform(x0, x1), random.uniform(y0 + 24, y1 - 24), random.uniform(0, 360)))
for k in range(int((PARK_X1 - PARK_X0) / 9)):
    for y in (PARK_Y0 + 1.5, PARK_Y1 - 1.5):
        GREEN.append(("grm", PARK_X0 + 4 + k * 9, y, random.uniform(0, 360)))
for k in range(12):
    GREEN.append(("grm", -405 + k * 20, BEACH_Y + 24, random.uniform(0, 360)))
for k in range(10):
    GREEN.append(("grm", HX - 50 + k * 11, HY - 26, random.uniform(0, 360)))
SIGNS += SIGNS_EXTRA + AIRPROPS + STREETPROPS + GREEN
WALKS = list(EXTRA_WALKS)   # sidewalk segments NPCs walk along: (x0, y0, x1, y1)
for a, b in open_segments(-HALF, HALF, SIDE_ROAD_W / 2 + 1):
    for y in (ROAD_W / 2 + 3.3, -(ROAD_W / 2 + 3.3)):
        WALKS.append((a + 2, y, b - 2, y))
WALKS.append((-HALF + 10, PROM_Y + 3, HALF - 10, PROM_Y + 3))
for x in CROSS_X:
    for sgn in (-1, 1):
        WALKS.append((x + sgn * (SIDE_ROAD_W / 2 + 1.55), -170, x + sgn * (SIDE_ROAD_W / 2 + 1.55), -20))
        WALKS.append((x + sgn * (SIDE_ROAD_W / 2 + 1.55), 22, x + sgn * (SIDE_ROAD_W / 2 + 1.55), 115))

# traffic loops (right-hand traffic, lane centres)
ROUTES = [
    [(-452.5, 127.5), (-452.5, -4.0), (452.5, -4.0), (452.5, 127.5)],     # avenue east -> river street west
    [(452.5, -182.5), (452.5, 4.0), (-452.5, 4.0), (-452.5, -182.5)],     # avenue west -> south street east
]

print(f"[OSRP] Osijek map v1.0.20: {len(PARKING)} parking, {len(SIGNS)} signs, {len(DOORS)} doors, {len(FURNITURE)} furniture, {len(col.objects)} objects, {li} street lights, collection '{COL_NAME}'")
