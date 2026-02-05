#!/usr/bin/env python3
"""
Generate 16x16 pixel art sprites for Outpost game.
Creates asset catalog structure for Xcode.
"""

from PIL import Image, ImageDraw
import os
import json

TILE_SIZE = 16
ASSETS_PATH = "Outpost/Assets.xcassets"

def create_imageset(name, category, image):
    """Create an .imageset folder with the image and Contents.json"""
    folder_path = os.path.join(ASSETS_PATH, category, f"{name}.imageset")
    os.makedirs(folder_path, exist_ok=True)

    # Save image at 1x, 2x, 3x
    for scale in [1, 2, 3]:
        scaled_size = TILE_SIZE * scale
        scaled_img = image.resize((scaled_size, scaled_size), Image.NEAREST)
        suffix = "" if scale == 1 else f"@{scale}x"
        scaled_img.save(os.path.join(folder_path, f"{name}{suffix}.png"))

    # Create Contents.json
    contents = {
        "images": [
            {"filename": f"{name}.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"}
        ],
        "info": {"author": "xcode", "version": 1}
    }
    with open(os.path.join(folder_path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

def create_folder_contents(path):
    """Create Contents.json for asset folder"""
    contents = {
        "info": {"author": "xcode", "version": 1},
        "properties": {"provides-namespace": True}
    }
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

# Color palette (retro pixel art style)
COLORS = {
    # Greens
    'grass_light': (98, 168, 68),
    'grass_dark': (68, 138, 48),
    'tree_dark': (34, 82, 34),
    'tree_light': (54, 112, 54),
    'shrub': (78, 128, 58),
    'plant_green': (88, 178, 88),

    # Browns
    'dirt_light': (158, 118, 78),
    'dirt_dark': (128, 88, 58),
    'wood_light': (168, 128, 88),
    'wood_med': (138, 98, 58),
    'wood_dark': (108, 78, 48),
    'bark': (88, 58, 38),

    # Grays/Stone
    'stone_light': (148, 148, 148),
    'stone_med': (118, 118, 118),
    'stone_dark': (88, 88, 88),
    'wall_dark': (68, 68, 68),

    # Blues
    'water_light': (88, 148, 218),
    'water_dark': (58, 118, 188),
    'water_deep': (38, 88, 158),

    # Metals
    'metal_light': (178, 178, 188),
    'metal_dark': (128, 128, 138),
    'gold': (218, 178, 58),
    'gold_dark': (178, 138, 38),

    # Creatures
    'skin': (218, 178, 138),
    'skin_dark': (188, 148, 108),
    'beard_brown': (98, 68, 48),
    'goblin_green': (88, 138, 68),
    'goblin_dark': (58, 108, 48),
    'wolf_gray': (128, 128, 128),
    'wolf_dark': (88, 88, 88),
    'bear_brown': (118, 78, 48),
    'bear_dark': (88, 58, 38),
    'giant_purple': (138, 108, 148),
    'undead_pale': (158, 178, 158),
    'undead_dark': (108, 128, 108),

    # Items
    'bread': (218, 178, 98),
    'meat_red': (198, 78, 78),
    'meat_dark': (158, 58, 58),
    'ale': (168, 118, 48),
    'fabric_red': (178, 68, 68),
    'fabric_blue': (68, 98, 158),

    # UI
    'select_yellow': (255, 238, 68),
    'select_orange': (255, 178, 38),

    # Special
    'empty': (28, 28, 38),
    'black': (0, 0, 0),
    'white': (255, 255, 255),
}

def new_image():
    return Image.new('RGBA', (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))

def draw_pixel(img, x, y, color):
    if 0 <= x < TILE_SIZE and 0 <= y < TILE_SIZE:
        if isinstance(color, str):
            color = COLORS[color]
        img.putpixel((x, y), color + (255,))

def fill_rect(img, x, y, w, h, color):
    for py in range(y, y + h):
        for px in range(x, x + w):
            draw_pixel(img, px, py, color)

# ============== TERRAIN SPRITES ==============

def terrain_empty_air():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'empty')
    # Add some subtle noise/stars
    for pos in [(3, 4), (8, 2), (12, 7), (5, 12), (14, 11)]:
        draw_pixel(img, pos[0], pos[1], (48, 48, 58, 255)[:3])
    return img

def terrain_grass():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'grass_dark')
    # Add lighter grass patches
    for y in range(16):
        for x in range(16):
            if (x + y) % 3 == 0:
                draw_pixel(img, x, y, 'grass_light')
    # Add grass blades on top
    for x in [1, 4, 7, 10, 13]:
        draw_pixel(img, x, 0, 'grass_light')
        draw_pixel(img, x+1, 1, 'grass_light')
    return img

