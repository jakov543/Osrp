"""
OSRP - Osijek starter map for Blender (V1.0.9)

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


def box(col, name, loc, size, mat, rot_z=0.0):
    """loc = center of the bottom face, size = full (x, y, z) in meters"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1], loc[2] + size[2] / 2), rotation=(0, 0, rot_z))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _link(col, obj, mat)


def plane(col, name, loc, size, mat):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _link(col, obj, mat)


def cylinder(col, name, loc, radius, height, mat, verts=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height,
                                        location=(loc[0], loc[1], loc[2] + height / 2))
    obj = bpy.context.active_object
    obj.name = name
    return _link(col, obj, mat)


def blob(col, name, loc, radius, mat, squash=1.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (1, 1, squash)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    return _link(col, obj, mat)


def pyramid(col, name, loc, base, height, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=base, depth=height,
                                    location=(loc[0], loc[1], loc[2] + height / 2), rotation=(0, 0, math.pi / 4))
    obj = bpy.context.active_object
    obj.name = name
    return _link(col, obj, mat)


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
    """one object per facade: a window + Array modifiers (columns x floors), applied"""
    cols = max(1, int((width - 2) // 3.2))
    step = (width - 2) / cols
    x0 = cx - (width - 2) / 2 + step / 2
    y = face_y + 0.06 * facing
    win = box(col, name, (x0, y, z0 + 1.0), (1.3, 0.12, 1.6), mat)
    arr_x = win.modifiers.new("cols", 'ARRAY')
    arr_x.use_relative_offset = False
    arr_x.use_constant_offset = True
    arr_x.constant_offset_displace = (step, 0, 0)
    arr_x.count = cols
    arr_z = win.modifiers.new("floors", 'ARRAY')
    arr_z.use_relative_offset = False
    arr_z.use_constant_offset = True
    arr_z.constant_offset_displace = (0, 0, floor_h)
    arr_z.count = floors
    bpy.context.view_layer.objects.active = win
    for m in list(win.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    return win


# ---------------------------------------------------------------- materials
M_GRASS = material("osrp_grass", (0.16, 0.30, 0.10))
M_PARK = material("osrp_park_grass", (0.20, 0.38, 0.12))
M_ROAD = material("osrp_asphalt", (0.06, 0.06, 0.07), rough=0.95)
M_LINE = material("osrp_road_line", (0.92, 0.92, 0.88))
M_WALK = material("osrp_pavement", (0.50, 0.49, 0.46))
M_CURB = material("osrp_curb", (0.62, 0.61, 0.58))
M_PATH = material("osrp_gravel_path", (0.62, 0.55, 0.42))
M_STONE = material("osrp_river_stone", (0.40, 0.38, 0.35))
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


def bench(col, i, x, y, back=1):
    """bench along x; back=+1 backrest on the +y side (you sit facing -y), back=-1 the other way"""
    box(col, f"osrp_klupa_sjed_{i}", (x, y, 0.42), (1.8, 0.45, 0.06), M_WOOD)
    box(col, f"osrp_klupa_nasl_{i}", (x, y + 0.22 * back, 0.6), (1.8, 0.06, 0.45), M_WOOD)
    for k, dx in enumerate((-0.8, 0.8)):
        box(col, f"osrp_klupa_noga_{i}_{k}", (x + dx, y, 0), (0.08, 0.45, 0.42), M_POLE)


# ---------------------------------------------------------------- build
col = get_collection(COL_NAME)
clear_collection(col)

MAP_W = 800
RIVER_Y, RIVER_W = 220, 90
ROAD_W = 16                      # Europska avenija: 4 lanes
SIDE_ROAD_W = 10

# Ground
plane(col, "osrp_ground_south", (0, -70, 0), (MAP_W, 460), M_GRASS)
plane(col, "osrp_ground_north", (0, RIVER_Y + RIVER_W / 2 + 40, 0), (MAP_W, 80), M_GRASS)

# Drava + stone banks
plane(col, "osrp_drava", (0, RIVER_Y, -1.6), (MAP_W, RIVER_W), M_WATER)
box(col, "osrp_obala_jug", (0, RIVER_Y - RIVER_W / 2 - 1.5, -2), (MAP_W, 3, 2.05), M_STONE)
box(col, "osrp_obala_sjever", (0, RIVER_Y + RIVER_W / 2 + 1.5, -2), (MAP_W, 3, 2.05), M_STONE)

# Promenade (south bank)
PROM_Y = RIVER_Y - RIVER_W / 2 - 11
plane(col, "osrp_promenada", (0, PROM_Y, 0.12), (MAP_W, 16), M_WALK)

# Europska avenija (y = 0): asphalt, dashed lines, curbs, sidewalks
plane(col, "osrp_europska_avenija", (0, 0, 0.1), (MAP_W, ROAD_W), M_ROAD)
CROSS_X = [-300, -150, 0, 150, 300]
for i, x in enumerate(range(-395, 400, 12)):
    if any(abs(x - cx) < 12 for cx in CROSS_X):
        continue  # clean intersections
    box(col, f"osrp_crta_{i}", (x, -0.1, 0.1), (5, 0.18, 0.02), M_LINE)
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
        box(col, f"osrp_plocnik_av_{side}_{k}", ((a + b) / 2, y_edge + side * 3.3, 0.1), (b - a, 6, 0.16), M_WALK)

# Side streets
plane(col, "osrp_ulica_jug", (0, -180, 0.1), (MAP_W, SIDE_ROAD_W), M_ROAD)
plane(col, "osrp_ulica_rijeka", (0, 125, 0.1), (MAP_W, SIDE_ROAD_W), M_ROAD)
for i, x in enumerate(CROSS_X):
    # two separate pieces so the cross street never overlaps the avenue or the side streets (no flicker)
    y_s0, y_s1 = -180 + SIDE_ROAD_W / 2, -ROAD_W / 2
    y_n0, y_n1 = ROAD_W / 2, 125 - SIDE_ROAD_W / 2
    plane(col, f"osrp_ulica_poprecna_{i}_j", (x, (y_s0 + y_s1) / 2, 0.1), (SIDE_ROAD_W, y_s1 - y_s0), M_ROAD)
    plane(col, f"osrp_ulica_poprecna_{i}_s", (x, (y_n0 + y_n1) / 2, 0.1), (SIDE_ROAD_W, y_n1 - y_n0), M_ROAD)
    # sidewalks + curbs on both sides of every cross street (not across the avenue)
    for side in (-1, 1):
        xe = x + side * SIDE_ROAD_W / 2
        for (ya, yb, tag) in ((-175, -ROAD_W / 2 - 6.3, "j"), (ROAD_W / 2 + 6.3, 120, "s")):
            box(col, f"osrp_rubnik_p_{i}_{side}_{tag}", (xe + side * 0.15, (ya + yb) / 2, 0.1), (0.3, yb - ya, 0.18), M_CURB)
            box(col, f"osrp_plocnik_p_{i}_{side}_{tag}", (xe + side * 1.55, (ya + yb) / 2, 0.1), (2.5, yb - ya, 0.16), M_WALK)
        # dashed centre line
        for k, yy in enumerate(range(-170, 120, 10)):
            if abs(yy) < ROAD_W / 2 + 7:
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
for name, yc in (("jug", -180), ("rijeka", 125)):
    for side in (-1, 1):
        for k, (a, b) in enumerate(open_segments(-MAP_W / 2, MAP_W / 2, SIDE_ROAD_W / 2)):
            box(col, f"osrp_rubnik_{name}_{side}_{k}", ((a + b) / 2, yc + side * (SIDE_ROAD_W / 2 + 0.15), 0.1), (b - a, 0.3, 0.18), M_CURB)

# Street lights: avenue both sides every 30 m, promenade every 25 m
li = 0
def clear_of_cross(x, gap):
    return all(abs(x - cx) >= gap for cx in CROSS_X)


for x in range(-390, 391, 30):
    if clear_of_cross(x, 8):
        street_light(col, li, x, ROAD_W / 2 + 1.2, -1); li += 1
    if clear_of_cross(x + 15, 8):
        street_light(col, li, x + 15, -ROAD_W / 2 - 1.2, 1); li += 1
for x in range(-385, 386, 25):
    street_light(col, li, x, PROM_Y + 6.5, 1); li += 1

# Tvrđa square + cathedral (east)
TV_X, TV_Y = 225, 62
plane(col, "osrp_tvrdja_trg", (TV_X, TV_Y, 0.14), (120, 95), M_WALK)
box(col, "osrp_katedrala_brod", (TV_X, TV_Y + 14, 0), (24, 56, 24), M_BRICK)
gable_roof(col, "osrp_katedrala_krov", TV_X, TV_Y + 14, 24, 56, 24, 10, M_ROOF, rot_z=math.pi / 2)
box(col, "osrp_katedrala_toranj", (TV_X, TV_Y - 20, 0), (12, 12, 58), M_BRICK)
pyramid(col, "osrp_katedrala_vrh", (TV_X, TV_Y - 20, 58), 8.6, 32, M_SPIRE)
for k, (dx, dy) in enumerate(((-10, 36), (10, 36))):
    box(col, f"osrp_katedrala_mali_toranj_{k}", (TV_X + dx, TV_Y + dy, 0), (5, 5, 30), M_BRICK)
    pyramid(col, f"osrp_katedrala_mali_vrh_{k}", (TV_X + dx, TV_Y + dy, 30), 3.6, 9, M_SPIRE)
for k in range(8):   # trees around the square (k=6 would stand in front of the Trinity column)
    if k == 6:
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

# City blocks: buildings with windows + pitched roofs
bid = 0
for bx in range(len(CROSS_X) - 1):
    for (y0, y1) in [(-175, -16), (16, 120)]:
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
                box(col, f"osrp_zgrada_{bid}_{side}", (cx, cy, 0), (w - 1, d, h), mat)
                street_face = yy if facing == -1 else yy + d
                windows(col, f"osrp_prozori_{bid}_{side}", cx, street_face, 0.8, w - 1, floors, floor_h, M_GLASS, facing)
                gable_roof(col, f"osrp_krov_{bid}_{side}", cx, cy, h, w - 1, d, random.uniform(3.5, 5.5), M_ROOF)
            bid += 1
            x += w

# Pedestrian bridge over the Drava (Pješački most)
BR_X = -80
box(col, "osrp_most_paluba", (BR_X, RIVER_Y, 2.0), (5, RIVER_W + 30, 0.8), M_STEEL)
for k, yy in enumerate((RIVER_Y - RIVER_W / 2 + 5, RIVER_Y + RIVER_W / 2 - 5)):
    box(col, f"osrp_most_pilon_{k}", (BR_X, yy, 0), (3, 3, 24), M_STEEL)
for side in (-1, 1):
    box(col, f"osrp_most_ograda_{side}", (BR_X + side * 2.3, RIVER_Y, 2.8), (0.2, RIVER_W + 30, 1.1), M_STEEL)
    for k in range(12):   # suspension cables
        t = k / 11
        yy = RIVER_Y - RIVER_W / 2 + 5 + t * (RIVER_W - 10)
        top = 24 - 16 * math.sin(t * math.pi)
        box(col, f"osrp_most_sajla_{side}_{k}", (BR_X + side * 2.3, yy, 3.5), (0.06, 0.06, max(0.5, top - 3.5)), M_STEEL)

# Promenade: lindens with benches between them
for i, x in enumerate(range(-380, 381, 25)):
    tree(col, f"prom_{i}", x + 12, PROM_Y - 4, 1.0)
    if i % 2 == 0:
        bench(col, i, x + 12, PROM_Y + 1.5)

# Trees along the avenue sidewalks (between lamps)
for i, x in enumerate(range(-375, 376, 30)):
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
cylinder(col, "osrp_fontana_bazen", (FX, FY, 0.14), 4.2, 0.6, M_WHITE_STONE, verts=24)
cylinder(col, "osrp_fontana_voda", (FX, FY, 0.2), 3.8, 0.5, M_WATER, verts=24)
cylinder(col, "osrp_fontana_stup", (FX, FY, 0.7), 0.35, 1.8, M_WHITE_STONE, verts=12)
cylinder(col, "osrp_fontana_zdjela", (FX, FY, 2.5), 1.2, 0.3, M_WHITE_STONE, verts=16)

# Bus stops on Europska avenija
for i, x in enumerate((-225, -75, 75)):
    bus_stop(i, x, -ROAD_W / 2 - 3.6, 1)
    bus_stop(i + 10, x + 40, ROAD_W / 2 + 3.6, -1)

# Flower beds along the promenade
for i, x in enumerate(range(-350, 351, 50)):
    flower_bed(f"prom_{i}", x, PROM_Y - 0.5, 4.0, 1.2)

print(f"[OSRP] Osijek map v1.0.9: {len(col.objects)} objects, {li} street lights, collection '{COL_NAME}'")
