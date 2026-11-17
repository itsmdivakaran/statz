# Bayesian one sample t-test (BayesFactor::ttestBF with mu)

codegen_bayes_ttest_one <- function(o, meta, ctx) {
  n <- length(o$dv)
  iv <- sn_bf_interval(o$alternative)
  blocks <- lapply(seq_len(n), function(i) {
    dv <- o$dv[[i]]
    s <- sn_suffix(i, n)
    d <- paste0("d", s)
    sn_bayes_t_code(o, ctx, s,
      prep = sn_code(
        paste0("# Bayesian one sample t-test: ", dv, " against ", o$mu,
               if (o$mu != 0) " (tested as x - test value against 0, so the posterior delta is relative to the test value)"),
        paste0(d, " <- subset(", ctx$data, ", !is.na(", sn_name(dv), "))"),
        if (o$descriptives) paste0("desc", s, " <- data.frame(variable = ", sn_lit(dv), ", n = nrow(", d, "), mean = mean(",
                                   sn_ref(d, dv), "), sd = sd(", sn_ref(d, dv), "))")),
      bf_call = function(data, r) paste0("ttestBF(x = ", sn_ref(data, dv), if (o$mu != 0) paste0(" - ", sn_lit(o$mu)),
                                       ", rscale = ", r, iv, ")"),
      min_ok = function(data) paste0("nrow(", data, ") >= 3 && sd(", sn_ref(data, dv), ") > 0"),
      title = dv)
  })
  list(code = sn_code(sn_libs(c("BayesFactor", if (length(o$plots)) ctx$plot_engine)), "",
                      paste(unlist(blocks), collapse = "\n\n")),
       assemble = assemble_bayes_ttest_one)
}

assemble_bayes_ttest_one <- function(env, o, ctx) {
  n <- length(o$dv)
  items <- lapply(seq_len(n), function(i) list(label = o$dv[[i]], s = sn_suffix(i, n)))
  desc <- if (o$descriptives) sn_tbl_simple_desc(do.call(rbind, lapply(items, function(it) sn_get(env, paste0("desc", it$s)))))
  dir <- switch(o$alternative, greater = "is above", less = "is below", "differs from")
  sn_bayes_t_assemble(env, o, ctx, items, "Bayesian One Sample T-Test",
    h1 = function(it) paste("the mean", dir, fmt_num(o$mu)),
    h0 = function(it) paste("the mean equals", fmt_num(o$mu)), desc_table = desc)
}
