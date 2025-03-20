import os
import re
import sys
import json
import helper
import argparse
from docx import Document
from docx.oxml.ns import qn


def add_table_footnotes(
    docx_in: str,
    docx_out: str,
    table_dir: str,
    footnotes_yaml: str,
    include_object_path: bool = False,
    fail_on_missing_metadata: bool = True,
):
    # Load standard footnotes from a JSON file
    footnotes = helper.load_footnotes(footnotes_yaml) 
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
        if not matches:
            continue
        
        if len(matches) > len(set(matches)):
            print(f"Duplicate figure names found in paragraph {i+1}")
        
        for match in matches:
            # Generalized extraction of the table name
            table_name = match.replace("{rpfy}:", "").strip()

            if table_name in os.listdir(table_dir):
                metadata = helper.load_metadata(table_dir, table_name)                                                     
                
                add_footnote = False
                if metadata is None:
                    missing_metadata = True
                else:
                    add_footnote = True

                if add_footnote:
                    # metadata is not None if we make it here.
                    meta_text_dict = helper.create_meta_text_lines(
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
                            new_paragraph = helper.create_footnote_paragraph(
                                    meta_text_dict, table_name, i
                            )

                            # Insert the new paragraph after the table
                            document.element.body.insert(
                                document.element.body.index(table) + 1,
                                new_paragraph,
                            )
                            found_magic_string = False
                            

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
