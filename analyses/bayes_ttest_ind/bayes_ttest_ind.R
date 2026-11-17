# Bayesian independent samples t-test (BayesFactor::ttestBF, Cauchy prior on delta)

codegen_bayes_ttest_ind <- function(o, meta, ctx) {
  g <- o$group
  n <- length(o$dv)
  blocks <- lapply(seq_len(n), function(i) {
    dv <- o$dv[[i]]
    s <- sn_suffix(i, n)
    d <- paste0("d", s)
    f <- paste0(sn_name(dv), " ~ ", sn_name(g))
    iv <- sn_bf_interval(o$alternative)
    sn_bayes_t_code(o, ctx, s,
      prep = sn_code(
        paste0("# Bayesian independent samples t-test: ", dv, " by ", g),
        paste0(d, " <- subset(", ctx$data, ", !is.na(", sn_name(dv), ") & !is.na(", sn_name(g), "))"),
        sn_factor_code(d, g, meta),
        if (o$descriptives) sn_group_desc_code(paste0("desc", s), d, dv, g)),
      bf_call = function(data, r) paste0("ttestBF(formula = ", f, ", data = ", data, ", rscale = ", r, iv, ")"),
      min_ok = function(data) paste0("all(table(", sn_ref(data, g), ") >= 2)"),
      title = dv)
  })
  list(code = sn_code(sn_libs(c("BayesFactor", if (length(o$plots)) ctx$plot_engine)), "",
                      paste(unlist(blocks), collapse = "\n\n")),
       assemble = assemble_bayes_ttest_ind)
}

assemble_bayes_ttest_ind <- function(env, o, ctx) {
  n <- length(o$dv)
  items <- lapply(seq_len(n), function(i) list(label = o$dv[[i]], s = sn_suffix(i, n)))
  desc <- if (o$descriptives) sn_tbl_group_desc(lapply(items, function(it)
    list(var = it$label, obj = sn_get(env, paste0("desc", it$s)))))
  dir <- switch(o$alternative, greater = "higher in group 1", less = "lower in group 1", "different between the groups")
  sn_bayes_t_assemble(env, o, ctx, items, "Bayesian Independent Samples T-Test",
    h1 = function(it) paste0(it$label, " is ", dir),
    h0 = function(it) "no difference", desc_table = desc)
}
