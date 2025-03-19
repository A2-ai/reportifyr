import os
import re
import sys
import json
import yaml
import helper
import argparse
from docx import Document
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


def add_figure_footnotes(
    docx_in: str,
    docx_out: str,
    figure_dir: str,
    footnotes_yaml: str,
    include_object_path: bool = False,
    fail_on_missing_metadata: bool = True,
):
    # Load standard footnotes from a yaml file
    with open(footnotes_yaml, "r") as y:
        footnotes = yaml.safe_load(y)

    document = Document(docx_in)

    # Define magic string pattern
    start_pattern = (
        r"\{rpfy\}\:"  # Matches "{rpfy}:" and any directory structure following it
    )
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)
    paragraphs = document.paragraphs
    missing_metadata = False

    for i, par in enumerate(paragraphs):
        matches = magic_pattern.findall(par.text)
        if matches:
            if len(matches) > len(set(matches)):
                print(f"Duplicate figure names found in paragraph {i+1}")

            for match in matches:
                # Generalized extraction of the figure name
                figure_name = match.replace("{rpfy}:", "").strip()
                
                if "[" not in figure_name:
                    figures = figure_name.split(",")
                else:
                    figures = figure_name.replace(" ", "").replace("[", "").replace("]", "").split(",")
                
                # Footnotes will get added in reverse
                # order for multi figure addition such that
                # all footnotes happen after the last figure
                # and in correct order.
                for figure_name in reversed(figures):
                    if figure_name in os.listdir(figure_dir):

                        object_name, extension = os.path.splitext(figure_name)
                        metadata_file = os.path.join(
                            figure_dir, f"{object_name}_{extension[1::]}_metadata.json"
                        )

                        add_footnote = False
                        try:
                            with open(metadata_file, "r") as m:
                                metadata = json.load(m)
                            add_footnote = True

                        except FileNotFoundError:
                            print(
                                f"Metadata file not found: {metadata_file}", file=sys.stderr
                            )
                            missing_metadata = True

                        if add_footnote:
                            meta_text_lines = helper.create_meta_text_lines(
                                footnotes, metadata, include_object_path, "figure"
                            )

                            # Insert text after the paragraph that contains the image
                            footnote_inserted = False
                            for j in range(i, len(paragraphs)):
                                paragraph = paragraphs[j]
                                if any(
                                    run.element.xpath(".//pic:pic")
                                    for run in paragraph.runs
                                ):
                                    if not footnote_inserted:
                                        new_paragraph = OxmlElement("w:p")

                                        # Create the bookmark start
                                        bookmark_start = OxmlElement("w:bookmarkStart")
                                        bookmark_start.set(qn("w:id"), str(i))
                                        bookmark_start.set(
                                            qn("w:name"), f"fp_{figure_name}"
                                        )
                                        new_paragraph.append(bookmark_start)

                                        for line in meta_text_lines:
                                            new_run = OxmlElement("w:r")

                                            rPr = OxmlElement("w:rPr")
                                            rFonts = OxmlElement("w:rFonts")
                                            rFonts.set(qn("w:ascii"), "Arial Narrow")
                                            sz = OxmlElement("w:sz")
                                            sz.set(qn("w:val"), "20")
                                            rPr.append(rFonts)
                                            rPr.append(sz)
                                            new_run.append(rPr)

                                            new_text = OxmlElement("w:t")
                                            new_text.text = line
                                            new_run.append(new_text)
                                            new_paragraph.append(new_run)

                                            # Add a line break
                                            if (
                                                line != meta_text_lines[-1]
                                                and line.strip() != ""
                                            ):
                                                run_break = OxmlElement("w:r")
                                                br = OxmlElement("w:br")
                                                run_break.append(br)
                                                new_paragraph.append(run_break)

                                        # Create the bookmark end
                                        bookmark_end = OxmlElement("w:bookmarkEnd")
                                        bookmark_end.set(qn("w:id"), str(i))
                                        new_paragraph.append(bookmark_end)

                                        paragraph._element.addnext(new_paragraph)
                                        footnote_inserted = True

    # Save the processed document
    if missing_metadata and fail_on_missing_metadata:
        print(
            "Output not created due to missing metadata. Please check logs for missing metadata files."
        )
        sys.exit(1)
    else:
        document.save(docx_out)
        print(f"Processed file saved at '{docx_out}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Add figure footnotes to input docx document"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument(
        "-o", "--output", type=str, required=True, help="Ouptu docx file"
    )
    parser.add_argument(
        "-d", "--figure_dir", type=str, required=True, help="Path to figures directory"
    )
    parser.add_argument(
        "-f",
        "--footnotes",
        type=str,
        required=True,
        help="path to standard footnotes yaml",
    )
    parser.add_argument(
        "-b",
        "--object",
        type=lambda x: x.lower() in ["true", "t"],
        help="include object path",
    )
    parser.add_argument(
        "-m",
        "--fail_metadata",
        type=lambda x: x.lower() in ["true", "t"],
        help="Allow missing metadata files",
    )
    args = parser.parse_args()

    add_figure_footnotes(
        args.input,
        args.output,
        args.figure_dir,
        args.footnotes,
        args.object,
        args.fail_metadata,
    )
