import shutil
import tempfile
from pathlib import Path

from docx import Document

from reportipyr.validate import validate_docx

DATA_DIR = Path(__file__).parent / "data"


def _make_docx_with_text(text: str) -> str:
    path = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    doc = Document()
    doc.add_paragraph(text)
    doc.save(path)
    return path


def test_validate_docx_corrupt_file():
    path = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    Path(path).write_text("this is not a docx file")
    result = validate_docx(path, strict=True)
    assert result["success"] is False
    assert any("Failed to read document" in msg for msg in result["errors"])


def test_validate_docx_missing_magic():
    path = _make_docx_with_text("no magic here")
    result = validate_docx(path, strict=True)
    assert result["success"] is True
    assert any("does not contain magic strings" in msg for msg in result["warnings"])
    assert result["errors"] == []
    assert result["file_names"] == []


def test_validate_docx_invalid_extension_strict():
    path = _make_docx_with_text("{rpfy}:example.doc")
    result = validate_docx(path, strict=True)
    assert result["success"] is False
    assert any("Unsupported file types" in msg for msg in result["errors"])


def test_validate_docx_invalid_extension_nonstrict():
    path = _make_docx_with_text("{rpfy}:example.doc")
    result = validate_docx(path, strict=False)
    assert result["success"] is True
    assert any("Unsupported file types" in msg for msg in result["warnings"])


def test_validate_docx_duplicates_strict():
    path = _make_docx_with_text("{rpfy}:[a.csv, a.csv]")
    result = validate_docx(path, strict=True)
    assert result["success"] is False
    assert any("Found duplicate files" in msg for msg in result["errors"])


def test_validate_docx_duplicates_nonstrict():
    path = _make_docx_with_text("{rpfy}:[a.csv, a.csv]")
    result = validate_docx(path, strict=False)
    assert result["success"] is True
    assert any("Found duplicate files" in msg for msg in result["warnings"])


def test_validate_docx_shell_strict_passes():
    source_doc = DATA_DIR / "test-doc-shell.docx"
    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    shutil.copyfile(source_doc, docx_in)

    result = validate_docx(docx_in, strict=True)
    assert result["success"] is True
    assert result["errors"] == []


def test_validate_docx_shell_nonstrict_passes():
    source_doc = DATA_DIR / "test-doc-shell.docx"
    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    shutil.copyfile(source_doc, docx_in)

    result = validate_docx(docx_in, strict=False)
    assert result["success"] is True
