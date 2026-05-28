import logging
import os

import pytest

from reportipyr.util import create_label, check_duplicates, safe_resolve
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


# ---------------------------------------------------------------------------
# safe_resolve
# ---------------------------------------------------------------------------

def test_safe_resolve_simple_filename(tmp_path):
    (tmp_path / "table.csv").touch()
    result = safe_resolve(str(tmp_path), "table.csv")
    assert result == os.path.join(str(tmp_path), "table.csv")


def test_safe_resolve_subdirectory(tmp_path):
    sub = tmp_path / "sub"
    sub.mkdir()
    (sub / "fig.png").touch()
    result = safe_resolve(str(tmp_path), "sub/fig.png")
    assert result == str(sub / "fig.png")


def test_safe_resolve_blocks_traversal(tmp_path):
    with pytest.raises(ValueError, match="resolves outside"):
        safe_resolve(str(tmp_path), "../../etc/passwd")


def test_safe_resolve_blocks_absolute_path(tmp_path):
    with pytest.raises(ValueError, match="resolves outside"):
        safe_resolve(str(tmp_path), "/etc/passwd")


def test_safe_resolve_blocks_symlink_escape(tmp_path):
    """Symlink inside boundary that points outside should be rejected."""
    target = tmp_path / "outside"
    target.mkdir()
    (target / "secret.txt").touch()

    inside = tmp_path / "artifacts"
    inside.mkdir()
    link = inside / "escape"
    link.symlink_to(target)

    with pytest.raises(ValueError, match="resolves outside"):
        safe_resolve(str(inside), "escape/secret.txt")


def test_safe_resolve_boundary_itself(tmp_path):
    """Resolving to the boundary directory itself should not raise."""
    result = safe_resolve(str(tmp_path), ".")
    assert result == os.path.realpath(str(tmp_path))
