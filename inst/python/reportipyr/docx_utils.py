from docx import Document
from docx.oxml.ns import qn

from .magic import get_magic_pattern

CAPTION_STYLE = "Caption"

# Bookmark prefix that add_tables() (R) wraps around a flextable caption it
# inserts between a table magic string and its <w:tbl>. Keep in sync with
# caption_bookmark_prefix in R/add_tables.R.
CAPTION_BOOKMARK_PREFIX = "rpcap_"


def is_inserted_caption(el) -> bool:
    """True if ``el`` is a <w:p> carrying an ``rpcap_`` bookmark."""
    if el is None or el.tag != qn("w:p"):
        return False
    return any(
        name.startswith(CAPTION_BOOKMARK_PREFIX)
        for name in el.xpath(".//w:bookmarkStart/@w:name")
    )


def artifact_after_magic(magic_p):
    """Return ``(caption_p, tbl)`` for a body-level table magic-string paragraph.

    The table must sit directly after the magic string, except that at most one
    paragraph carrying an ``rpcap_`` bookmark (a flextable caption inserted by
    add_tables) may sit between them. Anything else in between means "no table".

    ``tbl`` is None when no table follows. ``caption_p`` is returned even without
    a table, so callers can clean up an orphaned caption.
    """
    nxt = magic_p.getnext()
    caption_p = None
    if is_inserted_caption(nxt):
        caption_p = nxt
        nxt = nxt.getnext()
    tbl = nxt if nxt is not None and nxt.tag == qn("w:tbl") else None
    return caption_p, tbl


def magic_before_table(tbl):
    """Return ``(magic_p, caption_p)`` for a body-level <w:tbl>; the reverse of
    artifact_after_magic.

    ``magic_p`` is the paragraph that would hold the table's magic string,
    skipping one ``rpcap_`` caption paragraph. It is None if there is no
    paragraph there. Callers still have to check its text for a magic string.
    """
    prev = tbl.getprevious()
    caption_p = None
    if is_inserted_caption(prev):
        caption_p = prev
        prev = prev.getprevious()
    if prev is None or prev.tag != qn("w:p"):
        return None, None
    return prev, caption_p


def iter_cell_paragraphs(doc):
    """Yield (paragraph, cell, table_element) for paragraphs inside table cells.

    Deduplicates merged cells using cell._tc identity. Stores references
    to _tc elements (not just id()) to prevent lxml proxy garbage collection
    from causing id reuse across iterations.
    """
    for table in doc.tables:
        seen_tcs = {}  # id -> _tc reference (prevents GC/id reuse)
        for row in table.rows:
            for cell in row.cells:
                tc = cell._tc
                tc_id = id(tc)
                if tc_id in seen_tcs:
                    continue
                seen_tcs[tc_id] = tc
                for para in cell.paragraphs:
                    yield para, cell, table._element


def _set_keep_next(p_el):
    # get_or_add_keepNext inserts in schema order (after pStyle, before
    # spacing/jc/rPr); appending to the end of pPr is invalid OOXML.
    p_el.get_or_add_pPr().get_or_add_keepNext()


def _paragraph_text(p_el) -> str:
    return "".join(t.text or "" for t in p_el.xpath(".//w:t"))


def _is_blank_paragraph(p_el) -> bool:
    """A <w:p> with no text and nothing else that takes up space or breaks the
    page (drawing, picture, object, break, section break)."""
    if _paragraph_text(p_el).strip():
        return False
    return not p_el.xpath(
        ".//w:drawing | .//w:pict | .//w:object | .//w:br | ./w:pPr/w:sectPr"
    )


def keep_caption_next(docx_in, docx_out):
    """Add keepNext to every caption and to the chain that leads from it to
    its artifact.

    A caption is a paragraph styled ``Caption``, one with a ``SEQ Table`` /
    ``SEQ Figure`` field, or a flextable caption that add_tables() tagged with
    an ``rpcap_`` bookmark.

    From each caption, the walk goes forward over body-level siblings. Each magic
    string and each ``rpcap_`` caption gets keepNext, and so does every blank
    paragraph between them. The walk stops at the first other element: a table,
    an inserted image paragraph, text, or anything that isn't a paragraph.
    Blank paragraphs after the last chain member are left alone, so the artifact
    isn't glued to the text that follows it.

    So the template shape ``caption -> {rpfy}:t.rds -> rpcap_ caption -> tbl``
    gets keepNext on all three paragraphs. A caption placed below its figure
    gets keepNext itself, but the walk stops at the text after it instead of
    running on to an unrelated magic string further down.
    """
    doc = Document(docx_in)
    magic_pattern = get_magic_pattern()

    def is_caption(p) -> bool:
        if p.style is not None and p.style.name == CAPTION_STYLE:
            return True
        if is_inserted_caption(p._element):
            return True
        return any(
            ("SEQ Table" in (instr.text or "") or "SEQ Figure" in (instr.text or ""))
            for instr in p._element.xpath(".//w:instrText")
        )

    for p in doc.paragraphs:
        if not is_caption(p):
            continue

        _set_keep_next(p._element)

        pending_blanks = []
        el = p._element.getnext()
        while el is not None and el.tag == qn("w:p"):
            if _is_blank_paragraph(el):
                pending_blanks.append(el)
            elif is_inserted_caption(el) or magic_pattern.search(
                _paragraph_text(el)
            ):
                for blank in pending_blanks:
                    _set_keep_next(blank)
                pending_blanks = []
                _set_keep_next(el)
            else:
                break
            el = el.getnext()

    doc.save(docx_out)


def remove_bookmarks(docx_in, docx_out):
    doc = Document(docx_in)

    rpfy_bookmark_ids = set()

    for element in doc.element.findall(
        ".//w:bookmarkStart", namespaces=doc.element.nsmap
    ):
        bookmark_name = element.get(qn("w:name"))
        if bookmark_name and bookmark_name.startswith(
            ("fp_", CAPTION_BOOKMARK_PREFIX)
        ):
            rpfy_bookmark_ids.add(element.get(qn("w:id")))
            parent = element.getparent()
            parent.remove(element)

    for element in doc.element.findall(
        ".//w:bookmarkEnd", namespaces=doc.element.nsmap
    ):
        bookmark_id = element.get(qn("w:id"))
        if bookmark_id in rpfy_bookmark_ids:
            parent = element.getparent()
            parent.remove(element)

    doc.save(docx_out)
