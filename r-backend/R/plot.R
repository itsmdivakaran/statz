# Plots ------------------------------------------------------------------------
# ggnext is the primary engine. ggplot2 is used only when ggnext is unavailable
# or lacks a geom; such plots are flagged with `fallback = TRUE`.

#' Generate plot code. Returns NULL for type "none".
#' @param engine "ggnext" or "ggplot2"
#' @param x,y,fill variable names (unquoted in aes via sn_name)
sn_plot_code <- function(engine, type, df = "d", x = NULL, y = NULL, fill = NULL, title = NULL,
                         obj = "p", xlab = x, ylab = y) {
  if (is.null(type) || type == "none") return(NULL)
  if (type == "qq") { xlab <- "Theoretical quantiles"; ylab <- "Sample quantiles" }
  ctor <- if (engine == "ggnext") "ggnext" else "ggplot"
  X <- if (!is.null(x)) sn_name(x)
  Y <- if (!is.null(y)) sn_name(y)
  title <- title %||% (if (!is.null(y) && !is.null(x)) paste(y, "by", x) else x %||% y)
  labs <- paste0("labs(title = ", sn_lit(title),
                 if (!is.null(xlab)) paste0(", x = ", sn_lit(xlab)),
                 if (!is.null(ylab)) paste0(", y = ", sn_lit(ylab)) else if (type %in% c("histogram", "bar", "bar_dodge")) ", y = \"Count\"",
                 ")")
  layers <- switch(type,
    box_jitter = c(paste0(ctor, "(", df, ", aes(", X, ", ", Y, "))"),
                   "geom_boxplot()", "geom_jitter(width = 0.15, alpha = 0.7)"),
    violin = c(paste0(ctor, "(", df, ", aes(", X, ", ", Y, "))"),
               "geom_violin()", "geom_jitter(width = 0.1, alpha = 0.6)"),
    mean_ci = c(paste0(ctor, "(", df, "_ci, aes(", X, ", mean, ymin = lower, ymax = upper))"),
                "geom_pointrange()"),
    histogram = c(paste0(ctor, "(", df, ", aes(", X, "))"), "geom_histogram(bins = 20)"),
    bar = c(paste0(ctor, "(", df, ", aes(", X, "))"), "geom_bar()"),
    # ggnext maps bar colour via `color`; ggplot2 uses `fill`.
    bar_dodge = c(paste0(ctor, "(", df, ", aes(", X, if (engine == "ggnext") ", color = " else ", fill = ",
                         sn_name(fill), "))"),
                  "geom_bar(position = \"dodge\")"),
    qq = c(paste0(ctor, "(", df, ", aes(sample = ", X, "))"), "geom_qq()", "geom_qq_line()"),
    sn_abort(paste0("Unknown plot type: ", type), SN_ERR$invalid_options)
  )
  theme <- sn_plot_theme(engine)
  pre <- if (type == "mean_ci") sn_mean_ci_code(df, x, y) else NULL
  body <- paste(c(layers, labs, theme), collapse = " +\n  ")
  sn_code(pre, paste0(obj, " <- ", body))
}

#' Summary data for mean +/- 95% CI plots, in base R so the script stays standalone.
sn_mean_ci_code <- function(df, x, y) {
  paste0(
    df, "_ci <- do.call(rbind, lapply(split(", sn_ref(df, y), ", ", sn_ref(df, x), "), function(v) {\n",
    "  v <- v[!is.na(v)]; m <- mean(v); h <- qt(0.975, length(v) - 1) * sd(v) / sqrt(length(v))\n",
    "  data.frame(mean = m, lower = m - h, upper = m + h)\n",
    "}))\n",
    df, "_ci$", sn_name(x), " <- factor(rownames(", df, "_ci), levels = rownames(", df, "_ci))"
  )
}

#' Render a plot object to the session plot dir. Returns the plot descriptor.
sn_render_plot <- function(sess, p, title = NULL, fallback_reason = NULL) {
  if (is.null(p)) return(NULL)
  sess$plot_seq <- sess$plot_seq + 1L
  id <- paste0("plot", sess$plot_seq)
  dir <- file.path(sess$work_dir, "plots")
  svg <- file.path(dir, paste0(id, ".svg"))
  is_ggnext <- inherits(p, "ggnext::GgnextPlot") || inherits(p, "GgnextPlot") ||
    any(grepl("Ggnext", class(p)))
  out <- list(id = id, title = title %||% id, engine = if (is_ggnext) "ggnext" else "ggplot2",
              fallback = !is_ggnext, fallback_reason = fallback_reason,
              svg = svg, html = NULL, data_csv = NULL)
  if (is_ggnext) {
    ggnext::render(p, file = svg)
    html <- file.path(dir, paste0(id, ".html"))
    ggnext::render(p + ggnext::interact(), file = html)
    out$html <- html
    csv <- file.path(dir, paste0(id, ".csv"))
    try(ggnext::write_plot_data(p, csv), silent = TRUE)
    if (file.exists(csv)) out$data_csv <- csv
  } else {
    if (is.null(fallback_reason)) out$fallback_reason <- "ggnext is not installed"
    grDevices::svg(svg, width = 7, height = 5)
    on.exit(grDevices::dev.off(), add = TRUE)
    print(p)
  }
  sess$plots[[id]] <- out
  out
}

#' Export a rendered plot. PNG/PDF are converted from the SVG with rsvg.
sn_export_plot <- function(sess, plot_id, format = c("svg", "png", "pdf", "html", "csv"),
                           path, width = 1600L) {
  format <- match.arg(format)
  pl <- sess$plots[[plot_id]]
  if (is.null(pl)) sn_abort(paste0("Unknown plot: ", plot_id), SN_ERR$invalid_params)
  switch(format,
    svg = file.copy(pl$svg, path, overwrite = TRUE),
    html = if (is.null(pl$html)) sn_abort("This plot has no interactive version.", SN_ERR$invalid_params)
           else file.copy(pl$html, path, overwrite = TRUE),
    csv = if (is.null(pl$data_csv)) sn_abort("Plot data is not available.", SN_ERR$invalid_params)
          else file.copy(pl$data_csv, path, overwrite = TRUE),
    png = {
      if (!requireNamespace("rsvg", quietly = TRUE)) sn_abort("Package 'rsvg' is needed for PNG export.", SN_ERR$missing_package)
      rsvg::rsvg_png(pl$svg, path, width = as.integer(width))
    },
    pdf = {
      if (!requireNamespace("rsvg", quietly = TRUE)) sn_abort("Package 'rsvg' is needed for PDF export.", SN_ERR$missing_package)
      rsvg::rsvg_pdf(pl$svg, path)
    }
  )
  list(path = normalizePath(path, winslash = "/"))
}

#' Theme call for the engine: ggnext's modern theme, or the closest ggplot2 equivalent.
sn_plot_theme <- function(engine) if (engine == "ggnext") "theme_modern()" else "theme_minimal()"
