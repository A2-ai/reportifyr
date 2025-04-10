import re
import json
import argparse

def parse_magic_string(input_string: str) -> dict[str, dict[str, str]]:
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
    args = {}

    magic_value = input_string.replace("{rpfy}:", "").strip()

    # Check if it's a list of files
    if magic_value.startswith("[") and magic_value.endswith("]"):
        # Multiple files within brackets
        content = magic_value[1:-1].strip()

        # Split by commas, but not those inside angle brackets
        entries = []
        current_entry = ""
        bracket_depth = 0

        for char in content:
            if char == "<":
                bracket_depth += 1
                current_entry += char
            elif char == ">":
                bracket_depth -= 1
                current_entry += char
            elif char == "," and bracket_depth == 0:
                # Only split on commas outside of angle brackets
                entries.append(current_entry.strip())
                current_entry = ""
            else:
                current_entry += char

        if current_entry.strip():
            entries.append(current_entry.strip())
    else:
        # Single file
        entries = [magic_value]

    # Parse each file entry
    for entry in entries:
        file_match = re.match(r"^(.*?)(?:<|$)", entry)
        file_name = file_match.group(1).strip() if file_match else ""

        args_match = re.search(r"<(.*?)>", entry)
        file_args = {}

        if args_match:
            args_str = args_match.group(1)
            arg_pairs = args_str.split(",")

            for pair in arg_pairs:
                if ":" in pair:
                    key, value = pair.split(":", 1)
                    file_args[key.strip()] = value.strip()

        args[file_name] = file_args

    return args


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Parse magic string into list of file names and dictionary of file specific options."
    )
    parser.add_argument(
        "-i", "--input", type=str, required=True, help="input magic string"
    )
    args = parser.parse_args()

    result = parse_magic_string(args.input)
    json_out = json.dumps(result)
    print(json_out)
