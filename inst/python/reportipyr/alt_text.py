import base64
import gzip
import hashlib
import json
import os
import re

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

from .logging import setup_logger
from .magic import get_magic_pattern, parse_magic_entries


def _load_artifact_hash(artifact_dir: str, filename: str) -> str | None:
    """Load the hash from a _metadata.json file for a given artifact."""
    object_name, extension = os.path.splitext(filename)
    metadata_file = os.path.join(
        artifact_dir, f"{object_name}_{extension[1:]}_metadata.json"
    )
    try:
        with open(metadata_file, "r") as f:
            metadata = json.load(f)
        return metadata.get("object_meta", {}).get("hash")
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def _embed_hash_in_alt_text(alt_text: str, hash_value: str | None) -> str:
    """Append [hash:...] to alt text if a hash value is available."""
    if hash_value:
        return f"{alt_text} [hash:{hash_value}]"
    return alt_text


def _strip_hash_from_alt_text(alt_text: str) -> str:
    """Remove [hash:...], [content_hash:...], and [content_body:...] from alt text for comparison."""
    text = re.sub(r"\s*\[hash:[a-f0-9]+\]", "", alt_text)
    text = re.sub(r"\s*\[content_hash:[a-f0-9]+\]", "", text)
    text = re.sub(r"\s*\[content_body:[A-Za-z0-9+/=]+\]", "", text)
    return text


_HASH_PATTERN = re.compile(r"\[hash:([a-f0-9]+)\]")


def _extract_hash_from_alt_text(alt_text: str) -> str | None:
    """Extract the hash value from alt text, or None if not present."""
    match = _HASH_PATTERN.search(alt_text)
    return match.group(1) if match else None


def is_artifact_unchanged(
    alt_text: str,
    artifact_dir: str | None,
    filename: str,
) -> bool:
    """Check if an artifact's alt-text hash matches its current metadata hash.

    Returns True (unchanged, skip removal) when:
    - alt text contains a [hash:...] value
    - artifact_dir is provided
    - the metadata hash matches the embedded hash
    """
    if not artifact_dir:
        return False
    embedded_hash = _extract_hash_from_alt_text(alt_text)
    if not embedded_hash:
        return False
    current_hash = _load_artifact_hash(artifact_dir, filename)
    return current_hash is not None and current_hash == embedded_hash


def _get_gridspan(tc) -> int:
    """Return the gridSpan value for a table cell, defaulting to 1."""
    tcPr = tc.find(qn("w:tcPr"))
    if tcPr is not None:
        gs = tcPr.find(qn("w:gridSpan"))
        if gs is not None:
            return int(gs.get(qn("w:val"), "1"))
    return 1


def _has_vmerge(tc) -> bool:
    """Return True if the cell has a vMerge element."""
    tcPr = tc.find(qn("w:tcPr"))
    if tcPr is not None:
        return tcPr.find(qn("w:vMerge")) is not None
    return False


def _logical_column_count(tbl_element) -> int:
    """Return the maximum logical column count across all rows."""
    max_cols = 0
    for tr in tbl_element.findall(qn("w:tr")):
        total = sum(_get_gridspan(tc) for tc in tr.findall(qn("w:tc")))
        max_cols = max(max_cols, total)
    return max_cols


def _detect_header_rows(tbl_element) -> set[int]:
    """Detect header row indices.

    Primary: rows with w:tblHeader in w:trPr.
    Fallback: if no rows have w:tblHeader, all rows before the first row
    where every cell has gridSpan=1 and no vMerge.
    """
    trs = tbl_element.findall(qn("w:tr"))

    # Primary: w:tblHeader
    header_indices = set()
    for i, tr in enumerate(trs):
        trPr = tr.find(qn("w:trPr"))
        if trPr is not None and trPr.find(qn("w:tblHeader")) is not None:
            header_indices.add(i)

    if header_indices:
        return header_indices

    # Fallback: rows before first fully normal row
    for i, tr in enumerate(trs):
        tcs = tr.findall(qn("w:tc"))
        all_normal = all(
            _get_gridspan(tc) == 1 and not _has_vmerge(tc) for tc in tcs
        )
        if all_normal:
            return set(range(i))

    # All rows have spans/merges — no headers detected
    return set()


def _is_full_width_row(tr, logical_cols: int) -> bool:
    """Return True if the row is a single cell spanning all columns."""
    tcs = tr.findall(qn("w:tc"))
    if len(tcs) != 1:
        return False
    return _get_gridspan(tcs[0]) >= logical_cols


