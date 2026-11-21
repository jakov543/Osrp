"""
OSRP - Osijek starter map for Blender (V1)

How to use:
  1. Open Blender (4.x), go to the "Scripting" tab.
  2. Open this file and press "Run Script".
  3. A collection "OSRP_Osijek" is created: ground, Drava river, streets,
     Tvrđa square with a cathedral tower, city blocks and the pedestrian bridge.
  4. Follow map/BLENDER-MAP.md to convert it with Sollumz and put it in FiveM.

All sizes are in meters (GTA V uses meters too). The map is built around (0,0,0);
you move it to its final GTA position later in CodeWalker.
"""
import bpy
import random

random.seed(31000)  # Osijek postal code - same city every time

COL_NAME = "OSRP_Osijek"


# ---------- helpers ----------
def get_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def clear_collection(col):
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def material(name, rgb, rough=0.8, metal=0.0, alpha=1.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Alpha"].default_value = alpha
    mat.diffuse_color = (*rgb, alpha)
    return mat


def box(col, name, loc, size, mat):
    """size = (x, y, z) full size in meters, loc = center of the bottom face"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1], loc[2] + size[2] / 2))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def plane(col, name, loc, size, mat):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def cone(col, name, loc, radius, height, mat, verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, depth=height,
                                    location=(loc[0], loc[1], loc[2] + height / 2))
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


# ---------- materials ----------
M_GRASS = material("osrp_grass", (0.18, 0.32, 0.12))
M_ROAD = material("osrp_asphalt", (0.07, 0.07, 0.08), rough=0.95)
M_WALK = material("osrp_pavement", (0.45, 0.44, 0.42))
M_WATER = material("osrp_drava_water", (0.08, 0.22, 0.25), rough=0.05)
M_BRICK = material("osrp_red_brick", (0.45, 0.14, 0.09))
M_ROOF = material("osrp_roof", (0.35, 0.10, 0.06))
M_PLASTER = [
    material("osrp_plaster_yellow", (0.85, 0.72, 0.40)),
    material("osrp_plaster_white", (0.86, 0.84, 0.80)),
    material("osrp_plaster_peach", (0.88, 0.62, 0.48)),
    material("osrp_plaster_grey", (0.60, 0.60, 0.62)),
]
M_STEEL = material("osrp_bridge_steel", (0.75, 0.77, 0.80), rough=0.3, metal=1.0)

# ---------- build ----------
col = get_collection(COL_NAME)
clear_collection(col)

MAP_W, MAP_H = 800, 600            # meters
RIVER_Y, RIVER_W = 220, 90         # Drava runs east-west across the north

# Ground (south bank + north bank)
plane(col, "osrp_ground_south", (0, -70, 0), (MAP_W, MAP_H - 140), M_GRASS)
plane(col, "osrp_ground_north", (0, RIVER_Y + RIVER_W / 2 + 40, 0), (MAP_W, 80), M_GRASS)

# Drava river (slightly below ground) + river banks
plane(col, "osrp_drava", (0, RIVER_Y, -1.5), (MAP_W, RIVER_W), M_WATER)
box(col, "osrp_bank_south", (0, RIVER_Y - RIVER_W / 2 - 1, -2), (MAP_W, 2, 2), M_WALK)
box(col, "osrp_bank_north", (0, RIVER_Y + RIVER_W / 2 + 1, -2), (MAP_W, 2, 2), M_WALK)

# Promenade along the Drava (south side)
plane(col, "osrp_promenada", (0, RIVER_Y - RIVER_W / 2 - 8, 0.2), (MAP_W, 12), M_WALK)

# Streets: main avenue east-west + cross streets
ROAD_W = 14
plane(col, "osrp_europska_avenija", (0, 0, 0.15), (MAP_W, ROAD_W), M_ROAD)
plane(col, "osrp_ulica_south", (0, -180, 0.15), (MAP_W, ROAD_W), M_ROAD)
plane(col, "osrp_ulica_river", (0, 120, 0.15), (MAP_W, ROAD_W), M_ROAD)
cross_x = [-300, -150, 0, 150, 300]
for i, x in enumerate(cross_x):
    plane(col, f"osrp_ulica_cross_{i}", (x, -40, 0.17), (ROAD_W, 360), M_ROAD)

# Sidewalks next to the main avenue
plane(col, "osrp_sidewalk_av_n", (0, ROAD_W / 2 + 2.5, 0.3), (MAP_W, 5), M_WALK)
plane(col, "osrp_sidewalk_av_s", (0, -ROAD_W / 2 - 2.5, 0.3), (MAP_W, 5), M_WALK)

# Tvrđa square (east, near the river) with the main cathedral tower
TV_X, TV_Y = 225, 60
plane(col, "osrp_tvrdja_trg", (TV_X, TV_Y, 0.25), (110, 90), M_WALK)
box(col, "osrp_katedrala_brod", (TV_X, TV_Y + 15, 0), (24, 60, 22), M_BRICK)
box(col, "osrp_katedrala_toranj", (TV_X, TV_Y - 20, 0), (12, 12, 60), M_BRICK)
cone(col, "osrp_katedrala_vrh", (TV_X, TV_Y - 20, 60), 8.5, 30, M_ROOF, verts=4)

# City blocks between the streets
block_id = 0
for bx in range(len(cross_x) - 1):
    for by, (y0, y1) in enumerate([(-173, -7), (7, 113)]):
        x0 = cross_x[bx] + ROAD_W / 2 + 3
        x1 = cross_x[bx + 1] - ROAD_W / 2 - 3
        # leave space for Tvrđa square
        if x0 < TV_X + 55 and x1 > TV_X - 55 and y1 > TV_Y - 45:
            continue
        x = x0
        while x < x1 - 8:
            w = random.uniform(12, 22)
            w = min(w, x1 - x)
            d = random.uniform(14, 24)
            h = random.choice([8, 11, 14, 17, 20, 26])
            for side, yy in (("a", y0), ("b", y1 - d)):
                obj = box(col, f"osrp_zgrada_{block_id}_{side}", (x + w / 2, yy + d / 2, 0), (w - 1, d, h),
                          random.choice(M_PLASTER))
                box(col, f"osrp_krov_{block_id}_{side}", (x + w / 2, yy + d / 2, h), (w - 0.6, d + 0.4, 0.6), M_ROOF)
            block_id += 1
            x += w

# Pedestrian bridge over the Drava (Pješački most) - simple suspension style
BR_X = -80
box(col, "osrp_most_deck", (BR_X, RIVER_Y, 2.0), (5, RIVER_W + 30, 0.8), M_STEEL)
box(col, "osrp_most_pylon_s", (BR_X, RIVER_Y - RIVER_W / 2 + 5, 0), (3, 3, 22), M_STEEL)
box(col, "osrp_most_pylon_n", (BR_X, RIVER_Y + RIVER_W / 2 - 5, 0), (3, 3, 22), M_STEEL)
box(col, "osrp_most_rail_w", (BR_X - 2.3, RIVER_Y, 2.8), (0.2, RIVER_W + 30, 1.1), M_STEEL)
box(col, "osrp_most_rail_e", (BR_X + 2.3, RIVER_Y, 2.8), (0.2, RIVER_W + 30, 1.1), M_STEEL)

# Simple trees along the promenade
M_LEAF = material("osrp_tree_leaf", (0.12, 0.30, 0.10))
M_TRUNK = material("osrp_tree_trunk", (0.25, 0.16, 0.08))
for i, x in enumerate(range(-380, 381, 25)):
    y = RIVER_Y - RIVER_W / 2 - 16
    box(col, f"osrp_drvo_deblo_{i}", (x, y, 0), (0.5, 0.5, 3), M_TRUNK)
    cone(col, f"osrp_drvo_krosnja_{i}", (x, y, 3), 2.5, 6, M_LEAF, verts=6)

print(f"[OSRP] Osijek starter map created: {len(col.objects)} objects in collection '{COL_NAME}'")
