#' Autofits a flextable object, then fits the object to the page width
#'
#' @param ft A flextable object
#' @param page_width The width of page in inches
#'
#' @return A flextable object fit to page
#'
#' @keywords internal
#'
#' @examples \dontrun{
#' # Load libary for examples:
#' library(flextable)
#'
#' # Create a flextable object and fit to default page width:
#' ft <- flextable(iris)
#' fit_flextable_to_page(ft)
#'
#' # Create a flextable object and specify page width to fit to:
#' ft <- flextable(iris)
#' fit_flextable_to_page(ft, page_width = 6.5)
#' }
fit_flextable_to_page <- function(ft,
                                  page_width = 6) {
  log4r::debug(.le$logger, "Starting fit_flextable_to_page function")

  assertthat::assert_that(inherits(ft, "flextable"),
    msg = "'ft' must be a flextable object"
  )
  log4r::info(.le$logger, "ft passes flextable asseriton")

  ftout <- ft |> flextable::autofit()
  log4r::info(.le$logger, "Autofit applied to flextable")

  log4r::info(.le$logger, "Adjusting flextable width based on page width")
  ftout <- flextable::width(ftout, width = dim(ftout)$widths * page_width / (flextable::flextable_dim(ftout)$widths))

  log4r::debug(.le$logger, "Exiting fit_flextable_to_page function")
  return(ftout)
}
