#!/usr/bin/env python3
"""Derive the macOS icon canvas from the selected rounded presentation."""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    rounded = Image.open(ROOT / "assets/brand/icon-rounded.png").convert("RGBA")
    canvas = Image.new("RGBA", (1024, 1024))
    tile = rounded.resize((824, 824), Image.Resampling.LANCZOS)
    canvas.alpha_composite(tile, (100, 100))
    canvas.save(ROOT / "assets/brand/app-icon-macos.png", optimize=True)
    print("Generated inset macOS icon: 824 px rounded tile on a 1024 px canvas.")


if __name__ == "__main__":
    main()
