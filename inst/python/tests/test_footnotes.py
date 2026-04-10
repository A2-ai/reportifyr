import json
import logging

import pytest

from docx.oxml.ns import qn

from reportipyr.footnotes import (
    _make_bookmark_name,
    load_metadata,
    create_meta_text_lines,
    format_metadata_line,
    create_formatted_run,
    create_formatted_runs,
    create_footnote_paragraph,
)


# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------

def _make_metadata(
    source_path="prog.R",
    latest_time="2026-01-01",
    obj_path="output/fig.png",
    obj_creation_time="2026-01-02",
    meta_type="efficacy",
    notes=None,
    abbreviations=None,
):
    """Build a metadata dict matching the JSON structure the package expects."""
    return {
        "source_meta": {
            "path": source_path,
            "latest_time": latest_time,
        },
        "object_meta": {
            "path": obj_path,
            "creation_time": obj_creation_time,
            "meta_type": meta_type,
            "footnotes": {
                "notes": notes or [],
                "abbreviations": abbreviations or [],
            },
        },
    }


def _make_footnotes():
    """Build a minimal footnotes dict matching standard_footnotes.yaml."""
    return {
        "figure_footnotes": {
            "efficacy": "Efficacy population.",
        },
        "table_footnotes": {
            "efficacy": "Efficacy population.",
        },
        "abbreviations": {
            "PK": "pharmacokinetics",
            "CI": "confidence interval",
        },
    }


def _default_config():
    return {
        "footnotes_font": "Arial Narrow",
        "footnotes_font_size": 10,
        "wrap_path_in_[]": True,
    }


# ---------------------------------------------------------------------------
# load_metadata
# ---------------------------------------------------------------------------

def test_load_metadata_returns_dict(tmp_path):
    meta = {"source_meta": {"path": "x.R"}}
    meta_file = tmp_path / "figure_png_metadata.json"
    meta_file.write_text(json.dumps(meta))

    result = load_metadata(str(tmp_path), "figure.png")
    assert result == meta


def test_load_metadata_missing_file_returns_none(tmp_path, caplog):
    with caplog.at_level(logging.WARNING, logger="rpfy"):
        result = load_metadata(str(tmp_path), "missing.png")

    assert result is None
    assert "Could not load metadata" in caplog.text


def test_load_metadata_malformed_json_returns_none(tmp_path, caplog):
    """Bug N5 fix: JSONDecodeError is now caught and returns None."""
    meta_file = tmp_path / "bad_png_metadata.json"
    meta_file.write_text("{not valid json")

    with caplog.at_level(logging.WARNING, logger="rpfy"):
        result = load_metadata(str(tmp_path), "bad.png")

    assert result is None
    assert "Could not load metadata" in caplog.text


# ---------------------------------------------------------------------------
# create_meta_text_lines
# ---------------------------------------------------------------------------

def test_create_meta_text_lines_basic():
    metadata = _make_metadata(notes=["First note"], abbreviations=["PK"])
    footnotes = _make_footnotes()
    config = _default_config()

    result = create_meta_text_lines(footnotes, metadata, False, "figure", config)

    assert "Source" in result
    assert "prog.R" in result["Source"]
    assert "Notes" in result
    assert "Efficacy population." in result["Notes"]
    assert "First note." in result["Notes"]
    assert "Abbreviations" in result
    assert "PK: pharmacokinetics." in result["Abbreviations"]
    # Object excluded when include_object_path=False
    assert "Object" not in result


def test_create_meta_text_lines_include_object_path():
    metadata = _make_metadata()
    footnotes = _make_footnotes()
    config = _default_config()

    result = create_meta_text_lines(footnotes, metadata, True, "figure", config)

    assert "Object" in result
    assert "output/fig.png" in result["Object"]


def test_create_meta_text_lines_use_object_as_source():
    metadata = _make_metadata()
    footnotes = _make_footnotes()
    config = {**_default_config(), "use_object_path_as_source": True}

    result = create_meta_text_lines(footnotes, metadata, False, "figure", config)

    assert "Source" in result
    assert "output/fig.png" in result["Source"]
    assert "Object" not in result


def test_create_meta_text_lines_no_notes():
    metadata = _make_metadata(meta_type="NA", notes=[], abbreviations=[])
    footnotes = _make_footnotes()
    config = _default_config()

    result = create_meta_text_lines(footnotes, metadata, False, "figure", config)

    assert result["Notes"] == "N/A"
    assert result["Abbreviations"] == "N/A"


def test_create_meta_text_lines_table_type():
    metadata = _make_metadata(meta_type="efficacy")
    footnotes = _make_footnotes()
    config = _default_config()

    result = create_meta_text_lines(footnotes, metadata, False, "table", config)

    assert "Efficacy population." in result["Notes"]


def test_create_meta_text_lines_note_with_trailing_dot():
    """Notes that already end with '.' should not get a double dot."""
    metadata = _make_metadata(notes=["Already has dot."])
    footnotes = _make_footnotes()
    config = _default_config()

    result = create_meta_text_lines(footnotes, metadata, False, "figure", config)

    assert ".." not in result["Notes"]


