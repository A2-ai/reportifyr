import tempfile
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from reportipyr.figures import add_path_overlay_to_image


def _make_png(path: Path) -> None:
    Image.new("RGB", (100, 100), color=(255, 255, 255)).save(path)


def _drawn_label(png: Path, *args) -> str:
    """Run the overlay with ImageDraw mocked and return the stamped label."""
    with patch("reportipyr.figures.ImageDraw.Draw") as mock_draw:
        add_path_overlay_to_image(str(png), *args)
    # draw.text(position, label, fill=..., font=...)
    return mock_draw.return_value.text.call_args.args[1]


def test_overlay_source_label():
    png = Path(tempfile.mkdtemp()) / "fig.png"
    _make_png(png)
    assert _drawn_label(png, "scripts/fig.R", "source") == "source: scripts/fig.R"


def test_overlay_object_label():
    png = Path(tempfile.mkdtemp()) / "fig.png"
    _make_png(png)
    assert (
        _drawn_label(png, "OUTPUTS/figures/fig.png", "object")
        == "object: OUTPUTS/figures/fig.png"
    )


def test_overlay_default_kind_is_source():
    png = Path(tempfile.mkdtemp()) / "fig.png"
    _make_png(png)
    assert _drawn_label(png, "scripts/fig.R") == "source: scripts/fig.R"


def test_overlay_skips_non_png():
    non_png = Path(tempfile.mkdtemp()) / "fig.svg"
    non_png.write_text("not an image")
    with patch("reportipyr.figures.ImageDraw.Draw") as mock_draw:
        add_path_overlay_to_image(str(non_png), "scripts/fig.R", "object")
    mock_draw.assert_not_called()
