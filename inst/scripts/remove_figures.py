import argparse
import helper
from docx import Document

from typing import Optional
from parse_magic_string import parse_magic_string

def remove_figures(
    docx_in: str,
    docx_out: str,
    config_yaml: Optional[str],
):
    doc = Document(docx_in)
    paragraphs = doc.paragraphs

    # load config.yaml or set empty dict for defaults.
    if config_yaml is not None:
        config = helper.load_yaml(config_yaml)
    else:
        config = {}

    for i, paragraph in enumerate(paragraphs):
        text = paragraph.text.strip()
        if text.startswith("{rpfy}:"):
            figure_args = parse_magic_string(text)
            update_magic_string = False

            # if config.get("use_
            # update paragraph text
            # f"{text}<width: {helper.get_width()}, height: {helper.get_height()}>"
            paragraphs_to_remove = []
            for j, args in enumerate(figure_args.values()):
                if i + j + 1 < len(paragraphs):
                    next_par = paragraphs[i + j + 1]
                    if not next_par.text.strip() and next_par._element.xpath(
                        ".//w:drawing"
                    ):
                        paragraphs_to_remove.append((i + j + 1, next_par))
                        if config.get("use_embedded_dimensions", True):
                            dimensions = get_figure_dimensions(next_par)
                            # set width and height from emu to Inches
                            if dimensions["width"]:
                                args["width"] = str(
                                    round(dimensions["width"] / 914400, 2)
                                )
                                update_magic_string = True
                            if dimensions["height"]:
                                args["height"] = str(
                                    round(dimensions["height"] / 914400, 2)
                                )
                                update_magic_string = True

            # update text here:
            # {rpfy}:[figure<args[figure]>]
            if update_magic_string:
                new_magic_string = "{rpfy}:"
                if len(figure_args) > 1:
                    new_magic_string += "["
                    ending_string = "]"
                else:
                    ending_string = ""
                for fig_idx, (fig, arg) in enumerate(figure_args.items()):
                    arg_string = "<"
                    for p_idx, (prop, val) in enumerate(arg.items()):
                        arg_string += f"{prop}: {val}"
                        if p_idx + 1 != len(arg):
                            arg_string += ", "
                    arg_string += ">"

                    new_magic_string += f"{fig}{arg_string}"
                    if fig_idx + 1 != len(figure_args):
                        new_magic_string += ", "

                new_magic_string += ending_string
                paragraph.text = new_magic_string

            for _, par in reversed(paragraphs_to_remove):
                par._element.getparent().remove(par._element)

    doc.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")


def get_figure_dimensions(paragraph) -> dict[str, Optional[int]]:
    """Extract width and height from a paragraph containing a drawing."""
    # Get all drawing elements in the paragraph
    drawing_elements = paragraph._element.xpath(".//w:drawing")

    if not drawing_elements:
        return {}

    # Get the first drawing element
    drawing = drawing_elements[0]

    # Find the extent element within the drawing
    extent_elements = drawing.xpath(".//wp:extent")

    if not extent_elements:
        return {}

    # Get the first extent element
    extent = extent_elements[0]

    # Extract cx and cy values
    cx = extent.get(
        "{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}cx"
    )
    cy = extent.get(
        "{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}cy"
    )

    # If using namespaces doesn't work, try getting attributes directly
    if cx is None:
        cx = extent.get("cx")
    if cy is None:
        cy = extent.get("cy")

    if cx is None or cy is None:
        return {}

    # Convert to integers
    width = int(cx)
    height = int(cy)

    return {"width": width, "height": height}


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
    parser.add_argument(
        "-c", "--config", type=str, default=None, help="Path to config.yaml"
    )
    args = parser.parse_args()

    remove_figures(args.input, args.output, args.config)
