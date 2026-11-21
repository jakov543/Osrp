"""
OSRP - convert the Blender Osijek map into GTA V / FiveM assets with Sollumz.

Run headless (Linux/Windows) with Blender's Python + the Sollumz add-on enabled:
    blender -b -P osijek_export_gta.py -- <output_dir>

What it does:
  1. builds the city with osijek_starter.py
  2. turns every colour into a small embedded DDS texture + Sollumz shader (default.sps / emissive.sps for lamps)
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
LOD_DIST = 600.0
os.makedirs(TEX, exist_ok=True)

# ---------------------------------------------------------------- 1. city
runpy.run_path(os.path.join(HERE, "osijek_starter.py"))
col = bpy.data.collections["OSRP_Osijek"]
objs = [o for o in col.objects if o.type == "MESH"]
print(f"[OSRP] {len(objs)} meshes built")

from sollumz.ydr.shader_materials import create_shader  # noqa: E402
from sollumz.ybn.collision_materials import create_collision_material_from_index, collisionmats  # noqa: E402
from sollumz.sollumz_preferences import get_export_settings  # noqa: E402


# ---------------------------------------------------------------- 2. materials -> sollumz shaders + DDS
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


new_mats = {}
for mat in {m for o in objs for m in o.data.materials if m}:
    r, g, b = (to_srgb(c) for c in mat.diffuse_color[:3])
    tex_name = "osrp_" + mat.name.replace("osrp_", "")[:40]
    dds = os.path.join(TEX, tex_name + ".dds")
    hexcol = "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))
    subprocess.run(["convert", "-size", "16x16", "xc:" + hexcol, "-define", "dds:compression=dxt1",
                    "-define", "dds:mipmaps=0", dds], check=True)
    img = bpy.data.images.load(dds)
    img.name = tex_name
    shader = "emissive.sps" if "lamp_light" in mat.name else "default.sps"
    sm = create_shader(shader)
    sm.name = "sz_" + mat.name
    node = find_sampler(sm)
    node.image = img
    node.texture_properties.embedded = True
    new_mats[mat.name] = sm

for o in objs:
    for i, slot in enumerate(o.material_slots):
        if slot.material and slot.material.name in new_mats:
            o.material_slots[i].material = new_mats[slot.material.name]
    me = o.data
    if len(me.uv_layers) == 0:
        me.uv_layers.new(name="UVMap 0")
    me.uv_layers[0].name = "UVMap 0"
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

colmat = create_collision_material_from_index(col_index)
for o in bpy.data.objects:
    if o.type == "MESH" and str(o.sollum_type).startswith("sollumz_bound_poly"):
        o.data.materials.clear()
        o.data.materials.append(colmat)

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
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "osijek_sollumz.blend"))
print(f"[OSRP] DONE -> {OUT}")
