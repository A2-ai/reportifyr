# reportifyr 0.4.0
## New Features

* `rpfy_context()` captures session-level metadata (system info, source attribution, author, project root, caller-supplied tags) once and reuses it across many `*_with_metadata()` calls. A new `context` argument has been added to `ggsave_with_metadata()`, `save_rds_with_metadata()`, `write_csv_with_metadata()`, and `write_object_metadata()`. When `context = NULL` (default) an ephemeral context is built per call, so existing code is unaffected.
  * Example:
    ```{r}
    ctx <- rpfy_context(
      origin = shiny_source("myapp", app_version = "1.2.0"),
      addl_metadata = list(analyst = "usr", study = "PK-001")
    )

    ggsave_with_metadata(
      filename = "OUTPUTS/figures/pk.png",
      context = ctx,
      meta_type = "efficacy"
    )
    ```

* `shiny_source()` and `script_source()` build typed `rpfy_source_meta` objects used as the `origin` argument to `rpfy_context()`. The class is the source of truth for the source type, written into `_metadata.json` as `source_meta.type` at serialization time. When `origin = NULL` the script case is auto-detected from `this.path` and the git history of the calling script. `validate_shiny_source()` and `validate_script_source()` are exported for callers that build sources programmatically.

* `addl_metadata` on `rpfy_context()` accepts a named list of scalar character, numeric, or logical values. These are written to `_metadata.json` under a top-level `addl_meta` key for traceability of analyst/run identifiers, and are never rendered into the report footer. 

* `skip_unchanged` in config.yaml (default `true`) enables hash-based artifact caching across rebuilds. Artifacts whose source files have not changed are preserved in place during `build_report()` instead of being removed and re-inserted, dramatically reducing rebuild time and preserving any Word-side formatting adjustments (column widths, cell shading, etc.) on unchanged content. Hashes are embedded in the alt text of each figure and table on insertion, and `skip_unchanged` consults those alt-text hashes at removal time to decide whether an artifact can be left in place.
  * Hashes embedded in alt text on insertion:
    * `[hash:...]` (figures and tables) is the BLAKE3 hash of the source artifact loaded from `_metadata.json`.
    * `[content_hash:...]` (**tables only**) is the SHA-256 of normalized table body cell text; it detects edits made to table values directly in Word after insertion.
    * `[grid:...]` (**tables only**) is a gzip+base64 snapshot of the original table cell text at insertion time, used as the reference for cell-by-cell reconciliation.
  * For tables, removal evaluates three pathways:
    1. **Fully unchanged** (object hash match + content hash match): the table is skipped entirely.
    2. **Source unchanged, content edited** (object hash match, content hash mismatch): cell-by-cell reconciliation updates only the changed cells, preserving Word formatting. Alt text hashes are rewritten after reconciliation.
    3. **Source changed or grid dimensions changed**: full removal and re-insertion.
  * For figures, an object hash match preserves the figure and its footnote in place; a mismatch falls back to full removal and re-insertion.
  * Footnote removal also respects `skip_unchanged`: footnotes belonging to unchanged artifacts are preserved by matching bookmark names against the unchanged artifact set.

* Magic strings inside table cells are now processed end-to-end by the full reportifyr pipeline: validation, insertion, alt text, footnotes, removal, and finalization. Cell-level figures within a single table share one combined footnote paragraph placed after the table element, with Source/Notes/Abbreviations deduplicated across figures in the table. Merged cells are deduplicated via `_tc` identity. Previously, magic strings placed in table cells were silently ignored.

* `add_tables()` now respects pre-formatted flextables passed through `save_rds_with_metadata()`. If the deserialized object inherits from `flextable`, the default `format_flextable()` pass is skipped and the user's formatting flows through unchanged.
  * Example:
    ```{r}
    ft <- flextable::flextable(my_data) |>
      flextable::bg(j = "Subject", bg = "lightgray") |>
      flextable::width(j = "Time", width = 1.2)

    save_rds_with_metadata(
      object = ft,
      file = "OUTPUTS/tables/01-pk-summary.RDS"
    )
    # build_report() inserts `ft` verbatim; gray background and 1.2" width are preserved.
    ```

