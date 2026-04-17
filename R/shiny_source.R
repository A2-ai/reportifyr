#' Build a structured `source` value for an artifact produced from a Shiny app
#'
#' @description Returns a structured named list suitable for the
#' `origin` argument of [rpfy_context()].
#'
#' @param app_name Character scalar. Name of the installed R package that
#'   is the Shiny app.
#'
#' @return A named list with `type`, `app_name`, and `app_version` elements.
#'
#' @export
#'
#' @examples \dontrun{
#' ctx <- rpfy_context(origin = shiny_source("myapp"))
#' ggsave_with_metadata(
#'   filename = "OUTPUTS/figures/plot.png",
#'   context = ctx
#' )
#' }
shiny_source <- function(app_name) {
  if (!is.character(app_name) || length(app_name) != 1L || !nzchar(app_name)) {
    stop("`app_name` must be a non-empty character scalar.")
  }

  app_version <- tryCatch(
    as.character(utils::packageVersion(app_name)),
    error = function(e) {
      stop(
        sprintf(
          paste0(
            "Could not resolve version for package '%s'. ",
            "`shiny_source()` requires the app to be installed as a ",
            "package. Underlying error: %s"
          ),
          app_name,
          conditionMessage(e)
        ),
        call. = FALSE
      )
    }
  )

  list(
    type = "shiny",
    app_name = app_name,
    app_version = app_version
  )
}
