import logging

from reportipyr.util import create_label, check_duplicates
from reportipyr.cli import _parse_bool
from reportipyr.logging import RStyleFormatter


# ---------------------------------------------------------------------------
# create_label
# ---------------------------------------------------------------------------

def test_create_label_single_letters():
    assert create_label(0) == "A"
    assert create_label(1) == "B"
    assert create_label(25) == "Z"


def test_create_label_double_letters():
    assert create_label(26) == "AA"
    assert create_label(27) == "AB"
    assert create_label(51) == "AZ"
    assert create_label(52) == "BA"


# ---------------------------------------------------------------------------
# check_duplicates
# ---------------------------------------------------------------------------

def test_check_duplicates_warns_on_dupes(caplog):
    with caplog.at_level(logging.WARNING, logger="rpfy"):
        logger = logging.getLogger("rpfy")
        check_duplicates(["a", "b", "a"], "figures", logger)

    assert "Duplicate figures found" in caplog.text


def test_check_duplicates_no_warning_when_unique(caplog):
    with caplog.at_level(logging.WARNING, logger="rpfy"):
        logger = logging.getLogger("rpfy")
        check_duplicates(["a", "b", "c"], "figures", logger)

    assert caplog.text == ""


# ---------------------------------------------------------------------------
# _parse_bool
# ---------------------------------------------------------------------------

def test_parse_bool_true_values():
    assert _parse_bool("true") is True
    assert _parse_bool("True") is True
    assert _parse_bool("TRUE") is True
    assert _parse_bool("t") is True
    assert _parse_bool("T") is True


def test_parse_bool_false_values():
    assert _parse_bool("false") is False
    assert _parse_bool("False") is False
    assert _parse_bool("0") is False
    assert _parse_bool("no") is False


# ---------------------------------------------------------------------------
# RStyleFormatter
# ---------------------------------------------------------------------------

def test_rstyle_formatter_output_format():
    """Pin the format string that R's py_callback regex depends on."""
    formatter = RStyleFormatter()
    record = logging.LogRecord(
        name="rpfy", level=logging.WARNING, pathname="", lineno=0,
        msg="test message", args=(), exc_info=None,
    )
    output = formatter.format(record)

    # Must contain [py] tag and [LEVEL] tag for R callback parsing
    assert "[py]" in output
    assert "[WARNING]" in output
    assert "test message" in output
    # Format: "YYYY-MM-DD HH:MM:SS [py] [LEVEL] message"
    parts = output.split(" ")
    assert len(parts) >= 5  # date, time, [py], [LEVEL], message...
