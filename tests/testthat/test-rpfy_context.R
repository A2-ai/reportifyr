test_that("rpfy_context() with default origin returns class and cached fields", {
  ctx <- rpfy_context()

  expect_s3_class(ctx, "rpfy_context")
  expect_true(is.list(ctx$system_meta))
  expect_true(is.character(ctx$author))
  expect_true(is.list(ctx$source_meta))
  # system_meta has platform + software
  expect_true(!is.null(ctx$system_meta$platform))
  expect_true(!is.null(ctx$system_meta$software$version))
  expect_true(is.list(ctx$system_meta$software$packages_used))
})

test_that("rpfy_context() accepts a string origin as free-form text", {
  ctx <- rpfy_context(origin = "Manual analysis 2026-04-15")

  expect_equal(ctx$source_meta, list(text = "Manual analysis 2026-04-15"))
})

test_that("rpfy_context() accepts a named list origin (shiny shape)", {
  src <- list(type = "shiny", app_name = "myapp", app_version = "1.2.0")
  ctx <- rpfy_context(origin = src)

  expect_equal(ctx$source_meta, src)
})

test_that("rpfy_context() rejects a bad origin type", {
  expect_error(
    rpfy_context(origin = 42),
    "`origin` must be NULL, a string, or a list"
  )
})

test_that("rpfy_context() rejects an empty string origin", {
  expect_error(
    rpfy_context(origin = ""),
    "non-empty character scalar"
  )
})

test_that("rpfy_context() stores addl_metadata when valid", {
  ctx <- rpfy_context(
    addl_metadata = list(analyst = "jake", study = "PK-001")
  )

  expect_equal(
    ctx$addl_metadata,
    list(analyst = "jake", study = "PK-001")
  )
})

test_that("rpfy_context() rejects non-scalar addl_metadata values", {
  expect_error(
    rpfy_context(addl_metadata = list(x = c("a", "b"))),
    "scalar"
  )
})

test_that("print.rpfy_context produces output without error", {
  ctx <- rpfy_context(origin = "Test context")

  expect_output(print(ctx), "<rpfy_context>")
  expect_output(print(ctx), "origin:")
  expect_output(print(ctx), "text \\| Test context")
})

test_that("print.rpfy_context reports shiny origin distinctly", {
  ctx <- rpfy_context(
    origin = list(type = "shiny", app_name = "myapp", app_version = "1.0.0")
  )

  expect_output(print(ctx), "shiny \\| myapp v1.0.0")
})

test_that("print.rpfy_context reports addl_metadata keys", {
  ctx <- rpfy_context(
    origin = "t",
    addl_metadata = list(analyst = "jake", study = "PK-001")
  )

  expect_output(print(ctx), "analyst, study")
})

test_that("format.rpfy_context returns a one-line summary", {
  ctx <- rpfy_context(origin = "hello")
  out <- format(ctx)

  expect_length(out, 1L)
  expect_match(out, "<rpfy_context>")
  expect_match(out, "origin=text \\| hello")
})

test_that("validate.rpfy_context passes on a well-formed context", {
  ctx <- rpfy_context(origin = "ok")

  msgs <- capture_messages(validate(ctx))
  expect_true(any(grepl("\\[PASS\\] source_meta", msgs)))
})

test_that("validate.rpfy_context flags empty source_meta", {
  ctx <- rpfy_context(origin = "ok")
  ctx$source_meta <- list()  # simulate detection failure

  msgs <- capture_messages(validate(ctx))
  expect_true(any(grepl("\\[FAIL\\] source_meta", msgs)))
})
