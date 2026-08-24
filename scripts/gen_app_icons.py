#!/usr/bin/env python3
"""从 LOGO/logo（透明底）.png 生成 LonIsle 各平台应用图标。

风格：主题色渐变（#5865F2 → #4752C4）底 + 白色 logo 线条。
- macOS：圆角矩形图标（约 22% 圆角）
- iOS：直角满幅（系统裁圆角）
- Android：直角满幅 ic_launcher.png
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO_SRC = os.path.join(ROOT, "LOGO", "logo（透明底）.png")

C1 = (0x58, 0x65, 0xF2)  # primary
C2 = (0x47, 0x52, 0xC4)  # primaryDark


def gradient_bg(size: int, radius_ratio: float = 0.0) -> Image.Image:
    """对角线渐变底；radius_ratio>0 时裁圆角（macOS 风格）。"""
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    px = grad.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = (
                round(C1[0] + (C2[0] - C1[0]) * t),
                round(C1[1] + (C2[1] - C1[1]) * t),
                round(C1[2] + (C2[2] - C1[2]) * t),
                255,
            )
    if radius_ratio > 0:
        mask = Image.new("L", (size, size), 0)
        d = ImageDraw.Draw(mask)
        d.rounded_rectangle([0, 0, size - 1, size - 1],
                            radius=int(size * radius_ratio), fill=255)
        bg.paste(grad, (0, 0), mask)
    else:
        bg = grad
    return bg


def white_logo(target: int) -> Image.Image:
    """logo 线条重着色为白色（保留 alpha），输出 target 尺寸。"""
    logo = Image.open(LOGO_SRC).convert("RGBA")
    logo.thumbnail((target, target), Image.LANCZOS)
    white = Image.new("RGBA", logo.size, (255, 255, 255, 0))
    src = logo.load()
    dst = white.load()
    for y in range(logo.size[1]):
        for x in range(logo.size[0]):
            _, _, _, a = src[x, y]
            dst[x, y] = (255, 255, 255, a)
    return white


def render(size: int, rounded: bool) -> Image.Image:
    bg = gradient_bg(size, 0.2237 if rounded else 0.0)
    mark = white_logo(int(size * 0.66))
    off = ((size - mark.width) // 2, (size - mark.height) // 2)
    bg.alpha_composite(mark, off)
    return bg


def save(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("written:", os.path.relpath(path, ROOT))


def main() -> None:
    # macOS（圆角）
    mac_dir = os.path.join(
        ROOT, "client/macos/Runner/Assets.xcassets/AppIcon.appiconset")
    for side in (16, 32, 64, 128, 256, 512, 1024):
        save(render(side, rounded=True),
             os.path.join(mac_dir, f"app_icon_{side}.png"))

    # iOS（满幅直角，filename → 实际像素）
    ios_dir = os.path.join(
        ROOT, "client/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    ios_map = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, side in ios_map.items():
        save(render(side, rounded=False), os.path.join(ios_dir, name))

    # Android（满幅直角）
    android_res = os.path.join(ROOT, "client/android/app/src/main/res")
    for density, side in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)):
        save(render(side, rounded=False),
             os.path.join(android_res, f"mipmap-{density}", "ic_launcher.png"))


if __name__ == "__main__":
    main()
