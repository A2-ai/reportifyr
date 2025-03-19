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


def add_table_footnotes(
    docx_in,
    docx_out,
    table_dir,
    footnotes_yaml,
    include_object_path=False,
    fail_on_missing_metadata=True,
):
    # Load standard footnotes from a JSON file
    with open(footnotes_yaml, "r") as j:
        footnotes = yaml.safe_load(j)

    document = Document(docx_in)

    # Define magic string pattern that allows for flexible paths
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
            for match in matches:
                # Generalized extraction of the figure name
                table_name = match.replace("{rpfy}:", "").strip()
                if table_name in os.listdir(table_dir):
                    object_name, extension = os.path.splitext(table_name)
                    metadata_file = os.path.join(
                        table_dir, f"{object_name}_{extension[1::]}_metadata.json"
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
                            footnotes, metadata, include_object_path, "table"
                        )

                        # Find the table and insert the meta_text after it
                        found_magic_string = False
                        for element in document.element.body:
                            if element.tag == qn("w:p"):
                                para_text = "".join(
                                    node.text or ""
                                    for node in element.iter()
                                    if node.tag == qn("w:t")
                                )
                                if match in para_text:  # Use the original match string
                                    found_magic_string = True

                            if found_magic_string and element.tag == qn("w:tbl"):
                                table = element
                                new_paragraph = OxmlElement("w:p")

                                # Create the bookmark start
                                bookmark_start = OxmlElement("w:bookmarkStart")
                                bookmark_start.set(qn("w:id"), str(i))
                                bookmark_start.set(qn("w:name"), f"fp_{table_name}")
                                new_paragraph.append(bookmark_start)

                                for line in meta_text_lines:
                                    run = OxmlElement("w:r")

                                    rPr = OxmlElement("w:rPr")
                                    rFonts = OxmlElement("w:rFonts")
                                    rFonts.set(qn("w:ascii"), "Arial Narrow")
                                    sz = OxmlElement("w:sz")
                                    sz.set(qn("w:val"), "20")
                                    rPr.append(rFonts)
                                    rPr.append(sz)
                                    run.append(rPr)

                                    text = OxmlElement("w:t")
                                    text.text = line
                                    run.append(text)
                                    new_paragraph.append(run)

                                    # Add a break if it's not the last line
                                    if line != meta_text_lines[-1]:
                                        run_break = OxmlElement("w:r")
                                        br = OxmlElement("w:br")
                                        run_break.append(br)
                                        new_paragraph.append(run_break)

                                # Create the bookmark end
                                bookmark_end = OxmlElement("w:bookmarkEnd")
                                bookmark_end.set(qn("w:id"), str(i))
                                new_paragraph.append(bookmark_end)

                                # Insert the new paragraph after the table
                                document.element.body.insert(
                                    document.element.body.index(table) + 1,
                                    new_paragraph,
                                )
                                found_magic_string = (
                                    False  # Reset the flag to avoid multiple insertions
                                )

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
        description="Add table footnotes to input docx document"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument(
        "-o", "--output", type=str, required=True, help="Path to output docx file"
    )
    parser.add_argument(
        "-d", "--table_dir", type=str, required=True, help="Path to tables directory"
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

    add_table_footnotes(
        args.input,
        args.output,
        args.table_dir,
        args.footnotes,
        args.object,
        args.fail_metadata,
    )
