import argparse
from docx import Document

def remove_tables(docx_in, docx_out):
    doc = Document(docx_in)
    namespace = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'

    for paragraph in doc.paragraphs:
        if paragraph.text.startswith('{rpfy}:'):
            p_element = paragraph._element
            for next_elem in p_element.itersiblings():
                if next_elem.tag.endswith('tbl'):
                    next_elem.getparent().remove(next_elem)
                    break
                elif next_elem.tag.endswith('p'):
                    break

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add figures to input docx document")
    parser.add_argument('-i', '--input', type = str, required=True, help = "input docx file path")
    parser.add_argument("-o", "--output", type = str, required=True, help = "output docx file path")
    args = parser.parse_args()

    remove_tables(args.input, args.output)
