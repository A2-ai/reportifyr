import argparse
from docx import Document


def remove_magic_strings(docx_in, docx_out):
    sentinel = "{rpfy}:"  # Magic String

    doc = Document(docx_in)

    # Iterate over paragraphs to either clear text or remove the paragraph
    for para in doc.paragraphs:
        if sentinel in para.text:
            # Check if the paragraph contains a 'pic:pic' element (image)
            contains_pic = any(run.element.xpath(".//pic:pic") for run in para.runs)

            if contains_pic:
                # Clear only the text runs in the paragraph, preserving the picture
                for run in para.runs:
                    if not run.element.xpath(
                        ".//pic:pic"
                    ):  # If the run doesn't contain an image
                        run.text = ""  # Clear only the text
            else:
                # Remove the paragraph if it doesn't contain an image
                p = para._element
                p.getparent().remove(p)

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Remove magic strings from input docx document"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument(
        "-o", "--output", type=str, required=True, help="Output docx file"
    )
    args = parser.parse_args()

    remove_magic_strings(args.input, args.output)
