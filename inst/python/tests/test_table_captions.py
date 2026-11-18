"""Flextable captions inserted between a table magic string and its <w:tbl>.

add_tables() (R) writes a captioned flextable as

    {rpfy}:t1.rds
    <w:p> caption, wrapped in an rpcap_<md5(name)> bookmark
    <w:tbl>

These tests build that structure directly with python-docx (mirroring what
R/add_tables.R::tag_inserted_caption writes) and check that every walker
finds the table through the caption.
"""

import hashlib
import json

import yaml
from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

from reportipyr.alt_text import (
    add_table_alt_text,
    extract_artifact_hashes,
)
from reportipyr.docx_utils import (
    CAPTION_BOOKMARK_PREFIX,
    artifact_after_magic,
    is_inserted_caption,
    magic_before_table,
    remove_bookmarks,
)
from reportipyr.footnotes import add_table_footnotes
from reportipyr.tables import remove_tables


TABLE_NAME = "t1.rds"
MAGIC = f"{{rpfy}}:{TABLE_NAME}"
ARTIFACT_HASH = "abc123"


# ── Helpers ────────────────────────────────────────────────────────────────


def _caption_bookmark_name(name=TABLE_NAME):
    return CAPTION_BOOKMARK_PREFIX + hashlib.md5(name.encode("utf-8")).hexdigest()


def _make_caption_p(text="Table 1. Caption", bm_id="900000000"):
    """A caption paragraph as add_tables() leaves it: pPr, bookmarkStart,
    run(s), bookmarkEnd. An empty ``text`` gives a paragraph with no run,
    like set_caption(ft, "")."""
    p = OxmlElement("w:p")
    ppr = OxmlElement("w:pPr")
    pstyle = OxmlElement("w:pStyle")
    pstyle.set(qn("w:val"), "TableCaption")
    ppr.append(pstyle)
    p.append(ppr)

    start = OxmlElement("w:bookmarkStart")
    start.set(qn("w:id"), bm_id)
    start.set(qn("w:name"), _caption_bookmark_name())
    p.append(start)

    if text:
        r = OxmlElement("w:r")
        t = OxmlElement("w:t")
        t.text = text
        r.append(t)
        p.append(r)

    end = OxmlElement("w:bookmarkEnd")
    end.set(qn("w:id"), bm_id)
    p.append(end)
    return p


def _build_doc(
    tmp_path,
    caption_text="Table 1. Caption",
    template_caption=False,
    between=None,
    filename="in.docx",
):
    """Write a docx: [template caption] -> magic -> [caption] -> tbl -> after text.

    ``caption_text=None`` omits the inserted caption. ``between`` puts an
    ordinary (unbookmarked) paragraph with that text between magic and tbl.
    """
    doc = Document()
    doc.add_paragraph("before")
    if template_caption:
        doc.add_paragraph("Table 1. Template caption")
    magic = doc.add_paragraph(MAGIC)._p
    doc.add_paragraph("after text")

    table = doc.add_table(rows=2, cols=2)
    for r, row in enumerate([["A", "B"], ["1", "2"]]):
        for c, val in enumerate(row):
            table.cell(r, c).paragraphs[0].text = val
    magic.addnext(table._tbl)  # move the table to sit right after the magic

    if caption_text is not None:
        magic.addnext(_make_caption_p(caption_text))
    if between is not None:
        p = OxmlElement("w:p")
        r = OxmlElement("w:r")
        t = OxmlElement("w:t")
        t.text = between
        r.append(t)
        p.append(r)
        magic.addnext(p)

    path = tmp_path / filename
    doc.save(path)
    return path


def _magic_p(doc):
    for p in doc.paragraphs:
        if p.text.strip() == MAGIC:
            return p._p
    raise AssertionError("magic string paragraph not found")


def _text(el):
    return "".join(el.xpath(".//w:t/text()"))


def _write_table_dir(tmp_path):
    """Table dir holding t1.rds plus metadata with a known object hash."""
    table_dir = tmp_path / "tables"
    table_dir.mkdir()
    (table_dir / TABLE_NAME).write_bytes(b"")
    metadata = {
        "source_meta": {"path": "prog.R", "latest_time": "2026-01-01"},
        "object_meta": {
            "path": f"tables/{TABLE_NAME}",
            "creation_time": "2026-01-02",
            "meta_type": "efficacy",
            "hash": ARTIFACT_HASH,
            "footnotes": {"notes": [], "abbreviations": []},
        },
    }
    (table_dir / "t1_rds_metadata.json").write_text(json.dumps(metadata))
    return table_dir


def _write_yaml(tmp_path, name, data):
    path = tmp_path / name
    path.write_text(yaml.safe_dump(data))
    return path


# ── Walkers ────────────────────────────────────────────────────────────────


def test_no_caption(tmp_path):
    doc = Document(_build_doc(tmp_path, caption_text=None))
    magic = _magic_p(doc)

    caption, tbl = artifact_after_magic(magic)
    assert caption is None
    assert tbl is not None and tbl.tag == qn("w:tbl")
    assert magic_before_table(tbl) == (magic, None)


def test_plain_caption(tmp_path):
    doc = Document(_build_doc(tmp_path))
    magic = _magic_p(doc)

    caption, tbl = artifact_after_magic(magic)
    assert caption is not None and is_inserted_caption(caption)
    assert _text(caption) == "Table 1. Caption"
    assert tbl is not None and tbl.tag == qn("w:tbl")

    back_magic, back_caption = magic_before_table(tbl)
    assert back_magic is magic
    assert back_caption is caption


