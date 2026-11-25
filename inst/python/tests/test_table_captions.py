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

import pytest
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
    keep_caption_next,
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
    # flextable always writes keepNext on a top caption (verified on 0.10.0)
    ppr.append(OxmlElement("w:keepNext"))
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


def _add_bookmark(p_el, name, bm_id):
    """Wrap the contents of paragraph ``p_el`` in a bookmark."""
    start = OxmlElement("w:bookmarkStart")
    start.set(qn("w:id"), bm_id)
    start.set(qn("w:name"), name)
    end = OxmlElement("w:bookmarkEnd")
    end.set(qn("w:id"), bm_id)
    p_el.insert(0, start)
    p_el.append(end)


def test_table_footnote_id_does_not_reuse_template_bookmark_id(tmp_path):
    # Word numbers template bookmarks 0, 1, 2, ... The magic string is
    # paragraph 1, the id a paragraph-index footnote would have taken.
    src = _build_doc(tmp_path)
    doc = Document(src)
    before = doc.paragraphs[0]._p
    _add_bookmark(before, "_Toc100", "0")
    _add_bookmark(before, "_Ref200", "1")
    doc.save(src)

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
    add_table_footnotes(str(src), str(out), str(table_dir), str(footnotes), None)

    starts = Document(out).element.xpath("//w:bookmarkStart")
    names = [s.get(qn("w:name")) for s in starts]
    assert any(n.startswith("fp_") for n in names)
    ids = [s.get(qn("w:id")) for s in starts]
    assert len(ids) == len(set(ids))


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


@pytest.mark.parametrize("prefix", ["fp_", CAPTION_BOOKMARK_PREFIX])
@pytest.mark.parametrize("user_first", [True, False])
def test_remove_bookmarks_shared_id_keeps_user_range(tmp_path, prefix, user_first):
    # A draft built before footnote ids were allocated uniquely can have a
    # reportifyr bookmark sharing its id with a user bookmark. Only the
    # reportifyr range is removed; both ends of the user range survive.
    doc = Document()
    user_p = doc.add_paragraph("User text")._p
    rpfy_p = doc.add_paragraph("reportifyr text")._p
    if not user_first:
        user_p.addprevious(rpfy_p)
    _add_bookmark(user_p, "UserRef", "5")
    _add_bookmark(rpfy_p, prefix + "a" * 32, "5")
    src = tmp_path / "in.docx"
    out = tmp_path / "out.docx"
    doc.save(src)

    remove_bookmarks(str(src), str(out))

    body = Document(out).element.body
    user_out = next(p for p in body.iterchildren(qn("w:p")) if _text(p) == "User text")
    assert [s.get(qn("w:name")) for s in body.iter(qn("w:bookmarkStart"))] == ["UserRef"]
    assert user_out.xpath("./w:bookmarkStart/@w:id") == ["5"]
    assert user_out.xpath("./w:bookmarkEnd/@w:id") == ["5"]
    assert len(body.xpath(".//w:bookmarkEnd")) == 1


# ── keep_caption_next ──────────────────────────────────────────────────────


def _seq_caption_p(text="Table 1. Template caption"):
    """A template caption paragraph identified by a complex SEQ Table field."""
    p = OxmlElement("w:p")
    for fld_type, instr in (("begin", None), (None, " SEQ Table \\* ARABIC "), ("end", None)):
        r = OxmlElement("w:r")
        if fld_type:
            fc = OxmlElement("w:fldChar")
            fc.set(qn("w:fldCharType"), fld_type)
            r.append(fc)
        else:
            it = OxmlElement("w:instrText")
            it.text = instr
            r.append(it)
        p.append(r)
    r = OxmlElement("w:r")
    t = OxmlElement("w:t")
    t.text = text
    r.append(t)
    p.append(r)
    return p


def _text_p(text):
    p = OxmlElement("w:p")
    if text:
        r = OxmlElement("w:r")
        t = OxmlElement("w:t")
        t.text = text
        r.append(t)
        p.append(r)
    return p


