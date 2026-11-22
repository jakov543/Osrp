"""
OSRP - custom props made in Blender (v1.0.22). Each prop is its own GTA model (own .ydr + archetype in osijek.ytyp),
placed in-game by osrp_osijek (Life.CUSTOMPROPS). Built at the world origin: base centre = (0, 0, 0), front = +Y.

build_props(h) is called from osijek_starter.py with its helpers (box, cylinder, blob, material ...).
"""
import math


def build_props(h):
    bpy = h["bpy"]
    box, cylinder, blob, material, _mesh_obj = h["box"], h["cylinder"], h["blob"], h["material"], h["_mesh_obj"]
    pcol = bpy.data.collections.new("OSRP_Props")
    bpy.context.scene.collection.children.link(pcol)
    M = {
        "steel": h["M_STEEL"], "pole": h["M_POLE"], "glass": h["M_CLEAR"], "mirror": h["M_GLASS"], "white": material("osrp_ceramic_white", (0.86, 0.87, 0.87)),
        "black": material("osrp_screen_black", (0.02, 0.02, 0.025), rough=0.1),
        "blue": material("osrp_fabric_seat_blue", (0.10, 0.22, 0.42)), "teal": material("osrp_fabric_teal", (0.05, 0.40, 0.38)),
        "mattress": material("osrp_fabric_bedding", (0.75, 0.77, 0.80)), "curtain": material("osrp_fabric_curtain", (0.45, 0.62, 0.70)),
        "red": h["M_RED"], "wood": h["M_WOOD"], "yellow": material("osrp_paint_yellow", (0.85, 0.62, 0.05)),
        "rubber": material("osrp_screen_rubber", (0.04, 0.04, 0.04)), "white": material("osrp_paint_white", (0.9, 0.9, 0.9)), "blue": material("osrp_paint_blue", (0.05, 0.2, 0.6)), "case1": material("osrp_fabric_case_red", (0.45, 0.06, 0.05)),
        "case2": material("osrp_fabric_case_navy", (0.06, 0.09, 0.22)), "green": h["M_LEAVES"][0],
        "sign_blue": h["M_SIGN_BLUE"], "sign": h["M_SIGN"], "sign_y": material("osrp_lamp_light_amber", (1.0, 0.7, 0.1), emit=6.0),
        "umb1": material("osrp_fabric_umbrella_red", (0.62, 0.08, 0.06)), "umb2": material("osrp_fabric_umbrella_white", (0.85, 0.85, 0.82)),
        "sand": h["M_SAND"], "netting": material("osrp_fabric_net", (0.85, 0.85, 0.85)), "thatch": material("osrp_wood_thatch", (0.45, 0.33, 0.16)),
    }
    names = []

    def B(prop, part, loc, size, m):
        o = box(pcol, f"osrpprop_{prop}__{part}", loc, size, M[m])
        return o

    def C(prop, part, loc, r, hgt, m, verts=12):
        return cylinder(pcol, f"osrpprop_{prop}__{part}", loc, r, hgt, M[m], verts=verts)

    def cone(prop, part, loc, r, hgt, m, verts=16, a0=0.0):
        x, y, z = loc
        vs = [(x + math.cos(a) * r, y + math.sin(a) * r, z) for a in (a0 + i * 2 * math.pi / verts for i in range(verts))] + [(x, y, z + hgt)]
        fs = [(i, (i + 1) % verts, verts) for i in range(verts)] + [tuple(range(verts - 1, -1, -1))]
        return _mesh_obj(pcol, f"osrpprop_{prop}__{part}", vs, fs, M[m])

    # ---------------- doors / hospital
    p = "slidedoor"; names.append(p)            # 1.3 x 2.6 glass panel in a steel frame
    B(p, "staklo", (0, 0, 0.05), (1.24, 0.03, 2.5), "glass")
    for x in (-0.63, 0.63):
        B(p, f"okvir_{x}", (x, 0, 0), (0.05, 0.06, 2.6), "steel")
    for z in (0.0, 2.55):
        B(p, f"okvir_h_{z}", (0, 0, z), (1.3, 0.06, 0.05), "steel")
    B(p, "rucka", (0.5, 0.05, 1.0), (0.03, 0.03, 0.4), "steel")

    p = "slidedoor_w"; names.append(p)          # 2.5 x 3.0 wide glass panel (hospital lobby, terminal)
    B(p, "staklo", (0, 0, 0.05), (2.44, 0.03, 2.9), "glass")
    for x in (-1.23, 1.23):
        B(p, f"okvir_{x}", (x, 0, 0), (0.05, 0.06, 3.0), "steel")
    for z in (0.0, 2.95):
        B(p, f"okvir_h_{z}", (0, 0, z), (2.5, 0.06, 0.05), "steel")
    B(p, "traka", (0, 0.02, 1.05), (2.4, 0.01, 0.08), "sign_blue")

    p = "hbed"; names.append(p)                 # hospital bed, head at -Y
    B(p, "okvir", (0, 0, 0.45), (0.95, 2.05, 0.12), "steel")
    B(p, "madrac", (0, 0.05, 0.57), (0.88, 1.9, 0.14), "mattress")
    B(p, "jastuk", (0, -0.75, 0.71), (0.6, 0.35, 0.1), "white")
    B(p, "uzglavlje", (0, -1.0, 0.3), (0.95, 0.05, 0.75), "white")
    B(p, "podnozje", (0, 1.0, 0.3), (0.95, 0.05, 0.55), "white")
    for sx in (-0.48, 0.48):
        B(p, f"ograda_{sx}", (sx, -0.2, 0.75), (0.03, 1.0, 0.18), "steel")
    for sx in (-0.4, 0.4):
        for sy in (-0.9, 0.9):
            B(p, f"noga_{sx}_{sy}", (sx, sy, 0.1), (0.05, 0.05, 0.35), "steel")
            C(p, f"kotac_{sx}_{sy}", (sx, sy, 0.0), 0.06, 0.1, "rubber", 8)
    C(p, "infuzija", (0.6, -0.9, 0.0), 0.02, 1.9, "steel", 6)
    B(p, "vrecica", (0.6, -0.9, 1.65), (0.12, 0.04, 0.2), "glass")

    p = "curtain"; names.append(p)              # 3 m curtain divider
    for x in (-1.5, 1.5):
        C(p, f"stup_{x}", (x, 0, 0), 0.02, 2.2, "steel", 6)
    B(p, "sipka", (0, 0, 2.15), (3.0, 0.03, 0.03), "steel")
    B(p, "zavjesa", (0, 0, 0.25), (2.9, 0.02, 1.85), "curtain")

    p = "wchairs"; names.append(p)              # 3 waiting chairs on a beam, people look to +Y
    B(p, "greda", (0, 0, 0.3), (2.0, 0.08, 0.06), "steel")
    for x in (-0.68, 0, 0.68):
        B(p, f"sjedalo_{x}", (x, 0.05, 0.42), (0.55, 0.5, 0.06), "blue")
        B(p, f"nasl_{x}", (x, -0.2, 0.5), (0.55, 0.06, 0.5), "blue")
    for x in (-0.9, 0.9):
        B(p, f"noga_{x}", (x, 0, 0), (0.06, 0.45, 0.32), "steel")

    p = "medcab"; names.append(p)               # medical cabinet with a red cross
    B(p, "tijelo", (0, 0, 0), (1.0, 0.45, 1.9), "white")
    B(p, "linija", (0, 0.226, 0.1), (0.02, 0.01, 1.7), "steel")
    B(p, "kriz_v", (0, 0.228, 1.35), (0.1, 0.01, 0.35), "red")
    B(p, "kriz_h", (0, 0.228, 1.475), (0.35, 0.01, 0.1), "red")

    # ---------------- airport
    p = "bagcart"; names.append(p)              # luggage trolley with two suitcases
    B(p, "baza", (0, 0, 0.2), (0.6, 1.0, 0.05), "steel")
    B(p, "rucka", (0, -0.5, 0.25), (0.6, 0.04, 0.85), "steel")
    for sx in (-0.25, 0.25):
        for sy in (-0.4, 0.4):
            C(p, f"kotac_{sx}_{sy}", (sx, sy, 0.0), 0.08, 0.2, "rubber", 8)
    B(p, "kofer1", (0, 0.1, 0.25), (0.45, 0.7, 0.28), "case1")
    B(p, "kofer2", (0, 0.05, 0.53), (0.38, 0.55, 0.22), "case2")

    p = "checkin"; names.append(p)              # self check-in kiosk
    B(p, "tijelo", (0, 0, 0), (0.6, 0.45, 1.25), "white")
    B(p, "ekran", (0, 0.2, 1.0), (0.48, 0.06, 0.38), "black")
    B(p, "svjetlo", (0, 0, 1.25), (0.6, 0.45, 0.22), "sign_blue")

    p = "gateseats"; names.append(p)            # 5 airport seats on a beam
    B(p, "greda", (0, 0, 0.32), (3.4, 0.1, 0.06), "steel")
    for k in range(5):
        x = -1.36 + k * 0.68
        B(p, f"sjedalo_{k}", (x, 0.04, 0.42), (0.56, 0.5, 0.06), "teal")
        B(p, f"nasl_{k}", (x, -0.22, 0.48), (0.56, 0.06, 0.55), "teal")
    for x in (-1.5, 1.5):
        B(p, f"noga_{x}", (x, 0, 0), (0.06, 0.5, 0.34), "steel")

    p = "infoboard"; names.append(p)            # departures board on a post
    B(p, "stup", (0, 0, 0), (0.15, 0.15, 2.0), "steel")
    B(p, "ekran", (0, 0, 2.0), (2.4, 0.15, 1.3), "black")
    for k in range(6):
        B(p, f"red_{k}", (0, 0.08, 2.15 + k * 0.17), (2.1, 0.01, 0.06), "sign_y")

    p = "carousel"; names.append(p)             # baggage carousel 8 x 2.6 m
    B(p, "tijelo", (0, 0, 0), (5.4, 2.6, 0.5), "steel")
    for x in (-2.7, 2.7):
        C(p, f"kraj_{x}", (x, 0, 0), 1.3, 0.5, "steel", 16)
        C(p, f"traka_kraj_{x}", (x, 0, 0.5), 1.25, 0.04, "rubber", 16)
    B(p, "traka", (0, 0, 0.5), (5.4, 2.5, 0.04), "rubber")
    B(p, "sredina", (0, 0, 0.5), (5.0, 0.8, 0.3), "steel")
    B(p, "kofer1", (-1.5, 0.9, 0.54), (0.45, 0.7, 0.28), "case1")
    B(p, "kofer2", (1.2, -0.9, 0.54), (0.4, 0.6, 0.25), "case2")

    p = "planter"; names.append(p)              # planter with a shrub
    B(p, "posuda", (0, 0, 0), (1.2, 1.2, 0.6), "white")
    B(p, "zemlja", (0, 0, 0.6), (1.1, 1.1, 0.02), "wood")
    blob(pcol, "osrpprop_planter__grm", (0, 0, 1.1), 0.75, M["green"], squash=0.8)

    p = "tug"; names.append(p)                  # airport tug (baggage tractor)
    B(p, "sasija", (0, 0, 0.3), (1.5, 2.8, 0.55), "yellow")
    B(p, "kabina", (0, -0.6, 0.85), (1.4, 1.1, 1.0), "yellow")
    B(p, "staklo", (0, -0.04, 1.05), (1.3, 0.04, 0.6), "glass")
    for sx in (-0.75, 0.75):
        for sy in (-0.9, 0.9):
            C(p, f"kotac_{sx}_{sy}", (sx, sy, 0.0), 0.32, 0.3, "rubber", 10)
    B(p, "svjetlo", (0, -0.6, 1.85), (0.25, 0.25, 0.12), "sign_y")

    # ---------------- beach
    p = "lounger"; names.append(p)              # sun lounger, head at -Y
    B(p, "okvir", (0, 0, 0.3), (0.65, 1.9, 0.06), "pole")
    for sy in (-0.85, 0.85):
        B(p, f"noga_{sy}", (0, sy, 0), (0.62, 0.05, 0.3), "pole")
    for k in range(6):
        B(p, f"letva_{k}", (0, 0.1 + k * 0.15, 0.36), (0.62, 0.1, 0.03), "wood")
    for k in range(4):                          # raised back rest
        B(p, f"nasl_{k}", (0, -0.35 - k * 0.14, 0.4 + k * 0.1), (0.62, 0.12, 0.04), "wood")
    B(p, "rucnik", (0, 0.35, 0.39), (0.5, 1.0, 0.01), "umb1")

    p = "umbrella"; names.append(p)
    C(p, "stup", (0, 0, 0), 0.03, 2.45, "pole", 6)
    cone(p, "krov", (0, 0, 2.05), 1.7, 0.55, "umb1", 16)
    cone(p, "krov_rub", (0, 0, 2.02), 1.72, 0.06, "umb2", 16)

    p = "lifeguard"; names.append(p)            # lifeguard chair tower
    for sx in (-0.7, 0.7):
        for sy in (-0.7, 0.7):
            B(p, f"noga_{sx}_{sy}", (sx, sy, 0), (0.12, 0.12, 2.2), "wood")
    B(p, "platforma", (0, 0, 2.2), (1.8, 1.8, 0.1), "wood")
    B(p, "sjedalo", (0, -0.2, 2.3), (0.9, 0.7, 0.45), "red")
    B(p, "nasl", (0, -0.55, 2.3), (0.9, 0.08, 1.1), "red")
    for k in range(6):                          # ladder
        B(p, f"stepenica_{k}", (0, 1.05 + k * 0.0, 0.3 + k * 0.33), (0.6, 0.06, 0.04), "wood")
    B(p, "ljestve_l", (-0.32, 1.05, 0), (0.05, 0.06, 2.2), "wood")
    B(p, "ljestve_d", (0.32, 1.05, 0), (0.05, 0.06, 2.2), "wood")
    C(p, "kisobran_stup", (0.6, -0.6, 2.3), 0.03, 1.6, "pole", 6)
    cone(p, "kisobran", (0.6, -0.6, 3.6), 1.1, 0.35, "umb2", 12)
    B(p, "plutaca", (0.0, 0.92, 1.5), (0.5, 0.06, 0.5), "red")

    p = "vnet"; names.append(p)                 # beach volleyball net 9 m
    for x in (-4.7, 4.7):
        C(p, f"stup_{x}", (x, 0, 0), 0.06, 2.6, "pole", 8)
    B(p, "mreza", (0, 0, 1.55), (9.3, 0.02, 0.9), "netting")
    B(p, "traka", (0, 0, 2.43), (9.3, 0.03, 0.07), "umb2")

    p = "shower"; names.append(p)               # beach shower
    B(p, "baza", (0, 0, 0), (1.0, 1.0, 0.08), "wood")
    C(p, "stup", (0, -0.3, 0.08), 0.05, 2.3, "steel", 8)
    B(p, "ruka", (0, -0.05, 2.3), (0.06, 0.55, 0.06), "steel")
    C(p, "glava", (0, 0.2, 2.2), 0.12, 0.08, "steel", 10)

    p = "beachbar"; names.append(p)             # wooden beach bar with a thatched roof
    B(p, "pult", (0, 1.2, 0), (4.0, 0.6, 1.1), "wood")
    B(p, "ploca", (0, 1.25, 1.1), (4.2, 0.75, 0.06), "thatch")
    B(p, "zadnji", (0, -1.3, 0), (4.0, 0.2, 2.5), "wood")
    B(p, "polica", (0, -1.1, 1.3), (3.6, 0.3, 0.05), "wood")
    for k in range(8):
        B(p, f"boca_{k}", (-1.6 + k * 0.45, -1.1, 1.35), (0.08, 0.08, 0.3), "glass")
    for x in (-1.95, 1.95):
        for y in (-1.3, 1.45):
            B(p, f"stup_{x}_{y}", (x, y, 0), (0.15, 0.15, 2.7), "wood")
    cone(p, "krov", (0, 0, 2.7), 3.3, 1.2, "thatch", 4, math.pi / 4)
    B(p, "natpis", (0, 1.6, 2.35), (2.0, 0.05, 0.35), "sign_y")
    for x in (-1.2, 0, 1.2):
        C(p, f"stolac_{x}", (x, 1.9, 0), 0.18, 0.75, "wood", 10)

    # ---------------- v1.0.22: furniture for the flats (made here instead of GTA props). front = +Y
    M.update({
        "sofa": material("osrp_fabric_sofa", (0.20, 0.22, 0.26)), "cushion": material("osrp_fabric_cushion", (0.55, 0.42, 0.28)),
        "oak": h["M_FLOOR"], "dark": h["M_DOORFRAME"], "rug": material("osrp_fabric_rug", (0.42, 0.30, 0.22)),
        "kitchen": material("osrp_ceramic_kitchen", (0.80, 0.80, 0.78)), "worktop": material("osrp_white_stone_worktop", (0.25, 0.24, 0.23)),
        "lampshade": material("osrp_lamp_light_shade", (1.0, 0.86, 0.62), emit=4.0), "art": material("osrp_fabric_art", (0.18, 0.35, 0.55)),
        "towel": material("osrp_fabric_towel", (0.85, 0.85, 0.80)), "blanket": material("osrp_fabric_blanket", (0.30, 0.38, 0.48)),
        "pot": material("osrp_ceramic_pot", (0.55, 0.30, 0.20)), "books": material("osrp_fabric_books", (0.50, 0.15, 0.12)),
    })

    def H(kind):
        names.append("h_" + kind)
        return "h_" + kind

    p = H("sofa")                               # 2.1 m three-seater, seat 0.45
    B(p, "baza", (0, 0, 0.08), (2.1, 0.9, 0.35), "sofa")
    B(p, "naslon", (0, -0.35, 0.08), (2.1, 0.2, 0.85), "sofa")
    for x in (-0.97, 0.97):
        B(p, f"rukohvat_{x}", (x, 0, 0.08), (0.16, 0.9, 0.6), "sofa")
    for x in (-0.6, 0, 0.6):
        B(p, f"jastuk_{x}", (x, 0.08, 0.43), (0.58, 0.62, 0.1), "sofa")
    B(p, "ukrasni", (-0.65, -0.2, 0.53), (0.4, 0.12, 0.35), "cushion")
    for x in (-0.95, 0.95):
        for y in (-0.38, 0.38):
            B(p, f"noga_{x}_{y}", (x, y, 0), (0.06, 0.06, 0.08), "dark")

    p = H("fotelja")
    B(p, "baza", (0, 0, 0.08), (0.85, 0.85, 0.35), "sofa")
    B(p, "naslon", (0, -0.33, 0.08), (0.85, 0.2, 0.85), "sofa")
    for x in (-0.36, 0.36):
        B(p, f"rukohvat_{x}", (x, 0, 0.08), (0.14, 0.85, 0.6), "sofa")
    B(p, "jastuk", (0, 0.06, 0.43), (0.58, 0.6, 0.1), "cushion")

    p = H("stolic")                             # coffee table
    B(p, "ploca", (0, 0, 0.38), (1.1, 0.6, 0.05), "oak")
    B(p, "polica", (0, 0, 0.1), (1.0, 0.5, 0.03), "oak")
    for x in (-0.5, 0.5):
        for y in (-0.25, 0.25):
            B(p, f"noga_{x}_{y}", (x, y, 0), (0.05, 0.05, 0.38), "dark")
    B(p, "knjiga", (0.2, 0.05, 0.43), (0.25, 0.18, 0.04), "books")

    p = H("tepih")
    B(p, "tepih", (0, 0, 0.0), (2.4, 1.7, 0.012), "rug")
    B(p, "rub", (0, 0, 0.0), (2.5, 1.8, 0.008), "cushion")

    p = H("tvstol")                             # TV unit
    B(p, "tijelo", (0, 0, 0.05), (1.8, 0.45, 0.5), "dark")
    for x in (-0.6, 0, 0.6):
        B(p, f"ladica_{x}", (x, 0.226, 0.12), (0.56, 0.01, 0.36), "oak")
    B(p, "postolje", (0, 0, 0), (1.7, 0.4, 0.05), "black")

    p = H("tv")                                 # flat TV on a foot (put on the TV unit)
    B(p, "noga", (0, 0, 0), (0.35, 0.22, 0.03), "black")
    B(p, "vrat", (0, 0, 0.03), (0.06, 0.05, 0.1), "black")
    B(p, "ekran", (0, 0, 0.12), (1.25, 0.05, 0.72), "black")
    B(p, "slika", (0, 0.027, 0.16), (1.17, 0.005, 0.64), "sign_blue")

    p = H("polica")                             # book shelf
    for x in (-0.45, 0.45):
        B(p, f"bok_{x}", (x, 0, 0), (0.03, 0.35, 1.9), "oak")
    for k in range(5):
        B(p, f"polica_{k}", (0, 0, 0.02 + k * 0.45), (0.9, 0.35, 0.03), "oak")
        if k < 4:
            B(p, f"knjige_{k}", (-0.1 + (k % 2) * 0.15, 0.02, 0.05 + k * 0.45), (0.55, 0.25, 0.3), "books" if k % 2 else "art")
    B(p, "ledja", (0, -0.17, 0), (0.9, 0.01, 1.9), "dark")

    p = H("slika")                              # picture on the wall (origin = wall, picture on +Y)
    B(p, "okvir", (0, 0.015, -0.4), (1.0, 0.03, 0.8), "dark")
    B(p, "platno", (0, 0.031, -0.35), (0.9, 0.005, 0.7), "art")

    p = H("lampa")                              # floor lamp
    C(p, "baza", (0, 0, 0), 0.18, 0.03, "black", 12)
    C(p, "stup", (0, 0, 0.03), 0.015, 1.45, "steel", 6)
    C(p, "sjenilo", (0, 0, 1.45), 0.22, 0.3, "lampshade", 12)

    p = H("stolna_lampa")                       # table lamp
    C(p, "baza", (0, 0, 0), 0.08, 0.2, "pot", 10)
    C(p, "sjenilo", (0, 0, 0.2), 0.14, 0.18, "lampshade", 10)

    p = H("biljka")                             # pot plant
    C(p, "posuda", (0, 0, 0), 0.2, 0.42, "pot", 12)
    C(p, "zemlja", (0, 0, 0.42), 0.19, 0.01, "dark", 12)
    blob(pcol, "osrpprop_h_biljka__lisce", (0, 0, 0.9), 0.38, M["green"], squash=1.4)

    p = H("stol")                               # dining table 1.4 x 0.85
    B(p, "ploca", (0, 0, 0.72), (1.4, 0.85, 0.05), "oak")
    for x in (-0.62, 0.62):
        for y in (-0.36, 0.36):
            B(p, f"noga_{x}_{y}", (x, y, 0), (0.06, 0.06, 0.72), "dark")

    p = H("stolica")                            # chair, seat 0.46
    B(p, "sjedalo", (0, 0, 0.42), (0.45, 0.45, 0.05), "oak")
    B(p, "jastuk", (0, 0.01, 0.47), (0.4, 0.4, 0.03), "cushion")
    B(p, "naslon", (0, -0.2, 0.47), (0.45, 0.04, 0.5), "oak")
    for x in (-0.19, 0.19):
        for y in (-0.19, 0.19):
            B(p, f"noga_{x}_{y}", (x, y, 0), (0.04, 0.04, 0.42), "dark")

    p = H("hladnjak")                           # fridge
    B(p, "tijelo", (0, 0, 0), (0.7, 0.68, 1.85), "kitchen")
    B(p, "linija", (0, 0.341, 1.15), (0.68, 0.01, 0.02), "steel")
    B(p, "rucka1", (0.28, 0.36, 1.3), (0.03, 0.03, 0.4), "steel")
    B(p, "rucka2", (0.28, 0.36, 0.7), (0.03, 0.03, 0.3), "steel")

    p = H("stednjak")                           # cooker with oven
    B(p, "tijelo", (0, 0, 0), (0.9, 0.62, 0.88), "kitchen")
    B(p, "ploca", (0, 0, 0.88), (0.9, 0.62, 0.04), "black")
    for x in (-0.2, 0.2):
        for y in (-0.13, 0.13):
            C(p, f"ringla_{x}_{y}", (x, y, 0.92), 0.09, 0.006, "steel", 10)
    B(p, "pecnica", (0, 0.31, 0.15), (0.7, 0.01, 0.5), "black")
    B(p, "rucka", (0, 0.33, 0.7), (0.6, 0.03, 0.03), "steel")

    p = H("sudoper")                            # sink unit
    B(p, "tijelo", (0, 0, 0), (0.9, 0.62, 0.88), "kitchen")
    B(p, "ploca", (0, 0, 0.88), (0.92, 0.64, 0.04), "worktop")
    B(p, "korito", (0, 0.02, 0.86), (0.5, 0.38, 0.065), "steel")
    C(p, "slavina", (0, -0.24, 0.92), 0.02, 0.3, "steel", 6)
    B(p, "slavina_v", (0, -0.16, 1.2), (0.03, 0.18, 0.03), "steel")

    p = H("ormaric")                            # kitchen cabinet with wall unit
    B(p, "tijelo", (0, 0, 0), (0.9, 0.62, 0.88), "kitchen")
    B(p, "ploca", (0, 0, 0.88), (0.92, 0.64, 0.04), "worktop")
    B(p, "gornji", (0, -0.14, 1.5), (0.9, 0.35, 0.7), "kitchen")
    for x in (-0.22, 0.22):
        B(p, f"rucka_{x}", (x, 0.32, 0.7), (0.12, 0.02, 0.02), "steel")

    p = H("kuh_stol")                           # small kitchen table
    B(p, "ploca", (0, 0, 0.74), (1.0, 0.7, 0.04), "worktop")
    C(p, "stup", (0, 0, 0.03), 0.05, 0.71, "steel", 8)
    C(p, "baza", (0, 0, 0), 0.3, 0.03, "steel", 12)

    p = H("stolac")                             # bar stool, seat 0.7
    C(p, "sjedalo", (0, 0, 0.68), 0.19, 0.06, "sofa", 12)
    C(p, "stup", (0, 0, 0.03), 0.03, 0.65, "steel", 6)
    C(p, "baza", (0, 0, 0), 0.2, 0.03, "steel", 12)

    p = H("wc")                                 # toilet, sits on +Y side
    B(p, "baza", (0, 0.05, 0), (0.38, 0.5, 0.4), "white")
    B(p, "daska", (0, 0.08, 0.4), (0.4, 0.48, 0.03), "white")
    B(p, "spremnik", (0, -0.22, 0.4), (0.42, 0.18, 0.4), "white")

    p = H("umivaonik")                          # wash basin with mirror
    B(p, "ormaric", (0, 0, 0), (0.7, 0.45, 0.8), "white")
    B(p, "umivaonik", (0, 0.02, 0.8), (0.65, 0.45, 0.1), "white")
    C(p, "slavina", (0, -0.16, 0.9), 0.02, 0.16, "steel", 6)
    B(p, "ogledalo", (0, -0.215, 1.15), (0.6, 0.02, 0.75), "mirror")

    p = H("kada")                               # bath tub 1.7 x 0.75 (long side along x)
    B(p, "rub_l", (0, -0.34, 0), (1.7, 0.07, 0.58), "white")
    B(p, "rub_d", (0, 0.34, 0), (1.7, 0.07, 0.58), "white")
    for x in (-0.815, 0.815):
        B(p, f"kraj_{x}", (x, 0, 0), (0.07, 0.75, 0.58), "white")
    B(p, "dno", (0, 0, 0), (1.6, 0.62, 0.15), "white")
    B(p, "voda", (0, 0, 0.15), (1.58, 0.6, 0.25), "glass")
    C(p, "slavina", (-0.78, -0.3, 0.58), 0.02, 0.2, "steel", 6)

    p = H("rucnik")                             # towel rail
    for x in (-0.3, 0.3):
        B(p, f"nosac_{x}", (x, 0, 0), (0.03, 0.08, 1.2), "steel")
    B(p, "rucnik", (0, 0.03, 0.55), (0.55, 0.04, 0.6), "towel")

    p = H("krevet_d")                           # double bed 1.6 x 2.1, head at -Y
    B(p, "okvir", (0, 0, 0.1), (1.7, 2.1, 0.28), "dark")
    B(p, "madrac", (0, 0.03, 0.38), (1.6, 2.0, 0.2), "mattress")
    B(p, "deka", (0, 0.35, 0.58), (1.64, 1.35, 0.04), "blanket")
    for x in (-0.4, 0.4):
        B(p, f"jastuk_{x}", (x, -0.75, 0.58), (0.65, 0.4, 0.13), "white")
    B(p, "uzglavlje", (0, -1.07, 0), (1.75, 0.08, 1.1), "dark")
    for x in (-0.8, 0.8):
        for y in (-1.0, 1.0):
            B(p, f"noga_{x}_{y}", (x, y, 0), (0.07, 0.07, 0.1), "dark")

    p = H("nocni")                              # night stand
    B(p, "tijelo", (0, 0, 0.05), (0.48, 0.4, 0.5), "oak")
    B(p, "ladica", (0, 0.201, 0.3), (0.42, 0.01, 0.16), "dark")
    B(p, "postolje", (0, 0, 0), (0.44, 0.36, 0.05), "dark")

    p = H("ormar")                              # wardrobe 1.2 x 0.6 x 2.1
    B(p, "tijelo", (0, 0, 0), (1.2, 0.6, 2.1), "oak")
    B(p, "procjep", (0, 0.301, 0.05), (0.01, 0.01, 2.0), "dark")
    for x in (-0.06, 0.06):
        B(p, f"rucka_{x}", (x, 0.31, 1.0), (0.02, 0.02, 0.3), "steel")

    p = H("komoda")                             # chest of drawers
    B(p, "tijelo", (0, 0, 0), (1.0, 0.5, 0.85), "oak")
    for k in range(3):
        B(p, f"ladica_{k}", (0, 0.251, 0.07 + k * 0.26), (0.92, 0.01, 0.22), "dark")
    B(p, "ogledalo", (0, -0.22, 0.85), (0.7, 0.03, 0.8), "mirror")

    # ---------------- v1.0.24 under the water: sunken boats + river weed (front = +Y, base = river bed)
    M.update({"rust": material("osrp_metal_rust_wreck", (0.26, 0.12, 0.06), rough=0.9),
              "rust2": material("osrp_metal_rust_dark", (0.14, 0.09, 0.06), rough=0.95),
              "oldwood": material("osrp_wood_wreck", (0.20, 0.15, 0.10)),
              "weed": material("osrp_leaves_riverweed", (0.10, 0.22, 0.08))})

    def hull(prop, part, length, beam, depth, roll, sink, m, segs=10, broken=0.0):
        """V-shaped open hull along Y, rolled by `roll` degrees and sunk `sink` m into the bed; `broken` cuts the bow off"""
        cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))

        def R(x, y, z):
            return (x * cr - z * sr, y, x * sr + z * cr - sink)
        vs, fs = [], []
        ys = [-length / 2 + i * (length * (1 - broken)) / segs for i in range(segs + 1)]
        for y in ys:
            t = (y + length / 2) / length                      # 0 stern .. 1 bow
            w = beam / 2 * (1 - max(0, t - 0.7) / 0.3 * 0.9) if t > 0.7 else beam / 2
            kz = depth * 0.15 * max(0, t - 0.75) / 0.25        # bow keel rises
            for (x, z) in ((-w, depth), (-w * 0.9, depth * 0.35), (0, kz), (w * 0.9, depth * 0.35), (w, depth)):
                vs.append(R(x, y, z))
        n = 5
        for i in range(segs):
            for j in range(n - 1):
                a, b = i * n + j, i * n + j + 1
                fs.append((a, b, b + n, a + n))
                fs.append((a + n, b + n, b, a))            # both sides visible (open, broken hull)
        fs.append((0, 1, 2, 3, 4)); fs.append((4, 3, 2, 1, 0))        # stern plate
        return _mesh_obj(pcol, f"osrpprop_{prop}__{part}", vs, fs, M[m])

    def tilted_box(prop, part, c, size, roll, sink, m):
        cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
        x0, y0, z0 = c
        sx, sy, sz = size
        vs = []
        for z in (z0, z0 + sz):
            for (x, y) in ((x0 - sx / 2, y0 - sy / 2), (x0 + sx / 2, y0 - sy / 2), (x0 + sx / 2, y0 + sy / 2), (x0 - sx / 2, y0 + sy / 2)):
                vs.append((x * cr - z * sr, y, x * sr + z * cr - sink))
        return _mesh_obj(pcol, f"osrpprop_{prop}__{part}", vs, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], M[m])

    p = "wreck"; names.append(p)                # 26 m river cargo boat, lying on its side, bow broken off
    hull(p, "trup", 26, 7, 4.2, 22, 0.8, "rust", 12, 0.12)
    tilted_box(p, "paluba", (0, -2, 3.4), (6.0, 16, 0.15), 22, 0.8, "rust2")
    tilted_box(p, "kabina", (0, -9.5, 3.55), (4.6, 4.0, 3.0), 22, 0.8, "rust")
    tilted_box(p, "kabina_krov", (0, -9.5, 6.55), (5.0, 4.4, 0.2), 22, 0.8, "rust2")
    tilted_box(p, "dimnjak", (0, -11.0, 6.75), (0.9, 0.9, 2.2), 22, 0.8, "rust2")
    tilted_box(p, "jarbol", (0, 2.0, 3.55), (0.35, 0.35, 6.5), 22, 0.8, "rust2")
    tilted_box(p, "grotlo", (0, 3.0, 3.55), (3.2, 5.0, 0.6), 22, 0.8, "rust")
    for k, (x, y) in enumerate(((5.5, 4.0), (6.5, 6.0), (-6.0, -3.0), (4.8, 12.5))):     # spilled barrels + crates
        C(p, f"bacva_{k}", (x, y, 0), 0.35, 0.95, "rust", 10)
    for k, (x, y, sz) in enumerate(((7.0, 9.0, 1.2), (-5.0, 8.0, 1.0))):
        B(p, f"sanduk_{k}", (x, y, 0), (sz, sz, sz * 0.8), "oldwood")
    B(p, "pramac", (2.0, 15.5, 0), (4.5, 3.5, 1.4), "rust")                                # the broken-off bow piece
    blob(pcol, "osrpprop_wreck__sidro", (-4.0, 14.0, 0.3), 0.6, M["rust2"], squash=0.4)

    p = "wreck_small"; names.append(p)          # sunken wooden row boat
    hull(p, "trup", 5.0, 1.6, 0.8, -35, 0.15, "oldwood", 6)
    tilted_box(p, "klupa", (0, 0.2, 0.55), (1.4, 0.3, 0.06), -35, 0.15, "oldwood")
    B(p, "veslo", (1.6, 0.5, 0), (0.12, 2.6, 0.05), "oldwood")

    p = "kelp"; names.append(p)                 # river weed clump
    rr = __import__("random").Random(7)
    for k in range(9):
        a = k * 0.7
        x, y = math.cos(a) * 0.5 * (k % 3), math.sin(a) * 0.5 * (k % 3)
        hgt = rr.uniform(1.2, 3.2)
        B(p, f"list_{k}", (x, y, 0), (0.18, 0.04, hgt), "weed")
        B(p, f"list2_{k}", (x + 0.1, y, 0), (0.04, 0.18, hgt * 0.8), "weed")

    # ---------------- v1.0.27 Croatian traffic signs, road works, playground, gun shop (front = +Y)
    def signtex(key):
        return material(f"osrp_signtex_{key}", (1.0, 1.0, 1.0))
    M["signback"] = material("osrp_bridge_steel_signback", (0.55, 0.57, 0.6))

    def face(prop, part, verts_xz, y, mat):
        vs = [(x, y, z) for (x, z) in verts_xz]
        n = len(vs)
        return _mesh_obj(pcol, f"osrp{prop}__{part}", vs, [tuple(range(n)), tuple(range(n - 1, -1, -1))], mat)

    def shape(kind, cx, cz, r):
        if kind == "oct":
            return [(cx + r * math.cos(math.pi / 8 + i * math.pi / 4), cz + r * math.sin(math.pi / 8 + i * math.pi / 4)) for i in range(8)]
        if kind == "circle":
            return [(cx + r * math.cos(i * math.pi / 12), cz + r * math.sin(i * math.pi / 12)) for i in range(24)]
        if kind == "diamond":
            return [(cx + r, cz), (cx, cz + r), (cx - r, cz), (cx, cz - r)]
        if kind == "tri":
            return [(cx - r, cz - r * 0.75), (cx + r, cz - r * 0.75), (cx, cz + r * 0.95)]
        return [(cx - r, cz - r), (cx + r, cz - r), (cx + r, cz + r), (cx - r, cz + r)]      # square

    for key, kind, r, hgt in (("stop", "oct", 0.42, 2.1), ("crossing", "square", 0.38, 2.3), ("priority", "diamond", 0.45, 2.3),
                              ("noentry", "circle", 0.38, 2.2), ("speed50", "circle", 0.38, 2.2), ("works", "tri", 0.45, 1.4)):
        p = f"sign_{key}"; names.append(p)
        C(p, "stup", (0, -0.05, 0), 0.04, hgt + r, "pole", 8)
        sh = shape(kind, 0, hgt, r)
        face("prop_" + p, "lice", sh, 0.02, signtex(key))
        face("prop_" + p, "ledja", shape(kind, 0, hgt, r + 0.02), -0.005, M["signback"])
        if key == "works":                         # on a little A-frame stand, not a pole
            for sx in (-0.35, 0.35):
                B(p, f"noga_{sx}", (sx, -0.25, 0), (0.06, 0.06, 1.0), "pole")
    for key in ("closed", "detour"):               # big boards on a red/white barrier
        p = f"board_{key}"; names.append(p)
        face("prop_" + p, "lice", [(-0.7, 0.75), (0.7, 0.75), (0.7, 2.15), (-0.7, 2.15)], 0.03, signtex(key))
        B(p, "ploca", (0, 0, 0.75), (1.44, 0.04, 1.42), "signback")
        for sx in (-0.65, 0.65):
            B(p, f"noga_{sx}", (sx, 0, 0), (0.08, 0.5, 0.8), "pole")
        for k in range(4):
            B(p, f"traka_{k}", (-0.6 + k * 0.4, 0.04, 0.35), (0.2, 0.03, 0.25), "red" if k % 2 == 0 else "white")
    p = "sign_street"; names.append(p)            # blue street plate on a post
    C(p, "stup", (0, -0.05, 0), 0.04, 2.9, "pole", 8)
    face("prop_" + p, "lice", [(-0.45, 2.5), (0.45, 2.5), (0.45, 2.9), (-0.45, 2.9)], 0.02, signtex("street"))
    p = "gunshop_sign"; names.append(p)            # shop sign board (on the wall, origin = wall)
    face("prop_" + p, "lice", [(-1.6, 0), (1.6, 0), (1.6, 1.6), (-1.6, 1.6)], 0.09, signtex("gunshop"))
    B(p, "ploca", (0, 0.04, -0.05), (3.3, 0.08, 1.7), "black")

    p = "swing"; names.append(p)                   # playground swing (2 seats)
    for sx in (-1.6, 1.6):
        for sy in (-0.7, 0.7):
            B(p, f"noga_{sx}_{sy}", (sx, sy * 0.6, 0), (0.1, 0.1, 2.4), "yellow")
    B(p, "greda", (0, 0, 2.35), (3.4, 0.12, 0.12), "yellow")
    for sx in (-0.7, 0.7):
        for dx in (-0.22, 0.22):
            B(p, f"lanac_{sx}_{dx}", (sx + dx, 0, 0.55), (0.02, 0.02, 1.8), "steel")
        B(p, f"sjedalo_{sx}", (sx, 0, 0.5), (0.5, 0.22, 0.05), "rubber")
    p = "slide"; names.append(p)                   # slide with ladder
    B(p, "platforma", (0, -1.0, 1.4), (0.9, 0.9, 0.08), "red")
    for sx in (-0.4, 0.4):
        for sy in (-1.4, -0.6):
            B(p, f"noga_{sx}_{sy}", (sx, sy, 0), (0.08, 0.08, 1.45), "yellow")
    for k in range(5):
        B(p, f"ljestve_{k}", (0, -1.6, 0.25 + k * 0.28), (0.7, 0.06, 0.05), "steel")
    for k in range(8):
        B(p, f"tobogan_{k}", (0, -0.45 + k * 0.3, 1.35 - k * 0.17), (0.6, 0.32, 0.06), "blue")
    B(p, "rub_l", (-0.33, 0.6, 0.2), (0.05, 2.4, 0.15), "blue")
    B(p, "rub_d", (0.33, 0.6, 0.2), (0.05, 2.4, 0.15), "blue")
    p = "sandbox"; names.append(p)
    for k, (x, y, sx, sy) in enumerate(((0, -1.5, 3.2, 0.2), (0, 1.5, 3.2, 0.2), (-1.5, 0, 0.2, 3.0), (1.5, 0, 0.2, 3.0))):
        B(p, f"rub_{k}", (x, y, 0), (sx, sy, 0.3), "wood")
    B(p, "pijesak", (0, 0, 0), (2.8, 2.8, 0.18), "sand")

    p = "gunwall"; names.append(p)                 # wall rack with rifles and pistols (origin = wall, things on +Y)
    B(p, "ploca", (0, 0.03, 0.6), (3.0, 0.06, 1.8), "oldwood" if "oldwood" in M else "wood")
    for k in range(6):
        x = -1.25 + k * 0.5
        B(p, f"puska_kundak_{k}", (x, 0.1, 0.8), (0.07, 0.06, 0.35), "wood")
        B(p, f"puska_cijev_{k}", (x, 0.1, 1.15), (0.04, 0.05, 0.95), "black")
    for k in range(5):
        B(p, f"pistolj_{k}", (-1.1 + k * 0.55, 0.1, 2.15), (0.22, 0.05, 0.14), "black")
        B(p, f"pistolj_drska_{k}", (-1.17 + k * 0.55, 0.1, 2.02), (0.06, 0.05, 0.13), "black")
    p = "guncase"; names.append(p)                 # glass display counter
    B(p, "tijelo", (0, 0, 0), (2.0, 0.7, 0.75), "black")
    B(p, "staklo", (0, 0, 0.75), (2.0, 0.7, 0.3), "glass")
    for k in range(3):
        B(p, f"pistolj_{k}", (-0.6 + k * 0.6, 0, 0.77), (0.24, 0.12, 0.05), "steel")
    B(p, "ploca", (0, 0, 1.05), (2.04, 0.74, 0.03), "black")

    # ---------------- v1.0.29 more props for the police station, hospital and airport (front = +Y)
    M.update({"cabinet": material("osrp_metal_cabinet_grey", (0.45, 0.47, 0.50)), "keyboard": material("osrp_screen_keys", (0.08, 0.08, 0.09)),
              "orange": material("osrp_paint_orange", (0.85, 0.35, 0.05)), "screen_on": material("osrp_lamp_light_screen", (0.35, 0.6, 0.95), emit=3.0),
              "belt": material("osrp_fabric_belt_blue", (0.05, 0.15, 0.45))})
    p = "desk_pc"; names.append(p)               # office desk with monitor, keyboard, tower, papers (person sits on +Y side)
    B(p, "ploca", (0, 0, 0.73), (1.6, 0.8, 0.04), "wood")
    for sx in (-0.75, 0.75):
        B(p, f"bok_{sx}", (sx, 0, 0), (0.05, 0.75, 0.73), "cabinet")
    B(p, "ladice", (0.45, 0, 0.05), (0.45, 0.7, 0.6), "cabinet")
    B(p, "monitor_noga", (0, -0.25, 0.77), (0.2, 0.15, 0.02), "black")
    B(p, "monitor_vrat", (0, -0.27, 0.79), (0.05, 0.04, 0.15), "black")
    B(p, "monitor", (0, -0.25, 0.92), (0.62, 0.04, 0.38), "black")
    B(p, "ekran", (0, -0.227, 0.94), (0.58, 0.005, 0.34), "screen_on")
    B(p, "tipkovnica", (0, 0.1, 0.77), (0.45, 0.15, 0.02), "keyboard")
    B(p, "mis", (0.32, 0.1, 0.77), (0.06, 0.1, 0.02), "keyboard")
    B(p, "papiri", (-0.5, 0.05, 0.77), (0.3, 0.22, 0.03), "white")
    B(p, "kuciste", (-0.55, -0.15, 0.0), (0.2, 0.45, 0.45), "black")
    p = "filing"; names.append(p)                # filing cabinet, 4 drawers
    B(p, "tijelo", (0, 0, 0), (0.5, 0.62, 1.32), "cabinet")
    for k in range(4):
        B(p, f"ladica_{k}", (0, 0.312, 0.05 + k * 0.32), (0.46, 0.01, 0.28), "steel")
        B(p, f"rucka_{k}", (0, 0.33, 0.25 + k * 0.32), (0.14, 0.02, 0.02), "black")
    p = "flagpole"; names.append(p)              # 8 m flag pole with the Croatian flag
    C(p, "stup", (0, 0, 0), 0.06, 8.0, "steel", 10)
    C(p, "baza", (0, 0, 0), 0.3, 0.25, "white", 12)
    face("prop_" + p, "zastava", [(0.06, 6.2), (2.46, 6.2), (2.46, 7.8), (0.06, 7.8)], 0.0, signtex("flag_hr"))
    p = "stretcher"; names.append(p)             # ambulance stretcher
    B(p, "madrac", (0, 0, 0.82), (0.6, 1.95, 0.1), "orange")
    B(p, "okvir", (0, 0, 0.75), (0.62, 1.98, 0.07), "steel")
    for sy in (-0.8, 0.8):
        B(p, f"noge_{sy}", (0, sy, 0.1), (0.5, 0.04, 0.65), "steel")
        for sx in (-0.25, 0.25):
            C(p, f"kotac_{sx}_{sy}", (sx, sy, 0), 0.06, 0.1, "rubber", 8)
    B(p, "jastuk", (0, -0.75, 0.92), (0.45, 0.3, 0.08), "white")
    p = "defib"; names.append(p)                 # crash cart with defibrillator
    B(p, "kolica", (0, 0, 0.12), (0.7, 0.5, 0.9), "red")
    for k in range(4):
        B(p, f"ladica_{k}", (0, 0.252, 0.18 + k * 0.2), (0.62, 0.01, 0.16), "white")
    B(p, "defibrilator", (0, 0, 1.02), (0.4, 0.3, 0.18), "yellow")
    B(p, "ekran", (0, 0.152, 1.07), (0.25, 0.005, 0.1), "screen_on")
    for sx in (-0.3, 0.3):
        for sy in (-0.2, 0.2):
            C(p, f"kotac_{sx}_{sy}", (sx, sy, 0), 0.06, 0.12, "rubber", 8)
    p = "xray"; names.append(p)                  # airport security X-ray machine with belts (bags go along X)
    B(p, "traka_ulaz", (-1.9, 0, 0), (1.8, 0.75, 0.75), "black")
    B(p, "tunel", (0, 0, 0), (2.0, 1.1, 1.6), "white")
    B(p, "otvor", (0, 0, 0.75), (2.02, 0.7, 0.55), "black")
    B(p, "traka_izlaz", (2.1, 0, 0), (2.2, 0.75, 0.75), "black")
    B(p, "valjci", (2.1, 0, 0.75), (2.2, 0.7, 0.02), "steel")
    B(p, "monitor", (0.5, 0.75, 1.1), (0.5, 0.05, 0.35), "black")
    B(p, "ekran", (0.5, 0.778, 1.12), (0.46, 0.005, 0.31), "screen_on")
    B(p, "pult", (0.5, 0.75, 0), (0.6, 0.4, 1.0), "cabinet")
    B(p, "kofer", (-2.2, 0, 0.75), (0.45, 0.3, 0.6), "case1")
    p = "metaldet"; names.append(p)              # walk-through metal detector
    for sx in (-0.48, 0.48):
        B(p, f"stup_{sx}", (sx, 0, 0), (0.14, 0.6, 2.2), "cabinet")
    B(p, "vrh", (0, 0, 2.2), (1.1, 0.6, 0.25), "cabinet")
    B(p, "svjetlo", (0, 0.31, 2.25), (0.3, 0.01, 0.1), "screen_on")
    p = "qbarrier"; names.append(p)              # queue posts with a blue belt, 3 m
    for x in (-1.5, 0.0, 1.5):
        C(p, f"stup_{x}", (x, 0, 0), 0.04, 0.95, "steel", 8)
        C(p, f"baza_{x}", (x, 0, 0), 0.17, 0.03, "steel", 12)
    B(p, "traka", (0, 0, 0.82), (3.0, 0.02, 0.06), "belt")
    p = "cafe"; names.append(p)                  # coffee kiosk in the terminal
    B(p, "pult", (0, 0.6, 0), (3.0, 0.7, 1.05), "wood")
    B(p, "ploca", (0, 0.6, 1.05), (3.1, 0.8, 0.05), "white")
    B(p, "zid", (0, -0.9, 0), (3.0, 0.2, 2.6), "wood")
    B(p, "aparat", (-0.8, -0.65, 1.0), (0.6, 0.4, 0.6), "steel")
    B(p, "vitrina", (0.6, 0.6, 1.1), (1.2, 0.6, 0.4), "glass")
    B(p, "natpis", (0, -0.78, 2.1), (2.2, 0.02, 0.4), "sign_y")
    for k in range(5):
        C(p, f"salica_{k}", (-1.2 + k * 0.25, -0.75, 1.62), 0.05, 0.1, "white", 8)
    p = "gatedesk"; names.append(p)              # boarding gate desk with a GATE sign
    B(p, "pult", (0, 0, 0), (2.0, 0.7, 1.05), "white")
    B(p, "ploca", (0, 0, 1.05), (2.1, 0.8, 0.04), "black")
    C(p, "stup", (0.9, -0.2, 0), 0.04, 2.4, "steel", 8)
    face("prop_" + p, "natpis", [(0.45, 2.0), (1.35, 2.0), (1.35, 2.6), (0.45, 2.6)], -0.17, signtex("gate"))

    # ---------------- v1.0.32 police station details
    M.update({"panel_light": material("osrp_lamp_light_panel", (1.0, 0.98, 0.92), emit=6.0)})
    p = "ceilight"; names.append(p)              # ceiling LED panel 1.2 x 0.6 (origin = ceiling, hangs down)
    B(p, "okvir", (0, 0, -0.05), (1.25, 0.65, 0.05), "white")
    B(p, "svjetlo", (0, 0, -0.06), (1.15, 0.55, 0.012), "panel_light")
    p = "logo_wall"; names.append(p)             # 2.4 m emblem on the wall (origin = wall)
    face("prop_" + p, "lice", [(-1.2, 0.0), (1.2, 0.0), (1.2, 2.4), (-1.2, 2.4)], 0.05, signtex("police_logo"))
    B(p, "ploca", (0, 0.02, -0.05), (2.5, 0.04, 2.5), "black")
    p = "pu_plate"; names.append(p)              # plate beside the door (origin = wall)
    face("prop_" + p, "lice", [(-0.45, 0.0), (0.45, 0.0), (0.45, 0.9), (-0.45, 0.9)], 0.03, signtex("pu_plate"))
    B(p, "ploca", (0, 0.01, -0.02), (0.94, 0.02, 0.94), "steel")
    p = "noticeboard"; names.append(p)           # wanted posters / notices (origin = wall)
    face("prop_" + p, "lice", [(-1.0, 0.0), (1.0, 0.0), (1.0, 1.3), (-1.0, 1.3)], 0.04, signtex("notice"))
    B(p, "okvir", (0, 0.015, -0.05), (2.1, 0.03, 1.4), "wood")
    p = "citymap"; names.append(p)               # big city map for the briefing room (origin = wall)
    face("prop_" + p, "lice", [(-1.5, 0.0), (1.5, 0.0), (1.5, 1.6), (-1.5, 1.6)], 0.04, signtex("osijek_map"))
    B(p, "okvir", (0, 0.015, -0.05), (3.1, 0.03, 1.7), "steel")
    p = "interro"; names.append(p)               # interrogation table with two chairs and a lamp
    B(p, "ploca", (0, 0, 0.74), (1.6, 0.9, 0.05), "steel")
    for sx in (-0.7, 0.7):
        for sy in (-0.35, 0.35):
            B(p, f"noga_{sx}_{sy}", (sx, sy, 0), (0.05, 0.05, 0.74), "steel")
    for sy in (-0.85, 0.85):
        B(p, f"stolac_{sy}", (0, sy, 0.43), (0.45, 0.45, 0.05), "black")
        B(p, f"stolac_n_{sy}", (0, sy + (0.2 if sy > 0 else -0.2), 0.48), (0.45, 0.05, 0.5), "black")
        for sx in (-0.18, 0.18):
            B(p, f"stolac_noga_{sy}_{sx}", (sx, sy, 0), (0.04, 0.04, 0.43), "steel")
    B(p, "lampa", (0.5, 0, 0.79), (0.15, 0.15, 0.3), "black")
    p = "cctv"; names.append(p)                  # wall camera (origin = wall)
    B(p, "nosac", (0, 0.1, -0.05), (0.06, 0.2, 0.06), "white")
    B(p, "kamera", (0, 0.3, -0.12), (0.12, 0.32, 0.12), "white")
    B(p, "lec", (0, 0.465, -0.12), (0.08, 0.01, 0.08), "black")
    p = "acunit"; names.append(p)                # rooftop air conditioner
    B(p, "tijelo", (0, 0, 0), (1.8, 1.0, 1.1), "cabinet")
    C(p, "ventilator", (0, 0, 1.1), 0.4, 0.05, "black", 12)
    p = "bollard"; names.append(p)
    C(p, "stup", (0, 0, 0), 0.11, 0.95, "steel", 10)
    C(p, "traka", (0, 0, 0.75), 0.115, 0.08, "sign_y", 10)
    p = "briefchairs"; names.append(p)          # row of 4 briefing chairs with writing pads (people look to +Y)
    B(p, "greda", (0, 0, 0.3), (2.6, 0.08, 0.06), "steel")
    for k in range(4):
        x = -0.96 + k * 0.64
        B(p, f"sjedalo_{k}", (x, 0.04, 0.43), (0.5, 0.48, 0.06), "belt")
        B(p, f"nasl_{k}", (x, -0.2, 0.49), (0.5, 0.06, 0.5), "belt")
        B(p, f"pult_{k}", (x + 0.22, 0.25, 0.68), (0.25, 0.35, 0.03), "white")
    for x in (-1.2, 1.2):
        B(p, f"noga_{x}", (x, 0, 0), (0.06, 0.45, 0.32), "steel")

    return pcol, names
