#!/usr/bin/env python3
"""Generate a toon shading ramp texture for cel-shaded look."""
import os
from PIL import Image

def create_ramp_texture(width=256, height=4, output_path=None):
    """Create a 1D ramp texture for toon shading."""
    if output_path is None:
        output_path = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "toon_ramp.png")
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    img = Image.new('RGBA', (width, height), (0, 0, 0, 255))
    pixels = img.load()
    
    # Define color stops for the ramp (shadow -> highlight)
    stops = [
        (0.0, (50, 40, 35)),      # Deep shadow
        (0.3, (80, 65, 55)),      # Shadow
        (0.5, (160, 135, 115)),   # Mid-tone (base color)
        (0.7, (210, 185, 165)),   # Light
        (0.85, (235, 215, 195)),  # Highlight
        (1.0, (255, 245, 230)),   # Specular
    ]
    
    for x in range(width):
        t = x / (width - 1)
        
        # Find the two stops to interpolate between
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                local_t = (t - t0) / (t1 - t0)
                r = int(c0[0] + (c1[0] - c0[0]) * local_t)
                g = int(c0[1] + (c1[1] - c0[1]) * local_t)
                b = int(c0[2] + (c1[2] - c0[2]) * local_t)
                for y in range(height):
                    pixels[x, y] = (r, g, b, 255)
                break
    
    img.save(output_path)
    print(f"Created toon ramp: {output_path}")

def create_outline_ramp(width=256, height=4, output_path=None):
    """Create a ramp for outline thickness based on view angle."""
    if output_path is None:
        output_path = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "outline_ramp.png")
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    img = Image.new('RGBA', (width, height), (0, 0, 0, 255))
    pixels = img.load()
    
    for x in range(width):
        t = x / (width - 1)
        # Thicker outline at grazing angles (t=0), thinner at facing (t=1)
        thickness = 1.0 - t * 0.7
        val = int(thickness * 255)
        for y in range(height):
            pixels[x, y] = (val, val, val, 255)
    
    img.save(output_path)
    print(f"Created outline ramp: {output_path}")

if __name__ == "__main__":
    create_ramp_texture()
    create_outline_ramp()