* `initialize_report_project()` re-initialization (when the init file already exists) now validates and restores the full project structure. The report directory and its subdirectories (`draft/`, `final/`, `scripts/`, `shell/`), `config.yaml`, `standard_footnotes.yaml`, and the outputs directory subdirectories (`figures/`, `tables/`, `listings/`) are all checked and recreated if missing. Directory names are resolved from the init file when not supplied, falling back to defaults (`report`, `OUTPUTS`). Previously, re-initialization only checked whether the `.venv` directory existed.

### Architecture
* The Python code that drives docx manipulation has been consolidated from loose scripts under `inst/scripts/` into a proper `reportipyr` Python package at `inst/python/reportipyr/`. The package exposes a single CLI entry point (`uv run -m reportipyr.cli <subcommand>`); every R caller now invokes the CLI rather than shelling out to individual scripts. Modules are split by responsibility: `alt_text.py`, `config.py`, `docx_utils.py`, `figures.py`, `footnotes.py`, `logging.py`, `magic.py`, `tables.py`, `util.py`, `validate.py`, plus `cli.py` as the dispatcher.

* `validate_docx()` now performs its checks via the aforementioned Python CLI using `python-docx` rather than R-side `officer`. Error messages have been reformatted to flow through the unified logging pipeline, and the duplicate-table warning was retuned to surface affected magic strings more clearly. Validation runs under the same `RPFY_VERBOSE` filtering as the rest of the build pipeline.

* The R to Python logging pipeline now writes a unified session log file to `.rpfy-logs/<timestamp>-rpfy.log`. Every Python log line emitted on stderr by the bundled `reportipyr` CLI is captured by an R-side callback that (a) appends the line to the session log file and (b) prints it to the console filtered by `RPFY_VERBOSE` (default `WARN`). The log file itself always records at `DEBUG` regardless of console verbosity. R-side log lines emitted via `log4r` land in the same file with a `[R]` prefix, so the file is the single authoritative trace of a build for after-the-fact debugging. Session log files in `.rpfy-logs/` are pruned automatically on package load to keep the directory from growing unbounded over time. `prune_rpfy_logs()` deletes session logs older than 30 days and caps the directory at 500 files (oldest first).

* The uv/Python bootstrap (downloading uv, resolving paths, writing version metadata, pinning python-docx/pillow/pyyaml) has been factored out into the standalone `pyro` package. reportifyr now declares `pyro` as a dependency and calls `pyro::initialize_python(groups = "reportifyr")` at init and sync time. The reportifyr-specific Python pins are written into the project `pyproject.toml` under `[tool.pyro.groups.reportifyr]` by `pyro::write_group_to_pyproject("reportifyr")`.
  * `initialize_python()` is now a deprecated wrapper that forwards to `pyro::initialize_python()`.
  * `sync_report_project()` now defers Python environment reconciliation to `pyro::initialize_python()` rather than tracking pinned versions itself. The `python_versions` block has been removed from `_init.json` and uv's lockfile is now the single source of truth for installed Python dependencies.
  * `inst/extdata/uv_setup.sh` and `inst/extdata/uv_setup.ps1` were removed, along with `get_py_version()` and `get_uv_path()` and their tests.
  * The package-load (`.onAttach`) message no longer enumerates `python.version`, `python-docx.version`, `pyyaml.version`, and `pillow.version` options — these are owned by `pyro` and surfaced through its own startup messaging. The reportifyr message now shows only `venv_dir` and the installed uv version.
  * `DESCRIPTION` adds `pyro` to `Imports`.

### Build Pipeline
* `build_report()` calls each removal step independently (`remove-footnotes`, `remove-tables`, `remove-figures`) instead of the combined `remove_tables_figures_footnotes()`. Footnote removal is now conditional on the `add_footnotes` parameter. When `false`, footnotes are preserved and the document is copied as-is. Each removal step receives the relevant `figures_path` / `tables_path` and `config_yaml` arguments so it can apply the hash-based `skip_unchanged` logic consistently.

