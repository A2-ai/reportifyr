import os
import re
import argparse
from docx import Document
from docx.shared import Inches

def add_figure(docx_in, docx_out, figure_paths, fig_width=None, fig_height=None):
    figure_paths = figure_paths.split(',')
    figure_dict = {os.path.basename(path): path for path in figure_paths}

    document = Document(docx_in)
    
    # Define magic string pattern
    start_pattern = r'\{rpfy\}\:'  # Matches "{rpfy}:" and any directory structure following it
    end_pattern = r'\.[^.]+$'
    magic_pattern = re.compile(start_pattern + '.*?' + end_pattern)
    found_magic_strings = []

    for i, par in enumerate(document.paragraphs):
        matches = magic_pattern.findall(par.text)
        if matches:
            if len(matches) > len(set(matches)):
                print(f"Duplicate figure names found in paragraph {i+1}.")
            for match in matches:
                # Extract the figure name from the magic string
                figure_name = match.replace("{rpfy}:", "").strip()
                found_magic_strings.append(figure_name)

                # Match the figure name to the figure paths
                if figure_name in figure_dict:
                    image_path = figure_dict[figure_name]
                    run = par.add_run()
                    try:
                        if fig_width is not None and fig_height is not None:
                            run.add_picture(image_path, width=Inches(float(fig_width)), height=Inches(float(fig_height)))
                        elif fig_width is not None:
                            run.add_picture(image_path, width=Inches(float(fig_width)))
                        elif fig_height is not None:
                            run.add_picture(image_path, height=Inches(float(fig_height)))
                        else:
                            run.add_picture(image_path, width=Inches(6))  # Hardcoded backup size
                    except Exception as e:
                        print(f"Failed to add image '{image_path}': {e}")
                else:
                    print(f"Figure '{figure_name}' not found in the provided file paths.")

    # Check for duplicate magic strings in the entire document
    if len(set(found_magic_strings)) != len(found_magic_strings):   
        print("Duplicate figure names found in the document.")

    document.save(docx_out)
    print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add figures to input docx document")
    parser.add_argument('-i', '--input', type=str, required=True, help="Input docx file path")
    parser.add_argument('-o', '--output', type=str, required=True, help="Output docx file path")
    parser.add_argument('-d', '--figure_paths', type=str, required=True, help="Comma-separated list of figure file paths")
    parser.add_argument('-w', '--width', type=str, default=None, help="Figure width in inches")
    parser.add_argument('-g', '--height', type=str, default=None, help="Figure height in inches")
    args = parser.parse_args()

    add_figure(args.input, args.output, args.figure_paths, args.width, args.height)
