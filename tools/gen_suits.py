"""Paint spider-suit skins for the Kenney "Animated Characters" hero.

The UV layout (1024 px, measured with tools/uvdump.gd):
  head   x 0-640,   y 0-480   face centre ~(325, 215), back of head at the x edges
  torso  x 150-490, y 490-1024 shoulder line at y=768, chest below it, back above it (flipped)
  arms   x 0-640,   y 640-830 hands at the x edges, shoulders near x 230 / 410
  shoes  x 640-830, y 135-525 soles x 640-1024, y 0-135
  hands  x 830-1024, y 135-765 and x 640-1024, y 525-765
  legs   x 610-1024, y 765-1024 front x 640-830, back x 830-1024

Run: python3 tools/gen_suits.py  (writes assets/hero/suits/*.png)
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

S = 2  # draw at 2x then downsample for smooth lines
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "hero", "suits")
os.makedirs(OUT, exist_ok=True)


def P(x, y):
    return (x * S, y * S)


def line(d, pts, col, w):
    d.line([P(*p) for p in pts], fill=col, width=int(w * S), joint="curve")


def rect(d, x0, y0, x1, y1, col):
    d.rectangle((x0 * S, y0 * S, x1 * S, y1 * S), fill=col)


def radial_web(d, cx, cy, col, w, spokes=14, rings=(40, 80, 125, 175, 230, 290, 360), clip=None, sag=0.18, rot=0.0):
    """Spider-web lines: spokes out of (cx, cy) and saggy rings between them."""
    angs = [rot + i * 2 * math.pi / spokes for i in range(spokes)]
    far = 900
    for a in angs:
        line(d, [(cx, cy), (cx + math.cos(a) * far, cy + math.sin(a) * far)], col, w)
    for r in rings:
        for i in range(spokes):
            a0, a1 = angs[i], angs[(i + 1) % spokes] + (2 * math.pi if i == spokes - 1 else 0)
            pts = []
            for k in range(7):
                t = k / 6
                a = a0 + (a1 - a0) * t
                rr = r * (1 - sag * math.sin(t * math.pi))
                pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
            line(d, pts, col, w)


def grid_web(d, x0, y0, x1, y1, col, w, nx=5, step=34, sag=6, vertical=True):
    """Web lines for tube-like parts: long lines plus saggy cross lines."""
    if vertical:
        xs = [x0 + (x1 - x0) * i / nx for i in range(nx + 1)]
        for x in xs:
            line(d, [(x, y0), (x, y1)], col, w)
        y = y0 + step / 2
        while y < y1:
            for i in range(nx):
                xa, xb = xs[i], xs[i + 1]
                line(d, [(xa, y), ((xa + xb) / 2, y + sag), (xb, y)], col, w)
            y += step
    else:
        ys = [y0 + (y1 - y0) * i / nx for i in range(nx + 1)]
        for y in ys:
            line(d, [(x0, y), (x1, y)], col, w)
        x = x0 + step / 2
        while x < x1:
            for i in range(nx):
                ya, yb = ys[i], ys[i + 1]
                line(d, [(x, ya), (x + sag, (ya + yb) / 2), (x, yb)], col, w)
            x += step


def spider(d, cx, cy, size, col, flip=False):
    """A chunky comic spider emblem centred at (cx, cy)."""
    s = size
    fy = -1 if flip else 1
    # legs: (angle out, bend) for 4 legs per side
    legs = [(-60, -1.00), (-25, -0.35), (20, 0.35), (55, 1.0)]
    for side in (-1, 1):
        for ang, bend in legs:
            a = math.radians(ang)
            x1 = cx + side * s * 0.35
            y1 = cy + fy * s * 0.12 * bend
            x2 = x1 + side * s * 0.55 * math.cos(a)
            y2 = y1 + fy * s * 0.55 * math.sin(a) - fy * s * 0.18
            x3 = x2 + side * s * 0.25
            y3 = y2 + fy * s * 0.45 * (1 if bend > 0 else -1)
            line(d, [(cx, cy), (x1, y1), (x2, y2), (x3, y3)], col, s * 0.085)
    # body
    def ell(x, y, rx, ry):
        d.ellipse(((x - rx) * S, (y - ry) * S, (x + rx) * S, (y + ry) * S), fill=col)
    ell(cx, cy - fy * s * 0.18, s * 0.15, s * 0.18)
    ell(cx, cy + fy * s * 0.22, s * 0.2, s * 0.3)
    ell(cx, cy - fy * s * 0.42, s * 0.1, s * 0.1)


def eye(d, cx, cy, side, fill, rim, scale=1.0):
    """Big comic mask lens: a rounded teardrop tilted outward."""
    pts = []
    for k in range(40):
        t = k / 40 * 2 * math.pi
        x = math.cos(t)
        y = math.sin(t)
        # flatten the inner-bottom, pull the outer-top corner up
        y *= 0.72 + 0.28 * max(0, -y)
        x *= 1.0 + 0.25 * max(0, side * x) * max(0, -y)
        pts.append((cx + x * 40 * scale, cy + y * 34 * scale - side * x * 9 * scale))
    d.polygon([P(*p) for p in pts], fill=rim)
    inner = [(cx + (px - cx) * 0.72, cy + (py - cy) * 0.66) for px, py in pts]
    d.polygon([P(*p) for p in inner], fill=fill)


REGIONS = {
    "head": (0, 0, 640, 486),
    "front": (205, 786, 440, 1024),
    "back": (205, 486, 440, 786),
    "arm_r": (0, 640, 214, 836),
    "arm_l": (430, 640, 640, 836),
    "hands": (830, 135, 1024, 525),
    "hands2": (640, 525, 1024, 765),
    "shoes": (640, 135, 830, 525),
    "legs": (610, 765, 1024, 1024),
}


def clipped(img, box, draw_fn):
    """Run draw_fn on a transparent layer and paste it only inside box."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle(tuple(v * S for v in box), fill=255)
    alpha = Image.composite(layer.split()[3], Image.new("L", img.size, 0), mask)
    img.paste(layer.convert("RGB"), (0, 0), alpha)


