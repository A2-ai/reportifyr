local({
	rv_info <- system2("rv", c("info", "--library", "--r-version", "--repositories"), stdout = TRUE)
	if (!is.null(attr(rv_info, "status"))) {
		# if system2 fails it'll add a status attribute with the error code
		warning("failed to run rv info, check your console for messages")
	} else {
		# extract library, r-version, and repositories from rv
		rv_lib <- sub("library: (.+)", "\\1", grep("^library:", rv_info, value = TRUE))
		rv_r_ver <- sub("r-version: (.+)", "\\1", grep("^r-version:", rv_info, value = TRUE))
		repo_str <- sub("repositories: ", "", grep("^repositories:", rv_info, value = TRUE))
		repo_entries <- gsub("[()]", "", strsplit(repo_str, "), (", fixed = TRUE)[[1]])
    repo_list <- trimws(sub(".*, ", "", repo_entries))  # Extract URL
    names(repo_list) <- trimws(sub(", .*", "", repo_entries))   # Extract Name
		# this might not yet exist, so we'll normalize it but not force it to exist
		# and we create it below as needed
		rv_lib <- normalizePath(rv_lib, mustWork = FALSE)
		if (!dir.exists(rv_lib)) {
			message("creating rv library: ", rv_lib)
			dir.create(rv_lib, recursive = TRUE)
		}
		.libPaths(rv_lib, include.site = FALSE)
		options(repos = repo_list)

		if (interactive()) {
			message("rv libpaths active!\nlibrary paths: \n", paste0("  ", .libPaths(), collapse = "\n"), "\n")
			message("rv repositories active!\nrepositories: \n", paste0("  ", names(getOption("repos")), ": ", getOption("repos"), collapse = "\n"))
			sys_r <- sprintf("%s.%s", R.version$major, R.version$minor)
			if (!grepl(paste0("^", rv_r_ver), sys_r)) {
				message(sprintf("\nWARNING: R version specified in config (%s) does not match session version (%s)", rv_r_ver, sys_r))
		}
	}
	}
})
