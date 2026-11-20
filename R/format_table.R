#' Formats data frames to a tblkit table
#'
#' @description The tblkit counterpart of [format_flextable()]: gives a table
#' the look `format_flextable()` gives a flextable. Arial Narrow 10 pt, a bold
#' header, every cell left aligned, a 1 pt line on every cell edge, 1 pt
#' padding above and below, and the table centered on the page. Numbers are not
#' formatted: format them in the data, or with [tblkit::tk_format()] on the
#' result.
#'
#' A data frame becomes a [tblkit::tk()] table with every column a plain
#' column (no stub), and its columns are measured from their content and
#' scaled so the table is 6 inches wide with [fit_table_to_page()]. A
#' tblkit table keeps its own structure, formats, styles and column widths
#' (set them with [tblkit::tk_layout()]), and takes the look's theme.
#' `add_tables()` calls this for every data frame it inserts.
#'
#' @param data_in The input data to be formatted. Must be either a data frame or a tblkit table ([tblkit::tk()]).
#'
#' @export
#'
#' @return A tblkit table (`tblkit_spec`).
#'
#' @examples \dontrun{
#' dt <- head(iris, 10)
#' format_table(
#'   data_in = dt
#' )
#' }
format_table <- function(data_in) {
  log4r::debug(.le$logger, "Starting format_table function")

  assertthat::assert_that(
    is.data.frame(data_in) || inherits(data_in, "tblkit_spec"),
    msg = "'data_in' must be either a data frame or a tblkit table"
  )

  from_data_frame <- is.data.frame(data_in)
  if (from_data_frame) {
    log4r::info(
      .le$logger,
      "Input data is not a tblkit table, converting to tblkit table"
    )
    # stub = character(): every column plain, and no message from tk()
    # naming the row-label columns it guessed
    data_in <- tblkit::tk(data_in, stub = character())
  }

  line <- tblkit::tk_stroke(1)
  tbl_out <- tblkit::tk_theme(
    data_in,
    font_family = "Arial Narrow",
    font_size = 10,
    header_bold = TRUE,
    header_align = "left",
    stub_align = "left",
    value_align = "left",
    padding = c(top = 1, bottom = 1, left = 5, right = 5),
    border_table_top = line,
    border_table_bottom = line,
    border_table_left = line,
    border_table_right = line,
    border_header_bottom = line,
    border_inner_h = line,
    border_inner_v = line,
    border_stub_right = line,
    group_rule = line
  ) |>
    tblkit::tk_layout(page_alignment = "center")

  if (from_data_frame) {
    tbl_out <- fit_table_to_page(tbl_out)
  }

  log4r::debug(.le$logger, "Exiting format_table function")
  tbl_out
}
