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


def main():
    parser = argparse.ArgumentParser(description="reportipyr CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # add-figure
    p = subparsers.add_parser("add-figure", help="Insert figures into docx")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-d", "--figure-dir", required=True)
    p.add_argument("-c", "--config", default=None)
    p.add_argument("-w", "--width", type=float, default=None)
    p.add_argument("-g", "--height", type=float, default=None)

    # add-figure-alt-text
    p = subparsers.add_parser(
        "add-figure-alt-text", help="Insert alt text for figures"
    )
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-d", "--dir", default=None)

    # add-table-alt-text
    p = subparsers.add_parser("add-table-alt-text", help="Insert alt text for tables")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-d", "--dir", default=None)

    # add-figure-footnotes
    p = subparsers.add_parser("add-figure-footnotes", help="Insert figure footnotes")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-d", "--figure-dir", required=True)
    p.add_argument("-f", "--footnotes", required=True)
    p.add_argument("-c", "--config", required=True)
    p.add_argument("-b", "--object", type=_parse_bool)
    p.add_argument("-m", "--fail-metadata", type=_parse_bool)

    # add-table-footnotes
    p = subparsers.add_parser("add-table-footnotes", help="Insert table footnotes")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-d", "--table-dir", required=True)
    p.add_argument("-f", "--footnotes", required=True)
    p.add_argument("-c", "--config", required=True)
    p.add_argument("-b", "--object", type=_parse_bool)
    p.add_argument("-m", "--fail-metadata", type=_parse_bool)

    # remove-footnotes
    p = subparsers.add_parser("remove-footnotes", help="Remove footnotes")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-c", "--config", default=None)
    p.add_argument("--figures-dir", default=None)
    p.add_argument("--tables-dir", default=None)

    # remove-tables
    p = subparsers.add_parser("remove-tables", help="Remove tables")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-c", "--config", default=None)
    p.add_argument("-d", "--dir", default=None)

    # remove-figures
    p = subparsers.add_parser("remove-figures", help="Remove figures")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)
    p.add_argument("-c", "--config", default=None)
    p.add_argument("-d", "--dir", default=None)

    # remove-magic-strings
    p = subparsers.add_parser("remove-magic-strings", help="Remove magic strings")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)

    # remove-bookmarks
    p = subparsers.add_parser("remove-bookmarks", help="Remove bookmarks")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)

    # keep-caption-next
    p = subparsers.add_parser("keep-caption-next", help="Keep captions with artifacts")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-o", "--output", required=True)

    # check-alt-text-magic
    p = subparsers.add_parser(
        "check-alt-text-magic", help="Validate alt text vs magic strings"
    )
    p.add_argument("-i", "--input", required=True)

    # validate-docx
    p = subparsers.add_parser("validate-docx", help="Validate docx for reportipyr")
    p.add_argument("-i", "--input", required=True)
    p.add_argument("--no-strict", action="store_true")

    # add-path-overlay
    p = subparsers.add_parser(
        "add-path-overlay", help="Stamp source path onto image"
    )
    p.add_argument("-i", "--input", required=True)
    p.add_argument("-s", "--source-text", required=True)

    # parse-magic-string (optional)
    p = subparsers.add_parser("parse-magic-string", help="Parse a magic string")
    p.add_argument("-i", "--input", required=True)

    args = parser.parse_args()

    if args.command == "add-figure":
        add_figure(
            args.input,
            args.output,
            args.figure_dir,
            args.config,
            args.width,
            args.height,
        )
    elif args.command == "add-figure-alt-text":
        add_figure_alt_text(args.input, args.output, args.dir)
    elif args.command == "add-table-alt-text":
        add_table_alt_text(args.input, args.output, args.dir)
    elif args.command == "add-figure-footnotes":
        add_figure_footnotes(
            args.input,
            args.output,
            args.figure_dir,
            args.footnotes,
            args.config,
            args.object,
            args.fail_metadata,
        )
    elif args.command == "add-table-footnotes":
        add_table_footnotes(
            args.input,
            args.output,
            args.table_dir,
            args.footnotes,
            args.config,
            args.object,
            args.fail_metadata,
        )
    elif args.command == "remove-footnotes":
        remove_footnotes(
            args.input, args.output, args.config,
            args.figures_dir, args.tables_dir,
        )
    elif args.command == "remove-tables":
        remove_tables(args.input, args.output, args.config, args.dir)
    elif args.command == "remove-figures":
        remove_figures(args.input, args.output, args.config, args.dir)
    elif args.command == "remove-magic-strings":
        remove_magic_strings(args.input, args.output)
    elif args.command == "remove-bookmarks":
        remove_bookmarks(args.input, args.output)
    elif args.command == "keep-caption-next":
        keep_caption_next(args.input, args.output)
    elif args.command == "check-alt-text-magic":
        check_alt_text_magic_string(args.input)
    elif args.command == "validate-docx":
        result = validate_docx(args.input, strict=not args.no_strict)
        print(json.dumps(result))
        if not result.get("success", False):
            raise SystemExit(1)
    elif args.command == "add-path-overlay":
        add_path_overlay_to_image(args.input, args.source_text)
    elif args.command == "parse-magic-string":
        print(json.dumps(parse_magic_string(args.input)))


if __name__ == "__main__":
    main()
