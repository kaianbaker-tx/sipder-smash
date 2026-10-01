"""Paint outfits (skins) for the Kenney "Animated Characters" people.

UV layout of the 1024 px skins (see the Spideys tools/gen_suits.py notes):
  head   x 0-640,   y 0-490    hair, face (face centre ~ 325, 215)
  torso  x 150-490, y 490-1024 chest below y 768, back above it
  sleeves x 0-150 and 490-640, y 490-1024
  shoes  x 640-830, y 135-525  (soles x 640-1024, y 0-135)
  hands  x 830-1024, y 135-765 and x 640-1024, y 525-765
  legs   x 610-1024, y 765-1024

Run: python3 tools/gen_skins.py   (writes assets/chars/skins/*.png)
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
SKINS = os.path.join(HERE, "..", "assets", "chars", "skins")

SKIN_TONE = (246, 150, 115)


def load(name):
    return Image.open(os.path.join(SKINS, name + ".png")).convert("RGBA")


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def recolor_hair(im, col):
    """Flood fill the hair from the top of the head: dark (or teal streak)
    pixels joined to the top edge. Eyes and mouth are not joined, so they stay."""
    px = im.load()

    def is_hair(c):
        r, g, b = c[0], c[1], c[2]
        return lum((r, g, b)) < 0.34 or (g > r + 40 and b > r + 20)

    seen = set()
    todo = [(x, 2) for x in range(0, 640, 8) if is_hair(px[x, 2])]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < 640 and 0 <= y < 490):
            continue
        if not is_hair(px[x, y]):
            continue
        seen.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for (x, y) in seen:
        r, g, b, a = px[x, y]
        k = min(1.25, lum((r, g, b)) / 0.2 + 0.45)
        px[x, y] = (min(255, int(col[0] * k)), min(255, int(col[1] * k)), min(255, int(col[2] * k)), a)


def friendly_face(im, brow=(70, 45, 30)):
    """The criminalMaleA face frowns and has a scar: paint skin over the
    eyebrows and the scar, then draw raised eyebrows and a smile."""
    px = im.load()
    skin = px[290, 240]
    d = ImageDraw.Draw(im)
    for box in [(260, 188, 314, 211), (298, 211, 314, 220), (326, 182, 386, 209), (328, 209, 347, 218)]:
        d.rectangle(box, fill=skin)
    d.line([(375, 219), (354, 260)], fill=skin, width=11)
    for cx in (287, 357):
        d.arc((cx - 17, 194, cx + 17, 212), 200, 340, fill=brow + (255,), width=6)
    d.arc((306, 266, 340, 284), 20, 160, fill=(70, 30, 30, 255), width=4)


def fill(im, box, col, shade=0.12):
    """Flat fill with a soft top-to-bottom shade."""
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0)
        k = 1.0 - shade * t
        d.line([(x0, y), (x1 - 1, y)], fill=(int(col[0] * k), int(col[1] * k), int(col[2] * k), 255))


def bare_hands(im):
    """Paint gloves / dark marks on the hands back to skin colour."""
    px = im.load()
    for y in range(135, 765):
        for x in range(640, 1024):
            if x < 830 and y < 525:
                continue  # shoes
            r, g, b, a = px[x, y]
            if lum((r, g, b)) < 0.45:
                px[x, y] = SKIN_TONE + (255,)


def shoes(im, col):
    px = im.load()
    for y in range(135, 525):
        for x in range(640, 830):
            r, g, b, a = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            if mx - mn > 40 or lum((r, g, b)) < 0.3:
                k = max(0.6, lum((r, g, b)) / 0.5)
                px[x, y] = (min(255, int(col[0] * k)), min(255, int(col[1] * k)), min(255, int(col[2] * k)), a)


def outfit(base, shirt, pants, sleeves=None, shoe=(230, 60, 60), hair=None, bare=True):
    im = load(base)
    if hair:
        recolor_hair(im, hair)
    fill(im, (150, 490, 490, 1024), shirt)
    s = sleeves or shirt
    fill(im, (0, 490, 150, 1024), s)
    fill(im, (490, 490, 640, 1024), s)
    fill(im, (610, 765, 1024, 1024), pants, 0.2)
    if bare:
        bare_hands(im)
    shoes(im, shoe)
    return im


def ball_emblem(im, cx, cy, r):
    d = ImageDraw.Draw(im)
    d.ellipse((cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6), fill=(30, 20, 40, 255))
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 180, 360, fill=(240, 50, 50, 255))
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 0, 180, fill=(250, 250, 250, 255))
    d.rectangle((cx - r, cy - 5, cx + r, cy + 5), fill=(30, 20, 40, 255))
    d.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=(30, 20, 40, 255))
    d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), fill=(250, 250, 250, 255))


def stripe(im, box, col):
    ImageDraw.Draw(im).rectangle(box, fill=col + (255,))


def checker(im, box, a, b, n=34):
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    for y in range(y0, y1, n):
        for x in range(x0, x1, n):
            c = a if ((x - x0) // n + (y - y0) // n) % 2 == 0 else b
            d.rectangle((x, y, min(x1, x + n) - 1, min(y1, y + n) - 1), fill=c + (255,))


def dots(im, box, col, n=40, r=9):
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    for y in range(y0 + n // 2, y1, n):
        off = n // 2 if ((y - y0) // n) % 2 else 0
        for x in range(x0 + off, x1, n):
            d.ellipse((x - r, y - r, x + r, y + r), fill=col + (255,))


def save(im, name):
    im.save(os.path.join(SKINS, name + ".png"))
    print("wrote", name)


def main():
    # you: red jacket with a white stripe and a Crito Ball on the chest
    im = outfit("skaterMaleA", (225, 45, 50), (45, 55, 90), sleeves=(235, 235, 240), shoe=(225, 45, 50))
    stripe(im, (150, 930, 490, 960), (245, 245, 250))
    ball_emblem(im, 320, 850, 46)
    save(im, "player")
    # the rival: green hoodie, blond hair
    im = outfit("skaterMaleA", (60, 175, 110), (35, 35, 45), sleeves=(40, 150, 95), shoe=(250, 250, 250), hair=(235, 190, 80))
    stripe(im, (300, 768, 340, 1024), (230, 230, 230))
    save(im, "rival")
    # Professor Birch: white lab coat over a teal shirt
    im = outfit("criminalMaleA", (245, 245, 248), (180, 150, 110), sleeves=(240, 240, 245), shoe=(120, 80, 50), hair=(110, 70, 40))
    friendly_face(im, (85, 52, 30))
    stripe(im, (290, 768, 350, 1024), (40, 150, 160))
    stripe(im, (180, 880, 250, 890), (200, 200, 205))
    save(im, "prof")
    # lab aide: white coat, dark hair
    im = outfit("skaterMaleA", (245, 245, 248), (60, 70, 90), sleeves=(240, 240, 245), shoe=(70, 70, 80), hair=(40, 40, 50))
    stripe(im, (295, 768, 345, 1024), (90, 120, 200))
    save(im, "aide")
    # mom: pink top
    im = outfit("skaterFemaleA", (245, 130, 170), (70, 100, 170), shoe=(250, 250, 250))
    save(im, "mom")
    # youngster: blue shirt, tan shorts
    im = outfit("skaterMaleA", (60, 120, 230), (200, 170, 120), shoe=(250, 250, 250), hair=(60, 40, 30))
    save(im, "youngster")
    # lass: purple dress with dots, orange hair
    im = outfit("skaterFemaleA", (170, 90, 210), (170, 90, 210), shoe=(250, 120, 150), hair=(240, 130, 50))
    dots(im, (150, 490, 490, 1024), (230, 180, 250))
    save(im, "lass")
    # bug catcher: green shirt, brown shorts
    im = outfit("skaterMaleA", (120, 190, 70), (140, 100, 60), shoe=(90, 70, 50), hair=(40, 30, 25))
    save(im, "bugcatcher")
    # hiker: brown shirt, olive pants
    im = outfit("criminalMaleA", (170, 110, 60), (110, 120, 70), shoe=(90, 60, 40), hair=(70, 45, 30))
    friendly_face(im, (55, 35, 25))
    save(im, "hiker")
    # Connect Four kid: red and yellow checks
    im = outfit("skaterFemaleA", (230, 50, 50), (40, 70, 200), shoe=(250, 210, 40), hair=(90, 50, 160))
    checker(im, (150, 490, 490, 1024), (230, 50, 50), (250, 210, 40))
    save(im, "c4kid")
    # Connect Four grandma: lavender cardigan, grey hair
    im = outfit("skaterFemaleA", (190, 160, 225), (110, 90, 140), shoe=(120, 90, 70), hair=(215, 215, 225))
    dots(im, (150, 768, 490, 1024), (250, 210, 40), 60, 14)
    save(im, "grandma")
    # nurse: pink and white
    im = outfit("skaterFemaleA", (250, 250, 252), (250, 170, 200), sleeves=(250, 170, 200), shoe=(250, 250, 252), hair=(250, 140, 190))
    stripe(im, (290, 800, 350, 860), (240, 60, 90))
    stripe(im, (260, 820, 380, 840), (240, 60, 90))
    save(im, "nurse")
    # town kid: orange shirt
    im = outfit("skaterMaleA", (250, 150, 40), (60, 80, 150), shoe=(60, 160, 240), hair=(30, 25, 25))
    save(im, "kid")


if __name__ == "__main__":
    main()
