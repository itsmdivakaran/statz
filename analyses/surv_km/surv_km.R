# Kaplan-Meier survival estimates, median survival and log-rank test

codegen_surv_km <- function(o, meta, ctx) {
  tm <- o$time; ev <- o$event; g <- o$group
  times <- suppressWarnings(as.numeric(strsplit(trimws(o$times %||% ""), "[,; ]+")[[1]]))
  if (anyNA(times)) sn_abort("Survival times must be numbers separated by commas.", SN_ERR$invalid_options, data = list(option = "times"))
  en <- sn_event_name(c(tm, g))
  surv <- paste0("Surv(", sn_name(tm), ", ", en, ") ~ ", if (length(g)) sn_name(g) else "1")
  eng <- ctx$plot_engine
  plot <- if (o$plot == "km") {
    if (eng == "ggnext") sn_gg(eng, paste0("d, aes(time = ", sn_name(tm), ", status = ", en, if (length(g)) paste0(", color = ", sn_name(g)), ")"),
      c(paste0("geom_km(conf_int = ", sn_lit(o$conf_band), ")"), if (o$risk_table) "geom_km_risktable()"),
      "Kaplan-Meier survival", sn_label(meta, tm), "Survival probability", "p_km")
    else c(
      paste0("km_df <- data.frame(time = km$time, surv = km$surv, lower = km$lower, upper = km$upper",
             if (length(g)) ", group = rep(sub(\"^[^=]*=\", \"\", names(km$strata)), km$strata)", ")"),
      sn_gg(eng, paste0("km_df, aes(time, surv", if (length(g)) ", color = group", ")"),
        c("geom_step()", if (o$conf_band) c("geom_step(aes(y = lower), linetype = 3)", "geom_step(aes(y = upper), linetype = 3)"), "ylim(0, 1)"),
        "Kaplan-Meier survival", sn_label(meta, tm), "Survival probability", "p_km"))
  }
  code <- sn_code(
    sn_libs(c("survival", if (o$plot == "km") eng)),
    "",
    paste0("# Kaplan-Meier survival: ", tm, if (length(g)) paste0(" by ", g)),
    sn_prep_code("d", ctx$data, c(tm, ev, g), meta, factors = g),
    sn_event_code("d", ev, o$event_level, en),
    paste0("km <- survfit(", surv, ", data = d, conf.int = ", sn_lit(o$conf_level), ")"),
    "km_summary <- summary(km)$table",
    if (length(times)) paste0("km_times <- summary(km, times = ", sn_lit(times), ", extend = TRUE)"),
    if (length(g) && o$logrank) c(
      paste0("logrank <- survdiff(", surv, ", data = d)"),
      "logrank_p <- pchisq(logrank$chisq, length(logrank$n) - 1, lower.tail = FALSE)"),
    plot
  )
  list(code = code, assemble = assemble_surv_km)
}

assemble_surv_km <- function(env, o, ctx) {
  s <- env$km_summary; g <- o$group
  if (is.null(dim(s))) s <- matrix(s, nrow = 1, dimnames = list("All", names(s)))
  grp <- sub("^[^=]*=", "", rownames(s))
  pct <- sn_pct(o$conf_level)
  ci <- function(i) lapply(seq_len(nrow(s)), function(r) unname(s[r, i]))
  rows <- data.frame(group = grp, n = as.integer(s[, "records"]), events = as.integer(s[, "events"]),
                     censored = as.integer(s[, "records"] - s[, "events"]), median = unname(s[, "median"]), row.names = NULL)
  rows$ci <- I(ci(8:9))
  tables <- list(sn_table("summary", "Survival Summary", list(sn_col("group", if (length(g)) g else "Group", "text"), sn_col("n", "N", "int"),
    sn_col("events", "Events", "int"), sn_col("censored", "Censored", "int"), sn_col("median", "Median survival", digits = 1), sn_col("ci", pct, "ci", 1)), rows,
    notes = if (anyNA(rows$median)) "Median survival is not reached when the curve stays above 50%."))
  kt <- sn_get(env, "km_times")
  if (!is.null(kt)) {
    tr <- data.frame(group = if (is.null(kt$strata)) "All" else sub("^[^=]*=", "", as.character(kt$strata)), time = kt$time,
                     risk = as.integer(kt$n.risk), surv = kt$surv, se = kt$std.err)
    tr$ci <- I(lapply(seq_along(kt$time), function(i) c(kt$lower[i], kt$upper[i])))
    tables <- c(tables, list(sn_table("times", "Survival at Selected Times", list(sn_col("group", if (length(g)) g else "Group", "text"),
      sn_col("time", "Time", digits = 0), sn_col("risk", "At risk", "int"), sn_col("surv", "Survival", digits = 3), sn_col("se", "SE", digits = 3), sn_col("ci", pct, "ci", 3)), tr)))
  }
  lr <- sn_get(env, "logrank")
  text <- paste0(sum(rows$events), " of ", sum(rows$n), " cases had the event. ",
    paste0(vapply(seq_len(nrow(rows)), function(i) paste0("Median survival", if (length(g)) paste0(" for ", rows$group[i]), " was ",
      if (is.na(rows$median[i])) "not reached" else fmt_num(rows$median[i], 1)), ""), collapse = "; "), ".")
  if (!is.null(lr)) {
    df <- length(lr$n) - 1
    tables <- c(tables, list(sn_table("logrank", "Log-Rank Test", list(sn_col("chi", "χ²"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue")),
      data.frame(chi = lr$chisq, df = as.integer(df), p = env$logrank_p))))
    text <- paste0(text, " Survival ", if (env$logrank_p < 0.05) "differed" else "did not differ significantly", " between groups, log-rank χ²(", df, ") = ",
      fmt_num(lr$chisq), ", ", apa_p(env$logrank_p), ".")
  }
  checks <- list(sn_check("events", "Number of events", if (min(rows$events) < 5) "warn" else "ok",
    if (min(rows$events) < 5) "A group has fewer than 5 events; its curve and median are imprecise." else "Each group has at least 5 events."))
  sn_result(tables = tables, assumptions = checks, plots = sn_plots(env, ctx, list(p_km = "Kaplan-Meier survival")), interpretation = text)
}
