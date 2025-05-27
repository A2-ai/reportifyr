import re
import argparse
from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn


def set_table_alt_text(table, alt_text):
    """
    Set both the Alt Text title and description of a python-docx Table.
    """
    tblPr = table._tbl.tblPr

    desc = OxmlElement("w:tblDescription")
    desc.set(qn("w:val"), alt_text)
    tblPr.append(desc)


def tag_tables_with_magic(docx_in: str, docx_out: str):
    # Define magic string pattern
    # Matches "{rpfy}:" and any directory structure following it
    start_pattern = r"\{rpfy\}\:"
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)
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
            table = tbl_map.get(el)
            if table:
                set_table_alt_text(table, para_text)

    # save the updated document
    doc.save(docx_out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Add magic string alt text to input docx tables"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument("-o", "--output", type=str, required=True, help="output docx")
    args = parser.parse_args()

    tag_tables_with_magic(args.input, args.output)
