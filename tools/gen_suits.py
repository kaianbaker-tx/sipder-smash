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


def make_suit(name, base, web_col, legs_col, side_col, emblem_col, lens_col, rim_col,
              glove_col=None, shoe_col=None, back_col=None, back_emblem=None, hood_web=None,
              legs_web=None, web_w=2.4, extras=None):
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

    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))
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