### Configurable Toggles
* `add_hash_to_footnotes` in config.yaml (default `false`) adds a `Hash: <blake3>` line to footnotes showing the object hash read from the artifact's `_metadata.json` file, ordered by the new `Hash` entry in `footnote_order`.
* `add_path_overlay` in config.yaml (default `false`) stamps the source script path onto PNG figures saved through `ggsave_with_metadata()`. The overlay is rendered before metadata capture so the recorded artifact hash reflects the final image.
* `keep_caption_next` in config.yaml (default `true`) controls whether the "keep with next" paragraph property is applied to captions before artifact insertion. When `false`, the caption formatting step is skipped and the input document is copied directly to the intermediate path.
* `add_alt_text` in config.yaml (default `true`) controls whether alt text is embedded in figures and tables after insertion. When `false`, the alt text step is skipped and the intermediate document is copied directly to the output path.
* `abbreviation_delimiter` in config.yaml (default `","`) controls the character used to join abbreviation entries in footnotes. Previously hard-coded.
  * Before: `AUC: area under the curve. CL: clearance.`
  * After (with default `,`): `AUC: area under the curve, CL: clearance.`

### Footnote Updates
* Bookmark names for footnotes are safe for artifacts with long file paths. Word enforces a 40-character limit on bookmark names; names that would exceed this are replaced with `fp_{md5hash}` (35 characters), and short names retain the readable `fp_{name}` format. Previously, deeply nested artifact paths could produce bookmark names that Word silently dropped, breaking the footnote anchor.
* Footnote source rendering on the Python side now dispatches through a handler registry keyed by `source_meta.type`. A legacy handler is retained so `_metadata.json` files written by earlier reportifyr versions still render correctly.
* Footnote font rendering now sets `w:hAnsi` and `w:cs` in addition to `w:ascii`, ensuring correct rendering for non-ASCII and complex script characters.

## Minor Improvements
* `find_project_root()` is now exported. It walks upward from the working directory looking for a `*_init.json` file and returns the project root path. Useful for scripts that need to resolve paths relative to the project root the same way reportifyr does internally; `rpfy_context()` uses it under the hood.
* Artifact paths resolved from magic strings are now validated through a `safe_resolve()` helper that rejects paths outside the supplied `figures_path` / `tables_path`. A magic string like `{rpfy}:../../etc/passwd` will now error instead of silently reaching outside the artifact tree. Previously-valid relative paths that pointed outside the artifact directory will surface as errors and need to be moved into the artifact tree.
* `remove_tables_figures_footnotes()`, `add_plots_alt_text()`, and `add_tables_alt_text()` accept `figures_path` and/or `tables_path` arguments for hash-based skip of unchanged artifacts and for embedding artifact hashes in alt text.
* `footnote_order` in config.yaml supports a `Hash` entry for controlling placement of the hash footnote line.
* `set_table_alt_text()` updates an existing `w:tblDescription` element instead of always appending a new one, preventing duplicate alt text on rebuilds.
* `check_drawing_alt_text()` and `check_table_alt_text()` strip `[hash:...]`, `[content_hash:...]`, and `[grid:...]` suffixes before comparison, preventing false positive mismatch warnings.
* `load_yaml()` returns `{}` instead of `None` for empty YAML files, preventing downstream `NoneType` errors.
* `load_metadata()` catches `json.JSONDecodeError` in addition to `FileNotFoundError`, returning `None` with a warning instead of propagating an unhandled exception.

## Bug Fixes
* Fixed `validate_config()` reporting the wrong field name in `default_fig_width` validation, which previously said `"footnotes_font_size should be integer/double"`.
* Fixed an incorrect log message in `add_plots()` that said `"Deleting intermediate tabs document"` from the figure insertion path; it now correctly says `"Deleting intermediate figs document"`.

# reportifyr 0.3.4
## Bug Fixes

* Fixed an issue where magic strings with the extension `.rds` were not being processed correctly by `add_tables()`.
* Fixed an issue where `docx_out = NULL` for `build_report()` was failing within `validate_input_args()`.

