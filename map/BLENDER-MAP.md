# OSRP: making the Osijek map in Blender (free)

Everything here is free: **Blender**, the **Sollumz** add-on and **CodeWalker**.

```
Blender (build Osijek)  ->  Sollumz (GTA formats)  ->  CodeWalker (place in the world)  ->  osrp_core/stream/
```

## 1. Install the tools
| Tool | What it does | Where |
|---|---|---|
| Blender 4.x | modelling the city | blender.org |
| Sollumz | Blender add-on: GTA V models (.ydr), collisions (.ybn), textures | github.com/Skylumz/Sollumz (Releases) |
| CodeWalker | places models in the GTA world (.ytyp + .ymap) | github.com/dexyfex/CodeWalker (Releases) |

Installing Sollumz: Blender → *Edit → Preferences → Add-ons → Install from disk* → pick the Sollumz `.zip` → tick it on.

## 2. Make the starter city
1. Open Blender → **Scripting** tab → *Open* → `map/blender/osijek_starter.py` → **Run Script**.
2. You get the `OSRP_Osijek` collection (about 1,100 objects):
   - the Drava with stone banks, and the promenade with lindens, benches and lamps
   - Europska avenija: 4 lanes, dashed lines, curbs, sidewalks, street lights on both sides (the lamps glow at night)
   - buildings with rows of windows and pitched tile roofs
   - Tvrđa square with the cathedral, a city park with paths, the pedestrian bridge with cables
3. Now build it out: replace the boxes with real buildings, add details, and so on. **1 unit = 1 meter.**

> Tip: keep each piece **under ~300 m**. Big pieces load badly in GTA. Split the city into sections, for example `osijek_centar`, `osijek_tvrdja`, `osijek_drava`.

## 3. Convert with Sollumz
For each section:
1. **Model (.ydr):** select the meshes → Sollumz panel (N key) → *Convert to Drawable*. Convert the materials to Sollumz shaders (`default.sps` is fine for buildings, roads and grass).
2. **Collision (.ybn):** without collision, players fall through the map. Duplicate the ground, roads and buildings → Sollumz → *Convert to Composite* (Bound). Keep collision simple, using boxes and flat planes.
3. **Textures (.ytd):** the textures you use get packed into a `.ytd` (Sollumz does this on export).
4. **Export:** *File → Export → Sollumz*. If your version exports XML (`.ydr.xml`), convert it to `.ydr` in CodeWalker (*RPF Explorer → Import XML*).

Name files in lowercase with no spaces, e.g. `osijek_centar.ydr`, `osijek_centar_col.ybn`, `osijek_centar.ytd`.

## 4. Put it in the world with CodeWalker
1. CodeWalker → *Tools → Project Window → New Project*.
2. **New YTYP** (`osijek.ytyp`): add an *Archetype* for each `.ydr`. Set *LOD dist* to 300–500 and *Texture dictionary* to your `.ytd`.
3. **New YMAP** (`osijek.ymap`): add an *Entity* for each archetype at its position.
   - Put Osijek **in open sea, away from Los Santos**, and lift it about **20 m above sea level** so the GTA ocean doesn't flood it.
4. *Save* everything.

## 5. Into the server
Copy everything into `fivem-resources/osrp_core/stream/`:
```
osrp_core/stream/
  osijek.ytyp
  osijek.ymap
  osijek_centar.ydr
  osijek_centar.ytd
  osijek_centar_col.ybn
  ...
```
In `osrp_core/fxmanifest.lua`, uncomment this line:
```lua
data_file 'DLC_ITYP_REQUEST' 'stream/osijek.ytyp'
```
Restart the server (`ensure osrp_core`). Set your spawn point on the new Osijek map.

## Common problems
- **Falling through the map:** the `.ybn` collision is missing, or isn't in `stream/`.
- **Map is invisible:** the YTYP archetype name has to match the `.ydr` file name exactly, and *LOD dist* can't be 0.
- **Pink/missing textures:** the `.ytd` name has to match the *Texture dictionary* in the YTYP.
