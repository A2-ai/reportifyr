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

test_that("rpfy_context() accepts a shiny_source origin", {
  src <- shiny_source(app_name = "myapp", app_version = "1.2.0")
  ctx <- rpfy_context(origin = src)

  expect_s3_class(ctx$source_meta, "shiny_source")
  expect_s3_class(ctx$source_meta, "rpfy_source_meta")
  expect_null(ctx$source_meta$type)  # type is not stored; emitted at JSON time
  expect_equal(ctx$source_meta$app_name, "myapp")
  expect_equal(ctx$source_meta$app_version, "1.2.0")
})

test_that("rpfy_context() accepts a script_source origin", {
  src <- script_source(
    path            = "scripts/foo.R",
    creation_author = "jake",
    latest_author   = "jake",
    creation_time   = "2026-01-01 00:00:00",
    latest_time     = "2026-04-20 12:00:00"
  )
  ctx <- rpfy_context(origin = src)

  expect_s3_class(ctx$source_meta, "script_source")
  expect_s3_class(ctx$source_meta, "rpfy_source_meta")
  expect_null(ctx$source_meta$type)  # type is not stored; emitted at JSON time
  expect_equal(ctx$source_meta$path, "scripts/foo.R")
})

test_that("rpfy_context() rejects a character origin", {
  expect_error(
    rpfy_context(origin = "Manual analysis"),
    "`origin` must be NULL or an `rpfy_source_meta`"
  )
})

test_that("rpfy_context() rejects a raw named list origin", {
  expect_error(
    rpfy_context(origin = list(type = "shiny", app_name = "x")),
    "`origin` must be NULL or an `rpfy_source_meta`"
  )
})

test_that("rpfy_context() rejects a numeric origin", {
  expect_error(
    rpfy_context(origin = 42),
    "`origin` must be NULL or an `rpfy_source_meta`"
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

test_that("print.rpfy_context reports shiny origin", {
  ctx <- rpfy_context(
    origin = shiny_source("myapp", app_version = "1.0.0")
  )

  expect_output(print(ctx), "<rpfy_context>")
  expect_output(print(ctx), "origin:")
  expect_output(print(ctx), "shiny \\| myapp v1.0.0")
})

test_that("print.rpfy_context reports script origin", {
  ctx <- rpfy_context(origin = script_source(
    path            = "scripts/foo.R",
    creation_author = "jake",
    latest_author   = "jake",
    creation_time   = "2026-01-01 00:00:00",
    latest_time     = "2026-04-20 12:00:00"
  ))

  expect_output(print(ctx), "script \\| scripts/foo.R")
})

test_that("print.rpfy_context reports addl_metadata keys", {
  ctx <- rpfy_context(
    origin = shiny_source("myapp", app_version = "1.0.0"),
    addl_metadata = list(analyst = "jake", study = "PK-001")
  )

  expect_output(print(ctx), "analyst, study")
})

test_that("format.rpfy_context returns a one-line summary", {
  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))
  out <- format(ctx)

  expect_length(out, 1L)
  expect_match(out, "<rpfy_context>")
  expect_match(out, "origin=shiny \\| myapp v1\\.0\\.0")
})

test_that("validate_rpfy_context returns invisibly on a well-formed context", {
  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))

  expect_silent(out <- validate_rpfy_context(ctx))
  expect_identical(out, ctx)
})

test_that("validate_rpfy_context accepts empty source_meta (unresolved)", {
  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))
  ctx$source_meta <- list()

  expect_silent(validate_rpfy_context(ctx))
})

test_that("validate_rpfy_context rejects non-rpfy_context inputs", {
  expect_error(validate_rpfy_context(list()), "must inherit from class")
  expect_error(validate_rpfy_context("x"), "must inherit from class")
})

test_that("validate_rpfy_context rejects hand-crafted objects missing fields", {
  bad <- structure(list(project_root = NULL), class = "rpfy_context")
  expect_error(validate_rpfy_context(bad), "missing required field")
})

test_that("validate_rpfy_context accepts NULL project_root (unresolved)", {
  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))
  ctx["project_root"] <- list(NULL)
  expect_silent(validate_rpfy_context(ctx))
})

