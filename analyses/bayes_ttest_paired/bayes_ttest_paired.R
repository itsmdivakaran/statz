# Bayesian paired samples t-test (BayesFactor::ttestBF with paired = TRUE)

codegen_bayes_ttest_paired <- function(o, meta, ctx) {
  a <- o$var1; b <- o$var2
  iv <- sn_bf_interval(o$alternative)
  code <- sn_bayes_t_code(o, ctx, "",
    prep = sn_code(
      paste0("# Bayesian paired samples t-test: ", a, " vs ", b),
      paste0("d <- subset(", ctx$data, ", !is.na(", sn_name(a), ") & !is.na(", sn_name(b), "))"),
      if (o$descriptives) paste0("desc <- data.frame(variable = ", sn_lit(c(a, b, "Difference")), ",\n  n = nrow(d),\n",
        "  mean = c(mean(", sn_ref("d", a), "), mean(", sn_ref("d", b), "), mean(", sn_ref("d", a), " - ", sn_ref("d", b), ")),\n",
        "  sd = c(sd(", sn_ref("d", a), "), sd(", sn_ref("d", b), "), sd(", sn_ref("d", a), " - ", sn_ref("d", b), ")))")),
    bf_call = function(data, r) paste0("ttestBF(x = ", sn_ref(data, a), ", y = ", sn_ref(data, b),
                                       ", paired = TRUE, rscale = ", r, iv, ")"),
    min_ok = function(data) paste0("nrow(", data, ") >= 3 && sd(", sn_ref(data, a), " - ", sn_ref(data, b), ") > 0"),
    title = paste(a, "vs", b))
  list(code = sn_code(sn_libs(c("BayesFactor", if (length(o$plots)) ctx$plot_engine)), "", code),
       assemble = assemble_bayes_ttest_paired)
}

assemble_bayes_ttest_paired <- function(env, o, ctx) {
  label <- paste(o$var1, "−", o$var2)
  desc <- if (o$descriptives) sn_tbl_simple_desc(sn_get(env, "desc"))
  dir <- switch(o$alternative, greater = paste(o$var1, "is higher than", o$var2),
                less = paste(o$var1, "is lower than", o$var2), "the measures differ")
  sn_bayes_t_assemble(env, o, ctx, list(list(label = label, s = "")), "Bayesian Paired Samples T-Test",
    h1 = function(it) dir, h0 = function(it) "no difference", desc_table = desc)
}
