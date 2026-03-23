from docx import Document


def remove_tables(docx_in, docx_out):
    doc = Document(docx_in)

    for paragraph in doc.paragraphs:
        if paragraph.text.startswith("{rpfy}:"):
            p_element = paragraph._element
            for next_elem in p_element.itersiblings():
                if next_elem.tag.endswith("tbl"):
                    next_elem.getparent().remove(next_elem)
                    break
                elif next_elem.tag.endswith("p"):
                    break

    doc.save(docx_out)
