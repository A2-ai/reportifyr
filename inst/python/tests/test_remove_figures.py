import tempfile
from pathlib import Path

from docx import Document
from docx.shared import Inches
from PIL import Image

from reportipyr.figures import remove_figures


def _make_png() -> str:
    path = tempfile.NamedTemporaryFile(suffix=".png", delete=False).name
    img = Image.new("RGB", (10, 10), color=(255, 0, 0))
    img.save(path)
    return path


def _write_yaml(contents: str) -> str:
    path = tempfile.NamedTemporaryFile(suffix=".yaml", delete=False).name
    Path(path).write_text(contents)
    return path


def test_remove_figures_updates_magic_string_with_dimensions():
    img_path = _make_png()

    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    doc = Document()
    doc.add_paragraph("{rpfy}:figure.png")
    fig_par = doc.add_paragraph()
    fig_par.add_run().add_picture(img_path, width=Inches(2), height=Inches(3))
    doc.save(docx_in)

    config_yaml = _write_yaml("use_embedded_dimensions: true\n")

    docx_out = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    remove_figures(docx_in, docx_out, config_yaml)

    out_doc = Document(docx_out)
    text = out_doc.paragraphs[0].text
    assert "width: 2.0" in text
    assert "height: 3.0" in text


def test_remove_figures_no_dimensions_when_disabled():
    img_path = _make_png()

    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    doc = Document()
    doc.add_paragraph("{rpfy}:figure.png")
    fig_par = doc.add_paragraph()
    fig_par.add_run().add_picture(img_path, width=Inches(2), height=Inches(3))
    doc.save(docx_in)

    config_yaml = _write_yaml("use_embedded_dimensions: false\n")

    docx_out = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    remove_figures(docx_in, docx_out, config_yaml)

    out_doc = Document(docx_out)
    # Magic string should be unchanged
    assert out_doc.paragraphs[0].text.strip() == "{rpfy}:figure.png"
    # Image paragraph should be removed
    has_drawing = any(
        p._element.xpath(".//w:drawing") for p in out_doc.paragraphs
    )
    assert has_drawing is False
