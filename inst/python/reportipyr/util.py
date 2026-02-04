import string


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
