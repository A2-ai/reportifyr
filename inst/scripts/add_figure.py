import os
import re
import argparse
from docx import Document
from docx.shared import Inches

def add_figure(
    docx_in: str, docx_out: str, figure_dir: str, fig_width: float, fig_height: float
):
    document = Document(docx_in)

    # Define magic string pattern
    start_pattern = (
        r"\{rpfy\}\:"  # Matches "{rpfy}:" and any directory structure following it
    )
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)
    found_magic_strings = []

    for i, par in enumerate(document.paragraphs):
        matches = magic_pattern.findall(par.text)
        if matches:
            if len(matches) > len(set(matches)):
                print(f"Duplicate figure names found in paragraph {i+1}.")

            for match in matches:
                # Extract the image directory from the match
                figure_name = match.replace("{rpfy}:", "").strip()
    
                # If figure name isn't list like, add it to
                # found_magic_strings 
                if "[" not in figure_name: 
                    figures = figure_name.split(",")
                # Else remove brackets and create list for iterating through 
                # figures to add to paragraph.
                else:
                    figures = figure_name.replace(" ", "").replace("[", "").replace("]", "").split(",")

                for figure in  figures:
                    found_magic_strings.append(figure)
                    image_path = os.path.join(figure_dir, figure)
                    if os.path.exists(image_path):
                        run = par.add_run()
                        if fig_width is not None and fig_height is not None:
                            run.add_picture(
                                image_path,
                                width=Inches(fig_width),
                                height=Inches(fig_height),
                            )
                        elif fig_width is not None:
                            run.add_picture(image_path, width=Inches(fig_width))
                        elif fig_height is not None:
                            run.add_picture(image_path, height=Inches(fig_height))
                        else:
                            run.add_picture(image_path, width=Inches(6))  ##Hardcoded backup

    if len(set(found_magic_strings)) != len(found_magic_strings):
        print("Duplicate figure names found in the document.")
    document.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add figures to input docx document")
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument("-o", "--output", type=str, required=True, help="output docx")
    parser.add_argument(
        "-d", "--figure_dir", type=str, required=True, help="Path to figures directory"
    )
    parser.add_argument("-w", "--width", type=str, default=None, help="Figure width")
    parser.add_argument("-g", "--height", type=str, default=None, help="Figure height")
    args = parser.parse_args()

    add_figure(args.input, args.output, args.figure_dir, args.width, args.height)
