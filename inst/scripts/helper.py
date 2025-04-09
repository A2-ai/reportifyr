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


def load_yaml(yaml_file: str) -> dict:
    """Load contents from a YAML file."""
    with open(yaml_file, "r") as y:
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
    abbrev_list = metadata["object_meta"]["footnotes"]["abbreviations"]
    if len(abbrev_list) > 0:
        for abbrev in abbrev_list:
            full_form = footnotes["abbreviations"][abbrev]
            if full_form.endswith("."):
                abbrev_text += f"{abbrev}: {full_form} "
            else:
                abbrev_text += f"{abbrev}: {full_form}. "
    else:
        abbrev_text += "N/A"
    meta_text_lines["Abbreviations"] = abbrev_text

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

def parse_magic_string(input_string: str) -> tuple[list, dict[str, dict[str, str]]]:
    """
    Parse the magic string format where arguments can be tied to individual files.
    Returns a tuple of (list of files, arguments dictionary keyed by file name).
    
    The function handles formats like:
    - [file1.ext<width: 5, height: 8>, file2.ext<width: 4>, file3.ext]
    - [file1.ext, file2.ext]
    - file.ext<height: 6>
    - file.ext
    """
    # Initialize structure to hold files and their arguments
    files = []
    args = {}
    
    # Check if it's a list of files
    if input_string.startswith('[') and input_string.endswith(']'):
        # Multiple files within brackets
        content = input_string[1:-1].strip()
        
        # Split by commas, but not those inside angle brackets
        entries = []
        current_entry = ""
        bracket_depth = 0
        
        for char in content:
            if char == '<':
                bracket_depth += 1
                current_entry += char
            elif char == '>':
                bracket_depth -= 1
                current_entry += char
            elif char == ',' and bracket_depth == 0:
                # Only split on commas outside of angle brackets
                entries.append(current_entry.strip())
                current_entry = ""
            else:
                current_entry += char
        
        if current_entry.strip():
            entries.append(current_entry.strip())
    else:
        # Single file
        entries = [input_string]
    
    # Parse each file entry
    for entry in entries:
        file_match = re.match(r'^(.*?)(?:<|$)', entry)
        file_name = file_match.group(1).strip() if file_match else ""
        
        args_match = re.search(r'<(.*?)>', entry)
        file_args = {}
        
        if args_match:
            args_str = args_match.group(1)
            arg_pairs = args_str.split(',')
            
            for pair in arg_pairs:
                if ':' in pair:
                    key, value = pair.split(':', 1)
                    file_args[key.strip()] = value.strip()
        
        files.append(file_name)
        args[file_name] = file_args
    
    return files, args

def format_metadata_line(meta_key, meta_value, config):
    """Format a metadata line based on its key."""
    # TODO: update [Source: {meta_value}] to include []
    # if present in config
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
    rFonts.set(qn("w:ascii"), config.get("footnotes_font", "Arial Narrow"))
    sz = OxmlElement("w:sz")
    sz.set(qn("w:val"), str(2 * config.get("footnotes_font_size", "10")))
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
    meta_text_dict: dict[str, str], name: str, paragraph_id: int, config: dict
) -> paragraph.CT_P:
    """Create a paragraph element containing formatted footnote text with bookmarks."""
    new_paragraph = OxmlElement("w:p")

    # Create the bookmark start
    bookmark_start = OxmlElement("w:bookmarkStart")
    bookmark_start.set(qn("w:id"), str(paragraph_id))
    bookmark_start.set(qn("w:name"), f"fp_{name}")
    new_paragraph.append(bookmark_start)

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
        formatted_line = format_metadata_line(meta, value, config)

        # Create run with formatted text
        runs = create_formatted_runs(formatted_line, config)
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
