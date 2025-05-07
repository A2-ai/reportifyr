import re
import argparse
from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn


def check_alt_text_magic_string(docx_in: str):
    # Define magic string pattern
    start_pattern = r"\{rpfy\}\:"
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)

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
            check_drawing_alt_text(paragraphs[idx + 1], para_text)
            check_table_alt_text(tbl_map.get(paragraphs[idx + 1]), para_text) 

def check_drawing_alt_text(paragraph, para_text: str):
    drawings = paragraph.xpath(".//w:drawing")
    for drawing in drawings:
        inlines = drawing.xpath(".//wp:inline")
        for inline in inlines:
            doc_pr = inline.xpath(".//wp:docPr")
            if doc_pr:
                alt_text = doc_pr[0].get("descr")
                if alt_text != para_text:
                    print(f"Magic mismatch! magic string: {para_text} != alt-text: {alt_text}")


def check_table_alt_text(table, para_text: str):
    if table is None:
        return

    tbl_pr = table._tbl.tblPr
    
    desc = tbl_pr.find(qn("w:tblDescription"))
    alt_text = desc.get(qn("w:val"))

    if alt_text != para_text:
        print(f"Magic mismatch! magic string: {para_text} != alt-text: {alt_text}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Add magic string alt text to figures in docx"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    args = parser.parse_args()

    check_alt_text_magic_string(args.input)
