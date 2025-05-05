import re
import argparse
from docx import Document


def tag_figures_with_magic(docx_in: str, docx_out: str):
    # Define magic string pattern
    start_pattern = r"\{rpfy\}\:"
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)

    doc = Document(docx_in)

    body = doc._element.body
    paragraphs = list(body)

    # Find magic paragraphs and process the next paragraph for images
    for idx, para in enumerate(paragraphs):
        if not para.tag.endswith("}p"):
            continue

        text_elements = para.xpath(".//w:t")
        para_text = "".join([t.text for t in text_elements if t.text])

        if magic_pattern.search(para_text) and idx + 1 < len(paragraphs):
            next_para = paragraphs[idx + 1]

            drawings = next_para.xpath(".//w:drawing")
            for drawing in drawings:
                inlines = drawing.xpath(".//wp:inline")
                for inline in inlines:
                    doc_pr = inline.xpath(".//wp:docPr")
                    if doc_pr:
                        doc_pr[0].set("descr", para_text)

    doc.save(docx_out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Add magic string alt text to figures in docx"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument("-o", "--output", type=str, required=True, help="output docx")
    args = parser.parse_args()

    tag_figures_with_magic(args.input, args.output)
