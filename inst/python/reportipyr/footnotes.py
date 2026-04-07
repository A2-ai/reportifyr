import os
import re
import json
import logging
from typing import Optional

from docx import Document
from docx.oxml.text import run, paragraph
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

from .alt_text import extract_artifact_hashes, _load_artifact_hash
from .config import load_yaml
from .logging import setup_logger
from .magic import get_magic_pattern, parse_magic_string
from .util import create_label, check_duplicates, safe_resolve


def load_metadata(artifact_dir: str, artifact_file: str) -> dict | None:
    """Load metadata for a table or figure."""
    object_name, extension = os.path.splitext(artifact_file)
    metadata_file = os.path.join(
        artifact_dir, f"{object_name}_{extension[1::]}_metadata.json"
    )

    try:
        with open(metadata_file, "r") as m:
            return json.load(m)
    except FileNotFoundError:
        logging.getLogger("rpfy").warning(f"Metadata file not found: {metadata_file}")
        return None


def create_meta_text_lines(
    footnotes: dict,
    metadata: dict,
    include_object_path: bool,
    artifact_type: str,
    config: dict,
) -> dict[str, str]:
    assert artifact_type in ["figure", "table"]

    meta_text_lines = {}
    source_text = ""
    # Add source metadata
    source = metadata["source_meta"]["path"]
    latest_time = metadata["source_meta"]["latest_time"]
    if source and latest_time:
        source_text += f"{source} {latest_time}"
    meta_text_lines["Source"] = source_text

    object_source = ""
    obj_path = metadata["object_meta"]["path"]
    obj_creation_time = metadata["object_meta"]["creation_time"]
    if obj_path and obj_creation_time:
        object_source += f"{obj_path} {obj_creation_time}"
        meta_text_lines["Object"] = object_source

    # Add notes metadata
    notes_text = ""
    meta_type = metadata["object_meta"]["meta_type"]
    notes_list = metadata["object_meta"]["footnotes"][
        "notes"
    ]  # If empty this might be a list -- should be ok because len will still work.

    if isinstance(meta_type, str) and meta_type != "NA":
        footnote_section = footnotes.get(f"{artifact_type}_footnotes", {})
        if meta_type not in footnote_section:
            raise KeyError(
                f"meta_type '{meta_type}' not found in "
                f"{artifact_type}_footnotes section of footnotes YAML"
            )
        n = footnote_section[meta_type]
        if n:
            if n.endswith("."):
                notes_text += f"{n} "
            else:
                notes_text += f"{n}. "

    if len(notes_list) > 0:
        for note in notes_list:
            if note.endswith("."):
                notes_text += f"{note} "
            else:
                notes_text += f"{note}. "

    if notes_text == "":
        notes_text += "N/A"

    meta_text_lines["Notes"] = notes_text

    # Add abbreviations metadata
    abbrev_text = ""
    abbrev_delimiter = config.get("abbreviation_delimiter", ",")
    abbrev_list = metadata["object_meta"]["footnotes"]["abbreviations"]
    if len(abbrev_list) > 0:
        abbrev_section = footnotes.get("abbreviations", {})
        abbrev_parts = []
        for abbrev in abbrev_list:
            if abbrev not in abbrev_section:
                raise KeyError(
                    f"Abbreviation '{abbrev}' not found in "
                    f"abbreviations section of footnotes YAML"
                )
            full_form = abbrev_section[abbrev].rstrip(".")
            abbrev_parts.append(f"{abbrev}: {full_form}")
        abbrev_text = f"{abbrev_delimiter} ".join(abbrev_parts) + "."
    else:
        abbrev_text += "N/A"
    meta_text_lines["Abbreviations"] = abbrev_text

    if config.get("add_hash_to_footnotes", False):
        obj_hash = metadata["object_meta"].get("hash", "")
        if obj_hash:
            meta_text_lines["Hash"] = obj_hash

    if config.get("use_object_path_as_source", False):
        meta_text_lines["Source"] = meta_text_lines["Object"]
        del meta_text_lines["Object"]
        return meta_text_lines

    else:
        if include_object_path:
            return meta_text_lines

        else:
            del meta_text_lines["Object"]
            return meta_text_lines


def format_metadata_line(meta_key, meta_value, config):
    """Format a metadata line based on its key."""
    match meta_key:
        case "Source":
            if config.get("wrap_path_in_[]", True):
                return f"[Source: {meta_value}]"
            else:
                return f"Source: {meta_value}"
        case "Object":
            if config.get("wrap_path_in_[]", True):
                return f"[Object: {meta_value}]"
            else:
                return f"Object: {meta_value}"
        case "Notes":
            return f"Notes: {meta_value}"
        case "Abbreviations":
            return f"Abbreviations: {meta_value}"
        case "Hash":
            return f"Hash: {meta_value}"
        case _:
            return f"{meta_key}: {meta_value}"