def _body_doc(tmp_path, elements, filename="kn-in.docx"):
    """Write a docx whose body is exactly ``elements`` (``"TBL"`` -> a table)."""
    doc = Document()
    body = doc.element.body
    for child in list(body):
        if child.tag != qn("w:sectPr"):
            body.remove(child)
    sect = body.find(qn("w:sectPr"))
    for el in elements:
        if el == "TBL":
            el = doc.add_table(rows=1, cols=1)._tbl
            body.remove(el)
        sect.addprevious(el)
    path = tmp_path / filename
    doc.save(path)
    return path


def _keep_next_by_text(tmp_path, elements):
    """Run keep_caption_next and return [(text, has_keepNext)] for body paragraphs."""
    out = tmp_path / "kn-out.docx"
    keep_caption_next(str(_body_doc(tmp_path, elements)), str(out))
    doc = Document(out)
    return [
        (_text(p), bool(p.xpath("./w:pPr/w:keepNext")))
        for p in doc.element.body.iterchildren(qn("w:p"))
    ]


def test_keep_next_caption_string_tbl(tmp_path):
    # CAPTION -> STRING -> TBL (template caption)
    result = _keep_next_by_text(tmp_path, [
        _seq_caption_p(),
        _text_p(MAGIC),
        "TBL",
        _text_p("after text"),
    ])
    assert result == [
        ("Table 1. Template caption", True),
        (MAGIC, True),
        ("after text", False),
    ]


def test_keep_next_string_caption_tbl(tmp_path):
    # STRING -> CAPTION -> TBL (flextable caption). The string gets keepNext;
    # the caption already has it from flextable.
    result = _keep_next_by_text(tmp_path, [
        _text_p(MAGIC),
        _make_caption_p(),
        "TBL",
        _text_p("after text"),
    ])
    assert result == [
        (MAGIC, True),
        ("Table 1. Caption", True),
        ("after text", False),
    ]


def test_keep_next_template_and_flextable_caption(tmp_path):
    # CAPTION -> STRING -> CAPTION -> TBL (duplicate captions)
    result = _keep_next_by_text(tmp_path, [
        _seq_caption_p(),
        _text_p(MAGIC),
        _make_caption_p(),
        "TBL",
    ])
    assert result == [
        ("Table 1. Template caption", True),
        (MAGIC, True),
        ("Table 1. Caption", True),
    ]


def test_keep_next_only_strings_and_captions_directly_above(tmp_path):
    # Your template's shape: blanks between blocks are left alone, and each
    # string gets keepNext on its own.
    result = _keep_next_by_text(tmp_path, [
        _seq_caption_p(),
        _text_p(MAGIC),
        _text_p(""),
        _text_p(""),
        _text_p("{rpfy}:t2.rds"),
        _text_p(""),
    ])
    assert result == [
        ("Table 1. Template caption", True),
        (MAGIC, True),
        ("", False),
        ("", False),
        ("{rpfy}:t2.rds", True),
        ("", False),
    ]


def test_keep_next_leaves_captions_outside_reportifyr_blocks_alone(tmp_path):
    # A Word caption on a table typed into the template (no magic string) and
    # a caption below a string are not reportifyr blocks: untouched.
    result = _keep_next_by_text(tmp_path, [
        _seq_caption_p("Table 9. Revision history"),
        "TBL",
        _text_p("{rpfy}:f1.png"),
        _seq_caption_p("Figure 1. Below"),
        _text_p("body text"),
    ])
    assert result == [
        ("Table 9. Revision history", False),
        ("{rpfy}:f1.png", True),
        ("Figure 1. Below", False),
        ("body text", False),
    ]


