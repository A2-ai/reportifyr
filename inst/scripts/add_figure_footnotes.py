import os
import re
import sys
import helper
import argparse
from typing import Optional
from docx import Document
from parse_magic_string import parse_magic_string
from rpfy_logger import setup_logger


def add_figure_footnotes(
    docx_in: str,
    docx_out: str,
    figure_dir: str,
    footnotes_yaml: str,
    config_yaml: Optional[str],
    include_object_path: bool = False,
    fail_on_missing_metadata: bool = True,
    log_file: Optional[str] = None,
):
    logger = setup_logger(log_file)
    logger.debug("Starting add_figure_footnotes function")
    logger.debug(f"Loading document from: {docx_in}")
    logger.debug(f"Figure directory: {figure_dir}")

    # load standard footnotes from a yaml file
    logger.debug(f"Loading footnotes from: {footnotes_yaml}")
    footnotes = helper.load_yaml(footnotes_yaml)

    # load config.yaml or set empty dict for defaults.
    if config_yaml is not None:
        logger.debug(f"Loading config from: {config_yaml}")
        config = helper.load_yaml(config_yaml)
    else:
        config = {}

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
            logger.warning(f"Duplicate figure names found in paragraph {i+1}")

        for match in matches:
            logger.debug(f"Processing magic string: {match}")
            # generalized extraction of the figure name
            figure_args = parse_magic_string(match)

            # create empty dict for combining all metadata
            combined_footnotes: dict[str, list[str]] = {}
            # enumerating here so i can use f to get label for
            # helper.create_label(f)
            for f, figure_name in enumerate(figure_args.keys()):
                extension = os.path.splitext(figure_name)[1].lower()
                if extension != ".png":
                    logger.debug(f"Skipping non-png file: {figure_name}")
                    continue

                if figure_name not in os.listdir(figure_dir):
                    logger.debug(
                        f"Skipping {figure_name} - not found in figure directory"
                    )
                    continue

                logger.info(f"Processing footnote for figure: {figure_name}")
                metadata = helper.load_metadata(figure_dir, figure_name)

                if metadata is not None:
                    meta_text_dict = helper.create_meta_text_lines(
                        footnotes, metadata, include_object_path, "figure", config
                    )
                else:
                    logger.warning(f"Metadata file not found for: {figure_name}")
                    missing_metadata = True

                if len(figure_args) > 1:
                    for key in meta_text_dict.keys():
                        # Initialize the list for this key if it doesn't exist yet
                        if key not in combined_footnotes:
                            combined_footnotes[key] = []

                        if config.get("label_multi_figures", False):
                            new_footnote_text = (
                                f"{helper.create_label(f)}: {meta_text_dict[key]} "
                            )
                        else:
                            new_footnote_text = f"{meta_text_dict[key]} "

                        if config.get("combine_duplicate_footnotes", True):

                            if new_footnote_text not in combined_footnotes[key]:
                                combined_footnotes[key].append(new_footnote_text)

                        else:
                            combined_footnotes[key].append(new_footnote_text)

                else:
                    combined_footnotes = {
                        key: [value] for key, value in meta_text_dict.items()
                    }

                for key, value in combined_footnotes.items():
                    if len(value) > 1:
                        if "N/A " in value:
                            value.remove("N/A ")
                        combined_footnotes[key] = value

                if f == len(figure_args) - 1:
                    footnote_inserted = False
                    figure_paragraphs = []

                    # Find the paragraphs containing the figures
                    for j in range(i + 1, len(paragraphs)):
                        paragraph = paragraphs[j]
                        if any(
                            run.element.xpath(".//pic:pic") for run in paragraph.runs
                        ):
                            figure_paragraphs.append((j, paragraph))
                            # For single-figure or if we've collected enough figures for multi-figure
                            if len(figure_paragraphs) >= len(figure_args):
                                break

                    # Insert footnote after the last figure paragraph if we found any
                    if figure_paragraphs and not footnote_inserted:
                        # Get the last figure paragraph found
                        _, fig_paragraph = figure_paragraphs[-1]
                        new_paragraph = helper.create_footnote_paragraph(
                            combined_footnotes, "".join(figure_args.keys()), i, config
                        )
                        fig_paragraph._element.addnext(new_paragraph)
                        footnote_inserted = True
                        logger.info(f"Inserted footnote for: {figure_name}")

    # save the processed document
    if missing_metadata and fail_on_missing_metadata:
        logger.error("Output not created due to missing metadata")
        print(
            "output not created due to missing metadata. please check logs for missing metadata files."
        )
        sys.exit(1)
    else:
        document.save(docx_out)
        logger.info(f"Figure footnotes saved to '{docx_out}'")

    logger.debug("Exiting add_figure_footnotes function")


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
        "-c", "--config", type=str, required=True, help="path to config.yaml file"
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
    parser.add_argument("-l", "--log", type=str, default=None, help="Log file path")
    args = parser.parse_args()

    add_figure_footnotes(
        args.input,
        args.output,
        args.figure_dir,
        args.footnotes,
        args.config,
        args.object,
        args.fail_metadata,
        args.log,
    )
