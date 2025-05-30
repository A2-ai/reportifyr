#' Formats data frames to a flextable specification
#'
#' @param data_in The input data to be formatted. Must be either a data frame or a flextable object.
#' @param table1_format A boolean indicating whether to apply table1-style formatting. Default is `FALSE`.
#'
#' @export
#'
#' @return A formatted flextable
#'
#' @examples \dontrun{
#' dt <- head(iris, 10)
#' format_flextable(
#'   data_in = dt
#' )
#' }
format_flextable <- function(data_in, table1_format = FALSE) {
  log4r::debug(.le$logger, "Starting format_flextable function")

  assertthat::assert_that(
    is.data.frame(data_in) || inherits(data_in, "flextable"),
    msg = "'data_in' must be either a data frame or a flextable. If you are reading in a table1 table, pass table1_format = TRUE"
  )
  log4r::debug(.le$logger, "'data_in' is a data frame or flextable")

  assertthat::assert_that(
    is.logical(table1_format),
    msg = "'table1_format' must be TRUE or FALSE"
  )
  log4r::debug(.le$logger, "table1_format is validated as boolean")

  if (!table1_format) {
    log4r::info(
      .le$logger,
      "table1_format is FALSE, applying default formatting"
    )

    if (!inherits(data_in, "flextable")) {
      log4r::info(
        .le$logger,
        "Input data is not a flextable, converting to flextable"
      )

      ft_out <- flextable::qflextable(data_in) |>
        flextable::set_table_properties(layout = "autofit", width = 1) |>
        flextable::align(align = "left", part = "all") |>
        flextable::bold(bold = T, part = "header") |>
        flextable::border(border = officer::fp_border(), part = "all") |>
        flextable::font(fontname = "Arial Narrow", part = "all") |>
        flextable::fontsize(size = 10, part = "all") |>
        flextable::line_spacing(space = 1, part = "all") |>
        flextable::padding(padding.bottom = 1, padding.top = 1, part = "all")
    }

    if (inherits(data_in, "flextable")) {
      log4r::info(
        .le$logger,
        "Input data is already a flextable, applying formatting"
      )

      ft_out <- data_in |>
        flextable::set_table_properties(layout = "autofit", width = 1) |>
        flextable::align(align = "left", part = "all") |>
        flextable::bold(bold = T, part = "header") |>
        flextable::border(border = officer::fp_border(), part = "header") |>
        flextable::border(border = officer::fp_border(), part = "body") |>
        flextable::font(fontname = "Arial Narrow", part = "all") |>
        flextable::fontsize(size = 10, part = "all") |>
        flextable::line_spacing(space = 1, part = "all") |>
        flextable::padding(padding.bottom = 1, padding.top = 1, part = "all")
    }

    ft_out <- ft_out |> fit_flextable_to_page()
    log4r::debug(.le$logger, "Exiting format_flextable function")

    return(ft_out)
  } else {
    log4r::info(.le$logger, "table1_format is TRUE, applying table1 formatting")

    rownames(data_in) <- NULL

    data_in2 <- data_in
    colnames(data_in2)[2:ncol(data_in2)] <- paste(
      colnames(data_in)[-1],
      "\n",
      data_in[1, 2:ncol(data_in)]
    )
    data_in2 <- data_in2[-1, ]

    log4r::info(.le$logger, "Formatting flextable with table1 style")
    ft_out <- flextable::qflextable(data_in2) |>
      flextable::align(j = 2:ncol(data_in), align = "left", part = "body") |>
      flextable::align(j = 2:ncol(data_in), align = "left", part = "header") |>
      flextable::bold(
        i = substr(data_in2[, 1], start = 1, stop = 1) %in% c(letters, LETTERS),
        j = 1
      ) |>
      flextable::bold(bold = T, part = "header") |>
      flextable::border(border = officer::fp_border(), part = "all") |>
      flextable::font(fontname = "Arial Narrow", part = "all") |>
      flextable::fontsize(size = 10, part = "all") |>
      flextable::line_spacing(space = 1, part = "all") |>
      flextable::padding(padding.bottom = 1, padding.top = 1, part = "all")

    ft_out <- ft_out |> fit_flextable_to_page()

    log4r::debug(.le$logger, "Exiting format_flextable function")

    return(ft_out)
  }
}
