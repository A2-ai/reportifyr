import os
import re
import argparse
from typing import Optional
from docx import Document
from rpfy_logger import setup_logger


def tag_figures_with_magic(docx_in: str, docx_out: str, log_file: Optional[str] = None):
    logger = setup_logger(log_file)
    logger.debug("Starting add_figure_alt_text function")
    logger.debug(f"Loading document from: {docx_in}")

    # Define magic string pattern
    start_pattern = r"\{rpfy\}\:"
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)

    doc = Document(docx_in)

    body = doc._element.body
    paragraphs = list(body)

    figures_processed = 0

    # Find magic paragraphs and process the next paragraph for images
    for idx, para in enumerate(paragraphs):
        if not para.tag.endswith("}p"):
            continue

        text_elements = para.xpath(".//w:t")
        para_text = "".join([t.text for t in text_elements if t.text])

        match = magic_pattern.search(para_text)
        if match and idx + 1 < len(paragraphs):
            # Extract filename and check extension
            filename = match.group().replace("{rpfy}:", "").strip()
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
                        figures_processed += 1
                        logger.info(f"Inserted alt text for figure: {filename}")

    doc.save(docx_out)
    logger.info(f"Alt text saved to '{docx_out}'")
    logger.debug("Exiting add_figure_alt_text function")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Add magic string alt text to figures in docx"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument("-o", "--output", type=str, required=True, help="output docx")
    parser.add_argument("-l", "--log", type=str, default=None, help="Log file path")
    args = parser.parse_args()

    tag_figures_with_magic(args.input, args.output, args.log)