# ---------------------------------------------------------------- patterns
# Extra prints for the dimension suits. Each draws inside the named regions.

PATTERN_REGIONS = {
    "body": ["front", "back"],
    "limbs": ["arm_r", "arm_l", "legs"],
    "all": ["front", "back", "arm_r", "arm_l", "legs"],
}


def _star(dd, cx, cy, r, col, points=5):
    pts = []
    for k in range(points * 2):
        a = -math.pi / 2 + k * math.pi / points
        rr = r if k % 2 == 0 else r * 0.45
        pts.append(P(cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    dd.polygon(pts, fill=col)


def _leaf(dd, cx, cy, r, ang, col):
    pts = []
    for k in range(16):
        t = k / 16 * 2 * math.pi
        x = math.cos(t) * r
        y = math.sin(t) * r * 0.45 * (1 - 0.4 * math.cos(t))
        pts.append(P(cx + x * math.cos(ang) - y * math.sin(ang), cy + x * math.sin(ang) + y * math.cos(ang)))
    dd.polygon(pts, fill=col)


def _bolt(dd, x, y, h, col):
    w = h * 0.35
    pts = [(x, y), (x + w, y), (x + w * 0.35, y + h * 0.45), (x + w * 0.85, y + h * 0.45),
           (x - w * 0.2, y + h), (x + w * 0.15, y + h * 0.55), (x - w * 0.3, y + h * 0.55)]
    dd.polygon([P(*p) for p in pts], fill=col)


def _flame(dd, x, base_y, h, w, col, up=True):
    sgn = -1 if up else 1
    pts = []
    for k in range(13):
        t = k / 12
        xx = x - w / 2 + w * t
        pts.append((xx, base_y))
    tip = (x + w * 0.1, base_y + sgn * h)
    left = (x - w * 0.15, base_y + sgn * h * 0.55)
    right = (x + w * 0.35, base_y + sgn * h * 0.45)
    poly = [(x - w / 2, base_y), left, tip, right, (x + w / 2, base_y)]
    dd.polygon([P(*p) for p in poly], fill=col)


def draw_pattern(img, suit, idx, kind, regions, cols):
    """Draw one print (dots, stars, flames...) clipped to each region."""
    rng = random.Random(f"{suit}-{idx}")
    names = PATTERN_REGIONS.get(regions, regions) if isinstance(regions, str) else regions
    for k in names:
        box = REGIONS[k]
        x0, y0, x1, y1 = box

        def fn(dd, x0=x0, y0=y0, x1=x1, y1=y1, k=k):
            if kind == "dots":
                r = cols[1] if len(cols) > 1 and isinstance(cols[1], (int, float)) else 13
                step = r * 4
                row = 0
                y = y0 + step / 2
                while y < y1 + step:
                    x = x0 + (step / 2 if row % 2 else 0)
                    while x < x1 + step:
                        rr = r * rng.uniform(0.7, 1.15)
                        dd.ellipse(((x - rr) * S, (y - rr) * S, (x + rr) * S, (y + rr) * S), fill=cols[0])
                        x += step
                    y += step
                    row += 1
            elif kind == "stars":
                n = int((x1 - x0) * (y1 - y0) / 2600)
                for _ in range(n):
                    _star(dd, rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(6, 14), rng.choice(cols))
            elif kind == "pixels":
                cell = 22
                y = y0
                while y < y1:
                    x = x0
                    while x < x1:
                        if rng.random() < 0.45:
                            rect(dd, x, y, x + cell - 2, y + cell - 2, rng.choice(cols))
                        x += cell
                    y += cell
            elif kind == "confetti":
                n = int((x1 - x0) * (y1 - y0) / 900)
                for _ in range(n):
                    x = rng.uniform(x0, x1)
                    y = rng.uniform(y0, y1)
                    rect(dd, x, y, x + rng.uniform(6, 12), y + rng.uniform(4, 8), rng.choice(cols))
            elif kind == "checker":
                cell = 32
                for j, y in enumerate(range(int(y0), int(y1) + cell, cell)):
                    for i, x in enumerate(range(int(x0), int(x1) + cell, cell)):
                        if (i + j) % 2 == 0:
                            rect(dd, x, y, x + cell, y + cell, cols[0])
            elif kind == "stripes":
                w = 18
                for i in range(-40, 60):
                    xa = x0 + i * w * 2
                    dd.polygon([P(xa, y0), P(xa + w, y0), P(xa + w + (y1 - y0), y1), P(xa + (y1 - y0), y1)], fill=cols[i % len(cols)])
            elif kind == "hatch":
                for i in range(-60, 80):
                    xa = x0 + i * 12
                    line(dd, [(xa, y0), (xa + (y1 - y0), y1)], cols[0], 2)
            elif kind == "bands":
                h = 26
                for i, y in enumerate(range(int(y0), int(y1) + h, h * 2)):
                    rect(dd, x0, y, x1, y + h, cols[i % len(cols)])
            elif kind == "rainbow":
                h = (y1 - y0) / len(cols)
                for i, c in enumerate(cols):
                    rect(dd, x0, y0 + i * h, x1, y0 + (i + 1) * h + 1, c)
            elif kind == "grid":
                step = 30
                for x in range(int(x0), int(x1) + 1, step):
                    line(dd, [(x, y0), (x, y1)], cols[0], 2.2)
                for y in range(int(y0), int(y1) + 1, step):
                    line(dd, [(x0, y), (x1, y)], cols[0], 2.2)
            elif kind == "bricks":
                h = 24
                for j, y in enumerate(range(int(y0), int(y1) + h, h)):
                    line(dd, [(x0, y), (x1, y)], cols[0], 3)
                    off = 26 if j % 2 else 0
                    for x in range(int(x0) + off, int(x1) + 52, 52):
                        line(dd, [(x, y), (x, y + h)], cols[0], 3)
            elif kind == "leaves":
                n = int((x1 - x0) * (y1 - y0) / 2200)
                for _ in range(n):
                    _leaf(dd, rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(12, 22), rng.uniform(0, math.pi), rng.choice(cols))
            elif kind == "bolts":
                n = int((x1 - x0) * (y1 - y0) / 7000) + 1
                for _ in range(n):
                    _bolt(dd, rng.uniform(x0, x1 - 20), rng.uniform(y0 - 20, y1 - 40), rng.uniform(40, 70), rng.choice(cols))
            elif kind == "flames":
                # flames lick up from the waist on the chest, and down on the back (it is flipped)
                up = k != "back"
                base_y = y1 if up else y0
                x = x0 - 10
                while x < x1 + 20:
                    hgt = rng.uniform(50, 120) if k in ("front", "back") else rng.uniform(40, 90)
                    _flame(dd, x, base_y, hgt, rng.uniform(26, 40), cols[0], up)
                    _flame(dd, x + 4, base_y, hgt * 0.55, rng.uniform(16, 24), cols[-1], up)
                    x += rng.uniform(22, 34)
            elif kind == "drips":
                x = x0
                while x < x1:
                    w = rng.uniform(14, 26)
                    h = rng.uniform(20, 80)
                    rect(dd, x, y0, x + w, y0 + h, cols[0])
                    dd.ellipse(((x - 2) * S, (y0 + h - w / 2) * S, (x + w + 2) * S, (y0 + h + w / 2) * S), fill=cols[0])
                    x += w + rng.uniform(4, 16)
                rect(dd, x0, y0, x1, y0 + 14, cols[0])

        clipped(img, box, fn)


def make_suit(name, base, web_col, legs_col, side_col, emblem_col, lens_col, rim_col,
              glove_col=None, shoe_col=None, back_col=None, back_emblem=None, hood_web=None,
              legs_web=None, web_w=2.4, extras=None, size=1024, patterns=()):
    img = Image.new("RGB", (1024 * S, 1024 * S), base)
    d = ImageDraw.Draw(img)
    glove_col = glove_col or base
    shoe_col = shoe_col or base
    R = REGIONS

    rect(d, *R["legs"], legs_col)
    rect(d, *R["shoes"], shoe_col)
    rect(d, 640, 0, 1024, 135, shoe_col)
    rect(d, *R["hands"], glove_col)
    rect(d, *R["hands2"], glove_col)
    if back_col:
        rect(d, *R["back"], back_col)
    if side_col:
        for (x0, y0, x1, y1) in (R["front"], R["back"]):
            rect(d, x0, y0, 252, y1, side_col)
            rect(d, 393, y0, x1, y1, side_col)
        rect(d, 0, 640, 640, 690, side_col)  # under the arms

    head_web = hood_web or web_col
    if head_web:
        def head(dd):
            radial_web(dd, 325, 215, head_web, web_w, spokes=16, rings=(30, 62, 100, 145, 195, 250))
            for bx in (0, 640):
                radial_web(dd, bx, 170, head_web, web_w, spokes=12, rings=(45, 95, 150, 210))
        clipped(img, R["head"], head)
    if web_col:
        clipped(img, R["front"], lambda dd: radial_web(dd, 322, 836, web_col, web_w, spokes=14, rings=(38, 78, 122, 170, 222)))
        if not back_col:
            clipped(img, R["back"], lambda dd: radial_web(dd, 322, 690, web_col, web_w, spokes=14, rings=(40, 84, 130, 180, 232)))
        for k in ("arm_r", "arm_l"):
            clipped(img, R[k], lambda dd, k=k: grid_web(dd, *R[k], web_col, web_w, nx=4, step=30, sag=7, vertical=False))
        for k in ("hands", "hands2"):
            clipped(img, R[k], lambda dd, k=k: grid_web(dd, *R[k], web_col, web_w, nx=4, step=30, sag=5, vertical=True))
        if shoe_col == base:
            clipped(img, R["shoes"], lambda dd: grid_web(dd, *R["shoes"], web_col, web_w, nx=4, step=30, sag=5, vertical=True))
    if legs_web:
        clipped(img, R["legs"], lambda dd: grid_web(dd, *R["legs"], legs_web, web_w, nx=8, step=34, sag=6, vertical=True))
    for i, (kind, regions, cols) in enumerate(patterns):
        draw_pattern(img, name, i, kind, regions, cols)
    if side_col:  # keep the side stripes clean
        for (x0, y0, x1, y1) in (R["front"], R["back"]):
            rect(d, x0, y0, 252, y1, side_col)
            rect(d, 393, y0, x1, y1, side_col)

    spider(d, 322, 846, 84, emblem_col)
    if back_emblem:
        spider(d, 322, 676, 118, back_emblem, flip=True)

    eye(d, 272, 208, -1, lens_col, rim_col, 1.05)
    eye(d, 378, 208, 1, lens_col, rim_col, 1.05)

    if extras:
        extras(d)

    img = img.resize((size, size), Image.LANCZOS)
    if size < 1024:
        # the dimension suits are flat colours: a small palette keeps the web game light
        img = img.quantize(colors=48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    img.save(os.path.join(OUT, name + ".png"), optimize=size < 1024)
    print("wrote", name)


BLACK = (18, 16, 24)
RED = (214, 32, 40)
BLUE = (34, 64, 170)

# 1. CLASSIC: red with black webbing, blue sides, back and legs
make_suit("classic", base=RED, web_col=(20, 10, 16), legs_col=BLUE, side_col=BLUE, back_col=BLUE,
          emblem_col=BLACK, lens_col=(245, 248, 255), rim_col=BLACK, back_emblem=RED)


# 2. MIDNIGHT: black suit, red webbing, red spider, red gloves and shoes
make_suit("midnight", base=(22, 20, 30), web_col=(210, 28, 44), legs_col=(22, 20, 30), side_col=None,
          emblem_col=(226, 32, 48), lens_col=(250, 250, 255), rim_col=(5, 5, 8),
          glove_col=(200, 26, 40), shoe_col=(200, 26, 40), back_emblem=(226, 32, 48), legs_web=(150, 20, 34))


# 3. GHOST: white suit with pink hood webbing, black legs, teal and pink trim
def ghost_extras(d):
    rect(d, 205, 990, 440, 1024, (40, 210, 200))    # teal belt
    rect(d, 610, 765, 1024, 792, (240, 60, 170))    # pink waistband
    for y in (720, 758):
        rect(d, 0, y, 214, y + 10, (240, 60, 170))  # pink arm stripes
        rect(d, 430, y, 640, y + 10, (240, 60, 170))


make_suit("ghost", base=(238, 238, 246), web_col=None, hood_web=(235, 70, 160), legs_col=(28, 26, 40),
          side_col=None, emblem_col=BLACK, lens_col=(250, 250, 255), rim_col=BLACK,
          glove_col=(40, 210, 200), shoe_col=(240, 60, 170), back_emblem=BLACK, extras=ghost_extras)

# 4. NOIR: black and grey, white lenses (the game turns black-and-white!)
make_suit("noir", base=(46, 46, 50), web_col=(14, 14, 16), legs_col=(26, 26, 30), side_col=(26, 26, 30),
          back_col=(26, 26, 30), emblem_col=(210, 210, 215), lens_col=(235, 235, 235), rim_col=(8, 8, 8),
          glove_col=(26, 26, 30), shoe_col=(12, 12, 14), back_emblem=(210, 210, 215))

# 5. GOLD: the secret unlock suit, gold with purple webbing
make_suit("gold", base=(250, 190, 40), web_col=(110, 30, 140), legs_col=(120, 40, 170), side_col=(120, 40, 170),
          back_col=(120, 40, 170), emblem_col=(110, 30, 140), lens_col=(120, 255, 250), rim_col=(40, 10, 60),
          back_emblem=(250, 190, 40))


# ---------------------------------------------------------------- dimension suits
# One suit per dimension: beat all the bots there to unlock it. The four older
# suits belong to a dimension too (NOIR, SPOOKY -> GHOST, GOLDEN, MIDNIGHT).
# (key, name, dimension, power, words, colours + prints)

W = (245, 248, 255)
INK = (18, 16, 24)
WHITE = (255, 255, 255)

DIM_SUITS = [
    ("candy", "CANDY", "CANDY-VERSE", "points", "Sweet stripes, like a candy cane.",
     dict(base=(255, 150, 200), web_col=WHITE, legs_col=(120, 225, 185), emblem_col=(220, 40, 90), glove_col=WHITE, shoe_col=(220, 40, 90),
          patterns=[("stripes", ["arm_r", "arm_l", "legs"], [(230, 40, 70), WHITE])])),
    ("lava", "LAVA", "LAVA-VERSE", "power", "Too hot to handle!",
     dict(base=(45, 22, 24), web_col=(255, 120, 20), legs_col=(60, 20, 20), emblem_col=(255, 140, 30), glove_col=(255, 90, 20), shoe_col=(255, 90, 20),
          lens_col=(255, 220, 120), rim_col=(40, 10, 10), patterns=[("flames", "all", [(255, 80, 10), (255, 200, 40)])])),
    ("jungle", "JUNGLE", "JUNGLE-VERSE", "stealth", "Hide in the leaves.",
     dict(base=(70, 160, 70), web_col=(25, 70, 30), legs_col=(110, 75, 40), emblem_col=(25, 70, 30), glove_col=(110, 75, 40), shoe_col=(60, 40, 20),
          patterns=[("leaves", "all", [(40, 120, 40), (140, 210, 80)])])),
    ("ice", "ICE", "ICE-VERSE", "speed", "Slippery and super cool.",
     dict(base=(225, 242, 255), web_col=(90, 170, 240), legs_col=(130, 195, 255), side_col=(90, 170, 240), emblem_col=(40, 110, 200),
          glove_col=(90, 170, 240), shoe_col=WHITE, lens_col=(200, 245, 255), rim_col=(30, 70, 140),
          patterns=[("stars", "limbs", [WHITE, (180, 220, 255)])])),
    ("desert", "DESERT", "DESERT-VERSE", "regen", "Sandy, sunny and tough.",
     dict(base=(232, 192, 122), web_col=(150, 95, 45), legs_col=(190, 140, 80), emblem_col=(120, 60, 30), glove_col=(150, 95, 45), shoe_col=(120, 70, 35),
          patterns=[("bands", ["legs", "arm_r", "arm_l"], [(205, 155, 95)])])),
    ("toy", "TOY", "TOY-VERSE", "points", "Bright like a brand-new toy.",
     dict(base=(255, 215, 40), web_col=(40, 90, 220), legs_col=(230, 40, 40), side_col=(40, 90, 220), emblem_col=(230, 40, 40), glove_col=(40, 90, 220),
          shoe_col=(230, 40, 40), patterns=[("dots", ["legs", "arm_r", "arm_l"], [WHITE])])),
    ("moon", "MOON", "MOON-VERSE", "float", "Made for low gravity.",
     dict(base=(205, 205, 215), web_col=(110, 110, 125), legs_col=(130, 130, 150), emblem_col=(60, 60, 80), glove_col=(240, 240, 250), shoe_col=(240, 240, 250),
          lens_col=(140, 220, 255), rim_col=(40, 40, 60), patterns=[("dots", "all", [(170, 170, 185), 9])])),
    ("pixel", "PIXEL", "PIXEL-VERSE", "jump", "8-bit hero, 100% cool.",
     dict(base=(90, 200, 80), web_col=INK, legs_col=(130, 80, 40), emblem_col=INK, glove_col=INK, shoe_col=(130, 80, 40),
          patterns=[("pixels", "all", [(60, 170, 60), (120, 230, 100), (40, 130, 40)])])),
    ("neon", "NEON", "NEON-VERSE", "speed", "Glows in the dark city.",
     dict(base=(15, 12, 25), web_col=(0, 240, 255), legs_col=(15, 12, 25), legs_web=(255, 0, 210), side_col=(255, 0, 210), emblem_col=(0, 240, 255),
          glove_col=(255, 0, 210), shoe_col=(0, 240, 255))),
    ("cloud", "CLOUD", "CLOUD-VERSE", "float", "Light and fluffy.",
     dict(base=WHITE, web_col=(150, 200, 255), legs_col=(170, 215, 255), emblem_col=(100, 160, 240), glove_col=(170, 215, 255), shoe_col=WHITE,
          patterns=[("dots", "limbs", [(225, 240, 255), 18])])),
    ("temple", "TEMPLE", "TEMPLE-VERSE", "regen", "Ancient marble and gold.",
     dict(base=(240, 230, 205), web_col=(210, 170, 60), legs_col=(200, 180, 140), side_col=(210, 170, 60), emblem_col=(190, 140, 40),
          glove_col=(210, 170, 60), shoe_col=(190, 140, 40), patterns=[("bricks", "limbs", [(175, 155, 115)])])),
    ("mushroom", "MUSHROOM", "MUSHROOM-VERSE", "jump", "Spotty and bouncy.",
     dict(base=(225, 50, 50), web_col=WHITE, legs_col=(235, 215, 170), emblem_col=WHITE, glove_col=WHITE, shoe_col=(150, 100, 60),
          patterns=[("dots", ["front", "back", "arm_r", "arm_l"], [WHITE, 20])])),
    ("factory", "FACTORY", "FACTORY-VERSE", "power", "Heavy-duty robot smasher.",
     dict(base=(110, 112, 122), web_col=(255, 190, 30), legs_col=(60, 62, 70), emblem_col=(255, 190, 30), glove_col=(255, 190, 30), shoe_col=(40, 40, 46),
          patterns=[("stripes", ["legs", "arm_r", "arm_l"], [(255, 190, 30), (30, 30, 30)])])),
    ("beach", "BEACH", "BEACH-VERSE", "regen", "Surf's up, bots down!",
     dict(base=(40, 200, 210), web_col=WHITE, legs_col=(250, 220, 120), side_col=(255, 120, 110), emblem_col=(255, 120, 110), glove_col=WHITE,
          shoe_col=(250, 220, 120), patterns=[("stripes", ["legs"], [WHITE, (250, 220, 120)])])),
    ("space", "SPACE", "SPACE-VERSE", "float", "A suit full of stars.",
     dict(base=(22, 22, 62), web_col=(170, 140, 255), legs_col=(30, 26, 70), emblem_col=WHITE, glove_col=(170, 140, 255), shoe_col=WHITE,
          patterns=[("stars", "all", [WHITE, (255, 230, 120)])])),
    ("autumn", "AUTUMN", "AUTUMN-VERSE", "stealth", "Crunchy leaf camo.",
     dict(base=(232, 122, 40), web_col=(110, 60, 25), legs_col=(130, 50, 30), emblem_col=(110, 60, 25), glove_col=(110, 60, 25), shoe_col=(80, 40, 20),
          patterns=[("leaves", "all", [(200, 60, 30), (255, 190, 50), (160, 90, 30)])])),
    ("crystal", "CRYSTAL", "CRYSTAL-VERSE", "points", "Sparkly purple crystals.",
     dict(base=(150, 90, 230), web_col=(255, 195, 255), legs_col=(80, 40, 140), emblem_col=(255, 195, 255), glove_col=(200, 160, 255), shoe_col=(255, 195, 255),
          patterns=[("stars", "all", [(220, 180, 255), WHITE])])),
    ("cheese", "CHEESE", "CHEESE-VERSE", "regen", "Cheesy... but powerful!",
     dict(base=(255, 212, 64), web_col=(232, 150, 30), legs_col=(255, 200, 50), emblem_col=(232, 120, 20), glove_col=(232, 150, 30), shoe_col=(232, 120, 20),
          patterns=[("dots", "all", [(232, 170, 40), 12])])),
    ("winter", "WINTER", "WINTER-VERSE", "regen", "Warm, cosy and festive.",
     dict(base=(205, 40, 50), web_col=WHITE, legs_col=WHITE, side_col=WHITE, emblem_col=WHITE, glove_col=WHITE, shoe_col=(40, 40, 40),
          patterns=[("stars", "body", [WHITE])])),
    ("brick", "BRICK", "BRICK-VERSE", "jump", "Built like a brick wall.",
     dict(base=(200, 60, 40), web_col=(255, 230, 200), legs_col=(50, 90, 200), emblem_col=(255, 230, 200), glove_col=WHITE, shoe_col=(110, 60, 30),
          patterns=[("bricks", "body", [(150, 40, 30)])])),
    ("storm", "STORM", "STORM-VERSE", "speed", "Fast as lightning.",
     dict(base=(42, 52, 74), web_col=(255, 230, 60), legs_col=(30, 36, 52), emblem_col=(255, 230, 60), glove_col=(255, 230, 60), shoe_col=(255, 230, 60),
          patterns=[("bolts", "all", [(255, 230, 60)])])),
    ("swamp", "SWAMP", "SWAMP-VERSE", "stealth", "Slimy and sneaky.",
     dict(base=(92, 112, 52), web_col=(40, 50, 25), legs_col=(70, 80, 40), emblem_col=(40, 50, 25), glove_col=(140, 170, 60), shoe_col=(60, 45, 25),
          lens_col=(220, 255, 120), patterns=[("drips", "all", [(140, 190, 60)])])),
    ("retro", "RETRO", "RETRO-VERSE", "speed", "Totally radical, dude!",
     dict(base=(255, 60, 200), web_col=(0, 240, 255), legs_col=(120, 40, 200), emblem_col=(0, 240, 255), glove_col=(0, 240, 255), shoe_col=(255, 230, 60),
          patterns=[("grid", "limbs", [(0, 240, 255)])])),
    ("party", "PARTY", "PARTY-VERSE", "points", "Confetti for everyone!",
     dict(base=(200, 150, 255), web_col=(255, 230, 60), legs_col=(255, 120, 200), emblem_col=(255, 230, 60), glove_col=(255, 230, 60), shoe_col=(80, 200, 255),
          patterns=[("confetti", "all", [(255, 80, 80), (80, 200, 255), (255, 230, 60), (100, 230, 120)])])),
    ("maze", "MAZE", "MAZE-VERSE", "stealth", "You'll never find me.",
     dict(base=(60, 145, 60), web_col=(170, 230, 120), legs_col=(200, 180, 130), emblem_col=(30, 80, 30), glove_col=(170, 230, 120), shoe_col=(120, 90, 50),
          patterns=[("grid", "body", [(40, 110, 40)])])),
    ("farm", "FARM", "FARM-VERSE", "regen", "Overalls and a plaid shirt.",
     dict(base=(60, 100, 170), web_col=(200, 220, 255), legs_col=(60, 100, 170), emblem_col=(230, 60, 50), glove_col=(230, 60, 50), shoe_col=(110, 70, 40),
          patterns=[("checker", ["arm_r", "arm_l"], [(230, 60, 50)])])),
    ("shadow", "SHADOW", "SHADOW-VERSE", "stealth", "Only your eyes glow.",
     dict(base=(14, 12, 18), web_col=(55, 55, 68), legs_col=(10, 10, 14), emblem_col=(55, 55, 68), glove_col=(10, 10, 14), shoe_col=(10, 10, 14),
          lens_col=(255, 150, 40), rim_col=(5, 5, 5))),
    ("ruins", "RUINS", "RUINS-VERSE", "power", "Old stones, new hero.",
     dict(base=(150, 160, 130), web_col=(90, 130, 60), legs_col=(110, 95, 70), emblem_col=(90, 130, 60), glove_col=(110, 95, 70), shoe_col=(80, 70, 50),
          patterns=[("bricks", "all", [(120, 130, 100)])])),
    ("underwater", "UNDERWATER", "UNDERWATER-VERSE", "float", "Blub blub! Bubbles!",
     dict(base=(20, 140, 165), web_col=(160, 255, 240), legs_col=(10, 80, 100), emblem_col=(160, 255, 240), glove_col=(255, 140, 170), shoe_col=(255, 140, 170),
          patterns=[("dots", "all", [(150, 230, 255), 7])])),
    ("mars", "MARS", "MARS-VERSE", "jump", "Red planet power.",
     dict(base=(190, 80, 40), web_col=(110, 30, 20), legs_col=(90, 40, 25), emblem_col=(255, 200, 150), glove_col=(110, 30, 20), shoe_col=(60, 25, 15),
          patterns=[("dots", "body", [(160, 60, 30), 10])])),
    ("jelly", "JELLY", "JELLY-VERSE", "jump", "Wobbly and bouncy.",
     dict(base=(140, 240, 90), web_col=(255, 90, 170), legs_col=(255, 90, 170), emblem_col=(255, 90, 170), glove_col=(255, 90, 170), shoe_col=(140, 240, 90),
          patterns=[("dots", "body", [(200, 255, 170), 11])])),
    ("blueprint", "BLUEPRINT", "BLUEPRINT-VERSE", "points", "Drawn by a genius.",
     dict(base=(30, 80, 180), web_col=WHITE, legs_col=(30, 80, 180), emblem_col=WHITE, glove_col=WHITE, shoe_col=WHITE,
          patterns=[("grid", "all", [(120, 170, 255)])])),
    ("pencil", "PENCIL", "PENCIL-VERSE", "stealth", "A walking sketch.",
     dict(base=(245, 245, 245), web_col=(60, 60, 60), legs_col=(210, 210, 210), emblem_col=(40, 40, 40), glove_col=(60, 60, 60), shoe_col=(60, 60, 60),
          lens_col=WHITE, rim_col=(40, 40, 40), patterns=[("hatch", "limbs", [(150, 150, 150)])])),
    ("chess", "CHESS", "CHESS-VERSE", "power", "Checkmate, bots!",
     dict(base=(245, 245, 245), web_col=INK, legs_col=INK, emblem_col=INK, glove_col=INK, shoe_col=(245, 245, 245),
          patterns=[("checker", ["legs"], [(245, 245, 245)]), ("checker", ["arm_r", "arm_l"], [INK])])),
    ("camp", "CAMP", "CAMP-VERSE", "regen", "Ready for a night outdoors.",
     dict(base=(45, 95, 55), web_col=(200, 190, 140), legs_col=(110, 85, 55), emblem_col=(200, 190, 140), glove_col=(200, 190, 140), shoe_col=(80, 60, 40),
          patterns=[("leaves", "limbs", [(30, 70, 40), (70, 120, 60)])])),
    ("spiral", "SPIRAL", "SPIRAL-VERSE", "speed", "Round and round we go!",
     dict(base=(110, 100, 230), web_col=WHITE, legs_col=(180, 170, 255), emblem_col=WHITE, glove_col=WHITE, shoe_col=(110, 100, 230),
          patterns=[("stripes", "limbs", [WHITE, (180, 170, 255)])])),
    ("slime", "SLIME", "SLIME-VERSE", "regen", "Gooey green power.",
     dict(base=(120, 230, 40), web_col=(30, 90, 20), legs_col=(40, 70, 25), emblem_col=(30, 90, 20), glove_col=(30, 90, 20), shoe_col=(30, 90, 20),
          patterns=[("drips", "all", [(180, 255, 90)])])),
    ("upside", "UPSIDE-DOWN", "UPSIDE-DOWN-VERSE", "jump", "The classic suit, flipped!",
     dict(base=BLUE, web_col=(20, 10, 16), legs_col=RED, side_col=RED, back_col=RED, emblem_col=RED, back_emblem=BLUE)),
    ("rainbow", "RAINBOW", "RAINBOW-VERSE", "points", "Every colour at once!",
     dict(base=WHITE, web_col=(90, 90, 120), legs_col=WHITE, emblem_col=(90, 90, 120), glove_col=(255, 80, 80), shoe_col=(120, 90, 255),
          patterns=[("rainbow", ["legs", "arm_r", "arm_l"], [(255, 70, 70), (255, 160, 40), (255, 230, 60), (90, 220, 90), (70, 150, 255), (160, 90, 255)])])),
    ("blossom", "BLOSSOM", "BLOSSOM-VERSE", "regen", "Pretty in pink petals.",
     dict(base=(255, 185, 212), web_col=WHITE, legs_col=(150, 210, 120), emblem_col=(230, 90, 140), glove_col=WHITE, shoe_col=(230, 90, 140),
          patterns=[("leaves", "body", [(255, 230, 240), (240, 120, 170)])])),
    ("electric", "ELECTRIC", "ELECTRIC-VERSE", "speed", "ZAP! Super charged.",
     dict(base=(255, 230, 40), web_col=INK, legs_col=INK, side_col=INK, emblem_col=INK, glove_col=INK, shoe_col=INK,
          patterns=[("bolts", ["legs", "arm_r", "arm_l"], [(255, 230, 40)])])),
    ("sunset", "SUNSET", "SUNSET-VERSE", "power", "Orange, pink and purple.",
     dict(base=(255, 125, 60), web_col=(110, 40, 140), legs_col=(170, 60, 150), emblem_col=(110, 40, 140), glove_col=(255, 200, 80), shoe_col=(110, 40, 140),
          patterns=[("bands", "body", [(255, 200, 80), (255, 90, 90)])])),
    ("saturn", "SATURN", "SATURN-VERSE", "float", "Rings around a hero.",
     dict(base=(230, 182, 120), web_col=(120, 80, 50), legs_col=(100, 70, 50), emblem_col=(120, 80, 50), glove_col=(200, 150, 100), shoe_col=(100, 70, 50),
          patterns=[("bands", "all", [(205, 150, 95)])])),
    ("mega", "MEGA", "MEGA-VERSE", "power", "Big hero energy.",
     dict(base=RED, web_col=(255, 200, 40), legs_col=BLUE, side_col=(255, 200, 40), emblem_col=(255, 200, 40), glove_col=(255, 200, 40),
          shoe_col=(255, 200, 40), back_emblem=(255, 200, 40))),
    ("speed", "SPEED", "SPEED-VERSE", "speed", "Zoom zoom zoom!",
     dict(base=(230, 30, 30), web_col=WHITE, legs_col=WHITE, emblem_col=WHITE, glove_col=WHITE, shoe_col=(230, 30, 30),
          patterns=[("bolts", ["legs"], [(255, 220, 40)])])),
    ("domino", "DOMINO", "DOMINO-VERSE", "points", "Black and white dots.",
     dict(base=INK, web_col=(240, 240, 240), legs_col=INK, emblem_col=(240, 240, 240), glove_col=(240, 240, 240), shoe_col=(240, 240, 240),
          patterns=[("dots", "all", [(240, 240, 240), 10])])),
    ("nightmare", "NIGHTMARE", "NIGHTMARE-VERSE", "power", "Scary red eyes.",
     dict(base=(90, 0, 12), web_col=(10, 0, 4), legs_col=(20, 0, 6), emblem_col=(10, 0, 4), glove_col=(20, 0, 6), shoe_col=(10, 0, 4),
          lens_col=(255, 40, 40), rim_col=(10, 0, 0))),
    ("web", "WEB", "WEB-VERSE", "speed", "From the home of all spiders.",
     dict(base=(25, 20, 30), web_col=(240, 240, 250), legs_col=(180, 20, 60), legs_web=(240, 240, 250), side_col=(180, 20, 60), emblem_col=(240, 240, 250),
          glove_col=(180, 20, 60), shoe_col=(180, 20, 60), back_emblem=(240, 240, 250))),
    ("glitch", "GLITCH", "GLITCH-VERSE", "all", "Beat the Glitch King to earn it.",
     dict(base=(30, 10, 50), web_col=(0, 240, 255), legs_col=(255, 0, 170), emblem_col=(0, 240, 255), glove_col=(0, 240, 255), shoe_col=(255, 0, 170),
          lens_col=WHITE, rim_col=(255, 0, 170), patterns=[("pixels", "all", [(0, 240, 255), (255, 0, 170), WHITE])])),
]

for key, _name, _dim, _perk, _desc, design in DIM_SUITS:
    design = dict(design)
    design.setdefault("side_col", None)
    design.setdefault("lens_col", W)
    design.setdefault("rim_col", INK)
    make_suit(key, size=512, **design)


# ---------------------------------------------------------------- scripts/suits.gd
# The game's list of suits, in the order of the dimensions you beat for them.

OLD = {
    "classic": ("CLASSIC", "", "regen", "The one and only!"),
    "noir": ("NOIR", "NOIR-VERSE", "power", "Black & white world!"),
    "ghost": ("GHOST", "SPOOKY-VERSE", "speed", "Hood up. Spooky and quick."),
    "gold": ("GOLDEN", "GOLDEN-VERSE", "points", "Shiny! (Or find 25 tokens.)"),
    "midnight": ("MIDNIGHT", "MIDNIGHT-VERSE", "stealth", "Dark as midnight."),
}
DIM_ORDER = ["NOIR-VERSE", "CANDY-VERSE", "LAVA-VERSE", "JUNGLE-VERSE", "ICE-VERSE", "DESERT-VERSE", "TOY-VERSE", "MOON-VERSE",
             "PIXEL-VERSE", "SPOOKY-VERSE", "NEON-VERSE", "CLOUD-VERSE", "TEMPLE-VERSE", "MUSHROOM-VERSE", "FACTORY-VERSE",
             "BEACH-VERSE", "SPACE-VERSE", "AUTUMN-VERSE", "CRYSTAL-VERSE", "CHEESE-VERSE", "WINTER-VERSE", "BRICK-VERSE",
             "STORM-VERSE", "SWAMP-VERSE", "RETRO-VERSE", "PARTY-VERSE", "MAZE-VERSE", "FARM-VERSE", "SHADOW-VERSE",
             "RUINS-VERSE", "UNDERWATER-VERSE", "MARS-VERSE", "JELLY-VERSE", "BLUEPRINT-VERSE", "PENCIL-VERSE", "CHESS-VERSE",
             "CAMP-VERSE", "GOLDEN-VERSE", "SPIRAL-VERSE", "SLIME-VERSE", "UPSIDE-DOWN-VERSE", "RAINBOW-VERSE",
             "BLOSSOM-VERSE", "ELECTRIC-VERSE", "SUNSET-VERSE", "MIDNIGHT-VERSE", "SATURN-VERSE", "MEGA-VERSE",
             "SPEED-VERSE", "DOMINO-VERSE", "NIGHTMARE-VERSE", "WEB-VERSE", "GLITCH-VERSE"]

entries = {"classic": OLD["classic"]}
by_dim = {d: k for k, (_n, d, _p, _w) in OLD.items() if d}
for key, name, dim, perk, desc, _design in DIM_SUITS:
    by_dim[dim] = key
    entries[key] = (name, dim, perk, desc)
for k, v in OLD.items():
    entries.setdefault(k, v)
order = ["classic"] + [by_dim[d] for d in DIM_ORDER]
assert len(order) == len(set(order)) == len(entries), "every dimension needs exactly one suit"

lines = [
    "class_name Suits",
    "## Every spider suit, in the order of the dimensions you beat to unlock them.",
    "## Made by tools/gen_suits.py: edit that, then re-run it.",
    "## dim = the dimension to beat (\"\" = always yours). perk = the suit's power.",
    "",
    "const LIST := {",
]
for k in order:
    name, dim, perk, desc = entries[k]
    lines.append('\t"%s": {"name": "%s", "tex": "res://assets/hero/suits/%s.png", "dim": "%s", "perk": "%s", "desc": "%s"},'
                 % (k, name, k, dim, perk, desc.replace('"', '\\"')))
lines += [
    "}",
    "",
    "const PERKS := {",
    '\t"regen": "Heals faster!",',
    '\t"stealth": "Bots spot you later!",',
    '\t"speed": "Swings super fast!",',
    '\t"power": "Hits harder!",',
    '\t"points": "DOUBLE POINTS!",',
    '\t"float": "Floaty moon jumps!",',
    '\t"jump": "Jumps extra high!",',
    '\t"all": "Has EVERY power!",',
    "}",
    "",
    "",
    "## The suit you win in a dimension (by its name, like \"LAVA-VERSE\").",
    "static func for_dim(dim_name: String) -> String:",
    "\tfor k in LIST:",
    "\t\tif LIST[k].dim == dim_name:",
    "\t\t\treturn k",
    "\treturn \"\"",
    "",
]
with open(os.path.join(os.path.dirname(__file__), "..", "scripts", "suits.gd"), "w") as f:
    f.write("\n".join(lines))
print("wrote scripts/suits.gd with", len(order), "suits")
