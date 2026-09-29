"""앱 아이콘 생성 스크립트. 실행: python tool/make_icon.py
assets/icon/icon.png (1024x1024, 배경 포함) 과
assets/icon/icon_fg.png (Android adaptive 전경, 투명 배경) 을 만든다.
디자인: 주황 그라데이션 배경 위에 왕관을 쓴 금화."""
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
os.makedirs(OUT, exist_ok=True)

TOP = (255, 190, 80)
BOTTOM = (240, 110, 0)
GOLD = (255, 205, 50)
GOLD_DARK = (214, 140, 0)
GOLD_LIGHT = (255, 236, 150)
CROWN = (255, 225, 90)
GEM = (230, 57, 70)


def gradient_bg(size):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img


def draw_fg(scale):
    """전경(동전 + 왕관)을 투명 캔버스에 그린다. scale 은 캔버스 대비 크기."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    cx, cy = SIZE / 2, SIZE / 2 + 60 * scale
    r = 300 * scale
    # 그림자
    sh = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 30 * scale, cx + r, cy + r + 30 * scale], fill=(90, 40, 0, 110))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(24 * scale)))
    d = ImageDraw.Draw(img)
    # 동전: 테두리 → 본체 → 안쪽 링
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_DARK)
    r2 = r * 0.9
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=GOLD)
    r3 = r * 0.74
    d.ellipse([cx - r3, cy - r3, cx + r3, cy + r3], outline=GOLD_DARK, width=int(14 * scale))
    # 하이라이트
    d.arc([cx - r2 * 0.88, cy - r2 * 0.88, cx + r2 * 0.88, cy + r2 * 0.88], 200, 250, fill=GOLD_LIGHT, width=int(22 * scale))
    # 가운데 별
    import math
    pts = []
    for k in range(10):
        rad = r3 * (0.72 if k % 2 == 0 else 0.3)
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    d.polygon(pts, fill=GOLD_DARK)
    # 왕관 (동전 위쪽)
    top = cy - r - 150 * scale
    base = cy - r + 40 * scale
    left, right = cx - 230 * scale, cx + 230 * scale
    pts = [(left, base), (left - 20 * scale, top + 30 * scale), (cx - 120 * scale, top + 110 * scale),
           (cx, top - 10 * scale), (cx + 120 * scale, top + 110 * scale), (right + 20 * scale, top + 30 * scale),
           (right, base)]
    d.polygon(pts, fill=CROWN, outline=GOLD_DARK)
    d.line(pts + [pts[0]], fill=GOLD_DARK, width=int(12 * scale), joint="curve")
    for (x, y) in [pts[1], pts[3], pts[5]]:
        rr = 30 * scale
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=GEM, outline=GOLD_DARK, width=int(6 * scale))
    return img


bg = gradient_bg(SIZE).convert("RGBA")
Image.alpha_composite(bg, draw_fg(1.0)).convert("RGB").save(os.path.join(OUT, "icon.png"))
# adaptive 전경은 안전 영역(가운데 66%)에 들어가도록 축소
fg = draw_fg(1.0).resize((int(SIZE * 0.62),) * 2, Image.LANCZOS)
canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
off = (SIZE - fg.width) // 2
canvas.paste(fg, (off, off), fg)
canvas.save(os.path.join(OUT, "icon_fg.png"))
print("done")
