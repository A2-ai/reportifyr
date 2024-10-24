import argparse
from docx import Document

def remove_figures(docx_in, docx_out):
    doc = Document(docx_in)
    namespace = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'

    for paragraph in doc.paragraphs:
        if paragraph.text.startswith('{rpfy}:'):
            for drawing in paragraph._element.xpath(f'.//w:drawing'):
                drawing.getparent().remove(drawing)

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove figures from input docx document")
    parser.add_argument('-i', '--input', type = str, required = True, help = "input docx file path")
    parser.add_argument('-o', '--output', type = str, required = True, help = "output docx file path")
    args = parser.parse_args()

    remove_figures(args.input, args.output)
