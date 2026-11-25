w_ns_test <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")

# Build a docx with `{rpfy}:<table_name>` followed by "after text", run
# process_table_file() `times` times, and return the body nodes that follow
# the magic string.
run_process_table_file <- function(ft, times = 1, template_caption = FALSE) {
  tables_dir <- withr::local_tempdir(.local_envir = parent.frame())
  table_name <- "captioned.rds"
  table_file <- file.path(tables_dir, table_name)
  saveRDS(ft, table_file)

  doc <- officer::read_docx()
  if (template_caption) {
    doc <- officer::body_add_par(doc, "Table 1. Template caption")
  }
  doc <- officer::body_add_par(doc, paste0("{rpfy}:", table_name))
  doc <- officer::body_add_par(doc, "after text")

  for (i in seq_len(times)) {
    doc <- suppressWarnings(process_table_file(table_file, doc, table_name))
  }

  doc_xml <- doc$doc_obj$get()
  magic <- find_table_magic_paragraph(doc_xml, table_name)
  list(
    doc_xml = doc_xml,
    magic = magic,
    table_name = table_name,
    following = xml2::xml_find_all(magic, "following-sibling::*")
  )
}

caption_bookmarks <- function(node) {
  xml2::xml_find_all(
    node,
    ".//w:bookmarkStart[starts-with(@w:name, 'rpcap_')]",
    ns = w_ns_test
  )
}

test_that("an uncaptioned flextable is inserted directly after the magic string", {
  res <- run_process_table_file(flextable::flextable(head(cars, 2)))

  expect_equal(xml2::xml_name(res$following[[1]]), "tbl")
  expect_length(caption_bookmarks(res$doc_xml), 0)
})

test_that("a flextable caption is bookmarked with rpcap_<md5(table name)>", {
  ft <- flextable::set_caption(
    flextable::flextable(head(cars, 2)),
    "Plain caption"
  )
  res <- run_process_table_file(ft)

  caption <- res$following[[1]]
  expect_equal(xml2::xml_name(caption), "p")
  expect_equal(xml2::xml_text(caption), "Plain caption")
  expect_equal(xml2::xml_name(res$following[[2]]), "tbl")

  bm <- caption_bookmarks(caption)
  expect_length(bm, 1)
  expect_equal(
    xml2::xml_attr(bm[[1]], "w:name", ns = w_ns_test),
    paste0(
      "rpcap_",
      digest::digest(res$table_name, algo = "md5", serialize = FALSE)
    )
  )
  # integer id, not scientific notation, and a matching bookmarkEnd
  bm_id <- xml2::xml_attr(bm[[1]], "w:id", ns = w_ns_test)
  expect_match(bm_id, "^[0-9]+$")
  expect_length(
    xml2::xml_find_all(
      caption,
      sprintf(".//w:bookmarkEnd[@w:id='%s']", bm_id),
      ns = w_ns_test
    ),
    1
  )
})

test_that("an empty caption paragraph is still bookmarked", {
  ft <- flextable::set_caption(flextable::flextable(head(cars, 2)), "")
  res <- run_process_table_file(ft)

  expect_equal(xml2::xml_name(res$following[[1]]), "p")
  expect_length(caption_bookmarks(res$following[[1]]), 1)
  expect_equal(xml2::xml_name(res$following[[2]]), "tbl")
})

test_that("a second pass skips a captioned table that is already present", {
  ft <- flextable::set_caption(
    flextable::flextable(head(cars, 2)),
    "Plain caption"
  )
  res <- run_process_table_file(ft, times = 2)

  expect_length(
    xml2::xml_find_all(res$doc_xml, "//w:body/w:tbl", ns = w_ns_test),
    1
  )
  expect_length(caption_bookmarks(res$doc_xml), 1)
  expect_equal(xml2::xml_name(res$following[[2]]), "tbl")
  expect_equal(xml2::xml_text(res$following[[3]]), "after text")
})

test_that("a template caption above the magic string is left alone", {
  ft <- flextable::set_caption(
    flextable::flextable(head(cars, 2)),
    "Flextable caption"
  )
  res <- run_process_table_file(ft, template_caption = TRUE)

  above <- xml2::xml_find_first(res$magic, "preceding-sibling::*[1]")
  expect_equal(xml2::xml_text(above), "Table 1. Template caption")
  expect_length(caption_bookmarks(above), 0)
  expect_length(caption_bookmarks(res$following[[1]]), 1)
})
