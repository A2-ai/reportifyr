test_that("add_footnotes passes only the supplied absolute footnotes path", {
  directory <- withr::local_tempdir()
  withr::local_dir(directory)
  writeLines("table_footnotes: {}", "custom.yaml")
  calls <- list()
  local_mocked_bindings(
    validate_input_args = function(...) invisible(NULL),
    validate_docx = function(...) invisible(NULL),
    validate_config = function(...) TRUE,
    run_python_script = function(args, script_name) {
      calls[[length(calls) + 1L]] <<- args
    }
  )

  add_footnotes(
    "in.docx",
    "out.docx",
    "figures",
    "tables",
    standard_footnotes_yaml = "./custom.yaml",
    config_yaml = "config.yaml"
  )

  expect_length(calls, 2L)
  for (args in calls) {
    expect_equal(sum(args == "-f"), 1L)
    expect_equal(
      args[match("-f", args) + 1L],
      normalizePath("custom.yaml", winslash = "/")
    )
  }
})

test_that("add_footnotes rejects invalid supplied paths without running footnote scripts", {
  directory <- withr::local_tempdir()
  local_mocked_bindings(
    validate_input_args = function(...) invisible(NULL),
    validate_docx = function(...) invisible(NULL),
    run_python_script = function(...) stop("Footnote script must not run")
  )
  for (path in list(
    "",
    NA_character_,
    character(),
    c("a", "b"),
    file.path(directory, "missing.yaml"),
    directory
  )) {
    error <- tryCatch(
      add_footnotes(
        "in.docx",
        "out.docx",
        "figures",
        "tables",
        standard_footnotes_yaml = path
      ),
      error = identity
    )
    expect_s3_class(error, "error")
    expect_match(
      conditionMessage(error),
      "No default footnotes file will be used",
      fixed = TRUE
    )
  }
})
