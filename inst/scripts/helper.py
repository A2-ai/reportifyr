import string

def create_label(index: int) -> str:
    '''
        This function takes in an index and returns
        a label corresponding to index location in 
        the alphabet.
        For index > 26 multiple letters are added, e.g.
        create_label(29) -> "AD"
    '''

    label = ""
    while index >= 0:
        label = string.ascii_uppercase[index % 26] + label
        index = index // 26 - 1

    return label


def create_meta_text_lines(footnotes, metadata, include_object_path, artifact_type):
    assert artifact_type in ["figure", "table"]

    meta_text_lines = []
    source_text = ""
    # Add source metadata
    source = metadata.get("source_meta").get("path")
    creation_time = metadata.get("source_meta").get("creation_time")
    if source and creation_time:
        source_text += f"[Source: {source} {creation_time}]"
    meta_text_lines.append(source_text)

    if include_object_path:
        object_source = ""
        obj_path = metadata.get("object_meta").get("path")
        obj_creation_time = metadata.get("object_meta").get("creation_time")
        if obj_path and obj_creation_time:
            object_source += f"[Object: {obj_path} {obj_creation_time}]"
            meta_text_lines.append(object_source)

    # Add notes metadata
    notes_text = ""
    meta_type = metadata.get("object_meta").get("meta_type")
    notes_list = (
        metadata.get("object_meta").get("footnotes").get("notes")
    )  # If empty this might be a list -- should be ok because len will still work.
    notes_added = False
    if type(meta_type) == str and meta_type != "NA":
        n = footnotes[f"{artifact_type}_footnotes"][meta_type]
        if n:
            notes_text += f"Notes: {n}"
            notes_added = True

    if len(notes_list) > 0:
        for note in notes_list:
            if notes_added:
                notes_text += f". {note}"
            else:
                notes_text += f"Notes: {note}"
                notes_added = True

    if not notes_added:
        notes_text += "Notes N/A"
    meta_text_lines.append(notes_text)

    # Add abbreviations metadata
    abbrev_text = ""
    abbrev_list = metadata.get("object_meta").get("footnotes").get("abbreviations")
    if len(abbrev_list) > 0:
        for abbrev_ind, abbrev in enumerate(abbrev_list):
            if abbrev_ind == 0:
                abbrev_text += (
                    f"Abbreviations: {abbrev}: {footnotes['abbreviations'][abbrev]}. "
                )
            else:
                abbrev_text += f"{abbrev}: {footnotes['abbreviations'][abbrev]}. "
    else:
        abbrev_text += "Abbreviations: N/A"
    meta_text_lines.append(abbrev_text)

    return meta_text_lines