test_that("validate_rpfy_context rejects bad field values", {
  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))

  bad_root <- ctx
  bad_root$project_root <- "/this/path/does/not/exist/xyz"
  expect_error(validate_rpfy_context(bad_root), "existing directory")

  bad_source <- ctx
  bad_source$source_meta <- list(foo = "bar")
  expect_error(validate_rpfy_context(bad_source), "rpfy_source_meta")

  bad_author <- ctx
  bad_author$author <- ""
  expect_error(validate_rpfy_context(bad_author), "non-empty character scalar")

  bad_sys <- ctx
  bad_sys$system_meta <- list(platform = "x")  # missing software
  expect_error(validate_rpfy_context(bad_sys), "platform.*software")
})

test_that("validate_shiny_source errors on wrong class / values", {
  expect_error(validate_shiny_source(list()), "shiny_source")
  bad <- structure(
    list(app_name = "", app_version = "1"),
    class = c("shiny_source", "rpfy_source_meta")
  )
  expect_error(validate_shiny_source(bad), "non-empty character scalar")
})

test_that("validate_script_source errors on wrong class / values", {
  expect_error(validate_script_source(list()), "script_source")
  bad <- structure(
    list(
      creation_author = "a",
      latest_author   = "a",
      path            = "",
      creation_time   = "t",
      latest_time     = "t"
    ),
    class = c("script_source", "rpfy_source_meta")
  )
  expect_error(validate_script_source(bad), "non-empty character scalar")
})

test_that("shiny_source rejects invalid inputs", {
  expect_error(shiny_source(""), "non-empty character scalar")
  expect_error(shiny_source(c("a", "b")), "non-empty character scalar")
  expect_error(
    shiny_source("myapp", app_version = ""),
    "non-empty character scalar"
  )
})

test_that("script_source rejects invalid inputs", {
  expect_error(
    script_source(
      path = "",
      creation_author = "a",
      latest_author = "a",
      creation_time = "t",
      latest_time = "t"
    ),
    "non-empty character scalar"
  )
})

test_that("resolve_context() returns a fresh context when input is NULL", {
  ctx <- resolve_context(NULL)
  expect_s3_class(ctx, "rpfy_context")
})

test_that("resolve_context() returns a valid context unchanged", {
  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))
  out <- resolve_context(ctx)
  expect_identical(out, ctx)
})

test_that("resolve_context() rejects non-rpfy_context inputs", {
  expect_error(resolve_context(list()), "must inherit from class")
  expect_error(resolve_context("x"), "must inherit from class")
  expect_error(resolve_context(42), "must inherit from class")
})

test_that("to_list() emits the type discriminator per variant", {
  expect_equal(
    to_list(shiny_source("myapp", app_version = "1.0")),
    list(type = "shiny", app_name = "myapp", app_version = "1.0")
  )

  expect_equal(
    to_list(script_source(
      path            = "scripts/foo.R",
      creation_author = "jake",
      latest_author   = "jake",
      creation_time   = "2026-01-01 00:00:00",
      latest_time     = "2026-04-20 12:00:00"
    )),
    list(
      type            = "script",
      creation_author = "jake",
      latest_author   = "jake",
      path            = "scripts/foo.R",
      creation_time   = "2026-01-01 00:00:00",
      latest_time     = "2026-04-20 12:00:00"
    )
  )

  expect_equal(
    to_list(list()),
    list(
      type            = "unresolved",
      creation_author = NA_character_,
      latest_author   = NA_character_,
      path            = NA_character_,
      creation_time   = NA_character_,
      latest_time     = NA_character_
    )
  )
})

test_that("format_source() dispatches per variant", {
  expect_equal(
    format_source(shiny_source("myapp", app_version = "1.0")),
    "shiny | myapp v1.0"
  )
  expect_equal(
    format_source(script_source(
      path            = "scripts/foo.R",
      creation_author = "jake",
      latest_author   = "jake",
      creation_time   = "t",
      latest_time     = "t"
    )),
    "script | scripts/foo.R"
  )
  expect_equal(format_source(list()), "(unresolved)")
})
