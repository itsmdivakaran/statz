# Adverse event incidence by treatment arm (one input row per event)

sn_parse_arm_n <- function(txt) {
  txt <- trimws(txt %||% "")
  if (!nzchar(txt)) return(NULL)
  parts <- strsplit(strsplit(txt, "[,;]")[[1]], "=", fixed = TRUE)
  ok <- vapply(parts, function(p) length(p) == 2 && !is.na(suppressWarnings(as.numeric(p[2]))), TRUE)
  if (!all(ok)) sn_abort("Write the subjects per arm as Name=number, separated by commas, for example: Placebo=85, Drug=84.", SN_ERR$invalid_options, data = list(option = "arm_n"))
  stats::setNames(vapply(parts, function(p) as.numeric(p[2]), 0), vapply(parts, function(p) trimws(p[1]), ""))
}

codegen_clin_ae <- function(o, meta, ctx) {
  id <- o$subject; arm <- o$arm; term <- o$term; soc <- o$soc; sev <- o$severity
  n <- sn_parse_arm_n(o$arm_n)
  if (!is.null(n)) {
    extra <- setdiff(ctx$values(arm), names(n))
    if (length(extra)) sn_abort(paste0("These arms are in the data but not in 'Subjects per arm': ", paste(extra, collapse = ", "), "."),
                                SN_ERR$invalid_options, data = list(option = "arm_n"))
  }
  e <- ctx$plot_engine
  D <- function(v) sn_ref("ae", v)
  code <- sn_code(
    if (o$plot == "heatmap") sn_libs(e),
    "",
    paste0("# Adverse events by ", arm, ": subjects are counted once per event term"),
    paste0("ae <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(c(id, arm, term)), "]), , drop = FALSE]"),
    if (!is.null(n)) c(
      paste0("arm_n <- ", sn_lit(n), "   # subjects treated in each arm (the denominators)"),
      paste0("names(arm_n) <- ", sn_lit(names(n))),
      "arms <- names(arm_n)")
    else c(
      paste0("arms <- sort(unique(as.character(", D(arm), ")))"),
      paste0("arm_n <- sapply(arms, function(a) length(unique(", D(id), "[", D(arm), " == a])))   # no arm sizes given: subjects with at least one event")),
    paste0("count_subjects <- function(rows) sapply(arms, function(a) length(unique(rows[[", sn_lit(id), "]][rows[[", sn_lit(arm), "]] == a])))"),
    "any_event <- count_subjects(ae)",
    paste0("n_events <- sapply(arms, function(a) sum(", D(arm), " == a))"),
    paste0("by_term <- do.call(rbind, lapply(split(ae, ", D(term), "), count_subjects))"),
    if (length(soc)) c(
      paste0("by_soc <- do.call(rbind, lapply(split(ae, ", D(soc), "), count_subjects))"),
      paste0("term_soc <- tapply(as.character(", D(soc), "), ", D(term), ", function(s) s[1])")),
    if (length(sev)) c(
      "# Each subject's worst severity",
      paste0("sev_levels <- ", sn_lit(sn_severity_levels(meta, sev, ctx))),
      paste0("worst <- aggregate(match(as.character(", D(sev), "), sev_levels), list(subject = ", D(id), ", arm = ", D(arm), "), max)"),
      "by_severity <- do.call(rbind, lapply(seq_along(sev_levels), function(i) sapply(arms, function(a) sum(worst$x == i & worst$arm == a))))",
      "rownames(by_severity) <- sev_levels"),
    "pct_term <- 100 * sweep(by_term, 2, arm_n, \"/\")",
    if (o$compare) c(
      paste0("# Risk difference (percentage points) versus the first arm, Wald ", sn_pct(o$conf_level)),
      paste0("z <- qnorm(1 - (1 - ", sn_lit(o$conf_level), ") / 2)"),
      "risk_diff <- lapply(arms[-1], function(a) {",
      "  p1 <- by_term[, a] / arm_n[a]; p0 <- by_term[, 1] / arm_n[1]",
      "  se <- sqrt(p1 * (1 - p1) / arm_n[a] + p0 * (1 - p0) / arm_n[1])",
      "  100 * cbind(estimate = p1 - p0, lower = p1 - p0 - z * se, upper = p1 - p0 + z * se)",
      "})",
      "names(risk_diff) <- arms[-1]"),
    if (o$plot == "heatmap") c(
      "top <- names(sort(rowSums(by_term), decreasing = TRUE))[seq_len(min(nrow(by_term), 15))]",
      "heat_df <- data.frame(arm = factor(rep(arms, each = length(top)), levels = arms), term = factor(rep(top, length(arms)), levels = rev(top)),",
      "                      pct = round(as.vector(pct_term[top, arms]), 1))",
      if (e == "ggnext") c(
        "# Short term codes on the axis (ggnext clips long axis labels); the table lists the full terms",
        "heat_df$term <- factor(abbreviate(as.character(heat_df$term), 9), levels = abbreviate(rev(top), 9))",
        sn_gg(e, "heat_df, aes(arm, term, size = pct)", "geom_ae_heatmap()", "Adverse event incidence (%)", arm, ""),
        "p <- p + labs(color = \"% of subjects\")")
      else sn_gg(e, "heat_df, aes(arm, term, fill = pct)", c("geom_tile()", "geom_text(aes(label = pct))", "scale_fill_gradient(low = \"#F2F0EA\", high = \"#C1462F\")"),
                 "Adverse event incidence (%)", arm, ""))
  )
  list(code = code, assemble = assemble_clin_ae)
}

