import os
from PIL import Image, ImageDraw, ImageFont

def create_smart_khata_icon(size):
    # Deep Emerald background #0F5132
    img = Image.new("RGBA", (size, size), (15, 81, 50, 255))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle mask
    radius = int(size * 0.22)
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=radius, fill=255)

    # Circular emblem in center with Warm Sage / Gold tint
    center = size / 2
    r_outer = size * 0.40
    draw.ellipse(
        [(center - r_outer, center - r_outer), (center + r_outer, center + r_outer)],
        fill=(20, 100, 62, 255),
        outline=(196, 106, 74, 255), # Terracotta / Gold outline
        width=max(2, int(size * 0.03))
    )

    # Storefront / Book shape
    # Roof (Triangle / Awning)
    roof_top = (center, size * 0.24)
    roof_left = (size * 0.22, size * 0.42)
    roof_right = (size * 0.78, size * 0.42)
    draw.polygon([roof_top, roof_left, roof_right], fill=(247, 243, 235, 255)) # Cream roof

    # Store Body
    body_box = [
        (size * 0.28, size * 0.42),
        (size * 0.72, size * 0.74)
    ]
    draw.rectangle(body_box, fill=(247, 243, 235, 255))

    # Doorway / Ledger mark in Emerald
    door_box = [
        (size * 0.40, size * 0.52),
        (size * 0.60, size * 0.74)
    ]
    draw.rectangle(door_box, fill=(15, 81, 50, 255))

    # Rupee / Khata symbol line
    draw.line(
        [(size * 0.34, size * 0.48), (size * 0.66, size * 0.48)],
        fill=(196, 106, 74, 255),
        width=max(1, int(size * 0.025))
    )

    # Apply mask for smooth rounded icon
    output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    output.paste(img, (0, 0), mask)
    return output

def main():
    base_res = os.path.join(os.path.dirname(__file__), "android", "app", "src", "main", "res")
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, size in densities.items():
        dir_path = os.path.join(base_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        icon = create_smart_khata_icon(size)
        icon.save(os.path.join(dir_path, "ic_launcher.png"), "PNG")
        print(f"Generated {folder}/ic_launcher.png ({size}x{size})")

    # Store 512x512 Play Store icon in assets/icon.png
    play_store_dir = os.path.join(os.path.dirname(__file__), "assets")
    os.makedirs(play_store_dir, exist_ok=True)
    icon_512 = create_smart_khata_icon(512)
    icon_512.save(os.path.join(play_store_dir, "play_store_icon.png"), "PNG")
    print("Generated assets/play_store_icon.png (512x512)")

if __name__ == "__main__":
    main()