def create_formatted_run(
    text: str, config: dict, subscript: bool = False, superscript: bool = False
) -> run.CT_R:
    """Create a single formatted run with specified text."""
    run_element = OxmlElement("w:r")

    # Asserting that text is not both sub and super-script
    # shouldn't happen, but if it does...
    assert not (subscript and superscript)

    # Set formatting properties
    rPr = OxmlElement("w:rPr")
    rFonts = OxmlElement("w:rFonts")
    font = config.get("footnotes_font", "Arial Narrow")
    rFonts.set(qn("w:ascii"), font)
    rFonts.set(qn("w:hAnsi"), font)
    rFonts.set(qn("w:cs"), font)
    sz = OxmlElement("w:sz")
    font_size = int(config.get("footnotes_font_size", 10))
    sz.set(qn("w:val"), str(2 * font_size))
    rPr.append(rFonts)
    rPr.append(sz)

    # Add subscript or superscript property if needed
    vertAlign = OxmlElement("w:vertAlign")
    if subscript:
        vertAlign.set(qn("w:val"), "subscript")
        rPr.append(vertAlign)

    elif superscript:
        vertAlign.set(qn("w:val"), "superscript")
        rPr.append(vertAlign)

    run_element.append(rPr)

    # Set text
    text_element = OxmlElement("w:t")

    # Preserve spaces if text starts or ends with space
    if text.startswith(" ") or text.endswith(" "):
        text_element.set(qn("xml:space"), "preserve")

    text_element.text = text
    run_element.append(text_element)

    return run_element


def create_formatted_runs(text: str, config: dict) -> list[run.CT_R]:
    """Create a formatted run with specified text."""
    if "_{" not in text and "^{" not in text:
        return [create_formatted_run(text, config)]

    # here text has _{text} or ^{text} so we'll split
    # with re and then add a bunch of runs
    # based on the split
    parts = re.split(r"(_\{[^}]*\}|\^\{[^}]*\})", text)
    runs = []

    for part in parts:
        if not part:
            continue

        if part.startswith("_{") and part.endswith("}"):
            # Extract subscript text (remove _{} notation)
            subscript_text = part[2:-1]
            # Create subscript run
            sub_run = create_formatted_run(subscript_text, config, subscript=True)
            runs.append(sub_run)

        elif part.startswith("^{") and part.endswith("}"):
            # Extract superscript text (remove ^{})
            superscript_text = part[2:-1]
            # create superscript run
            sup_run = create_formatted_run(superscript_text, config, superscript=True)
            runs.append(sup_run)

        else:
            # Regular text run
            reg_run = create_formatted_run(part, config)
            runs.append(reg_run)

    return runs


def create_footnote_paragraph(
    meta_text_dict: dict[str, list], name: str, paragraph_id: int, config: dict
) -> paragraph.CT_P:
    """Create a paragraph element containing formatted footnote text with bookmarks."""
    new_paragraph = OxmlElement("w:p")

    # Create the bookmark start
    bookmark_start = OxmlElement("w:bookmarkStart")
    bookmark_start.set(qn("w:id"), str(paragraph_id))
    bookmark_start.set(qn("w:name"), f"fp_{name}")
    new_paragraph.append(bookmark_start)

    # Pull Hash out before ordering — it's appended separately at the end
    hash_value = meta_text_dict.pop("Hash", None)

    # Add metadata lines - this assumes ordered dict which should be fine
    meta_text_dict = {
        key: meta_text_dict[key]
        for key in config.get(
            "footnote_order", ["Source", "Object", "Notes", "Abbreviations"]
        )
        if key in meta_text_dict.keys()
    }

    for line_idx, (meta, value) in enumerate(meta_text_dict.items()):
        # Format the line based on metadata type
        formatted_line = format_metadata_line(meta, "".join(value), config)

        # Create run with formatted text
        runs = create_formatted_runs(formatted_line, config)
        for run in runs:
            new_paragraph.append(run)

        # Add line break if needed
        if line_idx != len(meta_text_dict) - 1 or hash_value:
            run_break = OxmlElement("w:r")
            br = OxmlElement("w:br")
            run_break.append(br)
            new_paragraph.append(run_break)

    # Append Hash after ordered fields if present
    if hash_value:
        formatted_line = format_metadata_line("Hash", hash_value, config)
        runs = create_formatted_runs(formatted_line, config)
        for run in runs:
            new_paragraph.append(run)

    # Create the bookmark end
    bookmark_end = OxmlElement("w:bookmarkEnd")
    bookmark_end.set(qn("w:id"), str(paragraph_id))
    new_paragraph.append(bookmark_end)

    return new_paragraph


