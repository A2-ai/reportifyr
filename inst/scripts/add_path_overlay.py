import argparse
import os

from PIL import Image, ImageDraw, ImageFont


def add_path_overlay(image_path: str, source_path: str) -> None:
    """
    Adds a source path overlay to the bottom-left corner of an image.

    Args:
        image_path: Path to the image file to modify
        source_path: The source path text to overlay on the image
    """
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)

    # Preserve original format and DPI
    original_format = img.format or os.path.splitext(image_path)[1][1:].upper()
    original_dpi = img.info.get("dpi", (72, 72))

    img_width, img_height = img.size

    # Scale font size based on image dimensions
    font_size = max(12, int(min(img_width, img_height) * 0.02))
    font = ImageFont.load_default(size=font_size)

    # Calculate text position (bottom-left corner with padding)
    padding = 10
    text_position = (padding, img_height - padding - font_size)

    # Draw the source path text with "source: " prefix
    draw.text(text_position, f"source: {source_path}", fill=(0, 0, 0), font=font)

    # Save the modified image
    img.save(image_path, format=original_format, dpi=original_dpi)
    print(f"Added path overlay to '{image_path}'")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Add source path overlay to an image"
    )
    parser.add_argument(
        "-i", "--image", type=str, required=True, help="Path to the image file"
    )
    parser.add_argument(
        "-s", "--source", type=str, required=True, help="Source path to overlay"
    )
    args = parser.parse_args()

    add_path_overlay(args.image, args.source)
