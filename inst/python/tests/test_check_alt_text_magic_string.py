import logging
import shutil
import tempfile
from pathlib import Path

from reportipyr.alt_text import check_alt_text_magic_string

DATA_DIR = Path(__file__).parent / "data"


def test_check_alt_text_magic_no_mismatch(caplog):
    source_doc = DATA_DIR / "test-doc-draft.docx"
    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    shutil.copyfile(source_doc, docx_in)

    with caplog.at_level(logging.WARNING, logger="rpfy"):
        check_alt_text_magic_string(docx_in)

    assert "Magic mismatch" not in caplog.text


def test_check_alt_text_magic_mismatch_emits_message(caplog):
    source_doc = DATA_DIR / "test-doc-magic-mismatch.docx"
    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    shutil.copyfile(source_doc, docx_in)

    with caplog.at_level(logging.WARNING, logger="rpfy"):
        check_alt_text_magic_string(docx_in)

    assert "Magic mismatch" in caplog.text
