import os
import re
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

def load_metadata(artifact_dir: str, artifact_file: str) -> dict | None:
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
    abbrev_list = metadata.get("object_meta").get("footnotes").get("abbreviations")
    if len(abbrev_list) > 0:
        for abbrev in abbrev_list:
            full_form = footnotes['abbreviations'][abbrev]
            if full_form.endswith("."):
                abbrev_text += f"{abbrev}: {full_form} "
            else:
                abbrev_text += f"{abbrev}: {full_form}. "
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


def create_formatted_run(text: str, subscript: bool = False) -> run.CT_R:
    """Create a single formatted run with specified text."""
    run_element = OxmlElement("w:r")

    # Set formatting properties
    rPr = OxmlElement("w:rPr")
    rFonts = OxmlElement("w:rFonts")
    rFonts.set(qn("w:ascii"), "Arial Narrow")
    sz = OxmlElement("w:sz")
    sz.set(qn("w:val"), "20")
    rPr.append(rFonts)
    rPr.append(sz)
    
    # Add subscript property if needed
    if subscript:
        vertAlign = OxmlElement("w:vertAlign")
        vertAlign.set(qn("w:val"), "subscript")
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


def create_formatted_runs(text: str) -> list[run.CT_R]:
    """Create a formatted run with specified text."""
    if "_{" not in text or "}" not in text:
        return [create_formatted_run(text)]
    
    # here text has _{text} so we'll split
    # with re and then add a bunch of runs 
    # based on the split
    parts = re.split(r'(_\{[^}]*\})', text)
    runs = []

    for part in parts:
        if not part:
            continue

        if part.startswith("_{") and part.endswith("}"):
        # Extract subscript text (remove _{} notation)
            subscript_text = part[2:-1]
            # Create subscript run
            sub_run = create_formatted_run(subscript_text, subscript=True)
            runs.append(sub_run)  
        else:
            # Regular text run
            reg_run = create_formatted_run(part)
            runs.append(reg_run)    

    return runs

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
        runs = create_formatted_runs(formatted_line)
        for run in runs:
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