# reportifyr 0.3.3
## Bug Fixes

* Fixed an issue where the source path of an object being written out with `write_object_metadata()` during a quarto render was being captured as the intermediate `.rmarkdown`.

# reportifyr 0.3.2
## Improvements

* Added Windows support for `uv` installation, ensuring the setup script now works on both Unix-like (Unix/Mac) and Windows platforms.

## Minor Improvements

* Added a `uv` version check such that the installed version is compared against requested version before installing requested version.
* Removed comments from JSON outputs.

## Bug Fixes

* Fixed changes to `.python_dependency_version.json` in `.venv` not being propagated to the `.python_dependency_version.json` in `report_dir_name`.
* Fixed an issue where user supplied `python.version` via `options('python.version')` was creating a new line in both `.python_dependency_version.json` files.

# reportifyr 0.3.1
## Minor Improvements

* If `config_yaml` is left `NULL` for the following functions, a default `config.yaml` file bundled with `reportifyr` is used instead:
  * `add_footnotes()`
  * `add_plots()`
  * `add_tables()`
  * `build_report()`
  * `finalize_document()`
  * `remove_tables_figures_footnotes()`

* `validate_input_args()` and `validate_alt_text_magic_strings()` no longer take a `config_yaml` argument.

* Function and argument descriptions introduced or expanded on in 0.3.0 have been updated for clarity and understanding.
  
# reportifyr 0.3.0
## New Features

* config.yaml now included with the package and allows for greater control over reportifyr content.
  * config.yaml contents are summarized below:
    * Report configuration:
      * `report_dir_name` captures the report directory name when calling `initialize_report_project()`.
      * `outputs_dir_name` captures the OUTPUTS directory name when calling `initialize_report_project()`.
      * `strict` if `true`, errors if duplicate figures/tables are found in document. If `false`, duplicate figures will be inserted as duplicates, but only the first instance of a duplicate table is inserted.

    * Table configuration:
      * `save_table_rtf` if `true`, saves table artifacts as .RTF in addition to .csv/.RDS.

    * Figure configuration:
      * `fig_alignment` [center/left/right] sets the alignment of the figure inserted into the document.
      * `use_embedded_dimensions` if `true`, captures the size of the reportifyr figures within the document and maintains this size when updating artifact.
      * `use_artifact_size` if `true`, uses the size of the saved artifact for dimensions when inserting the figure.
      * `default_fig_width` sets the default width (inches) to use for figures. Aspect ratio is maintained from saved artifact.
      * `label_multi_figures` if `true`, for multi-figure insertion (see below) adds a figure label (A, B, C, etc.) to upper left corner of figures before inserting into the document.

    * Footnote configuration:
      * font can be set through the `footnotes_font` field.
      * font size can be set through the `footnotes_font_size` field.
      * `use_object_path_as_source` if `true`, sets the source footnote to use the path to the artifact instead of the script that generated it. Default setting is `false`.
      * `wrap_path_in_[]` controls whether source/object footnotes are written as `[path/to/source.R]` (`true`) or `path/to/source.R` (`false`). Default setting is `true`.
      * `combine_duplicate_footnotes` if `true`, for multi-figure insertion (more below), only the first instance of duplicated footnotes will be inserted. To use, `label_multi_figures` must be set to `false`.
      * `footnote_order` sets the ordering of footnotes within the document.

  * `validate_config(path_to_config_yaml)` function is included to ensure config is compatible with reportifyr.
    * All expected fields are checked for correct type and valid options for non-boolean fields. Any errors are surfaced to the user. Any additional fields not used in reportifyr are ignored.
      * Examples:
        ```{r}
        > validate_config(here::here("inst/extdata/config.yaml"))
        2025-04-11 09:54:53 [ERROR] footnotes_font_size should be integer/double, not: character
        2025-04-11 09:54:53 [ERROR] Unexpected footnote field: source, object, notes, abbreviations. Acceptable fields are: Object, Source, Notes, Abbreviations
        2025-04-11 09:54:53 [ERROR] Unexpected figure alignment option: middle. Acceptable alignments are: center, left, right
        [1] FALSE
        ```
        fixing the capitalization on `footnote_order`, setting `fig_alignment` to one of [center/left/right], and making `footnotes_font_size` numeric gives the following result:
        ```{r}
        > validate_config(here::here("inst/extdata/config.yaml"))
        [1] `true`
        ```

