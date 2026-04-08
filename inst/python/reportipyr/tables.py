from docx import Document
from docx.oxml.ns import qn

import hashlib

from .alt_text import (
    _compute_table_content_hash,
    _encode_body_grid,
    _extract_body_grid,
    _extract_body_grid_from_alt_text,
    _get_body_row_indices,
    _grid_to_canonical,
    is_artifact_unchanged,
    is_table_unchanged,
)
from .config import load_yaml
from .logging import setup_logger


def _update_alt_text_after_reconcile(tbl_element, old_alt_text: str):
    """Rewrite content_hash and grid in alt text after reconciliation."""
    import re

    # Recompute from the now-updated table
    body_grid = _extract_body_grid(tbl_element)
    canonical = _grid_to_canonical(body_grid)
    new_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    new_body = _encode_body_grid(body_grid)

    # Replace content_hash
    new_alt = re.sub(
        r"\[content_hash:[a-f0-9]+\]",
        f"[content_hash:{new_hash}]",
        old_alt_text,
    )
    # Replace grid
    new_alt = re.sub(
        r"\[grid:[A-Za-z0-9+/=]+\]",
        f"[grid:{new_body}]",
        new_alt,
    )

    # Write back to tblDescription
    tbl_pr = tbl_element.find(qn("w:tblPr"))
    if tbl_pr is not None:
        desc = tbl_pr.find(qn("w:tblDescription"))
        if desc is not None:
            desc.set(qn("w:val"), new_alt)


def _update_cell_text(tc, new_text):
    """Replace cell text content, preserving all formatting.

    Updates w:t text in the first run. If the cell has multiple runs
    (e.g., split by Word), consolidates text into the first run and
    removes extra runs. Preserves w:rPr, w:tcPr, and w:pPr.
    """
    paragraphs = tc.findall(qn("w:p"))
    if not paragraphs:
        return

    # Work with the first paragraph
    p = paragraphs[0]
    runs = p.findall(qn("w:r"))

    if not runs:
        # No runs — create one with the new text
        from docx.oxml import OxmlElement

        run = OxmlElement("w:r")
        t = OxmlElement("w:t")
        if new_text.startswith(" ") or new_text.endswith(" "):
            t.set(qn("xml:space"), "preserve")
        t.text = new_text
        run.append(t)
        p.append(run)
        return

    # Preserve formatting from first run, update its text
    first_run = runs[0]
    wt_elements = first_run.findall(qn("w:t"))
    if wt_elements:
        wt_elements[0].text = new_text
        if new_text.startswith(" ") or new_text.endswith(" "):
            wt_elements[0].set(qn("xml:space"), "preserve")
        # Remove extra w:t elements in first run
        for extra_wt in wt_elements[1:]:
            first_run.remove(extra_wt)
    else:
        from docx.oxml import OxmlElement

        t = OxmlElement("w:t")
        if new_text.startswith(" ") or new_text.endswith(" "):
            t.set(qn("xml:space"), "preserve")
        t.text = new_text
        first_run.append(t)

    # Remove extra runs (consolidate split runs from Word editing)
    for extra_run in runs[1:]:
        p.remove(extra_run)

    # Remove extra paragraphs in the cell (keep only first)
    for extra_p in paragraphs[1:]:
        tc.remove(extra_p)


def reconcile_table_cells(
    tbl_element, source_grid: list[list[str]], logger
) -> bool:
    """Update only changed cells in the table, preserving formatting.

    Compares source_grid (from the original insertion) against the current
    table body cells. Only cells with different text are updated.

    Returns True if reconciliation succeeded, False if grids don't align.
    """
    current_grid = _extract_body_grid(tbl_element)

    # Grid shape check — if dimensions differ, can't reconcile (pathway 1c)
    if len(current_grid) != len(source_grid):
        logger.debug(
            f"Row count mismatch: current={len(current_grid)}, "
            f"source={len(source_grid)}"
        )
        return False

    for row_idx, (cur_row, src_row) in enumerate(
        zip(current_grid, source_grid)
    ):
        if len(cur_row) != len(src_row):
            logger.debug(
                f"Column count mismatch at row {row_idx}: "
                f"current={len(cur_row)}, source={len(src_row)}"
            )
            return False

    # Cell-by-cell comparison and update
    trs = tbl_element.findall(qn("w:tr"))
    body_indices = _get_body_row_indices(tbl_element)
    cells_updated = 0

    for row_offset, row_idx in enumerate(body_indices):
        tr = trs[row_idx]
        tcs = tr.findall(qn("w:tc"))
        for col_idx, tc in enumerate(tcs):
            current_text = current_grid[row_offset][col_idx]
            source_text = source_grid[row_offset][col_idx]
            if current_text != source_text:
                _update_cell_text(tc, source_text)
                cells_updated += 1
                logger.debug(
                    f"Updated cell ({row_idx},{col_idx}): "
                    f"{repr(current_text)} -> {repr(source_text)}"
                )

    logger.info(f"Reconciled {cells_updated} cell(s)")
    return True


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
                                # 1a: fully unchanged — skip
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

                                # Source unchanged but content
                                # edited — try reconciliation
                                if is_artifact_unchanged(
                                    alt,
                                    table_dir,
                                    table_name,
                                ):
                                    source_grid = (
                                        _extract_body_grid_from_alt_text(
                                            alt
                                        )
                                    )
                                    if source_grid is not None:
                                        success = (
                                            reconcile_table_cells(
                                                next_elem,
                                                source_grid,
                                                logger,
                                            )
                                        )
                                        if success:
                                            # 1b: reconciled —
                                            # update alt text hashes
                                            _update_alt_text_after_reconcile(
                                                next_elem, alt
                                            )
                                            logger.info(
                                                f"Reconciled cells "
                                                f"for: {table_name}"
                                            )
                                            break
                                        else:
                                            # 1c: grid changed
                                            logger.info(
                                                f"Grid changed, "
                                                f"full reset for: "
                                                f"{table_name}"
                                            )

                    # 2 or 1c: remove table
                    next_elem.getparent().remove(next_elem)
                    break
                elif next_elem.tag.endswith("p"):
                    break

    doc.save(docx_out)
