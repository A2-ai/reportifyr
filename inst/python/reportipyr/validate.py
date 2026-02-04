import json
from docx import Document

from .magic import parse_magic_entries, parse_magic_string

SUPPORTED_EXTENSIONS = {"csv", "rds", "png"}


def validate_docx(docx_in: str, strict: bool = True) -> dict:
    """
    Validate a docx file for reportifyr compatibility.

    Returns a dict with:
        - success: bool
        - file_names: list of extracted filenames
        - errors: list of error messages (if any)
        - warnings: list of warning messages (if any)
    """
    result = {
        "success": True,
        "file_names": [],
        "errors": [],
        "warnings": [],
    }

    sentinel = "{rpfy}:"

    try:
        doc = Document(docx_in)
    except Exception as e:
        result["success"] = False
        result["errors"].append(f"Failed to read document: {str(e)}")
        return result

    # Extract magic strings from paragraphs
    magic_strings = []
    for para in doc.paragraphs:
        if sentinel in para.text:
            magic_strings.append(para.text)

    if len(magic_strings) == 0:
        result["success"] = False
        result["errors"].append("The file does not contain magic strings.")
        return result

    # Parse filenames from magic strings
    file_names = []
    for magic_string in magic_strings:
        entries = parse_magic_entries(magic_string)
        file_names.extend([fname for fname, _ in entries])

    result["file_names"] = file_names

    # Check for unsupported file extensions
    unsupported_files = []
    for fname in file_names:
        ext = fname.rsplit(".", 1)[-1].lower() if "." in fname else ""
        if ext not in SUPPORTED_EXTENSIONS:
            unsupported_files.append(fname)

    if unsupported_files:
        message = (
            f"Unsupported file types found in document: {', '.join(unsupported_files)}"
        )
        if strict:
            result["success"] = False
            result["errors"].append(message)
            result["errors"].append(
                "Fix artifact extensions to continue. "
                "Currently .csv, .RDS are accepted for tables "
                "and .png is accepted for figures."
            )
        else:
            result["warnings"].append(message)

    # Check for duplicate files
    seen = set()
    duplicates = []
    for fname in file_names:
        if fname in seen:
            duplicates.append(fname)
        seen.add(fname)

    if duplicates:
        if strict:
            result["success"] = False
            result["errors"].append(
                f"Found duplicate files, please fix: {', '.join(duplicates)}"
            )
            result["errors"].append(
                "Using strict mode. Fix duplicate artifacts to continue."
            )
        else:
            result["warnings"].append(
                f"Found duplicate files, artifact addition might not work properly: {', '.join(duplicates)}"
            )

    return result


def main_validate_docx():
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate a docx file for reportifyr compatibility"
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input docx file path"
    )
    parser.add_argument(
        "--strict", action="store_true", default=True, help="enable strict mode"
    )
    parser.add_argument(
        "--no-strict", action="store_false", dest="strict", help="disable strict mode"
    )
    args = parser.parse_args()

    result = validate_docx(args.input, args.strict)
    print(json.dumps(result))

    if not result["success"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main_validate_docx()
