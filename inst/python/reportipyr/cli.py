import argparse
import json

from .alt_text import (
    add_figure_alt_text,
    add_table_alt_text,
    check_alt_text_magic_string,
)
from .docx_utils import keep_caption_next, remove_bookmarks
from .figures import add_figure, add_path_overlay_to_image, remove_figures
from .footnotes import add_figure_footnotes, add_table_footnotes, remove_footnotes
from .magic import remove_magic_strings, parse_magic_string
from .tables import remove_tables
from .validate import validate_docx


def _parse_bool(value: str) -> bool:
    return value.lower() in ["true", "t"]


def add_io_args(p, output=True):
    p.add_argument("-i", "--input", required=True)
    if output:
        p.add_argument("-o", "--output", required=True)


def add_config_arg(p, *, required=False):
    p.add_argument("-c", "--config", required=required, default=None)


def add_dir_arg(p, *dirs, required=False):
    """Add one or more directory options. Each dir is a (short, name) pair;
    short may be None for a long-only flag (e.g. (None, "figures-dir"))."""
    for short, name in dirs:
        flags = [f for f in (short, f"--{name}") if f]
        p.add_argument(*flags, required=required)


def add_metadata_args(p):
    p.add_argument("-b", "--object", type=_parse_bool)
    p.add_argument("-m", "--fail-metadata", type=_parse_bool)


def _run_validate(args):
    result = validate_docx(args.input, strict=not args.no_strict)
    print(json.dumps(result))
    if not result.get("success", False):
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description="reportipyr CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # add-figure
    p = subparsers.add_parser("add-figure", help="Insert figures into docx")
    add_io_args(p)
    add_dir_arg(p, ("-d", "figure-dir"), required=True)
    add_config_arg(p)
    p.add_argument("-w", "--width", type=float, default=None)
    p.add_argument("-g", "--height", type=float, default=None)
    p.set_defaults(func=lambda a: add_figure(
        a.input, a.output, a.figure_dir, a.config, a.width, a.height
    ))

    # add-figure-alt-text
    p = subparsers.add_parser(
        "add-figure-alt-text", help="Insert alt text for figures"
    )
    add_io_args(p)
    add_dir_arg(p, ("-d", "dir"))
    p.set_defaults(func=lambda a: add_figure_alt_text(a.input, a.output, a.dir))

    # add-table-alt-text
    p = subparsers.add_parser("add-table-alt-text", help="Insert alt text for tables")
    add_io_args(p)
    add_dir_arg(p, ("-d", "dir"))
    p.set_defaults(func=lambda a: add_table_alt_text(a.input, a.output, a.dir))

    # add-figure-footnotes
    p = subparsers.add_parser("add-figure-footnotes", help="Insert figure footnotes")
    add_io_args(p)
    add_dir_arg(p, ("-d", "figure-dir"), required=True)
    p.add_argument("-f", "--footnotes", required=True)
    add_config_arg(p, required=True)
    add_metadata_args(p)
    p.set_defaults(func=lambda a: add_figure_footnotes(
        a.input, a.output, a.figure_dir, a.footnotes, a.config, a.object, a.fail_metadata
    ))

    # add-table-footnotes
    p = subparsers.add_parser("add-table-footnotes", help="Insert table footnotes")
    add_io_args(p)
    add_dir_arg(p, ("-d", "table-dir"), required=True)
    p.add_argument("-f", "--footnotes", required=True)
    add_config_arg(p, required=True)
    add_metadata_args(p)
    p.set_defaults(func=lambda a: add_table_footnotes(
        a.input, a.output, a.table_dir, a.footnotes, a.config, a.object, a.fail_metadata
    ))

    # remove-footnotes
    p = subparsers.add_parser("remove-footnotes", help="Remove footnotes")
    add_io_args(p)
    add_config_arg(p)
    add_dir_arg(p, (None, "figures-dir"), (None, "tables-dir"))
    p.set_defaults(func=lambda a: remove_footnotes(
        a.input, a.output, a.config, a.figures_dir, a.tables_dir
    ))

    # remove-tables
    p = subparsers.add_parser("remove-tables", help="Remove tables")
    add_io_args(p)
    add_config_arg(p)
    add_dir_arg(p, ("-d", "dir"))
    p.set_defaults(func=lambda a: remove_tables(a.input, a.output, a.config, a.dir))

    # remove-figures
    p = subparsers.add_parser("remove-figures", help="Remove figures")
    add_io_args(p)
    add_config_arg(p)
    add_dir_arg(p, ("-d", "dir"))
    p.set_defaults(func=lambda a: remove_figures(a.input, a.output, a.config, a.dir))

    # remove-magic-strings
    p = subparsers.add_parser("remove-magic-strings", help="Remove magic strings")
    add_io_args(p)
    p.set_defaults(func=lambda a: remove_magic_strings(a.input, a.output))

    # remove-bookmarks
    p = subparsers.add_parser("remove-bookmarks", help="Remove bookmarks")
    add_io_args(p)
    p.set_defaults(func=lambda a: remove_bookmarks(a.input, a.output))

    # keep-caption-next
    p = subparsers.add_parser("keep-caption-next", help="Keep captions with artifacts")
    add_io_args(p)
    p.set_defaults(func=lambda a: keep_caption_next(a.input, a.output))

    # check-alt-text-magic
    p = subparsers.add_parser(
        "check-alt-text-magic", help="Validate alt text vs magic strings"
    )
    add_io_args(p, output=False)
    p.set_defaults(func=lambda a: check_alt_text_magic_string(a.input))

    # validate-docx
    p = subparsers.add_parser("validate-docx", help="Validate docx for reportipyr")
    add_io_args(p, output=False)
    p.add_argument("--no-strict", action="store_true")
    p.set_defaults(func=_run_validate)

    # add-path-overlay
    p = subparsers.add_parser(
        "add-path-overlay", help="Stamp a source or object path onto image"
    )
    add_io_args(p, output=False)
    p.add_argument("-s", "--text", required=True)
    p.add_argument(
        "-k", "--kind", default="source", choices=["source", "object"]
    )
    p.set_defaults(func=lambda a: add_path_overlay_to_image(a.input, a.text, a.kind))

    # parse-magic-string (optional)
    p = subparsers.add_parser("parse-magic-string", help="Parse a magic string")
    add_io_args(p, output=False)
    p.set_defaults(func=lambda a: print(json.dumps(parse_magic_string(a.input))))

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
