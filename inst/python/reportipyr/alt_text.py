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
    """Remove [hash:...] suffix from alt text for comparison."""
    return re.sub(r"\s*\[hash:[a-f0-9]+\]$", "", alt_text)


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
