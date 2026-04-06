from docx import Document
from docx.oxml.ns import qn

from .alt_text import is_table_unchanged
from .config import load_yaml
from .logging import setup_logger


def remove_tables(docx_in, docx_out, config_yaml=None, table_dir=None):
    logger = setup_logger()
    doc = Document(docx_in)

    if config_yaml is not None:
        config = load_yaml(config_yaml)
    else:
        config = {}

    skip_unchanged = config.get("skip_unchanged", False)

    for paragraph in doc.paragraphs:
        if paragraph.text.startswith("{rpfy}:"):
            table_name = paragraph.text.replace(
                "{rpfy}:", ""
            ).strip()

            p_element = paragraph._element
            for next_elem in p_element.itersiblings():
                if next_elem.tag.endswith("tbl"):
                    if skip_unchanged and table_dir:
                        tbl_pr = next_elem.find(qn("w:tblPr"))
                        if tbl_pr is not None:
                            desc = tbl_pr.find(
                                qn("w:tblDescription")
                            )
                            if desc is not None:
                                alt = desc.get(
                                    qn("w:val"), ""
                                )
                                if is_table_unchanged(
                                    alt,
                                    next_elem,
                                    table_dir,
                                    table_name,
                                ):
                                    logger.info(
                                        f"Skipping removal of "
                                        f"unchanged table: "
                                        f"{table_name}"
                                    )
                                    break

                    next_elem.getparent().remove(next_elem)
                    break
                elif next_elem.tag.endswith("p"):
                    break

    doc.save(docx_out)