def _get_body_row_indices(tbl_element) -> list[int]:
    """Return indices of body rows (not headers, not full-width spans)."""
    trs = tbl_element.findall(qn("w:tr"))
    logical_cols = _logical_column_count(tbl_element)
    header_rows = _detect_header_rows(tbl_element)

    indices = []
    for i, tr in enumerate(trs):
        if i in header_rows:
            continue
        if _is_full_width_row(tr, logical_cols):
            continue
        indices.append(i)
    return indices


def _extract_body_grid(tbl_element) -> list[list[str]]:
    """Extract cell text from body rows as a 2D grid.

    Same row filtering as _compute_table_content_hash:
    skips headers, full-width rows.
    Returns list of rows, each row is a list of stripped cell text strings.
    """
    trs = tbl_element.findall(qn("w:tr"))
    body_indices = _get_body_row_indices(tbl_element)

    grid = []
    for i in body_indices:
        tr = trs[i]
        cells = []
        for tc in tr.findall(qn("w:tc")):
            text = "".join(
                t.text for t in tc.iter(qn("w:t")) if t.text
            ).strip()
            cells.append(text)
        grid.append(cells)
    return grid


def _grid_to_canonical(grid: list[list[str]]) -> str:
    """Convert a body grid to the canonical tab/newline string."""
    return "\n".join("\t".join(row) for row in grid)


def _compute_table_content_hash(tbl_element) -> str:
    """Extract cell text from body rows of a table, normalize, and SHA-256 hash.

    Skips header rows (w:tblHeader or fallback detection) and full-width
    rows (single cell spanning all columns — section labels, footers).

    Normalization: rows top-to-bottom, cells left-to-right,
    each cell stripped, joined with \\t (cells) and \\n (rows).
    """
    grid = _extract_body_grid(tbl_element)
    canonical = _grid_to_canonical(grid)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


_CONTENT_HASH_PATTERN = re.compile(r"\[content_hash:([a-f0-9]+)\]")
_CONTENT_BODY_PATTERN = re.compile(r"\[content_body:([A-Za-z0-9+/=]+)\]")


def _extract_content_hash_from_alt_text(alt_text: str) -> str | None:
    """Extract the content_hash value from alt text."""
    match = _CONTENT_HASH_PATTERN.search(alt_text)
    return match.group(1) if match else None


def _encode_body_grid(grid: list[list[str]]) -> str:
    """Gzip + base64 encode a body grid for embedding in alt text."""
    canonical = _grid_to_canonical(grid)
    compressed = gzip.compress(canonical.encode("utf-8"))
    return base64.b64encode(compressed).decode("ascii")


def _decode_body_grid(encoded: str) -> list[list[str]] | None:
    """Decode a gzip + base64 encoded body grid from alt text."""
    try:
        compressed = base64.b64decode(encoded)
        canonical = gzip.decompress(compressed).decode("utf-8")
        return [row.split("\t") for row in canonical.split("\n") if row]
    except Exception:
        return None


def _extract_body_grid_from_alt_text(alt_text: str) -> list[list[str]] | None:
    """Extract and decode the body grid from alt text."""
    match = _CONTENT_BODY_PATTERN.search(alt_text)
    if not match:
        return None
    return _decode_body_grid(match.group(1))


def is_table_content_unchanged(alt_text: str, tbl_element) -> bool:
    """Check if a table's content matches its embedded content hash.

    Compares the content_hash stored in alt text (from insertion time)
    against a fresh hash of the table's current cell text in the docx.
    Returns True only if both exist and match.
    """
    embedded = _extract_content_hash_from_alt_text(alt_text)
    if not embedded:
        return False
    current = _compute_table_content_hash(tbl_element)
    return embedded == current


def is_table_unchanged(
    alt_text: str,
    tbl_element,
    artifact_dir: str | None,
    filename: str,
) -> bool:
    """Check if a table is fully unchanged (source + content).

    Both checks must pass to skip removal:
    1. Object hash: source file hasn't changed (alt text vs metadata)
    2. Content hash: table values not edited in Word (alt text vs XML)

    Returns True only if both are unchanged.
    """
    if not is_artifact_unchanged(alt_text, artifact_dir, filename):
        return False
    if not is_table_content_unchanged(alt_text, tbl_element):
        return False
    return True


