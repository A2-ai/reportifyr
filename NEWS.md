# reportifyr 0.3.0
## New Features

* config.yaml now included with the package and allows for greater control over reportifyr content
  * config.yaml contents are summarized below:
    * Report configuration:
      * `report_dir_name` captures the report directory name when calling `initialize_report_project()`
      * `outputs_dir_name` captures the OUTPUTS directory name when calling `initialize_report_project()`
      * `strict` if `true` errors if duplicate figures/tables are found in document. if `false` duplicate figures will be inserted, but only the first instance of a duplicate table is inserted.

    * Table configuration:
      * `save_table_rtf` if `true` saves table artifacts as .RTF in addition to .csv/.RDS

    * Figure configuration:
      * `fig_alignment` [center/left/right] sets the alignment of the figure inserted into the document
      * `use_embedded_dimensions` if `true`, captures the size of the reportifyr figures within the document and maintains this size when updating artifact
      * `use_artifact_size` if `true` uses the size of the saved artifact for dimensions when inserting the figure
      * `default_fig_width` sets the default width to use for figures. aspect ratio is maintained from saved artifact
      * `label_multi_figures` if `true`, for multi-figure insertion (see below) adds a figure label (A, B, C, etc.) to upper left corner of figure before inserting into the document

    * Footnote configuration:
      * font can be set through the `footnotes_font` field
      * font size can be set through the `footnotes_font_size` field
      * `use_object_path_as_source` sets the source footnote to use the path to the artifact instead of the script that generated it
      * `wrap_path_in_[]` controls whether source/object footnotes are written as `[path/to/source.R]` (`true`) or `path/to/source.R` (`false`)
      * `combine_duplicate_footnotes` if inserting a multi-figure artifact (more below), this controls whether duplicated footnotes will be included or not. Only used if `label_multi_figures` is `false`
      * `footnote_order` sets the ordering of footnotes within the document

  * `validate_config(path_to_config_yaml)` function is included to ensure config is compatible with reportifyr
    * all expected fields are checked for correct type and valid options for non-boolean fields. Any errors are surfaced to the user. Any additional fields not used in reportifyr are ignored
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

