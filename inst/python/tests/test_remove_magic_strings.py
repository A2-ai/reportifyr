import shutil
import tempfile
from pathlib import Path

from docx import Document

from reportipyr.magic import remove_magic_strings


DATA_DIR = Path(__file__).parent / "data"


def test_remove_magic_strings_preserves_image_and_table():
    source_doc = DATA_DIR / "test-doc-draft.docx"
    docx_in = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    shutil.copyfile(source_doc, docx_in)

    docx_out = tempfile.NamedTemporaryFile(suffix=".docx", delete=False).name
    remove_magic_strings(docx_in, docx_out)

    out_doc = Document(docx_out)

    # Magic string paragraphs should be removed or cleared
    assert all("{rpfy}:" not in p.text for p in out_doc.paragraphs)

    # Image should still exist
    has_image = any(
        run.element.xpath(".//pic:pic")
        for p in out_doc.paragraphs
        for run in p.runs
    )
    assert has_image is True

    # Table should still exist
    assert len(out_doc.tables) >= 1


def _fldsimple_caption_p(text="Table 9. Static", keep_next=False):
    """A caption paragraph whose SEQ field is a simple field (w:fldSimple)."""
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn

    p = OxmlElement("w:p")
    if keep_next:
        ppr = OxmlElement("w:pPr")
        ppr.append(OxmlElement("w:keepNext"))
        p.append(ppr)
    fld = OxmlElement("w:fldSimple")
    fld.set(qn("w:instr"), " SEQ Table \\* ARABIC ")
    r = OxmlElement("w:r")
    t = OxmlElement("w:t")
    t.text = "9"
    r.append(t)
    fld.append(r)
    p.append(fld)
    r = OxmlElement("w:r")
    t = OxmlElement("w:t")
    t.text = text
    r.append(t)
    p.append(r)
    return p


def test_remove_magic_strings_leaves_captions_alone(tmp_path):
    # Finalize must not add keepNext to captions (that's keep_caption_next's
    # job, gated by config): not to a static caption, and not a duplicate to
    # one that already has it.
    doc = Document()
    doc.add_paragraph("before")
    anchor = doc.add_paragraph("{rpfy}:t1.rds")._p
    anchor.addprevious(_fldsimple_caption_p("Table 9. Static"))
    anchor.addprevious(_fldsimple_caption_p("Table 1. Kept", keep_next=True))
    docx_in = tmp_path / "in.docx"
    doc.save(docx_in)

    docx_out = tmp_path / "out.docx"
    remove_magic_strings(str(docx_in), str(docx_out))

    counts = {
        "".join(p.xpath(".//w:t/text()")): len(p.xpath("./w:pPr/w:keepNext"))
        for p in Document(docx_out).element.body.iterchildren()
        if p.tag.endswith("}p")
    }
    assert counts["9Table 9. Static"] == 0
    assert counts["9Table 1. Kept"] == 1
    assert "{rpfy}:t1.rds" not in counts
