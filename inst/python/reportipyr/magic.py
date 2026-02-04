import argparse
import json
import re
from docx import Document
from docx.oxml import OxmlElement

MAGIC_PATTERN = re.compile(r"\{rpfy\}\:.*?\.[^.]+$")


def get_magic_pattern() -> re.Pattern:
    """Return compiled regex for matching {rpfy}: magic strings."""
    return MAGIC_PATTERN


def parse_magic_entries(input_string: str) -> list[tuple[str, dict[str, str]]]:
    """
    Parse the magic string format into a list of (filename, args) preserving duplicates.
    """
    # Magic string should start with {rpfy}:
    magic_value = input_string.replace("{rpfy}:", "").strip()

    # If magic_value is enclosed in [ ], it can contain multiple entries
    if magic_value.startswith("[") and magic_value.endswith("]"):
        content = magic_value[1:-1].strip()
        entries = []
        current = []
        depth = 0
        for ch in content:
            if ch == "<":
                depth += 1
            elif ch == ">" and depth > 0:
                depth -= 1
            if ch == "," and depth == 0:
                entry = "".join(current).strip()
                if entry:
                    entries.append(entry)
                current = []
                continue
            current.append(ch)
        tail = "".join(current).strip()
        if tail:
            entries.append(tail)
    else:
        entries = [magic_value]

    result = []

    # regex for optional <...> args
    arg_regex = re.compile(r"^(.*?)(<.*>)?$")
    for entry in entries:
        match = arg_regex.match(entry)
        if not match:
            continue
        fname = match.group(1).strip()
        arg_text = match.group(2)
        args = {}
        if arg_text:
            # strip < > and parse key: value pairs
            arg_text = arg_text[1:-1].strip()
            if arg_text:
                for part in arg_text.split(","):
                    if ":" in part:
                        key, val = part.split(":", 1)
                        args[key.strip()] = val.strip()
        result.append((fname, args))

    return result


def parse_magic_string(input_string: str) -> dict[str, dict[str, str]]:
    """
    Parse the magic string format where arguments can be tied to individual files.
    """
    result = {}
    for fname, args in parse_magic_entries(input_string):
        result[fname] = args
    return result


def remove_magic_strings(docx_in, docx_out):
    sentinel = "{rpfy}:"  # Magic String

    doc = Document(docx_in)

    # Iterate over paragraphs to either clear text or remove the paragraph
    for para in doc.paragraphs:
        if sentinel in para.text:
            # Check if the paragraph contains a "pic:pic" element (image)
            contains_pic = any(run.element.xpath(".//pic:pic") for run in para.runs)

            if contains_pic:
                # Clear only the text runs in the paragraph, preserving the picture
                for run in para.runs:
                    if not run.element.xpath(".//pic:pic"):
                        run.text = ""  # Clear only the text
            else:
                # Remove the paragraph if it doesn't contain an image
                p = para._element
                p.getparent().remove(p)

        else:
            is_caption = False
            fld_elements = para._element.xpath(".//w:fldSimple")
            for fld in fld_elements:
                # w:instr is in the WordprocessingML namespace
                instr_value = fld.get(
                    "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}instr"
                )
                if instr_value and (
                    "SEQ Table" in instr_value or "SEQ Figure" in instr_value
                ):
                    is_caption = True
                    break

            if is_caption:
                pPr = para._element.get_or_add_pPr()
                keep_next = OxmlElement("w:keepNext")
                pPr.append(keep_next)

    doc.save(docx_out)


def main_parse_magic_string():
    parser = argparse.ArgumentParser(
        description="Parse magic string into list of file names and dictionary of file specific options."
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input magic string"
    )
    args = parser.parse_args()
    result = parse_magic_string(args.input)
    print(json.dumps(result))


if __name__ == "__main__":
    main_parse_magic_string()