def test_empty_caption(tmp_path):
    doc = Document(_build_doc(tmp_path, caption_text=""))
    magic = _magic_p(doc)

    caption, tbl = artifact_after_magic(magic)
    assert caption is not None and _text(caption) == ""
    assert tbl is not None
    assert magic_before_table(tbl)[0] is magic


def test_duplicate_caption_template_caption_is_not_skipped(tmp_path):
    doc = Document(_build_doc(tmp_path, template_caption=True))
    magic = _magic_p(doc)

    caption, tbl = artifact_after_magic(magic)
    assert _text(caption) == "Table 1. Caption"
    assert tbl is not None
    assert magic_before_table(tbl)[0] is magic
    # the template caption above the magic string is untouched
    assert _text(magic.getprevious()) == "Table 1. Template caption"
    assert not is_inserted_caption(magic.getprevious())


def test_unbookmarked_paragraph_between_magic_and_table_means_no_table(tmp_path):
    doc = Document(
        _build_doc(tmp_path, caption_text=None, between="user text")
    )
    magic = _magic_p(doc)

    assert artifact_after_magic(magic) == (None, None)


# ── remove_tables ──────────────────────────────────────────────────────────


def test_remove_tables_removes_caption_with_table(tmp_path):
    out = tmp_path / "out.docx"
    remove_tables(str(_build_doc(tmp_path)), str(out))

    doc = Document(out)
    magic = _magic_p(doc)
    assert _text(magic.getnext()) == "after text"
    assert doc.element.body.findall(qn("w:tbl")) == []
    assert doc.element.xpath(
        f"//w:bookmarkStart[starts-with(@w:name, '{CAPTION_BOOKMARK_PREFIX}')]"
    ) == []


def test_remove_tables_removes_orphaned_caption(tmp_path):
    src = _build_doc(tmp_path)
    doc = Document(src)
    _caption, tbl = artifact_after_magic(_magic_p(doc))
    tbl.getparent().remove(tbl)
    orphan = tmp_path / "orphan.docx"
    doc.save(orphan)

    out = tmp_path / "out.docx"
    remove_tables(str(orphan), str(out))

    magic = _magic_p(Document(out))
    assert _text(magic.getnext()) == "after text"


def test_remove_tables_leaves_user_text_alone(tmp_path):
    src = _build_doc(tmp_path, caption_text=None, between="user text")
    out = tmp_path / "out.docx"
    remove_tables(str(src), str(out))

    doc = Document(out)
    magic = _magic_p(doc)
    assert _text(magic.getnext()) == "user text"
    # not adjacent, so not ours to remove
    assert len(doc.element.body.findall(qn("w:tbl"))) == 1


def test_skip_unchanged_keeps_caption_and_table(tmp_path):
    table_dir = _write_table_dir(tmp_path)
    with_alt = tmp_path / "alt.docx"
    add_table_alt_text(
        str(_build_doc(tmp_path)), str(with_alt), artifact_dir=str(table_dir)
    )

    config = _write_yaml(tmp_path, "config.yaml", {"skip_unchanged": True})
    out = tmp_path / "out.docx"
    remove_tables(
        str(with_alt), str(out), config_yaml=str(config), table_dir=str(table_dir)
    )

    caption, tbl = artifact_after_magic(_magic_p(Document(out)))
    assert caption is not None and _text(caption) == "Table 1. Caption"
    assert tbl is not None


# ── Footnotes ──────────────────────────────────────────────────────────────


def test_table_footnote_goes_after_table_not_caption(tmp_path):
    table_dir = _write_table_dir(tmp_path)
    footnotes = _write_yaml(
        tmp_path,
        "footnotes.yaml",
        {
            "figure_footnotes": {"efficacy": "Efficacy population."},
            "table_footnotes": {"efficacy": "Efficacy population."},
            "abbreviations": {},
        },
    )
    out = tmp_path / "out.docx"
    add_table_footnotes(
        str(_build_doc(tmp_path)),
        str(out),
        str(table_dir),
        str(footnotes),
        None,
    )

    magic = _magic_p(Document(out))
    caption, tbl = artifact_after_magic(magic)
    assert caption is not None and tbl is not None
    footnote = tbl.getnext()
    assert footnote.xpath(".//w:bookmarkStart[starts-with(@w:name, 'fp_')]")


# ── Alt text and hashes ────────────────────────────────────────────────────


def test_alt_text_and_hash_round_trip_through_caption(tmp_path):
    table_dir = _write_table_dir(tmp_path)
    out = tmp_path / "out.docx"
    add_table_alt_text(
        str(_build_doc(tmp_path)), str(out), artifact_dir=str(table_dir)
    )

    _caption, tbl = artifact_after_magic(_magic_p(Document(out)))
    desc = tbl.find(qn("w:tblPr")).find(qn("w:tblDescription"))
    assert desc is not None
    assert desc.get(qn("w:val")).startswith(f"{MAGIC} [hash:{ARTIFACT_HASH}]")

    assert extract_artifact_hashes(str(out)) == {TABLE_NAME: ARTIFACT_HASH}


# ── Finalize ───────────────────────────────────────────────────────────────


def test_remove_bookmarks_strips_caption_bookmark_keeps_caption(tmp_path):
    out = tmp_path / "out.docx"
    remove_bookmarks(str(_build_doc(tmp_path)), str(out))

    doc = Document(out)
    assert doc.element.xpath(
        f"//w:bookmarkStart[starts-with(@w:name, '{CAPTION_BOOKMARK_PREFIX}')]"
    ) == []
    assert doc.element.xpath('//w:bookmarkEnd[@w:id="900000000"]') == []
    caption = _magic_p(doc).getnext()
    assert _text(caption) == "Table 1. Caption"