def add_figure_alt_text(docx_in: str, docx_out: str, artifact_dir: str | None = None):
    logger = setup_logger()
    logger.debug("Starting add_figure_alt_text function")
    logger.debug(f"Loading document from: {docx_in}")

    magic_pattern = get_magic_pattern()

    doc = Document(docx_in)

    body = doc._element.body
    paragraphs = list(body)

    # Find magic paragraphs and process the next paragraph for images
    for idx, para in enumerate(paragraphs):
        if not para.tag.endswith("}p"):
            continue

        text_elements = para.xpath(".//w:t")
        para_text = "".join([t.text for t in text_elements if t.text])

        match = magic_pattern.search(para_text)
        if match and idx + 1 < len(paragraphs):
            # Extract filename and check extension
            entries = parse_magic_entries(match.group())
            if not entries:
                continue
            filename, _args = entries[0]
            extension = os.path.splitext(filename)[1].lower()
            if extension != ".png":
                logger.debug(f"Skipping non-png magic string: {filename}")
                continue

            logger.info(f"Processing alt text for figure: {filename}")

            # Load hash from metadata if artifact_dir provided
            hash_value = None
            if artifact_dir:
                hash_value = _load_artifact_hash(artifact_dir, filename)
                if hash_value:
                    logger.debug(f"Loaded hash for {filename}: {hash_value}")

            alt_text = _embed_hash_in_alt_text(para_text, hash_value)

            next_para = paragraphs[idx + 1]

            drawings = next_para.xpath(".//w:drawing")
            for drawing in drawings:
                inlines = drawing.xpath(".//wp:inline")
                for inline in inlines:
                    doc_pr = inline.xpath(".//wp:docPr")
                    if doc_pr:
                        doc_pr[0].set("descr", alt_text)
                        logger.info(f"Inserted alt text for figure: {filename}")

    doc.save(docx_out)
    logger.info(f"Alt text saved to '{docx_out}'")
    logger.debug("Exiting add_figure_alt_text function")


def set_table_alt_text(table, alt_text):
    """
    Set both the Alt Text title and description of a python-docx Table.
    """
    tblPr = table._tbl.tblPr

    desc = OxmlElement("w:tblDescription")
    desc.set(qn("w:val"), alt_text)
    tblPr.append(desc)


def add_table_alt_text(docx_in: str, docx_out: str, artifact_dir: str | None = None):
    logger = setup_logger()
    logger.debug("Starting add_table_alt_text function")
    logger.debug(f"Loading document from: {docx_in}")

    magic_pattern = get_magic_pattern()

    doc = Document(docx_in)

    # Map raw <w:tbl> elements back to their Table objects
    tbl_map = {tbl._element: tbl for tbl in doc.tables}

    # Get the direct children of <w:body>: paragraphs and tables in order
    body = doc._element.body
    siblings = list(body)

    for idx, el in enumerate(siblings):
        if not el.tag.endswith("}tbl"):
            continue
        if idx == 0 or not siblings[idx - 1].tag.endswith("}p"):
            continue
        para_el = siblings[idx - 1]

        texts = [t.text for t in para_el.xpath(".//w:t") if t.text]
        para_text = "".join(texts).strip()

        if magic_pattern.search(para_text):
            # Extract table name from magic string
            table_name = (
                magic_pattern.search(para_text).group().replace("{rpfy}:", "").strip()
            )
            logger.info(f"Processing alt text for table: {table_name}")

            # Load hash from metadata if artifact_dir provided
            hash_value = None
            if artifact_dir:
                hash_value = _load_artifact_hash(artifact_dir, table_name)
                if hash_value:
                    logger.debug(f"Loaded hash for {table_name}: {hash_value}")

            alt_text = _embed_hash_in_alt_text(para_text, hash_value)

            # Compute content hash and body grid from table cell text
            body_grid = _extract_body_grid(el)
            canonical = _grid_to_canonical(body_grid)
            content_hash = hashlib.sha256(
                canonical.encode("utf-8")
            ).hexdigest()
            encoded_body = _encode_body_grid(body_grid)
            alt_text = (
                f"{alt_text} [content_hash:{content_hash}]"
                f" [content_body:{encoded_body}]"
            )
            logger.debug(
                f"Content hash for {table_name}: {content_hash}"
            )

            table = tbl_map.get(el)
            if table:
                set_table_alt_text(table, alt_text)
                logger.info(f"Inserted alt text for table: {table_name}")
            else:
                logger.warning(
                    f"Could not find table object for element at index {idx}"
                )

    # save the updated document
    doc.save(docx_out)
    logger.info(f"Table alt text saved to '{docx_out}'")
    logger.debug("Exiting add_table_alt_text function")


def check_alt_text_magic_string(docx_in: str):
    logger = setup_logger()
    logger.debug("Starting check_alt_text_magic_string function")

    magic_pattern = get_magic_pattern()

    doc = Document(docx_in)

    # Map raw <w:tbl> elements back to their Table objects
    tbl_map = {tbl._element: tbl for tbl in doc.tables}

    body = doc._element.body
    paragraphs = list(body)

    # Find magic paragraphs and process the next paragraph for images
    for idx, para in enumerate(paragraphs):
        if not para.tag.endswith("}p"):
            continue

        text_elements = para.xpath(".//w:t")
        para_text = "".join([t.text for t in text_elements if t.text])

        if magic_pattern.search(para_text) and idx + 1 < len(paragraphs):
            # check for drawing and tbl
            check_drawing_alt_text(logger, paragraphs[idx + 1], para_text)
            check_table_alt_text(logger, tbl_map.get(paragraphs[idx + 1]), para_text)

    logger.debug("Exiting check_alt_text_magic_string function")