* `initialize_report_project` has two new arguments `report_dir_name` and `outputs_dir_name`.
  * `report_dir_name` sets the name/structure of where the report will be generated.
  * `outputs_dir_name` sets the name/structure of where the report artifacts will be saved.
  * Examples:
    * You can provide nested directories to further organize a project that might have multiple reports. Here we create two reports one in `report/PK` and one in `report/NCA` and similarly separate the outputs into two subdirectories.
      ```{r}
      > initialize_report_project(here::here(), report_dir_name = "reports/PK", outputs_dir_name = "outputs/PK")
      If uv, Python, and Python dependencies (python-docx, PyYAML, Pillow)
      
      are not installed, this will install them.
      
      Otherwise, the installed versions will be used.
      
      Are you sure you want to continue? [Y/n]
      y
      Creating python virtual environment with the following settings:
              venv_dir: /Users/user/Documents/reportifyr_project
              python-docx.version: 1.1.2
              pyyaml.version: 6.0.2
              pillow.version: 11.1.0
              uv.version: 0.7.8
              python.version: 3.13.2
      uv already installed
      Created venv at /Users/user/Documents/reportifyr_project/.venv
      Installed python-docx v1.1.2
      Installed pyyaml v6.0.2
      Installed pillow v11.1.0
      
      copied standard_footnotes.yaml into /Users/user/Documents/reportifyr_project/reports/PK
      copied config.yaml into /Users/user/Documents/reportifyr_project/reports/PK
      
      > initialize_report_project(here::here(), report_dir_name = "reports/NCA", outputs_dir_name = "outputs/NCA")
      If uv, Python, and Python dependencies (python-docx, PyYAML, Pillow)
      
      are not installed, this will install them.
      
      Otherwise, the installed versions will be used.
      
      Are you sure you want to continue? [Y/n]
      y
      uv already installed
      venv already exists at /Users/user/Documents/reportifyr_project/.venv
      Current python-docx version: 1.1.2
      python-docx already at correct version (v1.1.2)
      Current pyyaml version: 6.0.2
      pyyaml already at correct version (v6.0.2)
      Current pillow version: 11.1.0
      pillow already at correct version (v11.1.0)
      
      copied standard_footnotes.yaml into /Users/user/Documents/reportifyr_project/reports/NCA
      copied config.yaml into /Users/user/Documents/reportifyr_project/reports/NCA
      ```
      This creates the following directory structure
      ```
      .
      ├── outputs
      │   ├── NCA
      │   │   ├── figures
      │   │   ├── listings
      │   │   └── tables
      │   └── PK
      │       ├── figures
      │       ├── listings
      │       └── tables
      └── reports
          ├── NCA
          │   ├── config.yaml
          │   ├── draft
          │   ├── final
          │   ├── scripts
          │   ├── shell
          │   └── standard_footnotes.yaml
          └── PK
              ├── config.yaml
              ├── draft
              ├── final
              ├── scripts
              ├── shell
              └── standard_footnotes.yaml
      ```      
  * `initialize_report_project()` also creates a initialization .json file using the report_dir_name to store metadata about the report project setup.
    * Example `reports_NCA_init.json` created from the above `initialize_report_project` call:
      ```{json}
      {
        "creation_timestamp": "2025-04-11 10:14:29",
        "last_modified": "2025-04-11 10:14:29",
        "user": "user",
        "config": {
          "report_dir_name": "reports/NCA",
          "outputs_dir_name": "outputs/NCA",
          "footnotes_font": "Arial Narrow",
          "footnotes_font_size": "10",
          "use_object_path_as_source": false,
          "wrap_path_in_[]": true,
          "combine_duplicate_footnotes": true,
          "footnote_order": ["source", "object", "notes", "abbreviations"],
          "save_table_rtf": false,
          "fig_alignment": "middle",
          "use_artifact_size": true,
          "default_fig_width": 6,
          "use_embedded_dimensions": true,
          "label_multi_figures": false
        },
        "python_versions": {
          "venv_dir": "/Users/user/Documents/reportifyr_project",
          "python-docx.version": "1.1.2",
          "pyyaml.version": "6.0.2",
          "pillow.version": "11.1.0",
          "uv.version": "0.7.8",
          "python.version": "3.13.2"
        }
      }
      ```
      
