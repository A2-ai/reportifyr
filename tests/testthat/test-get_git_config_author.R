test_that("get_git_config_author returns correctly formatted author string for valid config", {
  settings <- data.frame(
    name = c("user.name", "user.email"),
    value = c("Alice Doe", "alice@example.com"),
    level = c("global", "global"),
    stringsAsFactors = FALSE
  )

  author <- get_git_config_author(settings)
  expect_equal(author, "Alice Doe <alice@example.com>")
})

test_that("get_git_config_author errors when multiple user.name or user.email entries found", {
  settings <- data.frame(
    name = c("user.name", "user.name", "user.email"),
    value = c("Alice", "Bob", "alice@example.com"),
    level = c("global", "global", "global"),
    stringsAsFactors = FALSE
  )

  expect_error(
    get_git_config_author(settings),
    "Multiple user names or emails found"
  )
})

test_that("get_git_config_author errors when either user.name or user.email is missing", {
  settings <- data.frame(
    name = c("user.email"),
    value = c("alice@example.com"),
    level = c("global"),
    stringsAsFactors = FALSE
  )

  expect_error(
    get_git_config_author(settings),
    "Please set git global configs"
  )

  settings2 <- data.frame(
    name = c("user.name"),
    value = c("Alice"),
    level = c("global"),
    stringsAsFactors = FALSE
  )

  expect_error(
    get_git_config_author(settings2),
    "Please set git global configs"
  )
})

test_that("get_git_config_author warns when user.name or user.email are empty strings", {
  settings <- data.frame(
    name = c("user.name", "user.email"),
    value = c("", ""),
    level = c("global", "global"),
    stringsAsFactors = FALSE
  )

  expect_warning(
    get_git_config_author(settings),
    "No default git user or email configuration set up"
  )
})