# ---------------------------------------------------------------------------
# format_metadata_line
# ---------------------------------------------------------------------------

def test_format_metadata_line_source_wrapped():
    config = {"wrap_path_in_[]": True}
    assert format_metadata_line("Source", "prog.R", config) == "[Source: prog.R]"


def test_format_metadata_line_source_unwrapped():
    config = {"wrap_path_in_[]": False}
    assert format_metadata_line("Source", "prog.R", config) == "Source: prog.R"


def test_format_metadata_line_object_wrapped():
    config = {"wrap_path_in_[]": True}
    assert format_metadata_line("Object", "out.png", config) == "[Object: out.png]"


def test_format_metadata_line_notes():
    assert format_metadata_line("Notes", "some note", {}) == "Notes: some note"


def test_format_metadata_line_abbreviations():
    assert (
        format_metadata_line("Abbreviations", "PK: pharma", {})
        == "Abbreviations: PK: pharma"
    )


def test_format_metadata_line_unknown_key():
    assert format_metadata_line("Custom", "value", {}) == "Custom: value"


# ---------------------------------------------------------------------------
# create_formatted_run
# ---------------------------------------------------------------------------

def test_create_formatted_run_basic():
    config = {"footnotes_font": "Courier", "footnotes_font_size": 12}
    r = create_formatted_run("hello", config)

    # Check text
    t = r.find(qn("w:t"))
    assert t.text == "hello"

    # Check font
    rPr = r.find(qn("w:rPr"))
    rFonts = rPr.find(qn("w:rFonts"))
    assert rFonts.get(qn("w:ascii")) == "Courier"

    # Check size (half-points: 12 * 2 = 24)
    sz = rPr.find(qn("w:sz"))
    assert sz.get(qn("w:val")) == "24"


def test_create_formatted_run_default_font():
    r = create_formatted_run("x", {})

    rPr = r.find(qn("w:rPr"))
    rFonts = rPr.find(qn("w:rFonts"))
    assert rFonts.get(qn("w:ascii")) == "Arial Narrow"

    sz = rPr.find(qn("w:sz"))
    assert sz.get(qn("w:val")) == "20"  # default 10 * 2


def test_create_formatted_run_font_size_string_cast():
    """Regression guard for bug #2: font_size was string, causing str * int."""
    config = {"footnotes_font_size": "8"}
    r = create_formatted_run("x", config)

    sz = r.find(qn("w:rPr")).find(qn("w:sz"))
    assert sz.get(qn("w:val")) == "16"  # 8 * 2, not "88"


def test_create_formatted_run_subscript():
    r = create_formatted_run("2", {}, subscript=True)

    rPr = r.find(qn("w:rPr"))
    vert = rPr.find(qn("w:vertAlign"))
    assert vert is not None
    assert vert.get(qn("w:val")) == "subscript"


def test_create_formatted_run_superscript():
    r = create_formatted_run("2", {}, superscript=True)

    rPr = r.find(qn("w:rPr"))
    vert = rPr.find(qn("w:vertAlign"))
    assert vert is not None
    assert vert.get(qn("w:val")) == "superscript"


def test_create_formatted_run_no_vert_align_by_default():
    r = create_formatted_run("x", {})

    rPr = r.find(qn("w:rPr"))
    vert = rPr.find(qn("w:vertAlign"))
    assert vert is None


def test_create_formatted_run_preserves_spaces():
    r = create_formatted_run(" leading", {})

    t = r.find(qn("w:t"))
    assert t.get(qn("xml:space")) == "preserve"


def test_create_formatted_run_no_space_preserve():
    r = create_formatted_run("nospace", {})

    t = r.find(qn("w:t"))
    assert t.get(qn("xml:space")) is None


# ---------------------------------------------------------------------------
# create_formatted_runs
# ---------------------------------------------------------------------------

def test_create_formatted_runs_plain_text():
    runs = create_formatted_runs("plain text", {})
    assert len(runs) == 1

    t = runs[0].find(qn("w:t"))
    assert t.text == "plain text"


def test_create_formatted_runs_subscript():
    runs = create_formatted_runs("H_{2}O", {})

    assert len(runs) == 3
    texts = [r.find(qn("w:t")).text for r in runs]
    assert texts == ["H", "2", "O"]

    # Middle run should be subscript
    vert = runs[1].find(qn("w:rPr")).find(qn("w:vertAlign"))
    assert vert.get(qn("w:val")) == "subscript"


def test_create_formatted_runs_superscript():
    runs = create_formatted_runs("x^{2}", {})

    assert len(runs) == 2
    texts = [r.find(qn("w:t")).text for r in runs]
    assert texts == ["x", "2"]

    vert = runs[1].find(qn("w:rPr")).find(qn("w:vertAlign"))
    assert vert.get(qn("w:val")) == "superscript"


