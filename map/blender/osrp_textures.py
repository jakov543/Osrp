"""
OSRP - procedural, seamless textures for the Osijek map (numpy only, works in Blender's bundled Python).

generate(key, base_rgb, seed, size) -> (albedo uint8 HxWx3, height float32 HxW in 0..1 or None)
save(path_without_ext, albedo, height, normal_strength) -> writes <path>.dds and <path>_n.dds (if height)

Every texture tiles seamlessly (all noise is periodic, patterns repeat exactly at the edge).
"""
import os
import subprocess
import numpy as np

# ------------------------------------------------------------------ noise helpers (periodic)


def _blur(a, sigma):
    """gaussian blur with wrap-around, via FFT"""
    if sigma <= 0:
        return a
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def _norm(a):
    a = a - a.mean()
    m = np.abs(a).max()
    return a / m if m > 0 else a


def noise(rng, n, sigma, sx=1.0, sy=1.0):
    """periodic noise -1..1; sx/sy stretch it (grain, streaks)"""
    a = rng.standard_normal((n, n))
    if sx == sy == 1.0:
        return _norm(_blur(a, sigma))
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi ** 2) * (((sigma * sx) * fx) ** 2 + ((sigma * sy) * fy) ** 2))
    return _norm(np.real(np.fft.ifft2(np.fft.fft2(a) * g)))


def fbm(rng, n, sigmas, weights):
    out = np.zeros((n, n))
    for s, w in zip(sigmas, weights):
        out += w * noise(rng, n, s)
    return _norm(out)


def speckles(rng, n, density, sigma=0.6):
    a = (rng.random((n, n)) < density).astype(float)
    return np.clip(_blur(a, sigma) * 4.0, 0, 1)


def cracks(rng, n, count, length, width=1.0):
    """random-walk dark lines (wrapping)"""
    a = np.zeros((n, n))
    for _ in range(count):
        x, y = rng.random() * n, rng.random() * n
        ang = rng.random() * np.pi * 2
        for _ in range(length):
            ang += rng.normal(0, 0.35)
            x = (x + np.cos(ang)) % n
            y = (y + np.sin(ang)) % n
            a[int(y), int(x)] = 1.0
            if rng.random() < 0.02:      # small branch
                ang += rng.choice([-1, 1]) * 0.9
    return np.clip(_blur(a, width) * 3.0, 0, 1)


def tiles(n, cols, rows, stagger=0.5, row_jitter=None):
    """brick-style tiling: per-pixel tile id, local u/v 0..1, distance to tile edge (in px)"""
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    th, tw = n / rows, n / cols
    r = np.floor(yy / th)
    off = (r % 2) * stagger * tw
    if row_jitter is not None:
        off = off + row_jitter[r.astype(int) % rows] * tw
    xs = (xx + off) % n
    c = np.floor(xs / tw)
    u = (xs - c * tw) / tw
    v = (yy - r * th) / th
    edge = np.minimum(np.minimum(u, 1 - u) * tw, np.minimum(v, 1 - v) * th)
    tid = (r * 1000 + c).astype(np.int64)
    return tid, u, v, edge


def per_tile(rng, tid, spread):
    ids, inv = np.unique(tid, return_inverse=True)
    vals = rng.normal(0, spread, len(ids))
    return vals[inv].reshape(tid.shape)


def colorize(base, shade, tint=None):
    """base rgb 0..255, shade multiplier array (1 = base), optional per-channel tint array HxWx3"""
    img = np.asarray(base, float)[None, None, :] * shade[..., None]
    if tint is not None:
        img = img + tint
    return np.clip(img, 0, 255).astype(np.uint8)


