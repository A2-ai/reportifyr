import argparse
import re
from docx import Document
from docx.oxml import OxmlElement

CAPTION_STYLE = "Caption"

def keep_caption_next(docx_in, docx_out):
    doc = Document(docx_in)
    paras = doc.paragraphs
    n = len(paras)
    
    start_pattern = r"\{rpfy\}\:"
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)

    for i, p in enumerate(paras):
        is_caption = (
            (p.style and p.style.name == CAPTION_STYLE) or
            any(
                ("SEQ Table" in instr.text or "SEQ Figure" in instr.text)
                for instr in p._element.xpath(".//w:instrText")
            )
        )
        if not is_caption:
            continue

        # add keepNext to caption
        pPr = p._element.get_or_add_pPr()
        if not pPr.xpath("./w:keepNext"):
            pPr.append(OxmlElement("w:keepNext"))

        # scan forward for first paragraph with magic string
        for j in range(i + 1, n):
            q = paras[j]
            has_magic = bool(
                magic_pattern.search("".join(t.text for t in q._element.xpath(".//w:t")))
            )
            if has_magic:
                qPr = q._element.get_or_add_pPr()
                if not qPr.xpath("./w:keepNext"):
                    qPr.append(OxmlElement("w:keepNext"))
                break

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Keep captions with artifacts in input docx document")
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument(
        "-o", "--output", type=str, required=True, help="output docx file path"
    )
    args = parser.parse_args()

    keep_caption_next(args.input, args.output)