def test_create_formatted_runs_mixed():
    runs = create_formatted_runs("a_{sub}b^{sup}c", {})

    texts = [r.find(qn("w:t")).text for r in runs]
    assert texts == ["a", "sub", "b", "sup", "c"]

    # subscript
    assert runs[1].find(qn("w:rPr")).find(qn("w:vertAlign")).get(qn("w:val")) == "subscript"
    # superscript
    assert runs[3].find(qn("w:rPr")).find(qn("w:vertAlign")).get(qn("w:val")) == "superscript"


# ---------------------------------------------------------------------------
# create_footnote_paragraph
# ---------------------------------------------------------------------------

def test_create_footnote_paragraph_structure():
    meta_text_dict = {
        "Source": ["prog.R 2026-01-01"],
        "Notes": ["Efficacy population."],
        "Abbreviations": ["PK: pharmacokinetics."],
    }
    config = _default_config()

    p = create_footnote_paragraph(meta_text_dict, "figure1", 42, config)

    # Bookmark start/end exist with matching IDs
    bk_start = p.find(qn("w:bookmarkStart"))
    bk_end = p.find(qn("w:bookmarkEnd"))
    assert bk_start is not None
    assert bk_end is not None
    assert bk_start.get(qn("w:id")) == "42"
    assert bk_end.get(qn("w:id")) == "42"
    assert bk_start.get(qn("w:name")) == "fp_figure1"

    # Runs contain the expected text
    all_text = "".join(
        t.text for t in p.findall(f".//{qn('w:t')}") if t.text
    )
    assert "Source:" in all_text
    assert "Notes:" in all_text
    assert "Abbreviations:" in all_text


def test_create_footnote_paragraph_line_breaks():
    meta_text_dict = {
        "Source": ["src"],
        "Notes": ["note"],
    }
    config = _default_config()

    p = create_footnote_paragraph(meta_text_dict, "fig", 1, config)

    # One line break between two entries, none after the last
    breaks = p.findall(f".//{qn('w:br')}")
    assert len(breaks) == 1


def test_create_footnote_paragraph_respects_order():
    meta_text_dict = {
        "Notes": ["note"],
        "Source": ["src"],
        "Abbreviations": ["abbr"],
    }
    config = {
        **_default_config(),
        "footnote_order": ["Abbreviations", "Notes", "Source"],
    }

    p = create_footnote_paragraph(meta_text_dict, "fig", 1, config)

    texts = [t.text for t in p.findall(f".//{qn('w:t')}") if t.text]
    full = " ".join(texts)
    # Abbreviations should come before Notes, Notes before Source
    assert full.index("Abbreviations:") < full.index("Notes:")
    assert full.index("Notes:") < full.index("Source:")


def test_create_footnote_paragraph_skips_missing_keys():
    """Keys in footnote_order that aren't in meta_text_dict are skipped."""
    meta_text_dict = {
        "Notes": ["note"],
    }
    config = {
        **_default_config(),
        "footnote_order": ["Source", "Notes", "Abbreviations"],
    }

    p = create_footnote_paragraph(meta_text_dict, "fig", 1, config)

    all_text = "".join(
        t.text for t in p.findall(f".//{qn('w:t')}") if t.text
    )
    assert "Notes:" in all_text
    assert "Source:" not in all_text
    assert "Abbreviations:" not in all_text

    # No line breaks when only one entry
    breaks = p.findall(f".//{qn('w:br')}")
    assert len(breaks) == 0


# ---------------------------------------------------------------------------
# _make_bookmark_name
# ---------------------------------------------------------------------------

def test_make_bookmark_name_short():
    """Short names get fp_ prefix directly."""
    result = _make_bookmark_name("figure1")
    assert result == "fp_figure1"
    assert len(result) <= 40


def test_make_bookmark_name_at_limit():
    """Name exactly at 40 chars (with fp_ prefix) is kept as-is."""
    name = "a" * 37  # fp_ + 37 = 40
    result = _make_bookmark_name(name)
    assert result == f"fp_{name}"
    assert len(result) == 40


def test_make_bookmark_name_over_limit():
    """Name exceeding 40 chars (with fp_ prefix) gets md5-hashed."""
    name = "a" * 38  # fp_ + 38 = 41, over limit
    result = _make_bookmark_name(name)
    assert result.startswith("fp_")
    assert len(result) <= 40
    assert result != f"fp_{name}"


def test_make_bookmark_name_long_deterministic():
    """Long names produce deterministic hashes."""
    name = "pk/theoph-pk-concentration-over-time.png"
    result1 = _make_bookmark_name(name)
    result2 = _make_bookmark_name(name)
    assert result1 == result2
    assert len(result1) <= 40


def test_make_bookmark_name_long_no_collision():
    """Different long names produce different hashes."""
    name1 = "pk/theoph-pk-concentration-over-time.png"
    name2 = "pk/theoph-pk-exposure-over-time-long.png"
    assert _make_bookmark_name(name1) != _make_bookmark_name(name2)