def check_drawing_alt_text(logger, paragraph, para_text: str):
    drawings = paragraph.xpath(".//w:drawing")
    for drawing in drawings:
        inlines = drawing.xpath(".//wp:inline")
        for inline in inlines:
            doc_pr = inline.xpath(".//wp:docPr")
            if doc_pr:
                alt_text = doc_pr[0].get("descr")
                if alt_text is None:
                    logger.warning(
                        f"Magic mismatch! Alt text MISSING for magic string: {para_text}"
                    )
                elif _strip_hash_from_alt_text(alt_text) != para_text:
                    logger.warning(
                        f"Magic mismatch! Magic string: {para_text} != alt text: {alt_text}"
                    )


def check_table_alt_text(logger, table, para_text: str):
    if table is None:
        return

    tbl_pr = table._tbl.tblPr
    desc = tbl_pr.find(qn("w:tblDescription"))
    if desc is None:
        logger.warning("Table found but it has no alt text description or title.")
        return

    alt_text = desc.get(qn("w:val"))
    if alt_text is None:
        logger.warning(f"Magic mismatch! Alt text MISSING for magic string: {para_text}")
    elif _strip_hash_from_alt_text(alt_text) != para_text:
        logger.warning(f"Magic mismatch! Magic string: {para_text} != alt text: {alt_text}")


def extract_artifact_hashes(docx_in: str) -> dict[str, str]:
    """Extract artifact hashes from alt text in a docx file.

    Scans figures (wp:docPr descr) and tables (w:tblDescription) for
    [hash:...] suffixes embedded by add_figure_alt_text/add_table_alt_text.

    Returns a dict mapping artifact filenames to their hash strings.
    """
    logger = setup_logger()
    logger.debug("Starting extract_artifact_hashes function")

    hash_pattern = re.compile(r"\[hash:([a-f0-9]+)\]")
    magic_pattern = get_magic_pattern()

    doc = Document(docx_in)
    hashes: dict[str, str] = {}

    body = doc._element.body
    siblings = list(body)

    for idx, el in enumerate(siblings):
        # Check figures: magic paragraph followed by drawing
        if el.tag.endswith("}p"):
            text_elements = el.xpath(".//w:t")
            para_text = "".join([t.text for t in text_elements if t.text])
            match = magic_pattern.search(para_text)
            if match and idx + 1 < len(siblings):
                next_el = siblings[idx + 1]
                # Check drawings in next paragraph
                if next_el.tag.endswith("}p"):
                    for drawing in next_el.xpath(".//w:drawing"):
                        for inline in drawing.xpath(".//wp:inline"):
                            for doc_pr in inline.xpath(".//wp:docPr"):
                                descr = doc_pr.get("descr", "")
                                hash_match = hash_pattern.search(descr)
                                if hash_match:
                                    entries = parse_magic_entries(match.group())
                                    for filename, _ in entries:
                                        hashes[filename] = hash_match.group(1)
                                        logger.debug(
                                            f"Extracted hash for figure {filename}: {hash_match.group(1)}"
                                        )

        # Check tables: magic paragraph before table element
        if el.tag.endswith("}tbl") and idx > 0:
            prev_el = siblings[idx - 1]
            if prev_el.tag.endswith("}p"):
                texts = [t.text for t in prev_el.xpath(".//w:t") if t.text]
                prev_text = "".join(texts).strip()
                if magic_pattern.search(prev_text):
                    table_name = (
                        magic_pattern.search(prev_text)
                        .group()
                        .replace("{rpfy}:", "")
                        .strip()
                    )
                    # Find table description alt text
                    tbl_pr = el.find(qn("w:tblPr"))
                    if tbl_pr is not None:
                        desc = tbl_pr.find(qn("w:tblDescription"))
                        if desc is not None:
                            alt_text = desc.get(qn("w:val"), "")
                            hash_match = hash_pattern.search(alt_text)
                            if hash_match:
                                hashes[table_name] = hash_match.group(1)
                                logger.debug(
                                    f"Extracted hash for table {table_name}: {hash_match.group(1)}"
                                )

    logger.debug(f"Extracted {len(hashes)} artifact hashes")
    logger.debug("Exiting extract_artifact_hashes function")
    return hashes