def mix(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


# ------------------------------------------------------------------ texture recipes


def asphalt(rng, n, base):
    big = fbm(rng, n, [n / 6, n / 14], [1, 0.6])
    mid = noise(rng, n, 3)
    fine = noise(rng, n, 0.7)
    agg = speckles(rng, n, 0.025)
    dark = speckles(rng, n, 0.02)
    cr = cracks(rng, n, 4, n // 2, 0.8)
    shade = 1 + 0.16 * big + 0.12 * mid + 0.22 * fine + 0.55 * agg - 0.35 * dark - 0.45 * cr
    # tar seam patches (repaired asphalt)
    patch = np.clip((noise(rng, n, n / 10) - 0.65) * 5, 0, 1)
    shade = shade * (1 - 0.10 * patch)
    height = 0.5 + 0.25 * fine + 0.2 * agg - 0.5 * cr
    return colorize(base, shade), height


def road_line(rng, n, base):
    wear = fbm(rng, n, [n / 16, 3, 0.8], [1, 0.6, 0.5])
    holes = np.clip((wear - 0.6) * 3, 0, 1)
    paint = colorize(base, 1 + 0.06 * wear)
    asph = colorize((40, 40, 42), 1 + 0.3 * noise(rng, n, 0.7))
    img = mix(paint.astype(float), asph.astype(float), holes * 0.85)
    return img.astype(np.uint8), 0.6 - 0.3 * holes


def pavement(rng, n, base):
    tid, u, v, edge = tiles(n, 4, 4, stagger=0.0)
    var = per_tile(rng, tid, 0.06)
    fine = noise(rng, n, 0.8)
    big = noise(rng, n, n / 8)
    joint = np.clip(1 - edge / 3.0, 0, 1)
    bevel = np.clip(edge / 6.0, 0, 1)
    shade = (1 + var + 0.12 * fine + 0.06 * big) * (1 - 0.55 * joint) * (0.93 + 0.07 * bevel)
    stain = speckles(rng, n, 0.002, 4) * 0.25
    return colorize(base, shade - stain), bevel * (0.8 + 0.1 * fine)


def cobble(rng, n, base):
    rows = 16
    jitter = rng.random(rows) * 0.5
    tid, u, v, edge = tiles(n, 16, rows, stagger=0.0, row_jitter=jitter)
    du, dv = (u - 0.5) * 2, (v - 0.5) * 2
    dome = np.clip(1 - (np.abs(du) ** 3 + np.abs(dv) ** 3) * 0.9, 0, 1) ** 0.6
    var = per_tile(rng, tid, 0.09)
    hue = per_tile(rng, tid, 4.0)
    fine = noise(rng, n, 0.9)
    joint = np.clip(1 - edge / 4.0, 0, 1)
    shade = (0.85 + 0.3 * dome + var + 0.1 * fine) * (1 - 0.6 * joint)
    tint = np.stack([hue, hue * 0.6, -hue * 0.3], -1)
    moss = np.clip((noise(rng, n, n / 10) - 0.3) * 2, 0, 1) * joint
    img = colorize(base, shade, tint).astype(float)
    img = mix(img, np.array([[[52, 66, 38]]], float) * np.ones_like(img), moss * 0.5)
    return img.astype(np.uint8), dome * (1 - joint) * 0.9 + 0.05 * fine


def curb(rng, n, base):
    tid, u, v, edge = tiles(n, 1, 1, stagger=0.0)
    gran = speckles(rng, n, 0.06, 0.5) - speckles(rng, n, 0.05, 0.5)
    fine = noise(rng, n, 1.0)
    joint = np.clip(1 - edge / 3.0, 0, 1)
    shade = (1 + 0.18 * gran + 0.08 * fine) * (1 - 0.5 * joint)
    return colorize(base, shade), 0.6 + 0.2 * fine - 0.5 * joint


def grass(rng, n, base, park=False):
    """v1.0.24: real-looking lawn - tens of thousands of thin blades (dark roots, bright lime tips) that flow in
    soft waves, drawn seamlessly (wrap-around) over a dark base"""
    # flow direction field: blades lean the same way in waves (like the reference photo)
    flow = fbm(rng, n, [n / 7, n / 16], [1, 0.5]) * np.pi * 1.2 + rng.uniform(0, np.pi)
    img = np.zeros((n, n, 3), float)
    dark = fbm(rng, n, [n / 6, n / 20], [1, 0.5])
    img[...] = np.array([20, 44, 13], float) * (0.92 + 0.16 * dark[..., None])
    height = np.full((n, n), 0.25)
    nb = int(n * n * 0.06)                        # ~63k blades at 1024 px
    bx, by = rng.uniform(0, n, nb), rng.uniform(0, n, nb)
    ang = flow[by.astype(int) % n, bx.astype(int) % n] + rng.normal(0, 0.35, nb)
    length = rng.uniform(n * 0.03, n * 0.075, nb)
    bend = rng.normal(0, 0.6, nb)
    hue = rng.uniform(0, 1, nb)
    lit = rng.uniform(0.75, 1.15, nb)
    root = np.array([22, 52, 14], float)
    tip_a = np.array([92, 142, 40], float)        # v1.0.27: less lime, more natural
    tip_b = np.array([52, 100, 28], float)        # deeper green
    if park:
        tip_a = np.array([96, 158, 44], float)
    steps = 14
    for k in range(steps + 1):                    # draw from root to tip, tips land on top
        t = k / steps
        a = ang + bend * t * t
        x = (bx + np.cos(a) * length * t).astype(int) % n
        y = (by + np.sin(a) * length * t).astype(int) % n
        tip = tip_a * (1 - hue[:, None]) + tip_b * hue[:, None]
        col = (root * (1 - t ** 0.8) + tip * t ** 0.8) * lit[:, None]
        width = 1 if t > 0.55 else 2              # blades get thinner to the tip
        for dx in range(width):
            img[y, (x + dx) % n] = col
            height[y, (x + dx) % n] = 0.3 + 0.7 * t
    # soft light / shadow waves over the lawn and a few dry blades
    wave = fbm(rng, n, [n / 4], [1])
    img *= (0.95 + 0.08 * wave)[..., None]        # gentle, so the tiling does not show
    if park:   # a few tiny daisies
        fl = speckles(rng, n, 0.0005, 0.6)
        img = mix(img, np.full_like(img, 230), np.clip(fl * 1.5, 0, 1))
    return np.clip(img, 0, 255).astype(np.uint8), height


def gravel(rng, n, base):
    pts = speckles(rng, n, 0.05, 1.6)
    small = speckles(rng, n, 0.12, 0.6)
    var = noise(rng, n, 1.5)
    shade = 0.8 + 0.35 * pts + 0.2 * small + 0.12 * var
    return colorize(base, shade), 0.3 + 0.5 * pts + 0.2 * small


def soil(rng, n, base):
    f = fbm(rng, n, [n / 10, 4, 1], [1, 0.6, 0.5])
    clods = speckles(rng, n, 0.01, 2.0)
    return colorize(base, 1 + 0.2 * f + 0.25 * clods), 0.4 + 0.3 * f + 0.3 * clods


def ashlar(rng, n, base, rows=5):
    """stone blocks with random widths per row (seamless)"""
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    th = n / rows
    r = np.floor(yy / th).astype(int)
    v = (yy - r * th) / th
    tid = np.zeros((n, n), np.int64)
    edge_x = np.full((n, n), 1e9)
    for row in range(rows):
        cuts = [0.0]
        while cuts[-1] < n:
            cuts.append(cuts[-1] + rng.uniform(0.28, 0.55) * n)
        cuts[-1] = n
        if n - cuts[-2] < 0.15 * n:
            cuts.pop(-2)
        shift = rng.random() * n
        m = r == row
        xs = (xx[m] + shift) % n
        idx = np.searchsorted(cuts, xs, side="right") - 1
        left, right = np.array(cuts)[idx], np.array(cuts)[idx + 1]
        tid[m] = row * 100 + idx
        edge_x[m] = np.minimum(xs - left, right - xs)
    edge = np.minimum(edge_x, np.minimum(v, 1 - v) * th)
    var = per_tile(rng, tid, 0.07)
    fine = fbm(rng, n, [3, 0.8], [0.6, 1])
    joint = np.clip(1 - edge / 4.0, 0, 1)
    shade = (1 + var + 0.14 * fine) * (1 - 0.5 * joint)
    return colorize(base, shade), np.clip(edge / 10.0, 0, 1) * 0.8 + 0.1 * fine


def brick(rng, n, base):
    tid, u, v, edge = tiles(n, 8, 26, stagger=0.5)
    var = per_tile(rng, tid, 0.10)
    hue = per_tile(rng, tid, 10.0)
    fine = noise(rng, n, 0.8)
    mortar = np.clip(1 - edge / 2.2, 0, 1)
    shade = 1 + var + 0.12 * fine
    tint = np.stack([hue, hue * 0.3, -hue * 0.2], -1)
    img = colorize(base, shade, tint).astype(float)
    mort = np.array([[[178, 170, 158]]], float) * (1 + 0.1 * noise(rng, n, 1))[..., None]
    img = mix(img, mort, mortar)
    soot = np.clip(noise(rng, n, n / 8) * 0.5, 0, 1) * 0.15
    img = img * (1 - soot[..., None])
    return img.astype(np.uint8), (1 - mortar) * (0.8 + 0.1 * fine)


def roof(rng, n, base):
    tid, u, v, edge = tiles(n, 10, 12, stagger=0.5)
    var = per_tile(rng, tid, 0.08)
    # each tile: darker under the overlap (top), rounded lower edge, slight barrel curve across
    curve = np.sin(u * np.pi) ** 0.5
    overlap = np.clip(v * 3, 0, 1)
    shade = (0.7 + 0.3 * overlap) * (0.85 + 0.2 * curve) * (1 + var) * (1 + 0.08 * noise(rng, n, 0.8))
    lichen = np.clip((noise(rng, n, n / 12) - 0.45) * 3, 0, 1) * 0.35
    img = colorize(base, shade).astype(float)
    img = mix(img, np.array([[[96, 92, 70]]], float) * np.ones_like(img), lichen)
    return img.astype(np.uint8), overlap * curve * 0.9


def slate(rng, n, base):
    tid, u, v, edge = tiles(n, 12, 16, stagger=0.5)
    var = per_tile(rng, tid, 0.07)
    scale = np.clip(1 - ((u - 0.5) * 2) ** 2 - (1 - v) ** 2 * 0.0, 0, 1)
    shade = (0.75 + 0.3 * v) * (1 + var) * (0.9 + 0.1 * scale)
    return colorize(base, shade), v * 0.8


def plaster(rng, n, base):
    stucco = noise(rng, n, 0.7)
    blot = fbm(rng, n, [n / 6, n / 16], [1, 0.6])
    streak = noise(rng, n, 2.0, sx=0.4, sy=12.0)
    cracks_ = cracks(rng, n, 2, n // 4, 0.6)
    shade = 1 + 0.05 * stucco + 0.06 * blot - 0.05 * np.clip(streak, 0, 1) - 0.25 * cracks_
    return colorize(base, shade), 0.5 + 0.25 * stucco - 0.4 * cracks_


def wood(rng, n, base, planks=8):
    grain = noise(rng, n, 1.0, sx=12.0, sy=0.5)
    rings = np.sin(noise(rng, n, 6, sx=8.0, sy=1.0) * 9) * 0.5
    yy = np.mgrid[0:n, 0:n][0].astype(float)
    pw = n / planks
    p = np.floor(yy / pw)
    edge = np.minimum(yy - p * pw, (p + 1) * pw - yy)
    var = per_tile(np.random.default_rng(int(rng.integers(1 << 30))), p.astype(np.int64), 0.09)
    gap = np.clip(1 - edge / 2.0, 0, 1)
    shade = (1 + var + 0.12 * grain + 0.08 * rings) * (1 - 0.5 * gap)
    return colorize(base, shade), (1 - gap) * (0.7 + 0.1 * grain)


def metal(rng, n, base):
    brushed = noise(rng, n, 0.8, sx=20.0, sy=0.4)
    spots = fbm(rng, n, [n / 10, 3], [1, 0.4])
    return colorize(base, 1 + 0.06 * brushed + 0.06 * spots), None


def glass(rng, n, base):
    refl = noise(rng, n, n / 6)
    dirt = speckles(rng, n, 0.004, 2)
    return colorize(base, 1 + 0.12 * refl + 0.2 * dirt), None


def manhole(rng, n, base):
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    k = 8
    gx = np.abs(((xx / n * k) % 1) - 0.5)
    gy = np.abs(((yy / n * k) % 1) - 0.5)
    bars = np.clip((0.12 - np.minimum(gx, gy)) * 12, 0, 1)
    rust = np.clip(noise(rng, n, n / 10) * 1.5, 0, 1) * 0.5
    tint = np.stack([rust * 50, rust * 18, -rust * 10], -1)
    shade = (1 + 0.5 * bars + 0.1 * noise(rng, n, 0.8))
    return colorize(base, shade, tint), 0.3 + 0.6 * bars


def flowers(rng, n, base):
    leaves = colorize((40, 80, 30), 1 + 0.3 * noise(rng, n, 1.2)).astype(float)
    bloom = speckles(rng, n, 0.03, 1.4)
    img = mix(leaves, np.asarray(base, float) * np.ones_like(leaves), np.clip(bloom * 1.6, 0, 1))
    return img.astype(np.uint8), 0.3 + 0.6 * bloom


def sand(rng, n, base):
    grains = noise(rng, n, 0.6)
    ripple = np.sin(np.mgrid[0:n, 0:n][0] / n * np.pi * 2 * 10 + noise(rng, n, n / 10) * 3) * 0.5
    shells = speckles(rng, n, 0.002, 0.8)
    return colorize(base, 1 + 0.10 * grains + 0.05 * ripple + 0.3 * shells), 0.5 + 0.2 * ripple + 0.1 * grains


def corrugated(rng, n, base):
    xx = np.mgrid[0:n, 0:n][1].astype(float)
    wave = np.sin(xx / n * np.pi * 2 * 16)
    streak = noise(rng, n, 2.0, sx=0.3, sy=10.0)
    shade = 1 + 0.10 * wave + 0.06 * streak
    return colorize(base, shade), 0.5 + 0.5 * wave


def water(rng, n, base):
    ripple = noise(rng, n, 2.0, sx=1.0, sy=3.0)
    glint = np.clip((noise(rng, n, 1.2) - 0.6) * 4, 0, 1)
    return colorize(base, 1 + 0.18 * ripple + 0.5 * glint), None


def facade_panels(rng, n, base, cols=4, rows=3, joint_px=4.0):
    """v1.0.25: modern ventilated facade - large smooth panels with dark joints (hospital, terminal)"""
    tid, u, v, edge = tiles(n, cols, rows, stagger=0.0)
    var = per_tile(rng, tid, 0.012)
    fine = noise(rng, n, 0.6)
    dirt = np.clip(fbm(rng, n, [n / 5, n / 14], [1, 0.5]), 0, None)
    streak = np.clip(noise(rng, n, 1.5, sx=0.3, sy=10.0), 0, 1)
    joint = np.clip(1 - edge / joint_px, 0, 1)
    shade = (1 + var + 0.025 * fine - 0.05 * dirt - 0.04 * streak * v) * (1 - 0.6 * joint)
    return colorize(base, shade), 0.6 - 0.5 * joint


def vinyl(rng, n, base):
    """v1.0.25: hospital floor - speckled vinyl in 1.2 m sheets with thin welded seams"""
    tid, u, v, edge = tiles(n, 2, 2, stagger=0.0)
    speck = speckles(rng, n, 0.05, 0.6)
    speck2 = speckles(rng, n, 0.03, 0.5)
    cloud = fbm(rng, n, [n / 4, n / 12], [1, 0.5])
    seam = np.clip(1 - edge / 1.5, 0, 1)
    shade = 1 + 0.04 * cloud - 0.10 * speck + 0.08 * speck2 - 0.25 * seam
    img = colorize(base, shade).astype(float)
    shine = np.clip(fbm(rng, n, [n / 2], [1]), 0, 1)[..., None]      # polished look
    img = img * (0.96 + 0.08 * shine)
    return np.clip(img, 0, 255).astype(np.uint8), 0.5 - 0.3 * seam


def terrazzo(rng, n, base):
    """v1.0.25: airport floor - big polished stone tiles with terrazzo chips"""
    tid, u, v, edge = tiles(n, 2, 2, stagger=0.0)
    var = per_tile(rng, tid, 0.012)
    chips = speckles(rng, n, 0.08, 0.9)
    dark = speckles(rng, n, 0.03, 0.7)
    joint = np.clip(1 - edge / 2.0, 0, 1)
    shade = (1 + var + 0.12 * chips - 0.18 * dark) * (1 - 0.35 * joint)
    return colorize(base, shade), 0.5 - 0.3 * joint


def rust_hull(rng, n, base, dark=False):
    """v1.0.26: sunken steel hull - welded plates with rivets, orange-brown rust, dark streaks, green algae and shells"""
    tid, u, v, edge = tiles(n, 2, 4, stagger=0.5)
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    var = per_tile(rng, tid, 0.10)
    rust = fbm(rng, n, [n / 6, n / 18, n / 60], [1, 0.6, 0.4])
    streak = np.clip(noise(rng, n, 2.0, sx=0.25, sy=14.0), 0, 1)
    seam = np.clip(1 - edge / 3.0, 0, 1)
    rivet = ((np.abs(edge - 9.0) < 2.2) & ((xx + yy).astype(int) % 22 < 4)).astype(float)
    pits = speckles(rng, n, 0.02, 1.0)
    shade = (0.85 + var + 0.35 * rust - 0.30 * streak) * (1 - 0.45 * seam) * (1 + 0.25 * rivet) * (1 - 0.3 * pits)
    img = colorize(base, shade).astype(float)
    orange = np.array([140, 62, 22], float) if not dark else np.array([70, 40, 24], float)
    k = np.clip(rust * 0.9, 0, 1)[..., None]
    img = img * (1 - 0.55 * k) + orange * (0.55 * k) * (0.8 + 0.4 * rng.random())
    algae = np.clip(fbm(rng, n, [n / 5, n / 15], [1, 0.5]) - 0.25, 0, 1)[..., None]
    img = img * (1 - 0.6 * algae) + np.array([38, 62, 30], float) * 0.6 * algae
    shells = speckles(rng, n, 0.0025, 0.9)[..., None]
    img = img * (1 - 0.8 * shells) + 205 * 0.8 * shells
    return np.clip(img, 0, 255).astype(np.uint8), 0.5 + 0.3 * rust - 0.4 * seam + 0.5 * rivet + 0.3 * shells[..., 0]


def rotten_wood(rng, n, base):
    """v1.0.26: waterlogged old wood with algae"""
    img, h = wood(rng, n, base, 6)
    img = img.astype(float)
    algae = np.clip(fbm(rng, n, [n / 4, n / 12], [1, 0.5]) - 0.2, 0, 1)[..., None]
    img = img * (0.75 - 0.4 * algae) + np.array([40, 60, 32], float) * 0.5 * algae
    return np.clip(img, 0, 255).astype(np.uint8), h


def plaster_smooth(rng, n, base):
    """v1.0.27: painted interior wall - fine roller texture, no cracks"""
    fine = noise(rng, n, 0.6)
    blot = fbm(rng, n, [n / 6], [1])
    return colorize(base, 1 + 0.025 * fine + 0.02 * blot), 0.5 + 0.1 * fine


def flat(rng, n, base):
    return colorize(base, 1 + 0.05 * noise(rng, n, 1.0)), None


# material-name key -> (recipe, texture size, tile size in metres, normal strength or 0)
def flats(rng, n, base):
    """v1.0.40: apartment block facade - one window per 3 x 3 m tile, plaster around, balcony slab under it"""
    yy, xx = np.mgrid[0:n, 0:n] / n
    pl = 1 + 0.03 * noise(rng, n, 0.8) - 0.05 * np.clip(fbm(rng, n, [n / 6, n / 16], [1, 0.5]), 0, None)
    img = colorize(base, pl).astype(float)
    win = (xx > 0.22) & (xx < 0.78) & (yy > 0.18) & (yy < 0.66)
    frame = (xx > 0.19) & (xx < 0.81) & (yy > 0.15) & (yy < 0.69) & ~win
    sill = (xx > 0.17) & (xx < 0.83) & (yy > 0.69) & (yy < 0.74)
    glass = np.stack([0.16 + 0.10 * (1 - yy), 0.20 + 0.10 * (1 - yy), 0.26 + 0.12 * (1 - yy)], -1) * 255
    img[win] = glass[win]
    img[frame] = (235, 235, 230)
    img[sill] = (150, 150, 148)
    rough = np.where(win, 0.08, 0.8)
    return np.clip(img, 0, 255).astype(np.uint8), rough


TABLE = [
    ("flats_",       lambda r, n, b: flats(r, n, b),           512, 3.0, 0.6),      # v1.0.40 apartment blocks
    ("plaster_interior", lambda r, n, b: plaster_smooth(r, n, b), 512, 3.0, 0.4),     # v1.0.27
    ("plaster_ceiling", lambda r, n, b: plaster_smooth(r, n, b),  512, 3.0, 0.3),
    ("rust_wreck",   lambda r, n, b: rust_hull(r, n, b),      1024, 3.0, 2.5),     # v1.0.26 sunken boat
    ("rust_dark",    lambda r, n, b: rust_hull(r, n, b, True), 1024, 3.0, 2.5),
    ("wood_wreck",   lambda r, n, b: rotten_wood(r, n, b),     512, 1.5, 1.5),
    ("plaster_police", lambda r, n, b: facade_panels(r, n, b, 4, 3), 1024, 6.0, 1.5),
    ("plaster_hospital", lambda r, n, b: facade_panels(r, n, b, 4, 3), 1024, 6.0, 1.5),    # v1.0.25
    ("plaster_terminal", lambda r, n, b: facade_panels(r, n, b, 3, 2, 3.0), 1024, 6.0, 1.5),
    ("pavement_hospital", lambda r, n, b: vinyl(r, n, b),     1024, 2.4, 0.8),
    ("pavement_terminal", lambda r, n, b: terrazzo(r, n, b),  1024, 2.4, 1.0),
    ("ceramic_hospital", lambda r, n, b: pavement(r, n, b),    512, 0.6, 1.5),
    ("asphalt",      lambda r, n, b: asphalt(r, n, b),        1024, 6.0, 2.0),
    ("road_line",    lambda r, n, b: road_line(r, n, b),       256, 2.0, 0.0),
    ("pavement",     lambda r, n, b: pavement(r, n, b),       1024, 2.0, 3.0),
    ("apron",        lambda r, n, b: pavement(r, n, b),       1024, 10.0, 2.0),
    ("tiles_floor",  lambda r, n, b: pavement(r, n, b),        512, 1.2, 1.5),
    ("beach_sand",   lambda r, n, b: sand(r, n, b),            512, 3.0, 1.5),
    ("hangar_metal", lambda r, n, b: corrugated(r, n, b),      512, 3.0, 3.0),
    ("cobble",       lambda r, n, b: cobble(r, n, b),         1024, 2.0, 4.0),
    ("curb",         lambda r, n, b: curb(r, n, b),            512, 1.0, 2.0),
    ("gravel_path",  lambda r, n, b: gravel(r, n, b),          512, 2.0, 3.0),
    ("park_grass",   lambda r, n, b: grass(r, n, b, True),    1024, 4.0, 0.5),
    ("grass",        lambda r, n, b: grass(r, n, b),          1024, 4.0, 0.5),
    ("soil",         lambda r, n, b: soil(r, n, b),            512, 2.0, 2.0),
    ("river_stone",  lambda r, n, b: ashlar(r, n, b, 5),      1024, 3.0, 3.0),
    ("plinth_stone", lambda r, n, b: ashlar(r, n, b, 4),       512, 2.0, 3.0),
    ("white_stone",  lambda r, n, b: ashlar(r, n, b, 4),       512, 2.0, 2.0),
    ("red_brick",    lambda r, n, b: brick(r, n, b),          1024, 2.0, 3.0),
    ("spire",        lambda r, n, b: slate(r, n, b),           512, 2.0, 2.0),
    ("roof_tiles",   lambda r, n, b: roof(r, n, b),           1024, 3.0, 3.5),
    ("plaster_",     lambda r, n, b: plaster(r, n, b),        1024, 4.0, 1.0),
    ("floor_wood",   lambda r, n, b: wood(r, n, b, 10),        512, 2.0, 2.0),
    ("bench_wood",   lambda r, n, b: wood(r, n, b, 4),         256, 1.0, 1.0),
    ("door_frame",   lambda r, n, b: wood(r, n, b, 6),         256, 1.0, 1.0),
    ("manhole",      lambda r, n, b: manhole(r, n, b),         256, 0.8, 3.0),
    ("flowers",      lambda r, n, b: flowers(r, n, b),         256, 1.0, 1.5),
    ("fountain_water", lambda r, n, b: water(r, n, b),        256, 2.0, 0.0),
    ("window_glass", lambda r, n, b: glass(r, n, b),           256, 3.0, 0.0),
    ("busstop_glass", lambda r, n, b: glass(r, n, b),          256, 2.0, 0.0),
    ("bridge_steel", lambda r, n, b: metal(r, n, b),           256, 2.0, 0.0),
    ("lamp_pole",    lambda r, n, b: metal(r, n, b),           256, 2.0, 0.0),
    ("canopy",       lambda r, n, b: metal(r, n, b),           256, 2.0, 0.0),
    ("gold",         lambda r, n, b: metal(r, n, b),           128, 1.0, 0.0),
]


def lookup(name):
    for key, fn, size, tile, nstr in TABLE:
        if key in name:
            return key, fn, size, tile, nstr
    return None, (lambda r, n, b: flat(r, n, b)), 128, 2.0, 0.0


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    nrm = np.stack([-dx / l, dy / l, nz / l], -1)
    return ((nrm * 0.5 + 0.5) * 255).astype(np.uint8)


def _write_ppm(path, img):
    h, w, _ = img.shape
    with open(path, "wb") as f:
        f.write(f"P6 {w} {h} 255\n".encode())
        f.write(np.ascontiguousarray(img, np.uint8).tobytes())


def _to_dds(ppm, dds):
    subprocess.run(["convert", ppm, "-define", "dds:compression=dxt1", "-define", "dds:mipmaps=8", dds], check=True)


def build(name, base_rgb, seed, out_dir):
    """make <name>.dds (+ <name>_n.dds); returns (diffuse path, normal path or None, tile metres)"""
    key, fn, size, tile, nstr = lookup(name)
    import re as _re
    if size > 512 and _re.search(r"_\d+$", name):   # v1.0.45: colour variants (houses, flats) at 512 px - keeps the .ytd small
        size = 512
    rng = np.random.default_rng(seed)
    albedo, height = fn(rng, size, base_rgb)
    tmp = os.path.join(out_dir, name + ".ppm")
    dds = os.path.join(out_dir, name + ".dds")
    _write_ppm(tmp, albedo)
    _to_dds(tmp, dds)
    ndds = None
    if height is not None and nstr > 0:
        ndds = os.path.join(out_dir, name + "_n.dds")
        nrm = normal_from_height(_blur(np.asarray(height, float), 0.6), nstr * size / 256.0)
        if size > 512:                                    # v1.0.45: normal maps at half size (you cannot see the difference)
            a = np.asarray(nrm, float)
            a = (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4.0
            nrm = np.clip(a, 0, 255).astype(np.uint8)
        _write_ppm(tmp, nrm)
        _to_dds(tmp, ndds)
    os.remove(tmp)
    return dds, ndds, tile