def test_keep_next_caption_above_table_is_not_above_string(tmp_path):
    # CAPTION -> TBL -> STRING: the caption belongs to the static table, not
    # to the string, even though doc.paragraphs puts them next to each other.
    result = _keep_next_by_text(tmp_path, [
        _seq_caption_p("Table 9. Static"),
        "TBL",
        _text_p(MAGIC),
    ])
    assert result == [
        ("Table 9. Static", False),
        (MAGIC, True),
    ]


def _fldsimple_caption_p(text="Table 1. Simple-field caption"):
    """A template caption whose SEQ field is a simple field (w:fldSimple)."""
    p = OxmlElement("w:p")
    fld = OxmlElement("w:fldSimple")
    fld.set(qn("w:instr"), " SEQ Table \\* ARABIC ")
    p.append(fld)
    r = OxmlElement("w:r")
    t = OxmlElement("w:t")
    t.text = text
    r.append(t)
    p.append(r)
    return p


def test_keep_next_simple_field_caption(tmp_path):
    # A fldSimple SEQ caption counts as a caption above a string (this used
    # to be handled by remove_magic_strings at finalize, for every caption).
    result = _keep_next_by_text(tmp_path, [
        _fldsimple_caption_p(),
        _text_p(MAGIC),
        "TBL",
        _fldsimple_caption_p("Table 9. Static"),
        "TBL",
    ])
    assert result == [
        ("Table 1. Simple-field caption", True),
        (MAGIC, True),
        ("Table 9. Static", False),
    ]


def test_keep_next_inserted_in_schema_order(tmp_path):
    # CT_PPr order: pStyle, keepNext, keepLines, ..., jc, ..., rPr
    cap = _seq_caption_p()
    ppr = OxmlElement("w:pPr")
    for tag in ("w:keepLines", "w:jc", "w:rPr"):
        el = OxmlElement(tag)
        if tag == "w:jc":
            el.set(qn("w:val"), "center")
        ppr.append(el)
    cap.insert(0, ppr)

    out = tmp_path / "kn-order.docx"
    keep_caption_next(str(_body_doc(tmp_path, [cap, _text_p(MAGIC), "TBL"])), str(out))

    first_p = next(Document(out).element.body.iterchildren(qn("w:p")))
    order = [c.tag.split("}")[1] for c in first_p.find(qn("w:pPr"))]
    assert order == ["keepNext", "keepLines", "jc", "rPr"]


def test_keep_next_is_idempotent(tmp_path):
    first = tmp_path / "kn-1.docx"
    second = tmp_path / "kn-2.docx"
    keep_caption_next(
        str(_body_doc(tmp_path, [_seq_caption_p(), _text_p(MAGIC), _make_caption_p(), "TBL"])),
        str(first),
    )
    keep_caption_next(str(first), str(second))
    doc = Document(second)
    for p in doc.element.body.iterchildren(qn("w:p")):
        assert len(p.xpath("./w:pPr/w:keepNext")) <= 1


def _runs_p(*texts):
    """A paragraph with one run per entry; ``None`` gives an empty <w:t/>."""
    p = OxmlElement("w:p")
    for text in texts:
        r = OxmlElement("w:r")
        t = OxmlElement("w:t")
        if text is not None:
            t.text = text
        r.append(t)
        p.append(r)
    return p


def test_keep_next_empty_text_node_without_captions(tmp_path):
    # A stray empty <w:t/> anywhere in the body must not abort the scan.
    result = _keep_next_by_text(tmp_path, [
        _text_p("before"),
        _runs_p(None),
        _text_p("after"),
    ])
    assert result == [
        ("before", False),
        ("", False),
        ("after", False),
    ]


def test_keep_next_empty_text_node_inside_magic_string(tmp_path):
    # A magic string split across runs with an empty <w:t/> between them is
    # still found, and its caption still gets keepNext.
    result = _keep_next_by_text(tmp_path, [
        _seq_caption_p(),
        _runs_p("{rpfy}:", None, TABLE_NAME),
        "TBL",
        _runs_p(None),
    ])
    assert result == [
        ("Table 1. Template caption", True),
        (MAGIC, True),
        ("", False),
    ]
