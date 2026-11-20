#' Fits a tblkit table to the page width
#'
#' @description The tblkit counterpart of [fit_flextable_to_page()]: scales the
#' table's column widths so the table is `page_width` inches wide. A table
#' without widths has its columns measured from their content (as
#' [flextable::autofit()] measures them); widths set with
#' [tblkit::tk_layout()] are scaled as they are. Widths are rounded down to
#' whole twips, so the total never passes `page_width`.
#'
#' Works for a table made from a data frame ([tblkit::tk()] on wide data),
#' with or without stub columns. A table built from long data is refused: set
#' its widths with [tblkit::tk_layout()].
#'
#' @param x A tblkit table ([tblkit::tk()]).
#' @param page_width The width of page in inches
#'
#' @return A tblkit table fit to page
#'
#' @export
#'
#' @examples \dontrun{
#' # Create a tblkit table and fit to default page width:
#' x <- tblkit::tk(iris, stub = character())
#' fit_table_to_page(x)
#'
#' # Create a tblkit table and specify page width to fit to:
#' fit_table_to_page(x, page_width = 6.5)
#' }
fit_table_to_page <- function(x, page_width = 6) {
  log4r::debug(.le$logger, "Starting fit_table_to_page function")

  assertthat::assert_that(
    inherits(x, "tblkit_spec"),
    msg = "'x' must be a tblkit table"
  )
  assertthat::assert_that(
    is.numeric(page_width) && length(page_width) == 1 && page_width > 0,
    msg = "'page_width' must be one positive number"
  )

  # The layout columns by name: the stub columns shown as columns, then the
  # value columns (wide data has one column key, ".col", whose values are the
  # data frame's value columns).
  keys <- tblkit::tk_keys(x)
  col_keys <- keys[keys$kind == "column", , drop = FALSE]
  if (nrow(col_keys) != 1 || !identical(col_keys$key, ".col")) {
    stop(
      "fit_table_to_page() needs a table made from wide data; ",
      "set the widths with tblkit::tk_layout()",
      call. = FALSE
    )
  }
  stub_shown <- keys$kind == "row" &
    keys$role %in% c("stub column", "group (merged stub column)")
  columns <- c(keys$key[stub_shown], col_keys$values[[1]])

  measured <- tblkit::tk_check(x)$widths_twips
  if (length(measured) != length(columns)) {
    stop(
      "fit_table_to_page(): the table has ", length(measured),
      " columns, but ", length(columns), " were named",
      call. = FALSE
    )
  }

  twips <- floor(measured * page_width * 1440 / sum(measured))
  log4r::info(.le$logger, "Adjusting table width based on page width")
  x <- tblkit::tk_layout(
    x,
    widths = stats::setNames(twips / 1440, columns),
    width_inches = page_width
  )

  log4r::debug(.le$logger, "Exiting fit_table_to_page function")
  x
}
