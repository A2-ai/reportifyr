import io
import shutil
import tempfile
from pathlib import Path
from contextlib import redirect_stdout

from reportipyr.alt_text import check_alt_text_magic_string

DATA_DIR = Path(__file__).parent / "data"


def test_check_alt_text_magic_no_mismatch():
    source_doc = DATA_DIR / "test-doc-draft.docx"
    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    shutil.copyfile(source_doc, docx_in)

    buf = io.StringIO()
    with redirect_stdout(buf):
        check_alt_text_magic_string(docx_in)

    output = buf.getvalue()
    assert "Magic mismatch" not in output

def test_check_alt_text_magic_mismatch_emits_message():
    source_doc = DATA_DIR / "test-doc-magic-mismatch.docx"
    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    shutil.copyfile(source_doc, docx_in)

    buf = io.StringIO()
    with redirect_stdout(buf):
        check_alt_text_magic_string(docx_in)

    output = buf.getvalue()
    assert "Magic mismatch" in output
