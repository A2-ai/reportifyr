test_that("nested Quarto sources are retained by metadata and save wrappers", {
  skip_if_not_installed("knitr")
  project <- withr::local_tempdir()
  reports <- file.path(project, "reports")
  dir.create(reports)
  writeLines("{}", file.path(project, ".report_init.json"))
  writeLines("save_table_rtf: false", file.path(reports, "config.yaml"))
  writeLines(
    "---\ntitle: Nested report\n---",
    file.path(reports, "analysis.qmd")
  )
  # A same-named root document must not override the actual nested input.
  writeLines("Root report", file.path(project, "analysis.qmd"))
  withr::local_dir(reports)
  withr::local_envvar(QUARTO_PROJECT_ROOT = project)
  local_mocked_bindings(
    get_packages = function() list(),
    get_git_config_author = function() "Test author",
    get_git_info = function(...) {
      list(
        creation_author = "Test author",
        latest_author = "Test author",
        creation_time = "2026-01-01",
        latest_time = "2026-01-01"
      )
    }
  )
  input <- file.path(reports, "analysis.rmarkdown")
  writeLines(
    c(
      "```{r}",
      'writeLines("Content", "direct.txt")',
      'reportifyr::write_object_metadata("direct.txt")',
      'reportifyr::save_rds_with_metadata(data.frame(x = 1), "table.rds", config_yaml = "config.yaml")',
      'reportifyr::ggsave_with_metadata("plot.png", plot = ggplot2::ggplot(), width = 1, height = 1)',
      "```"
    ),
    input
  )

  knitr::knit(input, output = file.path(reports, "analysis.md"), quiet = TRUE)

  for (artifact in c("direct.txt", "table.rds", "plot.png")) {
    metadata <- read_saved_metadata(file.path(reports, artifact))
    expect_equal(metadata$source_meta$path, "reports/analysis.qmd")
  }
})
