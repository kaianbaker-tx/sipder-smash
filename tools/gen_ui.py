"""Paint UI art for Spider Smash: the logo, HUD icons, spider tokens,
neon rooftop signs and wall graffiti.

Run: python3 tools/gen_ui.py   (writes into assets/ui)
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "assets", "ui")
FONTS = os.path.join(HERE, "..", "assets", "fonts")
os.makedirs(OUT, exist_ok=True)
random.seed(4)

BANGERS = os.path.join(FONTS, "bangers.ttf")
LUCKY = os.path.join(FONTS, "luckiest-guy.ttf")
MARKER = os.path.join(FONTS, "permanent-marker.ttf")
INK = (18, 6, 28, 255)


def font(path, size):
    return ImageFont.truetype(path, size)


def halftone(size, color, spacing=14, rmax=6, direction="diag"):
    """RGBA layer of dots that grow along a direction."""
    w, h = size
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(-spacing, h + spacing, spacing):
        for x in range(-spacing, w + spacing, spacing):
            ox = spacing // 2 if (y // spacing) % 2 else 0
            if direction == "diag":
                t = ((x + y) / (w + h))
            elif direction == "down":
                t = y / h
            else:
                t = 1.0 - abs((x / w) - 0.5) * 2
            r = rmax * max(0.0, min(1.0, t))
            if r > 0.4:
                d.ellipse((x + ox - r, y - r, x + ox + r, y + r), fill=color)
    return im


# ------------------------------------------------------------------ logo

def logo():
    W, H = 1600, 700
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def text_layer(txt, fnt, pos, fill, stroke=0, stroke_fill=None, rot=0):
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dd = ImageDraw.Draw(lay)
        dd.text(pos, txt, font=fnt, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=stroke_fill)
        if rot:
            lay = lay.rotate(rot, resample=Image.BICUBIC, center=pos)
        return lay

    f1 = font(BANGERS, 300)
    f2 = font(BANGERS, 340)
    lines = [("SPIDER", (W // 2 - 20, 190), f1, -4), ("SMASH!", (W // 2 + 20, 470), f2, -4)]
    for txt, pos, fnt, rot in lines:
        # extruded depth: stacked dark copies
        for k in range(22, 0, -1):
            img.alpha_composite(text_layer(txt, fnt, (pos[0] + k, pos[1] + k), (40, 8, 60, 255), 14, (40, 8, 60, 255), rot))
        # cyan / magenta misprint
        img.alpha_composite(text_layer(txt, fnt, (pos[0] - 9, pos[1] - 4), (0, 230, 255, 255), 14, (0, 230, 255, 255), rot))
        img.alpha_composite(text_layer(txt, fnt, (pos[0] + 9, pos[1] + 4), (255, 40, 150, 255), 14, (255, 40, 150, 255), rot))
        # main face: red to yellow gradient with halftone
        face = text_layer(txt, fnt, pos, (255, 255, 255, 255), 0, None, rot)
        grad = Image.new("RGBA", (W, H))
        gd = ImageDraw.Draw(grad)
        top = pos[1] - 150
        for y in range(H):
            t = max(0.0, min(1.0, (y - top) / 300))
            c = (int(255), int(230 - 190 * t), int(60 - 30 * t), 255)
            gd.line([(0, y), (W, y)], fill=c)
        dots = halftone((W, H), (255, 255, 180, 255), 16, 6, "down")
        grad.alpha_composite(dots)
        face_col = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        face_col.paste(grad, (0, 0), face)
        outline = text_layer(txt, fnt, pos, (0, 0, 0, 0), 14, INK, rot)
        img.alpha_composite(outline)
        img.alpha_composite(face_col)
        # shine stripe
        shine = text_layer(txt, fnt, (pos[0], pos[1]), (255, 255, 255, 255), 0, None, rot)
        mask = Image.new("L", (W, H), 0)
        md = ImageDraw.Draw(mask)
        md.polygon([(0, pos[1] - 120), (W, pos[1] - 170), (W, pos[1] - 150), (0, pos[1] - 100)], fill=170)
        sh = Image.new("RGBA", (W, H), (255, 255, 255, 0))
        sh.putalpha(ImageChops.multiply(mask, shine.split()[3]))
        img.alpha_composite(sh)
    # little spider emblem between the words
    d = ImageDraw.Draw(img)
    cx, cy, s = W // 2 + 470, 300, 70
    for side in (-1, 1):
        for k, (a, l) in enumerate([(-50, 1.0), (-15, 1.1), (20, 1.1), (55, 1.0)]):
            ang = math.radians(a)
            x1 = cx + side * s * 0.35
            y1 = cy + s * 0.1 * (k - 1.5)
            x2 = x1 + side * s * 0.7 * math.cos(ang) * l
            y2 = y1 + s * 0.7 * math.sin(ang) * l - s * 0.3
            x3 = x2 + side * s * 0.3
            y3 = y2 + s * 0.6 * (1 if k > 1 else -1)
            d.line([(cx, cy), (x1, y1), (x2, y2), (x3, y3)], fill=INK, width=12, joint="curve")
    d.ellipse((cx - 22, cy - 40, cx + 22, cy + 10), fill=INK)
    d.ellipse((cx - 30, cy - 5, cx + 30, cy + 70), fill=INK)
    img = img.crop(img.getbbox())
    img.save(os.path.join(OUT, "logo.png"))
    print("logo", img.size)


# ------------------------------------------------------------------ icons

def mask_icon(name, fill, lens, rim, web):
    S = 128
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((10, 6, 118, 124), fill=INK)
    d.ellipse((16, 12, 112, 118), fill=fill)
    if web:
        cx, cy = 64, 70
        for k in range(12):
            a = k * math.pi / 6
            d.line([(cx, cy), (cx + math.cos(a) * 60, cy + math.sin(a) * 60)], fill=web, width=2)
        for r in (16, 30, 44):
            d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=web, width=2)
        # clip back to the head
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).ellipse((16, 12, 112, 118), fill=255)
        base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(base).ellipse((10, 6, 118, 124), fill=INK)
        base.paste(im, (0, 0), m)
        im = base
        d = ImageDraw.Draw(im)
    for side in (-1, 1):
        cx = 64 + side * 24
        pts = []
        for k in range(30):
            t = k / 30 * 2 * math.pi
            x = math.cos(t)
            y = math.sin(t) * (0.72 + 0.28 * max(0, -math.sin(t)))
            pts.append((cx + x * 20, 62 + y * 17 - side * x * 5))
        d.polygon(pts, fill=rim)
        inner = [(cx + (px - cx) * 0.7, 62 + (py - 62) * 0.62) for px, py in pts]
        d.polygon(inner, fill=lens)
    im.save(os.path.join(OUT, name + ".png"))


def token():
    S = 256
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((8, 8, 248, 248), fill=INK)
    d.ellipse((20, 20, 236, 236), fill=(255, 196, 40, 255))
    d.ellipse((34, 34, 222, 222), fill=(255, 226, 90, 255))
    dots = halftone((S, S), (255, 160, 20, 255), 12, 4.5, "diag")
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse((34, 34, 222, 222), fill=255)
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    lay.paste(dots, (0, 0), ImageChops.multiply(m, dots.split()[3]))
    im.alpha_composite(lay)
    # spider
    cx, cy, s = 128, 132, 80
    for side in (-1, 1):
        for k, a in enumerate([-55, -20, 20, 55]):
            ang = math.radians(a)
            x1 = cx + side * s * 0.3
            y1 = cy + s * 0.08 * (k - 1.5)
            x2 = x1 + side * s * 0.55 * math.cos(ang)
            y2 = y1 + s * 0.55 * math.sin(ang) - s * 0.2
            x3 = x2 + side * s * 0.2
            y3 = y2 + s * 0.45 * (1 if k > 1 else -1)
            d.line([(cx, cy), (x1, y1), (x2, y2), (x3, y3)], fill=INK, width=9, joint="curve")
    d.ellipse((cx - 14, cy - 34, cx + 14, cy), fill=INK)
    d.ellipse((cx - 20, cy - 6, cx + 20, cy + 46), fill=INK)
    d.ellipse((cx - 9, cy - 50, cx + 9, cy - 32), fill=INK)
    # shine
    d.arc((40, 40, 216, 216), 200, 250, fill=(255, 255, 255, 230), width=10)
    im.save(os.path.join(OUT, "token.png"))


def reticle():
    S = 96
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    for k in range(8):
        a = k * math.pi / 4
        d.line([(c + math.cos(a) * 12, c + math.sin(a) * 12), (c + math.cos(a) * 40, c + math.sin(a) * 40)], fill=(255, 255, 255, 230), width=3)
    for r in (20, 32):
        pts = []
        for k in range(9):
            a = k * math.pi / 4
            pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
        d.line(pts, fill=(255, 255, 255, 230), width=3)
    d.ellipse((c - 4, c - 4, c + 4, c + 4), fill=(255, 60, 120, 255))
    im.save(os.path.join(OUT, "reticle.png"))


# ------------------------------------------------------------------ signs

SIGNS = [
    ("PIZZA", (255, 70, 90), (40, 10, 30), "slice"),
    ("SMASH COLA", (255, 230, 60), (200, 20, 40), None),
    ("ARCADE", (0, 240, 255), (30, 10, 60), "star"),
    ("NOODLES", (255, 140, 30), (20, 30, 60), None),
    ("KAIAN'S DINER", (255, 90, 200), (20, 10, 40), "star"),
    ("24 HR BAGELS", (140, 255, 120), (20, 40, 30), None),
    ("HOT DOGS", (255, 210, 60), (160, 20, 50), None),
    ("SPIDEY FANS", (255, 60, 70), (20, 20, 90), "spider"),
    ("COMICS", (255, 255, 255), (230, 40, 120), "star"),
    ("GLITCH TECH", (0, 255, 200), (10, 10, 20), None),
]


def neon_sign(i, txt, glow, bg, deco):
    W, H = 512, 192
    im = Image.new("RGBA", (W, H), bg + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, W - 1, H - 1), outline=INK, width=10)
    d.rectangle((14, 14, W - 15, H - 15), outline=glow + (255,), width=4)
    size = 110 if len(txt) < 8 else (84 if len(txt) < 12 else 66)
    f = font(BANGERS, size)
    glow_l = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow_l).text((W // 2, H // 2 + 4), txt, font=f, fill=glow + (255,), anchor="mm", stroke_width=10, stroke_fill=glow + (255,))
    glow_l = glow_l.filter(ImageFilter.GaussianBlur(10))
    im.alpha_composite(glow_l)
    d = ImageDraw.Draw(im)
    d.text((W // 2 + 5, H // 2 + 9), txt, font=f, fill=INK, anchor="mm")
    d.text((W // 2, H // 2 + 4), txt, font=f, fill=(255, 255, 240, 255), anchor="mm", stroke_width=4, stroke_fill=glow + (255,))
    if deco == "star":
        for x in (40, W - 40):
            pts = []
            for k in range(10):
                a = -math.pi / 2 + k * math.pi / 5
                r = 22 if k % 2 == 0 else 9
                pts.append((x + math.cos(a) * r, H // 2 + math.sin(a) * r))
            d.polygon(pts, fill=glow + (255,), outline=INK)
    im.save(os.path.join(OUT, "sign_%d.png" % i))


def graffiti(i, txt, cols):
    W, H = 512, 256
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f = font(MARKER, 120 if len(txt) < 7 else 90)
    d = ImageDraw.Draw(im)
    # spray blob background
    for k in range(40):
        x = random.randint(40, W - 40)
        y = random.randint(60, H - 60)
        r = random.randint(20, 60)
        d.ellipse((x - r, y - r, x + r, y + r), fill=cols[2] + (200,))
    d.text((W // 2 + 8, H // 2 + 8), txt, font=f, fill=INK, anchor="mm")
    d.text((W // 2, H // 2), txt, font=f, fill=cols[0] + (255,), anchor="mm", stroke_width=6, stroke_fill=cols[1] + (255,))
    # drips
    for k in range(8):
        x = random.randint(80, W - 80)
        y = random.randint(H // 2, H // 2 + 40)
        ln = random.randint(20, 70)
        d.line([(x, y), (x, y + ln)], fill=cols[1] + (255,), width=6)
        d.ellipse((x - 5, y + ln - 5, x + 5, y + ln + 5), fill=cols[1] + (255,))
    im.save(os.path.join(OUT, "graffiti_%d.png" % i))


if __name__ == "__main__":
    logo()
    mask_icon("hp_full", (220, 30, 45, 255), (250, 250, 255, 255), INK, (20, 5, 15, 255))
    mask_icon("hp_empty", (70, 50, 90, 200), (120, 110, 140, 200), (40, 25, 55, 220), None)
    token()
    reticle()
    for i, s in enumerate(SIGNS):
        neon_sign(i, *s)
    tags = [("SMASH!", ((255, 60, 150), (40, 0, 60), (0, 200, 255))),
            ("KAIAN", ((255, 230, 40), (200, 20, 60), (120, 30, 200))),
            ("THWIP", ((0, 240, 255), (30, 0, 80), (255, 80, 180))),
            ("WEB", ((140, 255, 90), (20, 60, 20), (255, 140, 0))),
            ("GO SPIDEY", ((255, 255, 255), (230, 20, 60), (40, 40, 200)))]
    for i, (t, c) in enumerate(tags):
        graffiti(i, t, c)
    print("done")
