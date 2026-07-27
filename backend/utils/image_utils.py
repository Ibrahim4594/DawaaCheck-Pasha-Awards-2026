"""Image utility functions for decoding, resizing, and encoding medicine images."""

import base64
import io

from PIL import Image


def decode_base64_image(b64_string: str) -> Image.Image:
    """
    Decode a base64-encoded string into a PIL Image.

    Handles optional data-URI prefixes like `data:image/png;base64,`.

    Args:
        b64_string: The base64 string (with or without data URI prefix).

    Returns:
        A PIL Image object.

    Raises:
        ValueError: If the string cannot be decoded into a valid image.
    """
    # Strip the data URI prefix if present
    if "," in b64_string and b64_string.startswith("data:"):
        b64_string = b64_string.split(",", 1)[1]

    try:
        image_bytes = base64.b64decode(b64_string)
        image = Image.open(io.BytesIO(image_bytes))
        image.load()  # Force-load so errors surface immediately
        return image
    except Exception as exc:
        raise ValueError(f"Failed to decode base64 image: {exc}") from exc


def resize_image(image: Image.Image, max_size: int = 1024) -> Image.Image:
    """
    Resize an image so its longest side is at most `max_size` pixels.

    Aspect ratio is preserved.  If the image is already within bounds it is
    returned unchanged.

    Args:
        image: The source PIL Image.
        max_size: Maximum dimension (width or height) in pixels.

    Returns:
        The (possibly resized) PIL Image.
    """
    width, height = image.size
    if width <= max_size and height <= max_size:
        return image

    if width >= height:
        new_width = max_size
        new_height = int(height * (max_size / width))
    else:
        new_height = max_size
        new_width = int(width * (max_size / height))

    return image.resize((new_width, new_height), Image.LANCZOS)


def image_to_base64(image: Image.Image, fmt: str = "PNG") -> str:
    """
    Encode a PIL Image to a base64 string.

    Args:
        image: The PIL Image to encode.
        fmt: The image format to use (default: PNG).

    Returns:
        A plain base64 string (no data-URI prefix).
    """
    buffer = io.BytesIO()
    image.save(buffer, format=fmt)
    buffer.seek(0)
    return base64.b64encode(buffer.read()).decode("utf-8")
