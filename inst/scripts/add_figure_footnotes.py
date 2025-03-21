import os
import re
import sys
import helper
import argparse
from docx import Document


def add_figure_footnotes(
    docx_in: str,
    docx_out: str,
    figure_dir: str,
    footnotes_yaml: str,
    config_yaml: str,
    include_object_path: bool = False,
    fail_on_missing_metadata: bool = True,
):
    # load standard footnotes from a yaml file
    footnotes = helper.load_yaml(footnotes_yaml)
    config = helper.load_yaml(config_yaml)

    document = Document(docx_in)

    # define magic string pattern
    # matches "{rpfy}:" and any directory structure following it
    start_pattern = r"\{rpfy\}\:"
    end_pattern = r"\.[^.]+$"
    magic_pattern = re.compile(start_pattern + ".*?" + end_pattern)

    paragraphs = document.paragraphs
    missing_metadata = False

    for i, par in enumerate(paragraphs):
        matches = magic_pattern.findall(par.text)
        if not matches:
            continue

        if len(matches) > len(set(matches)):
            print(f"duplicate figure names found in paragraph {i+1}")

        for match in matches:
            # generalized extraction of the figure name
            figure_name = match.replace("{rpfy}:", "").strip()

            if "[" not in figure_name:
                figures = figure_name.split(",")
            else:
                figures = (
                    figure_name.replace(" ", "")
                    .replace("[", "")
                    .replace("]", "")
                    .split(",")
                )
            # create empty dict for combining all metadata
            combined_footnotes = {}
            # enumerating here so i can use f to get label for
            # helper.create_label(f)
            for f, figure_name in enumerate(figures):

                if figure_name in os.listdir(figure_dir):
                    metadata = helper.load_metadata(figure_dir, figure_name)

                    if metadata is not None:
                        meta_text_dict = helper.create_meta_text_lines(
                            footnotes, metadata, include_object_path, "figure"
                        )
                    else:
                        missing_metadata = True

                    if len(figures) > 1:
                        for key in meta_text_dict.keys():
                            try:
                                combined_footnotes[
                                    key
                                ] += f"{helper.create_label(f)}: {meta_text_dict[key]} "
                            except:
                                combined_footnotes[key] = (
                                    f"{helper.create_label(f)}: {meta_text_dict[key]} "
                                )
                    else:
                        combined_footnotes = meta_text_dict

                    if f == len(figures) - 1:
                        footnote_inserted = False
                        for j in range(i, len(paragraphs)):
                            paragraph = paragraphs[j]
                            if any(
                                run.element.xpath(".//pic:pic")
                                for run in paragraph.runs
                            ):
                                if not footnote_inserted:
                                    new_paragraph = helper.create_footnote_paragraph(
                                        combined_footnotes, figure_name, i, config
                                    )
                                    paragraph._element.addnext(new_paragraph)
                                    footnote_inserted = True

    # save the processed document
    if missing_metadata and fail_on_missing_metadata:
        print(
            "output not created due to missing metadata. please check logs for missing metadata files."
        )
        sys.exit(1)
    else:
        document.save(docx_out)
        print(f"processed file saved at '{docx_out}'.")


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
        "-c",
        "--config",
        type=str,
        required=True,
        help="path to config.yaml file"
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
        args.config,
        args.object,
        args.fail_metadata,
    )