* `initialize_report_project` has two new arguments `report_dir_name` and `outputs_dir_name`
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
              venv_dir: /Users/mattsmith/Documents/reportifyr_project
              python-docx.version: 1.1.2
              pyyaml.version: 6.0.2
              pillow.version: 11.1.0
              uv.version: 0.6.3
              python.version: 3.13.2
      uv already installed
      Created venv at /Users/mattsmith/Documents/reportifyr_project/.venv
      Installed python-docx v1.1.2
      Installed pyyaml v6.0.2
      Installed pillow v11.1.0
      
      copied standard_footnotes.yaml into /Users/mattsmith/Documents/reportifyr_project/reports/PK
      copied config.yaml into /Users/mattsmith/Documents/reportifyr_project/reports/PK
      > initialize_report_project(here::here(), report_dir_name = "reports/NCA", outputs_dir_name = "outputs/NCA")
      If uv, Python, and Python dependencies (python-docx, PyYAML, Pillow)
      
      are not installed, this will install them.
      
      Otherwise, the installed versions will be used.
      
      Are you sure you want to continue? [Y/n]
      y
      uv already installed
      venv already exists at /Users/mattsmith/Documents/reportifyr_project/.venv
      Current python-docx version: 1.1.2
      python-docx already at correct version (v1.1.2)
      Current pyyaml version: 6.0.2
      pyyaml already at correct version (v6.0.2)
      Current pillow version: 11.1.0
      pillow already at correct version (v11.1.0)
      
      copied standard_footnotes.yaml into /Users/mattsmith/Documents/reportifyr_project/reports/NCA
      copied config.yaml into /Users/mattsmith/Documents/reportifyr_project/reports/NCA
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
          │   ├── python_dependency_versions.json
          │   ├── scripts
          │   ├── shell
          │   └── standard_footnotes.yaml
          └── PK
              ├── config.yaml
              ├── draft
              ├── final
              ├── python_dependency_versions.json
              ├── scripts
              ├── shell
              └── standard_footnotes.yaml
      ```      
  * `initialize_report_project` also creates a initialization json file using the report_dir_name to store metadata about the report project setup.
    * Example `reports_NCA_init.json` created from the above `initialize_report_project` call:
      ```{json}
      // WARNING: This file is automatically generated on initialization. Do not edit by hand!
      {
        "creation_timestamp": "2025-04-11 10:14:29",
        "last_modified": "2025-04-11 10:14:29",
        "user": "mattsmith",
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
          "venv_dir": "/Users/mattsmith/Documents/reportifyr_project",
          "python-docx.version": "1.1.2",
          "pyyaml.version": "6.0.2",
          "pillow.version": "11.1.0",
          "uv.version": "0.6.3",
          "python.version": "3.13.2"
        }
      }
      ```
* `sync_report_project(project_dir, report_dir_name)` has been added to synchronize the report project with both the config.yaml and any python dependency versions set with `options()` to ensure the reportifyr is using the desired specifications. `sync_report_project` consults the initialization file, options, and config.yaml to bring them to a consistent state, updating the init file if needed.
  ```{r}
  > options("python-docx.version" = "1.1.1")
  > sync_report_project(here::here(), "reports/NCA")
  Python dependency versions have been changed, updating /Users/mattsmith/Documents/reportifyr_project/.reports_NCA_init.json
  uv already installed
  venv already exists at /Users/mattsmith/Documents/reportifyr_project/.venv
  Current python-docx version: 1.1.2
  Updating python-docx from v1.1.2 to v1.1.1
  Installed python-docx v1.1.1
  Current pyyaml version: 6.0.2
  pyyaml already at correct version (v6.0.2)
  Current pillow version: 11.1.0
  pillow already at correct version (v11.1.0)
  ```

* a new function `validate_document(docx_in, config_yaml)` has been added that checks the document is in a format useable with reportifyr. Magic strings within `docx_in` are checked for duplicate artifacts and warns/errors (depending on strict config) user about duplicates.

### Magic string updates:
  * multiple figures with a single combined footnote can now be added with the following syntax:
   
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
 
     * If `label_multi_figures` is set to `true` in config.yaml, this will draw an A on figure_1 and a B on figure_2 in the upper left corner and combine the footnotes labelling them with A/B. This will work for any number of figures, with the labels wrapping to AA, AB after Z if necessary. If `label_multi_figures` is not in config.yaml the default is `false`, and the images will not be labeled. Additionally, when multi-figures aren't labeled the footnotes will not have the A/B/etc label. If `combine_duplicate_footnotes` is `true` then the above look like:
        
        Figure 1: Multiple figures with single footnote.<br>
        {rpfy}:[figure_1.png, figure_2.png].<br>
        [Figure 1]<br>
        [Figure 2]<br>
        Source: path/to/figure_1_source.R Timestamp. path/to/figure_2_source.R Timestamp.<br>
        Notes: notes for figure A. notes for figure B.<br>
        Abbreviations: N/A.<br>
          
       and if source/notes are the same they will also be combined into one entry.
     
  * multiple figures with multiple footnotes can also be inserted under a figure caption with:<br>
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
       
 * you can now supply per-figure sizing options with angled brackets: {rpfy}:figure.png<width: 3.67, height: 5.32> this syntax will cause reportifyr to insert figure.png into the document and resize to 3.67 in by 5.32 in. You can also specify options in multi-figure input {rpfy}:[figure1.png<width: 3, height: 4>, figure2.png<width: 4, height: 4>] and each figure will be inserted at the specified dimensions.
 * with `use_embedded_dimensions` set to `true` in your config.yaml, upon updating a report, when figures are removed their size is captured and added to the magic string and used on insertion of the updated figure. You can then resize an image from its saved dimension and the resizing will persist throughout the document lifecycle.

### Footnotes updates
* Footnotes now support subscript and superscript using latex-like syntax: `AUC_{0-24}` will show up in the rendered docx with `0-24` as a subscript, and `kg/m^{2}` will show up with the `2` as a superscript.
* The source footnote now reports the last time the source was committed to git. If you are not using git it will use the time the time the footnote is inserted. Object footnote reports the time the artifact was created.
  
## Minor Improvements
* Messaging on package load has been reworked:
    ```
    ℹ Loading reportifyr
    ── Set reportifyr options ────────────────────────────────────────────────────────────────────────────────
    ✔ Using installed uv version 0.6.3
    ── venv options ──────────────────────────────────────────────────────────────────────────────────────────
    ▇ Using project root for venv (unless already present), set options('venv_dir') to change
    ── Version options ───────────────────────────────────────────────────────────────────────────────────────
    ▇ Using system python version, set options('python.version') to change
    ▇ Using python-docx version 1.1.2, set options('python-docx.version') to change
    ▇ Using pyyaml version 6.0.2, set options('pyyaml.version') to change
    ▇ Using pillow v11.1.0, set options('pillow.version') to change    
    ```

* Messaging around venv/uv/python dependencies has been reworked:
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
            uv.version: 0.6.3
            python.version:  3.13.2
    uv already installed
    Created venv at /path/to/project/.venv
    Installed python-docx v1.1.2
    Installed pyyaml v6.0.2
    Installed pillow v11.1.0

    copied standard_footnotes.yaml into /path/to/project/report
    copied config.yaml into /path/to/project/report
    ```
* python dependency versions are now recorded in a .json file saved in project/<report_dir_name>/python_dependency_versions.json to improve traceability
  ```{json}
  // WARNING: This file is automatically generated on initialization. Do not edit by hand!
  {
    "venv_dir": "/Users/mattsmith/Documents/reportifyr_project",
    "python-docx.version": "1.1.2",
    "pyyaml.version": "6.0.2",
    "pillow.version": "11.1.0",
    "uv.version": "0.6.3",
    "python.version": "3.13.2"
  }
  ```
* `toggle_logger()` now prints the level logging is recorded at when called.
* `finalize_document()` now keeps the artifact caption on the same page of the artifact instead of being broken across page breaks in some situations.
