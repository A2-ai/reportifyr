test_that("get_git_info parses git log correctly", {
  fake_log <- paste(
    "commit def456",
    "Author: Bob <bob@example.com>",
    "Date:   Tue Apr 2 14:30:00 2024 +0000",
    "",
    "commit abc123",
    "Author: Alice <alice@example.com>",
    "Date:   Mon Apr 1 12:00:00 2024 +0000",
    sep = "\n"
  )

  mockery::stub(get_git_info, "processx::run", function(...) list(stdout = fake_log))

  result <- get_git_info("some/file.R")

  expect_equal(result$latest_author, "Bob <bob@example.com>")
  expect_equal(result$creation_author, "Alice <alice@example.com>")
  expect_match(result$latest_time, "2024-04-02 14:30:00")
  expect_match(result$creation_time, "2024-04-01 12:00:00")
})

test_that("get_git_info handles untracked file (empty log)", {
  mockery::stub(get_git_info, "processx::run", function(...) list(stdout = ""))

  result <- get_git_info("some/untracked_file.R")

  expect_equal(result$creation_author, "FILE NOT TRACKED BY GIT")
  expect_equal(result$latest_author, "FILE NOT TRACKED BY GIT")
  expect_equal(result$creation_time, "FILE NOT TRACKED BY GIT")
  expect_match(result$latest_time, "^\\d{4}-\\d{2}-\\d{2}")  # current time
})

test_that("get_git_info returns fallback values on error", {
  mockery::stub(get_git_info, "processx::run", function(...) stop("git not available"))

  result <- get_git_info("some/file.R")

  expect_equal(result$creation_author, "COULD NOT ACCESS GIT")
  expect_equal(result$latest_author, "COULD NOT ACCESS GIT")
  expect_equal(result$creation_time, "COULD NOT ACCESS GIT")
  expect_equal(result$latest_time, "COULD NOT ACCESS GIT")
})
