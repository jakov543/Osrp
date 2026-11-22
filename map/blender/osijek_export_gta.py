"""
OSRP - convert the Blender Osijek map into GTA V / FiveM assets with Sollumz.

Run headless (Linux/Windows) with Blender's Python + the Sollumz add-on enabled:
    blender -b -P osijek_export_gta.py -- <output_dir>

What it does:
  1. builds the city with osijek_starter.py
  2. real textures (asphalt, paving, grass, brick, roof tiles, plaster, water...) mapped in world space,
     Sollumz shaders (default.sps / emissive.sps for lamps), per-surface collision materials
     trees are removed from the model and exported as positions -> real GTA V tree props in-game
  3. cuts the city into 100 m chunks, each chunk = one drawable (.ydr) with embedded collision
  4. creates osijek.ytyp with an archetype per chunk
  5. exports everything (CodeWalker XML on Linux; native binary too when PyMateria is installed on Windows)
  6. writes osijek_layout.json (chunk name -> local position) for the in-game spawner (osrp_osijek)
"""
import bpy
import json
import math
import os
import runpy
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else os.path.join(HERE, "export"))
TEX = os.path.join(OUT, "_textures")
CHUNK = 100.0
LOD_DIST = 750.0
os.makedirs(TEX, exist_ok=True)

# ---------------------------------------------------------------- 1. city
city = runpy.run_path(os.path.join(HERE, "osijek_starter.py"))
col = bpy.data.collections["OSRP_Osijek"]
# trees -> real GTA V props in-game (positions saved below), remove the blob trees from the model
for o in [o for o in col.objects if "_drvo_" in o.name]:
    bpy.data.objects.remove(o, do_unlink=True)
with open(os.path.join(OUT, "osijek_trees.json"), "w") as f:
    json.dump([{"x": t[0], "y": t[1], "s": t[2], "kind": t[3]} for t in city["TREES"]], f)
with open(os.path.join(OUT, "osijek_doors.json"), "w") as f:
    json.dump([{"x": d[0], "y": d[1], "z": d[2], "h": d[3]} for d in city["DOORS"]], f)
with open(os.path.join(OUT, "osijek_life.json"), "w") as f:
    json.dump({k: city[k] for k in ("MAPRECTS", "LANDMARKS", "PARKING", "SIGNS", "WALKS", "ROUTES", "BENCHES", "SPECIAL", "STAFF", "INTERIOR_LIGHTS", "FOUNTAINS", "BOATS", "BIKEROUTES")}
              | {"PLACES": {k: list(v) for k, v in city["PLACES"].items()}}, f)
with open(os.path.join(OUT, "osijek_furniture.json"), "w") as f:
    json.dump([{"kind": m[0], "x": m[1], "y": m[2], "z": m[3], "h": m[4]} for m in city["FURNITURE"]], f)
objs = [o for o in col.objects if o.type == "MESH"]
print(f"[OSRP] {len(objs)} meshes built")

from sollumz.ydr.shader_materials import create_shader  # noqa: E402
from sollumz.ybn.collision_materials import create_collision_material_from_index, collisionmats  # noqa: E402
from sollumz.sollumz_preferences import get_export_settings  # noqa: E402


# ---------------------------------------------------------------- 2. textures + materials
def to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def find_sampler(mat):
    for n in mat.node_tree.nodes:
        if n.bl_idname == "ShaderNodeTexImage" and n.name == "DiffuseSampler":
            return n
    for n in mat.node_tree.nodes:
        if n.bl_idname == "ShaderNodeTexImage":
            return n
    return None


def grid(step, w=256, color="#00000055", width=2, offset_rows=0):
    d = []
    for k in range(0, w + 1, step):
        d.append(f"line {k},0 {k},{w}")
        d.append(f"line 0,{k} {w},{k}")
    return ["-fill", "none", "-stroke", color, "-strokewidth", str(width), "-draw", " ".join(d)]