def add_figure_footnotes(
    docx_in: str,
    docx_out: str,
    figure_dir: str,
    footnotes_yaml: str,
    config_yaml: Optional[str],
    include_object_path: bool = False,
    fail_on_missing_metadata: bool = True,
):
    logger = setup_logger()
    logger.debug("Starting add_figure_footnotes function")
    logger.debug(f"Loading document from: {docx_in}")
    logger.debug(f"Figure directory: {figure_dir}")

    # load standard footnotes from a yaml file
    logger.debug(f"Loading footnotes from: {footnotes_yaml}")
    footnotes = load_yaml(footnotes_yaml)

    # load config.yaml or set empty dict for defaults.
    if config_yaml is not None:
        logger.debug(f"Loading config from: {config_yaml}")
        config = load_yaml(config_yaml)
    else:
        config = {}

    document = Document(docx_in)

    magic_pattern = get_magic_pattern()

    paragraphs = document.paragraphs
    missing_metadata = False

    for i, par in enumerate(paragraphs):
        matches = magic_pattern.findall(par.text)
        if not matches:
            continue

        check_duplicates(matches, f"figure names in paragraph {i+1}", logger)

        for match in matches:
            logger.debug(f"Processing magic string: {match}")
            # generalized extraction of the figure name
            figure_args = parse_magic_string(match)

            # Check if footnote already exists for this artifact
            bookmark_name = f"fp_{''.join(figure_args.keys())}"
            existing = document.element.xpath(
                f'//w:bookmarkStart[@w:name="{bookmark_name}"]'
            )
            if existing:
                logger.info(
                    f"Footnote already present for: {''.join(figure_args.keys())}, skipping"
                )
                continue

            # create empty dict for combining all metadata
            combined_footnotes: dict[str, list[str]] = {}
            # enumerating here so i can use f to get label for
            # create_label(f)
            for f, figure_name in enumerate(figure_args.keys()):
                extension = os.path.splitext(figure_name)[1].lower()
                if extension != ".png":
                    logger.debug(f"Skipping non-png file: {figure_name}")
                    continue

                try:
                    figure_path = safe_resolve(figure_dir, figure_name)
                except ValueError:
                    logger.warning(f"Path traversal blocked for: {figure_name}")
                    continue
                if not os.path.exists(figure_path):
                    logger.debug(
                        f"Skipping {figure_name} - not found in figure directory"
                    )
                    continue

                logger.info(f"Processing footnote for figure: {figure_name}")
                metadata = load_metadata(os.path.dirname(figure_path), os.path.basename(figure_path))

                if metadata is not None:
                    meta_text_dict = create_meta_text_lines(
                        footnotes, metadata, include_object_path, "figure", config
                    )
                else:
                    logger.warning(f"Metadata file not found for: {figure_name}")
                    missing_metadata = True
                    continue

                if len(figure_args) > 1:
                    for key in meta_text_dict.keys():
                        # Initialize the list for this key if it doesn't exist yet
                        if key not in combined_footnotes:
                            combined_footnotes[key] = []

                        if config.get("label_multi_figures", False):
                            new_footnote_text = (
                                f"{create_label(f)}: {meta_text_dict[key]} "
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
                        new_paragraph = create_footnote_paragraph(
                            combined_footnotes, "".join(figure_args.keys()), i, config
                        )
                        fig_paragraph._element.addnext(new_paragraph)
                        footnote_inserted = True
                        logger.info(f"Inserted footnote for: {figure_name}")

    # save the processed document
    if missing_metadata and fail_on_missing_metadata:
        logger.error("Output not created due to missing metadata.")
        raise SystemExit(1)
    else:
        document.save(docx_out)
        logger.info(f"Figure footnotes saved to '{docx_out}'")

    logger.debug("Exiting add_figure_footnotes function")


def add_table_footnotes(
    docx_in: str,
    docx_out: str,
    table_dir: str,
    footnotes_yaml: str,
    config_yaml: Optional[str],
    include_object_path: bool = False,
    fail_on_missing_metadata: bool = True,
):
    logger = setup_logger()
    logger.debug("Starting add_table_footnotes function")
    logger.debug(f"Loading document from: {docx_in}")
    logger.debug(f"Table directory: {table_dir}")

    # Load standard footnotes from a JSON file
    logger.debug(f"Loading footnotes from: {footnotes_yaml}")
    footnotes = load_yaml(footnotes_yaml)

    # load config.yaml or set empty dict for defaults.
    if config_yaml is not None:
        logger.debug(f"Loading config from: {config_yaml}")
        config = load_yaml(config_yaml)
    else:
        config = {}

    document = Document(docx_in)

    magic_pattern = get_magic_pattern()
    paragraphs = document.paragraphs
    missing_metadata = False

    for i, par in enumerate(paragraphs):
        matches = magic_pattern.findall(par.text)
        if not matches:
            continue

        check_duplicates(matches, f"table names in paragraph {i+1}", logger)

        for match in matches:
            # Generalized extraction of the table name
            table_name = match.replace("{rpfy}:", "").strip()

            # Check if footnote already exists for this table
            bookmark_name = f"fp_{table_name}"
            existing = document.element.xpath(
                f'//w:bookmarkStart[@w:name="{bookmark_name}"]'
            )
            if existing:
                logger.info(
                    f"Footnote already present for: {table_name}, skipping"
                )
                continue

            try:
                table_path = safe_resolve(table_dir, table_name)
            except ValueError:
                logger.warning(f"Path traversal blocked for: {table_name}")
                continue
            if not os.path.exists(table_path):
                logger.debug(f"Skipping {table_name} - not found in table directory")
                continue

            logger.info(f"Processing footnote for table: {table_name}")
            metadata = load_metadata(os.path.dirname(table_path), os.path.basename(table_path))

            add_footnote = False
            if metadata is None:
                logger.warning(f"Metadata file not found for: {table_name}")
                missing_metadata = True
            else:
                add_footnote = True
                meta_text_dict = create_meta_text_lines(
                    footnotes, metadata, include_object_path, "table", config
                )

            if add_footnote:
                # this gets xml index rather than paragraph index
                current_p = par._p
                body_elements = list(document.element.body)
                p_index = body_elements.index(current_p)

                # w:tbl is directly after matching magic string
                table = body_elements[p_index + 1]
                if table.tag == qn("w:tbl"):
                    new_paragraph = create_footnote_paragraph(
                        meta_text_dict, table_name, i, config
                    )
                    document.element.body.insert(
                        document.element.body.index(table) + 1, new_paragraph
                    )
                    logger.info(f"Inserted footnote for: {table_name}")

    # Save the processed document
    if missing_metadata and fail_on_missing_metadata:
        logger.error("Output not created due to missing metadata.")
        raise SystemExit(1)
    else:
        document.save(docx_out)
        logger.info(f"Table footnotes saved to '{docx_out}'")

    logger.debug("Exiting add_table_footnotes function")


def _build_unchanged_set(
    docx_in: str,
    config: dict,
    figures_dir: str | None,
    tables_dir: str | None,
) -> set[str]:
    """Build set of unchanged artifact filenames by comparing
    alt-text hashes in the docx with current metadata hashes."""
    unchanged = set()
    if not config.get("skip_unchanged", False):
        return unchanged

    embedded = extract_artifact_hashes(docx_in)
    for filename, embedded_hash in embedded.items():
        # Try figures dir first, then tables dir
        for artifact_dir in [figures_dir, tables_dir]:
            if artifact_dir is None:
                continue
            current = _load_artifact_hash(artifact_dir, filename)
            if current is not None and current == embedded_hash:
                unchanged.add(filename)
                break
    return unchanged


def remove_footnotes(
    docx_in,
    docx_out,
    config_yaml=None,
    figures_dir=None,
    tables_dir=None,
):
    logger = setup_logger()
    namespace = (
        "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
    )

    if config_yaml is not None:
        config = load_yaml(config_yaml)
    else:
        config = {}

    unchanged = _build_unchanged_set(
        docx_in, config, figures_dir, tables_dir
    )
    if unchanged:
        logger.info(f"Unchanged artifacts: {unchanged}")

    doc = Document(docx_in)

    # Remove footnotes with 'fp_' in the bookmark name
    for bookmark in doc.element.xpath("//w:bookmarkStart"):
        name = bookmark.get(namespace + "name")
        if name.startswith("fp_"):
            # Check if this footnote belongs to an unchanged artifact
            if unchanged:
                bookmark_artifact = name[3:]  # strip "fp_" prefix
                if any(
                    artifact in bookmark_artifact
                    for artifact in unchanged
                ):
                    logger.info(
                        f"Skipping removal of footnote: {name}"
                    )
                    continue
            bookmark_id = bookmark.get(namespace + "id")
            end_bookmark = doc.element.xpath(
                f'//w:bookmarkEnd[@w:id="{bookmark_id}"]'
            )[0]

            elements_to_remove = []
            current_element = bookmark.getnext()
            while current_element is not end_bookmark:
                elements_to_remove.append(current_element)
                current_element = current_element.getnext()

            for element in elements_to_remove:
                element.getparent().remove(element)

            parent_element = bookmark.getparent()

            bookmark.getparent().remove(bookmark)
            end_bookmark.getparent().remove(end_bookmark)

            if len(parent_element) == 0:
                parent_element.getparent().remove(parent_element)
            elif parent_element.tag.endswith("p") and not any(
                child.tag.endswith("r") for child in parent_element
            ):
                parent_element.getparent().remove(parent_element)

    doc.save(docx_out)
