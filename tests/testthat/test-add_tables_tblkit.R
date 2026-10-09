# add_tables() with table_engine "tblkit": the same tables, in the same places, as the
# officer engine (tblkit_engine needs tblkit with marker anchors and max_story_bytes).

skip_if_no_tblkit_markers <- function() {
  testthat::skip_if_not_installed("tblkit")
  if (!"max_story_bytes" %in% names(formals(tblkit::report_inspect)))
    testthat::skip("tblkit without marker anchors and max_story_bytes")
}

make_add_tables_inputs <- function(dir, magic) {
  tables <- file.path(dir, "tables")
  dir.create(tables)
  ft1 <- flextable::flextable(head(iris))
  ft2 <- flextable::flextable(head(mtcars[, 1:5]))
  saveRDS(ft1, file.path(tables, "iris.rds"))
  saveRDS(ft2, file.path(tables, "mtcars.rds"))
  doc <- officer::read_docx()
  for (p in magic) doc <- officer::body_add_par(doc, p)
  template <- file.path(dir, "template.docx")
  print(doc, target = template)
  list(template = template, tables = tables)
}

run_add_tables <- function(inputs, engine, dir) {
  config <- yaml::read_yaml(system.file("extdata", "config.yaml", package = "reportifyr"))
  config$table_engine <- engine
  config$keep_caption_next <- FALSE
  config$add_alt_text <- FALSE
  config_yaml <- file.path(dir, paste0(engine, ".yaml"))
  yaml::write_yaml(config, config_yaml)
  out <- file.path(dir, paste0(engine, ".docx"))
  add_tables(inputs$template, out, inputs$tables, config_yaml = config_yaml)
  s <- officer::docx_summary(officer::read_docx(out))
  list(
    paragraphs = s$text[s$content_type == "paragraph"],
    cells = s$text[s$content_type == "table cell"]
  )
}

test_that("tblkit places the tables the officer engine places", {
  skip_if_no_tblkit_markers()
  local_mocked_bindings(validate_docx = function(...) invisible(TRUE))
  dir <- withr::local_tempdir()
  inputs <- make_add_tables_inputs(dir, c(
    "Table 1", "{rpfy}:iris.rds", "Table 2", "{rpfy}:mtcars.rds",
    "Table 3", "{rpfy}:missing.rds", "End"
  ))
  officer_out <- run_add_tables(inputs, "officer", dir)
  tblkit_out <- run_add_tables(inputs, "tblkit", dir)
  expect_identical(tblkit_out$cells, officer_out$cells)
  expect_identical(tblkit_out$paragraphs, officer_out$paragraphs)
  expect_true(length(tblkit_out$cells) > 0)
})

test_that("a duplicate magic string sends the whole document through officer", {
  skip_if_no_tblkit_markers()
  local_mocked_bindings(validate_docx = function(...) invisible(TRUE))
  dir <- withr::local_tempdir()
  inputs <- make_add_tables_inputs(dir, c(
    "{rpfy}:iris.rds", "{rpfy}:mtcars.rds", "{rpfy}:iris.rds"
  ))
  officer_out <- run_add_tables(inputs, "officer", dir)
  tblkit_out <- run_add_tables(inputs, "tblkit", dir)
  expect_identical(tblkit_out$cells, officer_out$cells)
})

test_that("the bundled config sets tblkit_max_story_bytes", {
  config <- yaml::read_yaml(system.file("extdata", "config.yaml", package = "reportifyr"))
  expect_true(is.numeric(config$tblkit_max_story_bytes))
})