def bricks(bw=64, bh=24, w=256, color="#d8cfc2aa"):
    d = []
    for row, y in enumerate(range(0, w + bh, bh)):
        d.append(f"line 0,{y} {w},{y}")
        off = (bw // 2) if row % 2 else 0
        for x in range(-bw, w + bw, bw):
            d.append(f"line {x + off},{y} {x + off},{y + bh}")
    return ["-fill", "none", "-stroke", color, "-strokewidth", "2", "-draw", " ".join(d)]


def stripes(step=20, w=256, color="#00000066"):
    d = [f"line 0,{y} {w},{y}" for y in range(0, w, step)]
    return ["-fill", "none", "-stroke", color, "-strokewidth", "3", "-draw", " ".join(d)]


# material key -> (noise strength 0..1, blur, extra drawing, tile size in meters, collision material)
RECIPES = {
    "asphalt":        (0.55, 0.6, [], 4.0, "TARMAC"),
    "road_line":      (0.15, 0.5, [], 2.0, "TARMAC_PAINTED"),
    "pavement":       (0.35, 0.6, grid(64), 2.0, "CONCRETE_PAVEMENT"),
    "curb":           (0.30, 0.6, grid(128, color="#00000040"), 1.0, "CONCRETE_PAVEMENT"),
    "cobble":         (0.30, 0.6, [], 2.0, "COBBLESTONE"),
    "beach_sand":     (0.30, 0.6, [], 2.0, "SAND_LOOSE"),
    "hangar_metal":   (0.30, 0.6, [], 2.0, "METAL_SOLID_MEDIUM"),
    "manhole":        (0.30, 0.6, [], 1.0, "METAL_SOLID_SMALL"),
    "plinth_stone":   (0.30, 0.6, [], 2.0, "STONE"),
    "gravel_path":    (0.80, 0.3, [], 2.0, "GRAVEL_SMALL"),
    "grass":          (0.70, 0.8, [], 3.0, "GRASS"),
    "park_grass":     (0.70, 0.8, [], 3.0, "GRASS"),
    "soil":           (0.70, 0.8, [], 1.0, "SOIL"),
    "river_stone":    (0.60, 1.5, grid(85, color="#00000050", width=3), 2.0, "STONE"),
    "white_stone":    (0.25, 1.0, [], 2.0, "STONE"),
    "drava_water":    (0.35, 4.0, [], 8.0, "STONE"),
    "red_brick":      (0.35, 0.6, bricks(), 2.0, "BRICK"),
    "spire":          (0.30, 0.6, stripes(16), 2.0, "ROOF_TILE"),
    "roof_tiles":     (0.30, 0.6, stripes(20) + bricks(32, 20, color="#00000030"), 2.0, "ROOF_TILE"),
    "plaster_":       (0.20, 1.2, [], 4.0, "CONCRETE"),
    "window_glass":   (0.15, 2.0, grid(128, color="#ffffff30", width=6), 1.6, "GLASS_OPAQUE"),
    "busstop_glass":  (0.10, 2.0, [], 2.0, "GLASS_OPAQUE"),
    "bench_wood":     (0.40, 0.4, stripes(32, color="#00000044"), 1.0, "WOOD_SOLID_MEDIUM"),
    "bridge_steel":   (0.20, 1.0, [], 2.0, "METAL_SOLID_MEDIUM"),
    "lamp_pole":      (0.10, 1.0, [], 2.0, "METAL_SOLID_MEDIUM"),
    "gold":           (0.10, 1.0, [], 1.0, "METAL_SOLID_SMALL"),
    "flowers":        (0.40, 0.5, [], 1.0, "GRASS"),
    "floor_wood":     (0.35, 0.4, stripes(28, color="#00000040") + bricks(256, 28, color="#00000030"), 2.0, "WOOD_SOLID_POLISHED"),
    "door_frame":     (0.30, 0.5, stripes(40, color="#00000040"), 1.0, "WOOD_SOLID_MEDIUM"),
    "canopy":         (0.15, 1.0, [], 2.0, "METAL_SOLID_MEDIUM"),
}
DEFAULT_RECIPE = (0.15, 1.0, [], 2.0, "CONCRETE")


def recipe_for(name):
    for k, r in RECIPES.items():
        if k in name:
            return r
    return DEFAULT_RECIPE


def make_texture(path, hexcol, strength, blur, extra, seed):
    """base colour + grayscale detail noise (Overlay) + pattern, saved as DXT1 DDS with mipmaps"""
    lo, hi = int(50 - strength * 50), int(50 + strength * 50)
    cmd = ["convert", "-size", "256x256", "xc:gray50", "-seed", str(seed), "+noise", "Random",
           "-colorspace", "Gray", "-blur", f"0x{blur}", "-auto-level", "+level", f"{lo}%,{hi}%",
           "(", "-size", "256x256", "xc:" + hexcol, ")", "+swap", "-compose", "Overlay", "-composite"]
    cmd += extra
    cmd += ["-define", "dds:compression=dxt1", path]
    subprocess.run(cmd, check=True)


sys.path.insert(0, HERE)
import osrp_textures  # noqa: E402  (v1.0.13: 1024px seamless textures + normal maps)


def find_node(mat, name):
    for n in mat.node_tree.nodes:
        if n.bl_idname == "ShaderNodeTexImage" and n.name == name:
            return n
    return None


new_mats, mat_tile, mat_col = {}, {}, {}
for seed, mat in enumerate(sorted({m for o in objs for m in o.data.materials if m}, key=lambda m: m.name)):
    r, g, b = (to_srgb(c) for c in mat.diffuse_color[:3])
    rgb = (int(r * 255), int(g * 255), int(b * 255))
    hexcol = "#%02x%02x%02x" % rgb
    tex_name = "osrp_" + mat.name.replace("osrp_", "")[:40]
    strength, blur, extra, tile, colname = recipe_for(mat.name)
    ndds = None
    if "lamp_light" in mat.name:
        dds = os.path.join(TEX, tex_name + ".dds")
        subprocess.run(["convert", "-size", "16x16", "xc:" + hexcol, "-define", "dds:compression=dxt1", dds], check=True)
    else:
        dds, ndds, tile = osrp_textures.build(tex_name, rgb, seed + 7, TEX)
    img = bpy.data.images.load(dds)
    img.name = tex_name
    shader = "emissive.sps" if "lamp_light" in mat.name else ("normal.sps" if ndds else "default.sps")
    sm = create_shader(shader)
    sm.name = "sz_" + mat.name
    node = find_node(sm, "DiffuseSampler") or find_sampler(sm)
    node.image = img
    node.texture_properties.embedded = True
    if ndds:
        bump = find_node(sm, "BumpSampler")
        if bump:
            nimg = bpy.data.images.load(ndds)
            nimg.name = tex_name + "_n"
            nimg.colorspace_settings.name = "Non-Color"
            bump.image = nimg
            bump.texture_properties.embedded = True
    new_mats[mat.name] = sm
    mat_tile[sm.name] = tile
    mat_col[sm.name] = colname


def world_uv(o):
    """planar world-space UVs per face (texture keeps its real size in meters, no stretching)"""
    me = o.data
    if len(me.uv_layers) == 0:
        me.uv_layers.new(name="UVMap 0")
    uv = me.uv_layers[0]
    uv.name = "UVMap 0"
    mw = o.matrix_world
    rot = mw.to_3x3()
    for poly in me.polygons:
        m = me.materials[poly.material_index] if me.materials else None
        tile = mat_tile.get(m.name, 2.0) if m else 2.0
        n = rot @ poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        coords = []
        for li in poly.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            u, v = (co.x, co.y) if ax == 2 else (co.y, co.z) if ax == 0 else (co.x, co.z)
            coords.append((li, u / tile, v / tile))
        # shift each face by whole tiles so UVs stay small (precision) - tiling stays seamless
        su, sv = math.floor(coords[0][1]), math.floor(coords[0][2])
        for li, u, v in coords:
            uv.data[li].uv = (u - su, v - sv)


for o in objs:
    for i, slot in enumerate(o.material_slots):
        if slot.material and slot.material.name in new_mats:
            o.material_slots[i].material = new_mats[slot.material.name]
    world_uv(o)
    me = o.data
    if "Color 1" not in me.color_attributes:
        ca = me.color_attributes.new("Color 1", "BYTE_COLOR", "CORNER")
        for d in ca.data:
            d.color = (1.0, 1.0, 1.0, 1.0)

# ---------------------------------------------------------------- 3. chunks
cells = {}
for o in objs:
    c = sum((o.matrix_world @ v.co for v in o.data.vertices), start=o.location * 0) / max(1, len(o.data.vertices))
    key = (math.floor(c.x / CHUNK), math.floor(c.y / CHUNK))
    cells.setdefault(key, []).append(o)

layout = []
chunk_objs = []
col_index = [i for i, m in enumerate(collisionmats) if m.name == "CONCRETE"][0]

for (cx, cy), members in sorted(cells.items()):
    name = f"osijek_{'m' if cx < 0 else ''}{abs(cx)}_{'m' if cy < 0 else ''}{abs(cy)}"
    bpy.ops.object.select_all(action="DESELECT")
    for o in members:
        o.select_set(True)
    bpy.context.view_layer.objects.active = members[0]
    if len(members) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    # origin at the chunk centre on the ground
    ox, oy = (cx + 0.5) * CHUNK, (cy + 0.5) * CHUNK
    bpy.context.scene.cursor.location = (ox, oy, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    layout.append({"name": name, "x": ox, "y": oy, "z": 0.0})
    chunk_objs.append(obj)

print(f"[OSRP] {len(chunk_objs)} chunks")

# ---------------------------------------------------------------- convert chunks to drawables (+ embedded collision)
bpy.context.scene.auto_create_embedded_col = True
bpy.context.scene.create_seperate_drawables = True
drawables = []
for obj in chunk_objs:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.sollumz.converttodrawable()
    drw = bpy.data.objects[obj.name]
    drawables.append(drw)

col_cache = {}
# v1.0.20: GTA grows real 3D grass / weeds on collision with a procedural ID (ids from Sollumz procids.json)
PROC_IDS = {"park_grass": 148, "grass": 139, "beach_sand": 143}


def proc_for(name):
    for k, v in PROC_IDS.items():
        if k in name:
            return v
    return 0


def collision_mat(colname, procid=0):
    key = (colname, procid)
    if key not in col_cache:
        idx = next((i for i, m in enumerate(collisionmats) if m.name == colname), col_index)
        m = create_collision_material_from_index(idx)
        m.collision_properties.procedural_id = procid
        col_cache[key] = m
    return col_cache[key]


for o in bpy.data.objects:
    if o.type == "MESH" and str(o.sollum_type).startswith("sollumz_bound_poly"):
        for i, slot in enumerate(o.material_slots):
            name = slot.material.name if slot.material else ""
            base = name.split(".")[0]
            o.material_slots[i].material = collision_mat(mat_col.get(base, "CONCRETE"), proc_for(base))

# ---------------------------------------------------------------- 4. ytyp
bpy.ops.sollumz.createytyp()
ytyp = bpy.context.scene.ytyps[bpy.context.scene.ytyp_index]
ytyp.name = "osijek"
bpy.ops.object.select_all(action="DESELECT")
for d in drawables:
    d.select_set(True)
bpy.context.view_layer.objects.active = drawables[0]
bpy.ops.sollumz.createarchetypefromselected()
for a in ytyp.archetypes:
    a.lod_dist = LOD_DIST

# ---------------------------------------------------------------- 5. export
st = get_export_settings()
fmts = {"CWXML"}
try:
    st.target_formats = {"CWXML", "NATIVE"}
    fmts = set(st.target_formats)
except Exception:
    st.target_formats = {"CWXML"}
st.limit_to_selected = False
st.export_ytyps = True
st.export_ytyps_include = "ALL"
try:
    st.target_versions = {"GEN8"}   # FiveM (GTA V Legacy) uses gen8 assets
except Exception as e:
    print("[OSRP] target_versions:", e)
print("[OSRP] export formats:", fmts)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.sollumz.export_assets(directory=OUT + os.sep)

with open(os.path.join(OUT, "osijek_layout.json"), "w") as f:
    json.dump(layout, f, indent=1)


# ---------------------------------------------------------------- 6. one shared texture dictionary (osijek_txd.ytd)
# Every chunk used to embed its own copy of the textures (791 copies). Now all chunks point to one .ytd,
# so the textures can be big (1024 px + normal maps) and the map is still smaller.
def share_txd(out, txd="osijek_txd"):
    import re
    import shutil
    folder = os.path.join(out, txd)
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(TEX):
        if f.endswith(".dds"):
            shutil.copy(os.path.join(TEX, f), folder)
    items = []
    for f in sorted(os.listdir(folder)):
        items.append(
            "  <Item>\n    <Name>%s</Name>\n    <Unk32 value=\"0\" />\n    <Usage>UNKNOWN</Usage>\n"
            "    <ExtraFlags value=\"0\" />\n    <Width value=\"0\" />\n    <Height value=\"0\" />\n"
            "    <MipLevels value=\"0\" />\n    <Format>D3DFMT_DXT1</Format>\n    <FileName>%s</FileName>\n  </Item>" % (f[:-4], f))
    with open(os.path.join(out, txd + ".ytd.xml"), "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="UTF-8"?>\n<TextureDictionary>\n' + "\n".join(items) + "\n</TextureDictionary>\n")
    for f in os.listdir(out):
        p = os.path.join(out, f)
        if f.endswith(".ydr.xml"):
            x = open(p, encoding="utf-8").read()
            x = re.sub(r"\s*<TextureDictionary>.*?</TextureDictionary>", "", x, count=1, flags=re.S)
            open(p, "w", encoding="utf-8").write(x)
            d = p[:-len(".ydr.xml")]
            if os.path.isdir(d):
                shutil.rmtree(d)
        elif f.endswith(".ytyp.xml"):
            x = open(p, encoding="utf-8").read()
            x = re.sub(r"<textureDictionary>[^<]*</textureDictionary>", f"<textureDictionary>{txd}</textureDictionary>", x)
            open(p, "w", encoding="utf-8").write(x)
    print(f"[OSRP] shared texture dictionary {txd}.ytd: {len(items)} textures")


share_txd(OUT)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "osijek_sollumz.blend"))
print(f"[OSRP] DONE -> {OUT}")
