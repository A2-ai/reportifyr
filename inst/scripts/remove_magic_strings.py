import argparse
from docx import Document
from docx.oxml import OxmlElement

def remove_magic_strings(docx_in, docx_out):
    sentinel = "{rpfy}:"  # Magic String

    doc = Document(docx_in)

    # Iterate over paragraphs to either clear text or remove the paragraph
    for para in doc.paragraphs:
        if sentinel in para.text:
            # Check if the paragraph contains a "pic:pic" element (image)
            contains_pic = any(run.element.xpath(".//pic:pic") for run in para.runs)

            if contains_pic:
                # Clear only the text runs in the paragraph, preserving the picture
                for run in para.runs:
                    if not run.element.xpath(".//pic:pic"):
                        run.text = ""  # Clear only the text
            else:
                # Remove the paragraph if it doesn"t contain an image
                p = para._element
                p.getparent().remove(p)

        else:
            is_caption = False
            fld_elements = para._element.xpath(".//w:fldSimple")
            for fld in fld_elements:
                # w:instr is in the WordprocessingML namespace
                instr_value = fld.get("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}instr")
                if instr_value and ("SEQ Table" in instr_value or "SEQ Figure" in instr_value):
                    is_caption = True
                    break

            if is_caption:
                pPr = para._element.get_or_add_pPr()
                keep_next = OxmlElement("w:keepNext")
                pPr.append(keep_next)

    doc.save(docx_out)
    print(f"Processed file saved at {docx_out}.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove magic strings from input docx document")
    parser.add_argument("-i", "--input", type=str, required=True, help="input docx file path")
    parser.add_argument("-o", "--output", type=str, required=True, help="Output docx file")
    args = parser.parse_args()

    remove_magic_strings(args.input, args.output)
