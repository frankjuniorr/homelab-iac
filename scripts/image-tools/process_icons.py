import os
from PIL import Image, ImageOps

def process_garage_icon(img):
    """
    Specifically processes the garage-s3 icon:
    1. Crops to the top icon part (removing 'Garage' text).
    2. Makes the white background transparent.
    """
    # 1. Convert to RGBA
    img = img.convert("RGBA")
    
    # 2. Crop logic: The text is in the bottom ~1/3. 
    # We'll find the actual bounding box of content if possible, 
    # but a safe crop for this specific image is the top 65%.
    width, height = img.size
    img = img.crop((0, 0, width, int(height * 0.65)))
    
    # 3. Remove white background
    datas = img.getdata()
    new_data = []
    for item in datas:
        # If pixel is white (or very close to it), make it transparent
        if item[0] > 240 and item[1] > 240 and item[2] > 240:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
    
    img.putdata(new_data)
    
    # 4. Trim empty space around the remaining icon
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        
    return img

def main():
    icon_dir = "images/icons"
    target_size = (100, 100)
    
    if not os.path.exists(icon_dir):
        print(f"Error: Directory {icon_dir} not found.")
        return

    for filename in os.listdir(icon_dir):
        if filename.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            filepath = os.path.join(icon_dir, filename)
            print(f"Processing: {filename}...")
            
            with Image.open(filepath) as img:
                # Specific logic for garage-s3
                if "garage-s3" in filename:
                    img = process_garage_icon(img)
                
                # Resize keeping aspect ratio, then pad to 100x100 if needed
                # Actually, user requested 100x100px, so we'll do a high-quality resize
                # We use thumbnail to keep aspect ratio, then paste on a transparent canvas
                img.thumbnail(target_size, Image.Resampling.LANCZOS)
                
                # Create 100x100 transparent background
                final_img = Image.new("RGBA", target_size, (255, 255, 255, 0))
                
                # Paste resized image in center
                offset = ((target_size[0] - img.size[0]) // 2, (target_size[1] - img.size[1]) // 2)
                final_img.paste(img, offset)
                
                # Save back (always as PNG to preserve transparency)
                output_path = os.path.join(icon_dir, os.path.splitext(filename)[0] + ".png")
                final_img.save(output_path, "PNG")
                
                # If the original wasn't a .png, we might want to keep/delete it? 
                # For now, let's just save. If original was .webp, we now have both.
                if not filename.endswith(".png"):
                    print(f"  -> Created {os.path.basename(output_path)}")

if __name__ == "__main__":
    main()
