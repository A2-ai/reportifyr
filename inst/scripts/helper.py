import os
import sys
import json
import yaml
import string
from docx.oxml.text import run, paragraph
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


def create_label(index: int) -> str:
    """
    This function takes in an index and returns
    a label corresponding to index location in
    the alphabet.
    For index > 26 multiple letters are added, e.g.
    create_label(29) -> "AD"
    """

    label = ""
    while index >= 0:
        label = string.ascii_uppercase[index % 26] + label
        index = index // 26 - 1

    return label

def load_footnotes(footnotes_yaml: str) -> dict:
    """Load footnotes from a YAML file."""
    with open(footnotes_yaml, "r") as y:
        return yaml.safe_load(y)

def load_metadata(artifact_dir: str, artifact_file: str) -> dict:
    """Load metadata for a table."""
    object_name, extension = os.path.splitext(artifact_file)
    metadata_file = os.path.join(
        artifact_dir, f"{object_name}_{extension[1::]}_metadata.json"
    )
    
    try:
        with open(metadata_file, "r") as m:
            return json.load(m)
    except FileNotFoundError:
        print(f"Metadata file not found: {metadata_file}", file=sys.stderr)
        return None

def create_meta_text_lines(
    footnotes: dict, metadata: dict, include_object_path: bool, artifact_type: str
) -> dict[str, str]:
    assert artifact_type in ["figure", "table"]

    meta_text_lines = {}
    source_text = ""
    # Add source metadata
    source = metadata.get("source_meta").get("path")
    creation_time = metadata.get("source_meta").get("creation_time")
    if source and creation_time:
        source_text += f"{source} {creation_time}"
    meta_text_lines["Source"] = source_text

    if include_object_path:
        object_source = ""
        obj_path = metadata.get("object_meta").get("path")
        obj_creation_time = metadata.get("object_meta").get("creation_time")
        if obj_path and obj_creation_time:
            object_source += f"{obj_path} {obj_creation_time}"
            meta_text_lines["Object"] = object_source

    # Add notes metadata
    notes_text = ""
    meta_type = metadata.get("object_meta").get("meta_type")
    notes_list = (
        metadata.get("object_meta").get("footnotes").get("notes")
    )  # If empty this might be a list -- should be ok because len will still work.

    if type(meta_type) == str and meta_type != "NA":
        n = footnotes[f"{artifact_type}_footnotes"][meta_type]
        if n:
            notes_text += f"{n}. "

    if len(notes_list) > 0:
        for note in notes_list:
            notes_text += f"{note}. "

    if notes_text == "":
        notes_text += "N/A"

    meta_text_lines["Notes"] = notes_text

    # Add abbreviations metadata
    abbrev_text = ""
    abbrev_list = metadata.get("object_meta").get("footnotes").get("abbreviations")
    if len(abbrev_list) > 0:
        for abbrev in abbrev_list:
            abbrev_text += f"{abbrev}: {footnotes['abbreviations'][abbrev]}. "
    else:
        abbrev_text += "N/A"
    meta_text_lines["Abbreviations"] = abbrev_text

    return meta_text_lines


def format_metadata_line(meta_key, meta_value):
    """Format a metadata line based on its key."""
    match meta_key:
        case "Source":
            return f"[Source: {meta_value}]"
        case "Object":
            return f"[Object: {meta_value}]"
        case "Notes":
            return f"Notes: {meta_value}"
        case "Abbreviations":
            return f"Abbreviations: {meta_value}"
        case _:
            return f"{meta_key}: {meta_value}"


def create_formatted_run(text: str) -> run.CT_R:
    """Create a formatted run with specified text."""
    run = OxmlElement("w:r")

    # Set formatting properties
    rPr = OxmlElement("w:rPr")
    rFonts = OxmlElement("w:rFonts")
    rFonts.set(qn("w:ascii"), "Arial Narrow")
    sz = OxmlElement("w:sz")
    sz.set(qn("w:val"), "20")
    rPr.append(rFonts)
    rPr.append(sz)
    run.append(rPr)

    # Set text
    text_element = OxmlElement("w:t")
    text_element.text = text
    run.append(text_element)

    return run


def create_footnote_paragraph(
    meta_text_dict: dict[str, str], name: str, paragraph_id: int
) -> paragraph.CT_P:
    """Create a paragraph element containing formatted footnote text with bookmarks."""
    new_paragraph = OxmlElement("w:p")

    # Create the bookmark start
    bookmark_start = OxmlElement("w:bookmarkStart")
    bookmark_start.set(qn("w:id"), str(paragraph_id))
    bookmark_start.set(qn("w:name"), f"fp_{name}")
    new_paragraph.append(bookmark_start)

    # Add metadata lines
    for line_idx, (meta, value) in enumerate(meta_text_dict.items()):
        # Format the line based on metadata type
        formatted_line = format_metadata_line(meta, value)

        # Create run with formatted text
        run = create_formatted_run(formatted_line)
        new_paragraph.append(run)

        # Add line break if needed
        if line_idx != len(meta_text_dict) - 1:
            run_break = OxmlElement("w:r")
            br = OxmlElement("w:br")
            run_break.append(br)
            new_paragraph.append(run_break)

    # Create the bookmark end
    bookmark_end = OxmlElement("w:bookmarkEnd")
    bookmark_end.set(qn("w:id"), str(paragraph_id))
    new_paragraph.append(bookmark_end)

    return new_paragraph



