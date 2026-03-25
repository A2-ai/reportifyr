import os
import string


def safe_resolve(artifact_dir: str, relative_path: str) -> str:
    """Resolve a relative path within artifact_dir, raising if it escapes."""
    boundary = os.path.realpath(artifact_dir)
    resolved = os.path.realpath(os.path.join(boundary, relative_path))
    if resolved != boundary and not resolved.startswith(boundary + os.sep):
        raise ValueError(
            f"Path '{relative_path}' resolves outside of '{artifact_dir}'"
        )
    return resolved


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


def check_duplicates(matches: list, context: str, logger) -> None:
    """Warn if duplicate items found in matches list."""
    if len(matches) > len(set(matches)):
        logger.warning(f"Duplicate {context} found")