* `sync_report_project(project_dir, report_dir_name)` has been added to synchronize the report project with both the config.yaml and any Python dependency versions set with `options()` to ensure that reportifyr is using the desired specifications. `sync_report_project()` consults the initialization file, options, and config.yaml to bring them to a consistent state, updating the init file if needed.
  * Example:
    ```{r}
    > options("python-docx.version" = "1.1.1")
    > sync_report_project(here::here(), "reports/NCA")
    Python dependency versions have been changed, updating /Users/user/Documents/reportifyr_project/.reports_NCA_init.json
    uv already installed
    venv already exists at /Users/user/Documents/reportifyr_project/.venv
    Current python-docx version: 1.1.2
    Updating python-docx from v1.1.2 to v1.1.1
    Installed python-docx v1.1.1
    Current pyyaml version: 6.0.2
    pyyaml already at correct version (v6.0.2)
    Current pillow version: 11.1.0
    pillow already at correct version (v11.1.0)
    ```

* `validate_document(docx_in, config_yaml)` has been added to check that the document is in a format compatible with reportifyr use. Magic strings within `docx_in` are checked for duplicate artifacts and warns/errors (depending on `strict` config) user about duplicates.

### Magic String Updates:
* Multiple figures (multi-figure) with a single combined footnote can now be added with the following syntax:
   
    Figure 1: Multiple figures with single footnote.<br>
    {rpfy}:[figure_1.png, figure_2.png].<br>
   
    The resulting document after `build_report()` will look like the following:
     
    Figure 1: Multiple figures with single footnote.<br>
    {rpfy}:[figure_1.png, figure_2.png].<br>
    A[Figure 1]<br>
    B[Figure 2]<br>
    Source: A: path/to/figure_1_source.R Timestamp. B: path/to/figure_2_source.R Timestamp.<br>
    Notes: A: notes for figure A. B: notes for figure B.<br>
    Abbreviations: A: N/A, B: N/A.<br>
 
  * If `label_multi_figures` is set to `true` in the config.yaml, figure labels will be added to each figure on the top left corner before insertion.
  (Example: Label 'A' on figure_1, Label 'B' on figure_2). Each footnote will be denoted with respective labels (A/B) before combining into one 'Notes' line.
  This will work for any number of figures, with the labels wrapping to AA, AB after Z, if necessary. If `label_multi_figures` is not in config.yaml the default is 
  `false`, and the images will not be labeled (accordingly, footnotes will not have the A/B/etc. label).
     
  Below is an example of multiple image insertion with `label_multi_figures` set to `false` and `combine_duplicate_footnotes` set to `true`:
        
      Figure 1: Multiple figures with single footnote.<br>
      {rpfy}:[figure_1.png, figure_2.png].<br>
      [Figure 1]<br>
      [Figure 2]<br>
      Source: path/to/figure_1_source.R Timestamp. path/to/figure_2_source.R Timestamp.<br>
      Notes: notes for figure A. notes for figure B.<br>
      Abbreviations: N/A.<br>
          
      Note: If source/notes are the same they will also be combined into one entry.
     
  * Alternatively, multiple figures with multiple footnotes can also be inserted under a figure caption with:<br>
      Figure 2: Some caption for multiple figures<br>
      {rpfy}:figure_1.png<br>
      {rpfy}:figure_2.png<br>
    
    * The resulting document after `build_report()` will look like:<br>
        Figure 2: Some caption for multiple figures.<br>
        {rpfy}:figure_1.png<br>
        [Figure 1]<br>
        [Footnote for Figure 1]<br>
        {rpfy}:figure_2.png<br>
        [Figure 2]<br>
        [Footnote for Figure 2]<br>
       
  * Users can now supply per-figure sizing options with angled brackets: {rpfy}:figure.png<width: 3.67, height: 5.32>. This syntax will cause reportifyr to insert figure.png into the document and resize to 3.67 in by 5.32 in. You can also specify options in multi-figure input {rpfy}:[figure1.png<width: 3, height: 4>, figure2.png<width: 4, height: 4>] and each figure will be inserted at the specified dimensions.
 
  * With `use_embedded_dimensions` set to `true` in your config.yaml, upon updating a report, when figures are removed their dimensions are captured and added to the magic string and used on insertion of the updated figure. You can then resize an image from its saved dimension and the resizing will persist throughout the document life cycle.

