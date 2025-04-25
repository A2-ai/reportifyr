import argparse
import re
from docx import Document
from docx.oxml import OxmlElement

def keep_caption_next(docx_in, docx_out):
  
    doc = Document(docx_in)
    """
    Finds caption paragraphs (containing 'SEQ Table' or 'SEQ Figure') and applies 'keepNext'.
    Also applies 'keepNext' to the next paragraph if it contains a matching magic string.
    """
    # Define magic string pattern
    start_pattern = r"\{rpfy\}\:"
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)

    paragraphs = doc.paragraphs
    n = len(paragraphs)

    for i, para in enumerate(paragraphs):
        # Check if this paragraph is a caption
        fld_elements = para._element.xpath(".//w:fldSimple")
        is_caption = False
        for fld in fld_elements:
            instr_value = fld.get(
                "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}instr"
            )
            if instr_value and ("SEQ Table" in instr_value or "SEQ Figure" in instr_value):
                is_caption = True
                break
        
        if is_caption:
            # Apply keepNext to caption paragraph
            pPr = para._element.get_or_add_pPr()
            if not pPr.xpath("./w:keepNext"):
                keep_next = OxmlElement("w:keepNext")
                pPr.append(keep_next)

            # Check the next paragraph
            if i + 1 < n:
                next_para = paragraphs[i + 1]
                if magic_pattern.search(next_para.text):
                    pPr_next = next_para._element.get_or_add_pPr()
                    if not pPr_next.xpath("./w:keepNext"):
                        keep_next_next = OxmlElement("w:keepNext")
                        pPr_next.append(keep_next_next)

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
