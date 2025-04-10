
<!-- README.md is generated from README.Rmd. Please edit that file -->

# reportifyr <a href="https://github.com/a2-ai/reportifyr/"><img src="man/figures/logo.png" align="right" height="139" alt="reportifyr website" /></a>

<!-- badges: start -->

[![R-CMD-check](https://github.com/A2-ai/reportifyr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/A2-ai/reportifyr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of `reportifyr` is to optimize and streamline workflows
associated with Microsoft Word document (report) generation, which
includes supporting tasks across multiple stages of the reporting
process (analyses, drafting, etc.) `reportifyr` functions as a wrapper
around the `officer` `R` package and `python-docx` `Python` library,
allowing users to easily produce traceable and consistent reports in
`R`.

## Installation

You can install the development version of `reportifyr` like so:

``` r
pak::pkg_install("a2-ai/reportifyr")
```

## Interacting with `reportifyr`

``` r
library(reportifyr)
```

## Initializing Appropriate Folder Structures

Before starting any reporting effort, it is important to initialize all
reporting directories within the project directory you are working in.
Please note that for development, the directory structure and names have
been hard-coded. We realize this is sub-optimal and are working on
allowing user-defined `report` and `OUTPUTS` structure!

``` r
initialize_report_project(project_dir = here::here())
```

## Steps at the Analysis Stage

To take advantage of more advanced features of the `reportifyr` package
(such as automatic abbreviation creation and footnote placing) you need
to capture some metadata during the analysis.

The `reportifyr` package contains some helpful functions for easily
capturing metadata. These functions should be used in actual analysis
scripts. The metadata `.json` files are saved along side the artifact
files (figures or tables) and will be referenced when building reports.

This is a basic example which shows how to save a plot and table using
two of `reportifyr`’s wrapper functions:

``` r
# ------------------------------------------------------------------------------
# Retrieve standardized parameters to ease footnote insertion
# ------------------------------------------------------------------------------
meta_abbrevs <- get_meta_abbrevs(path_to_footnotes_yaml = here::here("report", "standard_footnotes.yaml"))
meta_type <- get_meta_type(path_to_footnotes_yaml = here::here("report", "standard_footnotes.yaml"))

# ------------------------------------------------------------------------------
# Construct and save a simple ggplot
# ------------------------------------------------------------------------------
g <- ggplot2::ggplot(
  data = Theoph,
  ggplot2::aes(x = Time, y = conc, group = Subject)
) +
  ggplot2::geom_point() +
  ggplot2::geom_line() +
  ggplot2::theme_bw()

# Save a png using the wrapper function
figures_path <- here::here("OUTPUTS", "figures")
plot_file_name <- "01-12345-pk-timecourse1.png"

ggsave_with_metadata(
  filename = file.path(figures_path, plot_file_name),
  meta_type = meta_type$conc-time-trajectories,
  meta_abbrevs = c(meta_abbrevs$CMAXA)
)

# Alternatively you could call `ggplot2::ggsave()` and then call `write_object_metadata()`
ggplot2::ggsave(
  filename = file.path(figures_path, plot_file_name),
  plot = p,
  width = 6,
  height = 4
)

write_object_metadata(
  object_file = file.path(figures_path, plot_file_name),
  meta_type = meta_type$conc-time-trajectories,
  meta_abbrevs = c(meta_abbrevs$CMAXA)
)
```

``` r
# ------------------------------------------------------------------------------
# Save a simple table
# ------------------------------------------------------------------------------
tables_path <- here::here("OUTPUTS", "tables")
out_name <- "01-12345-pk-theoph.csv"

write_csv_with_metadata(
  object = Theoph,
  file = file.path(tables_path, out_name),
  row_names = FALSE
)

# Alternatively you could call `write.csv()` and then call `write_object_metadata()`.
write.csv(
  x = Theoph, 
  file = file.path(tables_path, out_name), 
  row.names = FALSE
)

write_object_metadata(object = file.path(tables_path, out_name))
```

## Steps at the Report Drafting Stage

This is a basic step-by-step example which shows how to render a report
with figures, tables, and footnotes included:

``` r
# ------------------------------------------------------------------------------
# Load all dependencies
# ------------------------------------------------------------------------------
docx_in <- here::here("report", "shell", "template.docx")
doc_dirs <- make_doc_dirs(docx_in = docx_in)
figures_path <- here::here("OUTPUTS", "figures")
tables_path <- here::here("OUTPUTS", "tables")
standard_footnotes_yaml <- here::here("report", "standard_footnotes.yaml")

# ------------------------------------------------------------------------------
# Step 1.
# `add_tables()` will format and insert tables into the `.docx` file.
# ------------------------------------------------------------------------------
add_tables(
  docx_in = doc_dirs$doc_in,
  docx_out = doc_dirs$doc_tables,
  tables_path = tables_path
)

# ------------------------------------------------------------------------------
# Step 2.
# Next we insert the plots using the `add_plots()` function.
# ------------------------------------------------------------------------------
add_plots(
  docx_in = doc_dirs$doc_tables,
  docx_out = doc_dirs$doc_tabs_figs,
  figures_path = figures_path
)

# ------------------------------------------------------------------------------
# Step 3.
# Now we can add the footnotes with the `add_footnotes` function.
# ------------------------------------------------------------------------------
add_footnotes(
  docx_in = doc_dirs$doc_tabs_figs,
  docx_out = doc_dirs$doc_draft,
  figures_path = figures_path,
  tables_path = tables_path,
  standard_footnotes_yaml = standard_footnotes_yaml,
  include_object_path = FALSE,
  footnotes_fail_on_missing_metadata = TRUE
)

# ---------------------------------------------------------------------------
# Step 4.
# If you are ready to finalize the `.docx` file, run the `finalize_document()`
# function. This will remove the ties between reportifyr and the document, so
# please be mindful!
# ---------------------------------------------------------------------------
finalize_document(
  docx_in = doc_dirs$doc_draft,
  docx_out = doc_dirs$doc_final
)
```

`reportifyr` also offers a wrapper to complete all of the artifact
additions with one function call:

``` r
# ---------------------------------------------------------------------------
# Load all dependencies
# ---------------------------------------------------------------------------
docx_in <- here::here("report", "shell", "template.docx")
doc_dirs <- make_doc_dirs(docx_in = docx_in)
figures_path <- here::here("OUTPUTS", "figures")
tables_path <- here::here("OUTPUTS", "tables")
standard_footnotes_yaml <- here::here("report", "standard_footnotes.yaml")

# ---------------------------------------------------------------------------
# Step 1.
# Run the `build_report()` wrapper function to replace figures, tables, and
# footnotes in a `.docx` file.
# ---------------------------------------------------------------------------
build_report(
  docx_in = doc_dirs$doc_in,
  docx_out = doc_dirs$doc_draft,
  figures_path = figures_path,
  tables_path = tables_path,
  standard_footnotes_yaml = standard_footnotes_yaml
)
```