def terrain_dirt():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'dirt_dark')
    # Add texture
    for y in range(16):
        for x in range(16):
            if (x * 3 + y * 7) % 5 == 0:
                draw_pixel(img, x, y, 'dirt_light')
    # Small rocks
    for pos in [(3, 5), (10, 8), (6, 12)]:
        draw_pixel(img, pos[0], pos[1], 'stone_med')
    return img

def terrain_stone():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_med')
    # Cracks and texture
    for y in range(16):
        for x in range(16):
            if (x * 5 + y * 3) % 7 == 0:
                draw_pixel(img, x, y, 'stone_dark')
            elif (x * 2 + y * 5) % 9 == 0:
                draw_pixel(img, x, y, 'stone_light')
    return img

def terrain_water():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'water_dark')
    # Waves
    for y in range(0, 16, 4):
        for x in range(16):
            if (x + y//4) % 4 < 2:
                draw_pixel(img, x, y, 'water_light')
                draw_pixel(img, x, y+1, 'water_light')
    # Highlights
    for pos in [(2, 3), (8, 7), (13, 11)]:
        draw_pixel(img, pos[0], pos[1], (128, 188, 238))
    return img

def terrain_tree():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'grass_dark')
    # Trunk
    fill_rect(img, 6, 10, 4, 6, 'bark')
    fill_rect(img, 7, 11, 2, 4, 'wood_dark')
    # Foliage (circular canopy)
    fill_rect(img, 3, 2, 10, 9, 'tree_dark')
    fill_rect(img, 2, 4, 12, 5, 'tree_dark')
    # Highlights
    fill_rect(img, 4, 3, 4, 4, 'tree_light')
    draw_pixel(img, 5, 4, 'shrub')
    return img

def terrain_shrub():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'grass_dark')
    # Bush shape
    fill_rect(img, 3, 6, 10, 8, 'shrub')
    fill_rect(img, 5, 4, 6, 4, 'shrub')
    # Highlights
    for pos in [(5, 7), (8, 5), (10, 8)]:
        draw_pixel(img, pos[0], pos[1], 'grass_light')
    # Berries
    for pos in [(6, 9), (9, 7), (11, 10)]:
        draw_pixel(img, pos[0], pos[1], (198, 58, 58))
    return img

def terrain_wall():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'wall_dark')
    # Rock face texture
    fill_rect(img, 0, 0, 8, 6, 'stone_dark')
    fill_rect(img, 8, 0, 8, 8, 'stone_med')
    fill_rect(img, 0, 6, 10, 6, 'stone_med')
    fill_rect(img, 10, 8, 6, 8, 'stone_dark')
    # Cracks
    for pos in [(4, 3), (12, 5), (6, 10), (3, 13)]:
        draw_pixel(img, pos[0], pos[1], 'black')
    return img

def terrain_ore():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_dark')
    # Ore veins
    fill_rect(img, 2, 3, 4, 3, 'gold')
    fill_rect(img, 9, 7, 5, 4, 'gold')
    fill_rect(img, 4, 11, 3, 3, 'gold')
    # Sparkles
    for pos in [(3, 4), (11, 8), (5, 12)]:
        draw_pixel(img, pos[0], pos[1], 'gold_dark')
    for pos in [(4, 3), (10, 9), (6, 11)]:
        draw_pixel(img, pos[0], pos[1], 'white')
    return img

