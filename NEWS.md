# reportifyr 0.3.0

* multiple figures with single combined footnote can now be added with the following syntax: 

    Figure 1: Multiple figures with single footnote.
    `{rpfy}:[figure_1.png, figure_2.png]`. 

    * The resulting document after `build_report()` will look like the following:
    Figure 1: Multiple figures with single footnote.
    `{rpfy}:[figure_1.png, figure_2.png]`. 
    A<Figure 1>
    B<Figure 2>
    Source: A: path/to/figure_1.png Timestamp. B: path/to/figure_2.png Timestamp.
    Notes: A: notes for figure A. B: notes for figure B.
    Abbreviations: A: N/A, B: N/A.

    * This will draw an A on figure_1 and a B on figure_2 in the upper left corner and combine the footnotes labelling them with A/B. This will work for any number of figures, with the labels wrapping to AA, AB after Z if necessary.
    
* multiple figures with multiple footnotes can also be inserted under a figure caption with:

    Figure 2: Some caption for multiple figures
    `{rpfy}:figure_1.png
    {rpfy}:figure_2.png`

    * The resulting document after `build_report()` will look like:
    Figure 2: Some caption for multiple figures
    `{rpfy}:figure_1.png`
    <Figure 1>
    [Footnote for Figure 1]

    `{rpfy}:file_2.png`
    <Figure 2>
    [Footnote for Figure 2]

* Config file is now included with reportifyr to set footnote options. Available configuration is:
    * footnote font, default Arial Narrow
    * footnote font size, default 10 pt
    * use_object_path_as_source, default false
    * wrap_path_in_[], default true
    * footnote_order, default ["Source", "Object", "Notes", "Abbreviations"]

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
    ▇ Using default v11.1.0, set options('pillow.version') to change    
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

* Footnotes now support subscript and superscript using latex-like syntax: `AUC_{0-24}` will show up in the rendered docx with `0-24` as a subscript, and `kg/m^{2}` will show up with the `2` as a superscript.