#' Severity levels in increasing order: value labels, a recognised scale, or sorted values.
sn_severity_levels <- function(meta, sev, ctx) {
  vl <- meta$variables[[sev]]$value_labels
  if (length(vl)) return(vapply(vl, function(v) as.character(v$value), ""))
  c("MILD", "MODERATE", "SEVERE", "LIFE THREATENING", "FATAL")
}

assemble_clin_ae <- function(env, o, ctx) {
  arms <- env$arms; n <- env$arm_n
  if (anyNA(n) || any(n <= 0)) sn_abort("Give a positive number of subjects for every arm.", SN_ERR$invalid_options, data = list(option = "arm_n"))
  if (any(env$any_event > n)) sn_abort("An arm has more subjects with events than subjects in 'Subjects per arm'.", SN_ERR$invalid_options, data = list(option = "arm_n"))
  cell <- function(x, a) sprintf("%d (%.1f%%)", as.integer(x), 100 * x / n[[a]])
  ids <- paste0("a", seq_along(arms))
  mk <- function(label, counts, fmt = TRUE) {
    r <- data.frame(event = label, stringsAsFactors = FALSE)
    for (i in seq_along(arms)) r[[ids[i]]] <- if (is.null(counts)) "" else if (fmt) cell(counts[[i]], arms[i]) else as.character(counts[[i]])
    r
  }
  cols <- c(list(sn_col("event", "", "text")), lapply(seq_along(arms), function(i) sn_col(ids[i], sprintf("%s (N = %d)", arms[i], as.integer(n[[i]])), "text")))
  ov <- list(mk("Subjects with any adverse event", env$any_event), mk("Number of events", env$n_events, FALSE))
  bs <- sn_get(env, "by_severity")
  if (!is.null(bs)) { bs <- bs[rowSums(bs) > 0, , drop = FALSE]; ov <- c(ov, list(mk("Worst severity", NULL)), lapply(rownames(bs), function(s) mk(paste0("   ", s), bs[s, ]))) }
  bt <- env$by_term; pt <- env$pct_term
  keep <- rownames(bt)[apply(pt, 1, max) >= o$min_pct]
  ord <- function(m) rownames(m)[order(-rowSums(m), rownames(m))]
  rd <- sn_get(env, "risk_diff")
  rd_ids <- if (!is.null(rd)) paste0("rd", seq_along(rd)) else character()
  term_row <- function(t, indent) {
    r <- mk(paste0(indent, t), bt[t, ])
    for (j in seq_along(rd)) r[[rd_ids[j]]] <- I(list(unname(rd[[j]][t, 2:3])))
    for (j in seq_along(rd)) r[[paste0(rd_ids[j], "e")]] <- rd[[j]][t, 1]
    r
  }
  head_row <- function(label, counts) {
    r <- mk(label, counts)
    for (j in seq_along(rd)) { r[[rd_ids[j]]] <- I(list(c(NA_real_, NA_real_))); r[[paste0(rd_ids[j], "e")]] <- NA_real_ }
    r
  }
  rows <- list()
  bsoc <- sn_get(env, "by_soc")
  if (!is.null(bsoc)) {
    for (s in ord(bsoc)) {
      ts <- intersect(ord(bt), names(env$term_soc)[env$term_soc == s]); ts <- intersect(ts, keep)
      if (!length(ts)) next
      rows <- c(rows, list(head_row(s, bsoc[s, ])), lapply(ts, term_row, indent = "   "))
    }
  } else rows <- lapply(intersect(ord(bt), keep), term_row, indent = "")
  if (!length(rows)) sn_abort("No adverse event reaches the minimum percentage.", SN_ERR$invalid_options, data = list(option = "min_pct"))
  tcols <- cols
  for (j in seq_along(rd)) tcols <- c(tcols, list(sn_col(paste0(rd_ids[j], "e"), paste0(names(rd)[j], " − ", arms[1], " (%)"), digits = 1), sn_col(rd_ids[j], sn_pct(o$conf_level), "ci", 1)))
  tb <- do.call(rbind, rows)
  tb <- tb[, vapply(tcols, function(c) c$id, ""), drop = FALSE]
  tcols[[1]]$label <- if (!is.null(bsoc)) "System organ class / event" else "Event"
  given <- nzchar(trimws(o$arm_n %||% ""))
  tables <- list(
    sn_table("overview", "Overview of Adverse Events", cols, do.call(rbind, ov),
             notes = if (!given) "No arm sizes were given, so percentages use the subjects with at least one event as the denominator. Enter 'Subjects per arm' for true incidence."),
    sn_table("events", "Adverse Events by Arm", tcols, tb,
             notes = c("n (%) = subjects with at least one such event; a subject is counted once per row.",
                       if (o$min_pct > 0) sprintf("Events in at least %s%% of subjects in any arm.", format(o$min_pct)),
                       if (!is.null(rd)) "Risk differences are in percentage points with Wald confidence intervals; they are descriptive, not adjusted for multiple comparisons.")))
  top <- ord(bt)[1]
  text <- sprintf("At least one adverse event occurred in %s. The most common event was %s (%s).",
    paste(sprintf("%s on %s", vapply(seq_along(arms), function(i) cell(env$any_event[[i]], arms[i]), ""), arms), collapse = ", "), top,
    paste(sprintf("%s: %.1f%%", arms, pt[top, arms]), collapse = "; "))
  chk <- if (!given) list(sn_check("denominator", "Denominators", "warn", "Arm sizes were not entered; subjects without any event are missing from the denominators.")) else list()
  p <- sn_get(env, "p")
  sn_result(tables = tables, assumptions = chk, plots = list(if (!is.null(p)) ctx$plot(p, "Adverse event incidence")), interpretation = text)
}
