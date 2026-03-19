import os

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

from .logging import setup_logger
from .magic import get_magic_pattern, parse_magic_entries


def add_figure_alt_text(docx_in: str, docx_out: str):
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
            next_para = paragraphs[idx + 1]

            drawings = next_para.xpath(".//w:drawing")
            for drawing in drawings:
                inlines = drawing.xpath(".//wp:inline")
                for inline in inlines:
                    doc_pr = inline.xpath(".//wp:docPr")
                    if doc_pr:
                        doc_pr[0].set("descr", para_text)
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


def add_table_alt_text(docx_in: str, docx_out: str):
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
            table = tbl_map.get(el)
            if table:
                set_table_alt_text(table, para_text)
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
                elif alt_text != para_text:
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
    elif alt_text != para_text:
        logger.warning(f"Magic mismatch! Magic string: {para_text} != alt text: {alt_text}")