* Magic strings are now embedded in the alt text of each figure or table (when calling `add_plots` or `add_tables`) using the respective `add_plots_alt_text()` or `add_tables_alt_text()`. 

  * `validate_alt_text_magic_strings()` compares these stored values to the inline magic strings to catch any potential discrepancies.

### Footnote Updates
* Footnotes now support subscript and superscript using LaTeX-like syntax: `AUC_{0-24}` will show up in the rendered .docx with `0-24` as a subscript, and `kg/m^{2}` will show up with the `2` as a superscript.

* The source footnote now reports the last time the source was committed to Git. If you are not using Git, it will use the time that the footnote was inserted at, while object footnote reports the time of artifact creation.
  
## Minor Improvements
* uv has been been updated from version 0.5.1 to 0.7.8.

* Messaging on package load has been reworked:
    ```
    ℹ Loading reportifyr
    ── Set reportifyr options ────────────────────────────────────────────────────────────────────────────────
    ✔ Using installed uv version 0.7.8
    ── venv options ──────────────────────────────────────────────────────────────────────────────────────────
    ▇ Using project root for venv (unless already present), set options('venv_dir') to change
    ── Version options ───────────────────────────────────────────────────────────────────────────────────────
    ▇ Using system python version, set options('python.version') to change
    ▇ Using python-docx version 1.1.2, set options('python-docx.version') to change
    ▇ Using pyyaml version 6.0.2, set options('pyyaml.version') to change
    ▇ Using pillow v11.1.0, set options('pillow.version') to change    
    ```

* Messaging around venv/uv/Python dependencies has been reworked:
    ```
    > initialize_report_project(here::here())
    If uv, Python, and Python dependencies (python-docx, PyYAML, Pillow)

    are not installed, this will install them.

    Otherwise, the installed versions will be used.

    Are you sure you want to continue? [Y/n]
    y
    Creating python virtual environment with the following settings:
            venv_dir: /path/to/project/
            python-docx.version: 1.1.2
            pyyaml.version: 6.0.2
            pillow.version: 11.1.0
            uv.version: 0.7.8
            python.version:  3.13.2
    uv already installed
    Created venv at /path/to/project/.venv
    Installed python-docx v1.1.2
    Installed pyyaml v6.0.2
    Installed pillow v11.1.0

    copied standard_footnotes.yaml into /path/to/project/report
    copied config.yaml into /path/to/project/report
    ```
    
* Python dependency versions are now recorded in a .json file saved in project/<report_dir_name>/.python_dependency_versions.json to improve traceability.
  ```{json}
  // WARNING: This file is automatically generated on initialization. Do not edit by hand!
  {
    "venv_dir": "/Users/user/Documents/reportifyr_project",
    "python-docx.version": "1.1.2",
    "pyyaml.version": "6.0.2",
    "pillow.version": "11.1.0",
    "uv.version": "0.7.8",
    "python.version": "3.13.2"
  }
  ```
  
* `toggle_logger()` now displays the logging level at which it’s operating.

* `add_tables()` and `add_plots()` now keep the artifact caption and magic string on the same page of the artifact instead of being broken across pages in some situations.

* `get_venv_uv_paths()` returns both venv and uv paths as a convenient helper function. 