def terrain_wooden_floor():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'wood_med')
    # Planks (horizontal lines)
    for y in [0, 4, 8, 12]:
        fill_rect(img, 0, y, 16, 1, 'wood_dark')
    # Wood grain
    for y in range(16):
        for x in range(16):
            if (x + y * 3) % 8 == 0:
                draw_pixel(img, x, y, 'wood_light')
    return img

def terrain_stone_floor():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_light')
    # Tile pattern
    for y in [0, 8]:
        fill_rect(img, 0, y, 16, 1, 'stone_dark')
    for x in [0, 8]:
        fill_rect(img, x, 0, 1, 16, 'stone_dark')
    # Slight variation
    fill_rect(img, 1, 1, 6, 6, 'stone_med')
    fill_rect(img, 9, 9, 6, 6, 'stone_med')
    return img

def terrain_constructed_wall():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_med')
    # Brick pattern
    for y in range(0, 16, 4):
        fill_rect(img, 0, y, 16, 1, 'stone_dark')
        offset = 4 if (y // 4) % 2 == 0 else 0
        for x in range(offset, 16, 8):
            fill_rect(img, x, y, 1, 4, 'stone_dark')
    return img

def terrain_stairs_up():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_dark')
    # Steps going up
    for i, y in enumerate([12, 8, 4, 0]):
        fill_rect(img, 0, y, 16, 4, 'stone_med' if i % 2 == 0 else 'stone_light')
        fill_rect(img, 0, y, 16, 1, 'stone_dark')
    # Arrow up
    fill_rect(img, 7, 5, 2, 6, 'white')
    for i in range(3):
        draw_pixel(img, 7-i, 5+i, 'white')
        draw_pixel(img, 8+i, 5+i, 'white')
    return img

def terrain_stairs_down():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_dark')
    # Steps going down
    for i, y in enumerate([0, 4, 8, 12]):
        fill_rect(img, 0, y, 16, 4, 'stone_med' if i % 2 == 0 else 'stone_light')
        fill_rect(img, 0, y+3, 16, 1, 'stone_dark')
    # Arrow down
    fill_rect(img, 7, 5, 2, 6, 'white')
    for i in range(3):
        draw_pixel(img, 7-i, 11-i, 'white')
        draw_pixel(img, 8+i, 11-i, 'white')
    return img

def terrain_stairs_updown():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_med')
    # Mixed steps
    for y in [0, 4, 8, 12]:
        fill_rect(img, 0, y, 16, 1, 'stone_dark')
    # Up arrow (left)
    fill_rect(img, 3, 4, 2, 8, 'white')
    draw_pixel(img, 2, 5, 'white')
    draw_pixel(img, 5, 5, 'white')
    # Down arrow (right)
    fill_rect(img, 11, 4, 2, 8, 'white')
    draw_pixel(img, 10, 11, 'white')
    draw_pixel(img, 13, 11, 'white')
    return img

def terrain_ramp_up():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_dark')
    # Diagonal ramp
    for i in range(16):
        fill_rect(img, 0, 15-i, i+1, 1, 'stone_med')
    # Surface highlight
    for i in range(14):
        draw_pixel(img, i, 14-i, 'stone_light')
    return img

def terrain_ramp_down():
    img = new_image()
    fill_rect(img, 0, 0, 16, 16, 'stone_dark')
    # Diagonal ramp (opposite direction)
    for i in range(16):
        fill_rect(img, 15-i, 15-i, i+1, 1, 'stone_med')
    # Surface highlight
    for i in range(14):
        draw_pixel(img, 15-i, 14-i, 'stone_light')
    return img

# ============== CREATURE SPRITES ==============

def creature_dwarf():
    img = new_image()
    # Body (tunic)
    fill_rect(img, 4, 7, 8, 6, 'fabric_blue')
    # Head
    fill_rect(img, 5, 2, 6, 5, 'skin')
    # Beard
    fill_rect(img, 5, 5, 6, 4, 'beard_brown')
    fill_rect(img, 6, 8, 4, 2, 'beard_brown')
    # Eyes
    draw_pixel(img, 6, 3, 'black')
    draw_pixel(img, 9, 3, 'black')
    # Helmet
    fill_rect(img, 5, 1, 6, 2, 'metal_dark')
    draw_pixel(img, 7, 0, 'metal_light')
    draw_pixel(img, 8, 0, 'metal_light')
    # Legs
    fill_rect(img, 5, 13, 2, 3, 'skin_dark')
    fill_rect(img, 9, 13, 2, 3, 'skin_dark')
    # Arms
    fill_rect(img, 2, 8, 2, 4, 'skin')
    fill_rect(img, 12, 8, 2, 4, 'skin')
    return img

def creature_goblin():
    img = new_image()
    # Body
    fill_rect(img, 5, 6, 6, 7, 'goblin_dark')
    # Head (larger, pointed ears)
    fill_rect(img, 4, 1, 8, 6, 'goblin_green')
    # Ears
    draw_pixel(img, 3, 2, 'goblin_green')
    draw_pixel(img, 12, 2, 'goblin_green')
    # Eyes (red, menacing)
    draw_pixel(img, 5, 3, (255, 68, 68))
    draw_pixel(img, 10, 3, (255, 68, 68))
    # Mouth
    fill_rect(img, 6, 5, 4, 1, 'black')
    # Legs
    fill_rect(img, 5, 13, 2, 3, 'goblin_dark')
    fill_rect(img, 9, 13, 2, 3, 'goblin_dark')
    # Arms
    fill_rect(img, 3, 7, 2, 4, 'goblin_green')
    fill_rect(img, 11, 7, 2, 4, 'goblin_green')
    return img

def creature_wolf():
    img = new_image()
    # Body (horizontal)
    fill_rect(img, 2, 7, 12, 5, 'wolf_gray')
    # Head
    fill_rect(img, 11, 4, 5, 5, 'wolf_gray')
    # Snout
    fill_rect(img, 14, 6, 2, 2, 'wolf_dark')
    # Ears
    draw_pixel(img, 12, 3, 'wolf_dark')
    draw_pixel(img, 14, 3, 'wolf_dark')
    # Eye
    draw_pixel(img, 13, 5, 'black')
    # Legs
    fill_rect(img, 3, 12, 2, 4, 'wolf_dark')
    fill_rect(img, 7, 12, 2, 4, 'wolf_dark')
    fill_rect(img, 11, 10, 2, 4, 'wolf_dark')
    # Tail
    fill_rect(img, 0, 6, 3, 2, 'wolf_gray')
    return img

def creature_bear():
    img = new_image()
    # Body (large)
    fill_rect(img, 2, 5, 12, 8, 'bear_brown')
    # Head
    fill_rect(img, 10, 2, 6, 6, 'bear_brown')
    # Snout
    fill_rect(img, 13, 4, 3, 3, 'bear_dark')
    draw_pixel(img, 15, 5, 'black')  # Nose
    # Ears
    fill_rect(img, 10, 1, 2, 2, 'bear_dark')
    fill_rect(img, 14, 1, 2, 2, 'bear_dark')
    # Eyes
    draw_pixel(img, 11, 3, 'black')
    # Legs (thick)
    fill_rect(img, 3, 13, 3, 3, 'bear_dark')
    fill_rect(img, 8, 13, 3, 3, 'bear_dark')
    return img

def creature_giant():
    img = new_image()
    # Body (large, fills most of tile)
    fill_rect(img, 3, 4, 10, 10, 'giant_purple')
    # Head
    fill_rect(img, 5, 0, 6, 5, 'giant_purple')
    # Eyes
    draw_pixel(img, 6, 2, (255, 255, 128))
    draw_pixel(img, 9, 2, (255, 255, 128))
    # Mouth
    fill_rect(img, 7, 3, 2, 1, 'black')
    # Legs
    fill_rect(img, 4, 14, 3, 2, (108, 78, 118))
    fill_rect(img, 9, 14, 3, 2, (108, 78, 118))
    # Arms
    fill_rect(img, 1, 5, 2, 6, 'giant_purple')
    fill_rect(img, 13, 5, 2, 6, 'giant_purple')
    return img

def creature_undead():
    img = new_image()
    # Body (tattered)
    fill_rect(img, 5, 6, 6, 8, 'undead_dark')
    # Head (skull-like)
    fill_rect(img, 5, 1, 6, 6, 'undead_pale')
    # Eye sockets
    fill_rect(img, 6, 2, 2, 2, 'black')
    fill_rect(img, 9, 2, 2, 2, 'black')
    # Eye glow
    draw_pixel(img, 6, 2, (158, 255, 158))
    draw_pixel(img, 9, 2, (158, 255, 158))
    # Mouth
    fill_rect(img, 7, 5, 2, 1, 'black')
    # Arms (bony)
    fill_rect(img, 3, 7, 2, 5, 'undead_pale')
    fill_rect(img, 11, 7, 2, 5, 'undead_pale')
    # Legs
    fill_rect(img, 5, 14, 2, 2, 'undead_dark')
    fill_rect(img, 9, 14, 2, 2, 'undead_dark')
    return img

# ============== ITEM SPRITES ==============

def item_food():
    img = new_image()
    # Bread loaf
    fill_rect(img, 3, 6, 10, 6, 'bread')
    fill_rect(img, 4, 5, 8, 2, 'bread')
    # Top highlight
    fill_rect(img, 5, 6, 6, 2, (238, 198, 118))
    # Scoring marks
    draw_pixel(img, 6, 7, 'wood_med')
    draw_pixel(img, 9, 7, 'wood_med')
    return img

def item_drink():
    img = new_image()
    # Mug body
    fill_rect(img, 4, 4, 8, 10, 'wood_med')
    fill_rect(img, 5, 5, 6, 8, 'ale')
    # Handle
    fill_rect(img, 12, 6, 2, 6, 'wood_dark')
    fill_rect(img, 13, 7, 1, 4, 'wood_dark')
    # Foam
    fill_rect(img, 5, 4, 6, 2, 'white')
    return img

def item_raw_meat():
    img = new_image()
    # Meat chunk
    fill_rect(img, 3, 5, 10, 8, 'meat_red')
    fill_rect(img, 4, 4, 8, 2, 'meat_red')
    # Fat/marbling
    fill_rect(img, 5, 7, 3, 2, 'white')
    fill_rect(img, 9, 9, 2, 2, 'white')
    # Darker edges
    fill_rect(img, 3, 11, 10, 2, 'meat_dark')
    return img

def item_plant():
    img = new_image()
    # Stem
    fill_rect(img, 7, 6, 2, 10, 'shrub')
    # Leaves
    fill_rect(img, 4, 4, 3, 4, 'plant_green')
    fill_rect(img, 9, 3, 4, 3, 'plant_green')
    fill_rect(img, 5, 8, 3, 3, 'plant_green')
    fill_rect(img, 10, 7, 3, 3, 'plant_green')
    return img

def item_bed():
    img = new_image()
    # Frame
    fill_rect(img, 1, 10, 14, 4, 'wood_dark')
    # Mattress
    fill_rect(img, 2, 6, 12, 5, 'fabric_red')
    # Pillow
    fill_rect(img, 2, 4, 4, 3, 'white')
    # Blanket fold
    fill_rect(img, 2, 8, 12, 1, (148, 48, 48))
    return img

def item_table():
    img = new_image()
    # Top
    fill_rect(img, 1, 5, 14, 3, 'wood_med')
    fill_rect(img, 0, 5, 16, 1, 'wood_light')
    # Legs
    fill_rect(img, 2, 8, 2, 8, 'wood_dark')
    fill_rect(img, 12, 8, 2, 8, 'wood_dark')
    return img

def item_chair():
    img = new_image()
    # Back
    fill_rect(img, 5, 2, 6, 7, 'wood_med')
    fill_rect(img, 6, 3, 4, 5, 'wood_light')
    # Seat
    fill_rect(img, 4, 9, 8, 2, 'wood_med')
    # Legs
    fill_rect(img, 4, 11, 2, 5, 'wood_dark')
    fill_rect(img, 10, 11, 2, 5, 'wood_dark')
    return img

def item_door():
    img = new_image()
    # Door frame
    fill_rect(img, 2, 0, 12, 16, 'wood_dark')
    # Door panels
    fill_rect(img, 3, 1, 10, 6, 'wood_med')
    fill_rect(img, 3, 9, 10, 6, 'wood_med')
    # Handle
    fill_rect(img, 10, 8, 2, 2, 'metal_light')
    # Hinges
    fill_rect(img, 3, 3, 1, 2, 'metal_dark')
    fill_rect(img, 3, 11, 1, 2, 'metal_dark')
    return img

def item_barrel():
    img = new_image()
    # Body
    fill_rect(img, 3, 2, 10, 12, 'wood_med')
    fill_rect(img, 4, 1, 8, 2, 'wood_med')
    fill_rect(img, 4, 13, 8, 2, 'wood_med')
    # Bands
    fill_rect(img, 3, 4, 10, 1, 'metal_dark')
    fill_rect(img, 3, 11, 10, 1, 'metal_dark')
    # Wood grain
    for x in [5, 8, 11]:
        fill_rect(img, x, 2, 1, 12, 'wood_dark')
    return img

def item_bin():
    img = new_image()
    # Open box
    fill_rect(img, 2, 5, 12, 9, 'wood_med')
    fill_rect(img, 3, 6, 10, 7, 'wood_dark')
    # Rim
    fill_rect(img, 1, 4, 14, 2, 'wood_light')
    return img

def item_pickaxe():
    img = new_image()
    # Handle
    fill_rect(img, 2, 3, 2, 12, 'wood_dark')
    # Head
    fill_rect(img, 4, 2, 10, 3, 'metal_light')
    fill_rect(img, 12, 1, 3, 2, 'metal_light')
    fill_rect(img, 12, 4, 3, 2, 'metal_light')
    # Edge highlight
    draw_pixel(img, 14, 1, 'white')
    draw_pixel(img, 14, 5, 'white')
    return img

def item_axe():
    img = new_image()
    # Handle
    fill_rect(img, 3, 3, 2, 12, 'wood_dark')
    # Head
    fill_rect(img, 5, 2, 6, 6, 'metal_light')
    fill_rect(img, 9, 3, 4, 4, 'metal_light')
    # Edge
    fill_rect(img, 11, 3, 2, 4, 'metal_dark')
    draw_pixel(img, 12, 4, 'white')
    draw_pixel(img, 12, 5, 'white')
    return img

def item_log():
    img = new_image()
    # Log body
    fill_rect(img, 1, 5, 14, 7, 'wood_med')
    # Bark
    fill_rect(img, 1, 5, 14, 2, 'bark')
    fill_rect(img, 1, 10, 14, 2, 'bark')
    # End grain
    fill_rect(img, 13, 6, 2, 5, 'wood_light')
    draw_pixel(img, 14, 8, 'wood_dark')
    return img

def item_stone():
    img = new_image()
    # Irregular stone shape
    fill_rect(img, 3, 5, 10, 8, 'stone_med')
    fill_rect(img, 4, 4, 8, 2, 'stone_med')
    fill_rect(img, 5, 12, 6, 2, 'stone_med')
    # Highlights
    fill_rect(img, 5, 6, 4, 3, 'stone_light')
    # Shadows
    fill_rect(img, 9, 9, 3, 3, 'stone_dark')
    return img

def item_ore():
    img = new_image()
    # Rock base
    fill_rect(img, 3, 5, 10, 8, 'stone_dark')
    fill_rect(img, 4, 4, 8, 2, 'stone_dark')
    # Gold veins
    fill_rect(img, 5, 6, 3, 3, 'gold')
    fill_rect(img, 9, 8, 3, 3, 'gold')
    # Sparkles
    draw_pixel(img, 6, 7, 'white')
    draw_pixel(img, 10, 9, 'white')
    return img

# ============== UI SPRITES ==============

def ui_selection():
    img = new_image()
    # Animated selection ring (corner brackets style)
    c = COLORS['select_yellow']
    # Top-left corner
    for i in range(4):
        draw_pixel(img, i, 0, c)
        draw_pixel(img, 0, i, c)
    # Top-right corner
    for i in range(4):
        draw_pixel(img, 15-i, 0, c)
        draw_pixel(img, 15, i, c)
    # Bottom-left corner
    for i in range(4):
        draw_pixel(img, i, 15, c)
        draw_pixel(img, 0, 15-i, c)
    # Bottom-right corner
    for i in range(4):
        draw_pixel(img, 15-i, 15, c)
        draw_pixel(img, 15, 15-i, c)
    return img

# ============== MAIN ==============

def main():
    # Create category folders
    for category in ["Terrain", "Creatures", "Items", "UI"]:
        path = os.path.join(ASSETS_PATH, category)
        os.makedirs(path, exist_ok=True)
        create_folder_contents(path)

    # Generate terrain sprites
    terrain_sprites = {
        "terrain_empty_air": terrain_empty_air,
        "terrain_grass": terrain_grass,
        "terrain_dirt": terrain_dirt,
        "terrain_stone": terrain_stone,
        "terrain_water": terrain_water,
        "terrain_tree": terrain_tree,
        "terrain_shrub": terrain_shrub,
        "terrain_wall": terrain_wall,
        "terrain_ore": terrain_ore,
        "terrain_wooden_floor": terrain_wooden_floor,
        "terrain_stone_floor": terrain_stone_floor,
        "terrain_constructed_wall": terrain_constructed_wall,
        "terrain_stairs_up": terrain_stairs_up,
        "terrain_stairs_down": terrain_stairs_down,
        "terrain_stairs_updown": terrain_stairs_updown,
        "terrain_ramp_up": terrain_ramp_up,
        "terrain_ramp_down": terrain_ramp_down,
    }

    for name, func in terrain_sprites.items():
        print(f"Generating {name}...")
        create_imageset(name, "Terrain", func())

    # Generate creature sprites
    creature_sprites = {
        "creature_dwarf": creature_dwarf,
        "creature_goblin": creature_goblin,
        "creature_wolf": creature_wolf,
        "creature_bear": creature_bear,
        "creature_giant": creature_giant,
        "creature_undead": creature_undead,
    }

    for name, func in creature_sprites.items():
        print(f"Generating {name}...")
        create_imageset(name, "Creatures", func())

    # Generate item sprites
    item_sprites = {
        "item_food": item_food,
        "item_drink": item_drink,
        "item_raw_meat": item_raw_meat,
        "item_plant": item_plant,
        "item_bed": item_bed,
        "item_table": item_table,
        "item_chair": item_chair,
        "item_door": item_door,
        "item_barrel": item_barrel,
        "item_bin": item_bin,
        "item_pickaxe": item_pickaxe,
        "item_axe": item_axe,
        "item_log": item_log,
        "item_stone": item_stone,
        "item_ore": item_ore,
    }

    for name, func in item_sprites.items():
        print(f"Generating {name}...")
        create_imageset(name, "Items", func())

    # Generate UI sprites
    print("Generating ui_selection...")
    create_imageset("ui_selection", "UI", ui_selection())

    print("\nDone! Generated all sprites in Assets.xcassets")

if __name__ == "__main__":
    main()
