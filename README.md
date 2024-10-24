
<!-- README.md is generated from README.Rmd. Please edit that file -->

# reportifyr <a href="https://github.com/a2-ai/reportifyr/"><img src="man/figures/logo.png" align="right" height="139" alt="reportifyr website" /></a>

<!-- badges: start -->
<!-- badges: end -->

The goal of `reportifyr` is to assist with semi-automatic report
creation, providing a streamlined process for saving tables, figures,
and footnotes from analysis scripts and incorporating them into
Microsoft Word documents for report generation. `reportifyr` is a
wrapper around the `officer` R package and `python-docx` python library,
allowing users to easily manipulate Microsoft Word documents in R for
polished and consistent reports.

## Installation

You can install the development version of `reportifyr` like so:

``` r
# FILL THIS IN! HOW CAN PEOPLE INSTALL YOUR DEV PACKAGE?
```

## Interacting with reportifyr

``` r
library(reportifyr)
```

## Initializing appropriate folder structures

Before starting any reporting effort, it is important to initialize all
reporting directories within the project directory you are working in.
Please note that for development, the directory structure and names have
been hard-coded. We realize this is sub-optimal and are working on
allowing user-defined `report/` and `OUTPUTS/` structure!

``` r
initialize_report_project(project_dir = here::here())
```

## Steps at the analysis level

To take advantage of more advanced features of the `reportifyr` package
(such as automatic abbreviation creation and footnote placing) you need
to capture some metadata during the analysis.

The `reportifyr` package contains some helpful functions for easily
capturing metadata. These functions should be used in actual analysis
scripts. The metadata .json files are saved along side the object files
(figures or tables) and will be referenced when building reports.

``` r
# Path to the analysis figures
figures_path <- "OUTPUTS/figures"

# We can grab some standard meta types to ease footnote insertion
meta_types = get_meta_types(project_dir = here::here())

# ------------------------------------------------------------------------------
# Construct a simple ggplot
# ------------------------------------------------------------------------------
library(ggplot2)
g <- ggplot(data = Theoph, aes(x=Time, y = conc, group = Subject)) + 
  geom_point() + 
  geom_line() + 
  theme_bw()

# Save a .png using the helper function
out_name <- "01-12345-pk-timecourse.png"
ggsave_with_metadata(
  filename = file.path(figures_path, out_name), 
  width = 9.4, 
  height = 6.72,
  meta_type = meta_type$conc-time-trajectories
)

# Or save with `ggplot2::ggsave` and immediately after run the `write_object_metadata` function
out_name <- "01-12345-pk-timecourse2.png"
ggplot2::ggsave(
  filename = file.path(figures.path, out_name), 
  plot = g,
  width = 9.4,
  height = 6.72) 
write_object_metadata(
  file.path(figures.path, out_name),
  meta_type = meta_type$conc-time-trajectories)
```

``` r
# Path to the analysis tables
tables_path  <- "OUTPUTS/tables"

# ------------------------------------------------------------------------------
# Construct a simple table
# ------------------------------------------------------------------------------

# Let's save a .csv using the helper function
out_name <- "01-12345-pk-theoph.csv"
write_csv_with_metadata(
  object = Theoph, 
  file = file.path(tables.path, out_name),
  row.names = F
)

# Or save with `write.csv` and immediately after run the `write_object_metadata` function
write.csv(x = Theoph, file = file.path(tables.path, out_name), row.names = F)
write_object_metadata(object = file.path(tables.path, out_name))
```

## Report creation

This is a basic example which shows you how to render a Microsoft Word
document with figures, tables, and footnotes.

``` r
# ------------------------------------------------------------------------------
# A minimal example
# ------------------------------------------------------------------------------
# Load all dependencies.
# ------------------------------------------------------------------------------
library(reportifyr)

initialize_report_project(project_dir = here::here())

docx_in <- file.path(here::here(), "report", "shell", "template.docx")
doc_dirs <- make_doc_dirs(docx_in = docx_in)
figures_path <- file.path(here::here(), "OUTPUTS", "figures")
tables_path <- file.path(here::here(), "OUTPUTS", "tables")
footnotes <- file.path(here::here(), "report", "standard_footnotes.yaml")

# ---------------------------------------------------------------------------
# Step 1.
# Table addition, running `add_tables` will format and insert tables into the doc.
# ---------------------------------------------------------------------------
add_tables(
  docx_in = doc_dirs$doc_clean,
  docx_out = doc_dirs$doc_tables,
  tables_path = tables_path
)

# ---------------------------------------------------------------------------
# Step 2.
# Next we place in the plots using the `add_plots` function.
# ---------------------------------------------------------------------------
add_plots(
  docx_in = doc_dirs$doc_tables,
  docx_out = doc_dirs$doc_tabs_figs,
  figures_path = figures_path
)

# ---------------------------------------------------------------------------
# Step 3.
# Now we can add the footnotes to all the inserted figures and tables using `add_footnotes`.
# ---------------------------------------------------------------------------
add_footnotes(
  docx_in = doc_dirs$doc_tabs_figs,
  docx_out = doc_dirs$doc_draft,
  figures_path = figures_path,
  tables_path = tables_path,
  footnotes = footnotes
)

# ---------------------------------------------------------------------------
# Step 4.
# Clean the output for final document creation using `finalize_document`. 
# This will remove the ties between reportifyr and the document so be careful!
# ---------------------------------------------------------------------------
finalize_document(
  docx_in = doc_dirs$doc_draft,
  docx_out = doc_dirs$doc_final
)
```

`reportifyr` also offers a wrapper to complete all above steps with one
function call:

``` r
library(reportifyr)

initialize_report_project(project_dir = here::here())

figures_path <- file.path(here::here(), "OUTPUTS", "figures")
tables_path <- file.path(here::here(), "OUTPUTS", "tables")
footnotes <- file.path(here::here(), "report", "standard_footnotes.yaml")

docx_in <- file.path(here::here(), "report", "shell", "template.docx")
docx_out <- file.path(here::here(), "report", "draft", "draft.docx")

build_report(docx_in = docx_in,
             docx_out = docx_out,
             figures_path = figures_path,
             tables_path = tables_path,
             standard_footnotes_yaml = footnotes)
             
# If you're satisfied with the report and want to remove the magic strings, you'll 
# need to run `finalize_document`
finalize_document(docx_in = docx_out,
                  docx_out = "report/final/final.docx")
```
