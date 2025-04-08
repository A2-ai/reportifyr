import argparse
from docx import Document

def remove_figures(docx_in, docx_out):
    doc = Document(docx_in)
    paragraphs = doc.paragraphs

    for i, paragraph in enumerate(paragraphs):
        text = paragraph.text.strip()
        if text.startswith("{rpfy}:"):
            figure_name = text.replace("{rpfy}:", "").strip()
            figure_name = figure_name.replace("[", "").replace("]", "")
            figures = [fig.strip() for fig in figure_name.split(",")]
            
            paragraphs_to_remove = []
            for j in range(len(figures)):
                if i + j + 1 < len(paragraphs):
                    next_par = paragraphs[i + j + 1]
                    if not next_par.text.strip() and next_par._element.xpath(".//w:drawing"):
                        paragraphs_to_remove.append((i + j + 1, next_par))
            
            for idx, par in reversed(paragraphs_to_remove):
                par._element.getparent().remove(par._element)

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Remove figures from input docx document"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument(
        "-o", "--output", type=str, required=True, help="output docx file path"
    )
    args = parser.parse_args()

    remove_figures(args.input, args.output)
