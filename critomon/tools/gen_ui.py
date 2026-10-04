"""Draw the Crito Mon logo, the app icon and the loading splash.

Run: python3 tools/gen_ui.py   (writes assets/ui/*.png)
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "assets", "ui")
FONT = os.path.join(HERE, "..", "assets", "fonts", "lilita_one_regular.ttf")
os.makedirs(OUT, exist_ok=True)

INK = (28, 22, 60)
BLUE = (40, 90, 200)
YELLOW = (255, 214, 40)
YELLOW2 = (255, 160, 20)
RED = (236, 56, 56)


def ball(d, cx, cy, r, ink=INK):
    d.ellipse((cx - r - r * 0.12, cy - r - r * 0.12, cx + r + r * 0.12, cy + r + r * 0.12), fill=ink)
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 180, 360, fill=RED)
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 0, 180, fill=(250, 250, 250))
    d.rectangle((cx - r, cy - r * 0.1, cx + r, cy + r * 0.1), fill=ink)
    d.ellipse((cx - r * 0.34, cy - r * 0.34, cx + r * 0.34, cy + r * 0.34), fill=ink)
    d.ellipse((cx - r * 0.2, cy - r * 0.2, cx + r * 0.2, cy + r * 0.2), fill=(250, 250, 250))
    # shine
    d.ellipse((cx - r * 0.62, cy - r * 0.72, cx - r * 0.3, cy - r * 0.45), fill=(255, 150, 150))


def gradient_text(size, text, font, top, bottom):
    """Text filled with a top-to-bottom gradient, returned as an RGBA image."""
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).text((0, 0), text, font=font, fill=255)
    grad = Image.new("RGBA", size)
    gd = ImageDraw.Draw(grad)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,)
        gd.line([(0, y), (size[0], y)], fill=c)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out


def logo():
    W, H = 1720, 560
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f = ImageFont.truetype(FONT, 250)
    words = [("CRITO", 90), ("MON", 1040)]
    y = 110
    layers = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layers)
    # thick outlines first: dark ink, then blue
    for word, x in words:
        d.text((x, y + 14), word, font=f, fill=INK, stroke_width=34, stroke_fill=INK)
    for word, x in words:
        d.text((x, y), word, font=f, fill=BLUE, stroke_width=24, stroke_fill=BLUE)
    im = Image.alpha_composite(im, layers.filter(ImageFilter.GaussianBlur(0.6)))
    for word, x in words:
        g = gradient_text((W, H), word, f, YELLOW, YELLOW2)
        shifted = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        shifted.paste(g, (x, y), g)
        im = Image.alpha_composite(im, shifted)
    d = ImageDraw.Draw(im)
    ball(d, 925, 260, 78)
    im = im.crop(im.getbbox())
    im.save(os.path.join(OUT, "logo.png"))
    return im


def icon():
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ball(d, 256, 256, 210)
    im.save(os.path.join(OUT, "icon.png"))


def splash(lg):
    W, H = 1280, 720
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        c = (int(60 + 120 * t), int(140 + 90 * t), int(245 - 20 * t), 255)
        d.line([(0, y), (W, y)], fill=c)
    s = lg.copy()
    s.thumbnail((980, 400))
    im.paste(s, ((W - s.width) // 2, (H - s.height) // 2 - 40), s)
    im.save(os.path.join(OUT, "splash.png"))


lg = logo()
icon()
splash(lg)
print("wrote logo.png, icon.png, splash.png")
