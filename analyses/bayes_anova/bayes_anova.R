# Bayesian ANOVA (BayesFactor::anovaBF): model comparison and inclusion Bayes factors.
# A subject variable makes it a repeated-measures design (subject as a random factor).

codegen_bayes_anova <- function(o, meta, ctx) {
  dv <- o$dv; fs <- unlist(o$factors); subj <- unlist(o$subject)
  vars <- c(dv, fs, subj)
  rhs <- paste(c(paste(sn_name(fs), collapse = " * "), if (length(subj)) sn_name(subj)), collapse = " + ")
  which_models <- if (length(fs) == 1) "withmain" else o$models
  eng <- ctx$plot_engine
  code <- sn_code(
    sn_libs(c("BayesFactor", if (isTRUE(o$inclusion)) "bayestestR", if (o$plot != "none") eng)), "",
    paste0("# Bayesian ANOVA: ", dv, " by ", paste(fs, collapse = ", "), if (length(subj)) paste0(" (repeated measures within ", subj, ")")),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(vars), "]), ", sn_lit(vars), "]"),
    unlist(lapply(c(fs, subj), function(f) paste0(sn_ref("d", f), " <- factor(", sn_ref("d", f), ")"))),
    if (o$descriptives) sn_group_desc_code("desc", "d", dv, fs[1]),
    paste0("set.seed(", o$seed, ")"),
    paste0("bf <- anovaBF(", sn_name(dv), " ~ ", rhs, ", data = d,\n  whichModels = ", sn_lit(which_models),
           ", rscaleFixed = ", sn_bf_prior(o, "anova"),
           if (length(subj)) paste0(", whichRandom = ", sn_lit(subj)), ", progress = FALSE)"),
    sn_bf_models_code("bf"),
    if (isTRUE(o$inclusion))
      "inclusion <- bayesfactor_inclusion(bf)",
    if (isTRUE(o$estimates)) sn_code(
      "# Posterior estimates from the full model",
      paste0("full <- lmBF(", sn_name(dv), " ~ ", rhs, ", data = d, rscaleFixed = ", sn_bf_prior(o, "anova"),
             if (length(subj)) paste0(", whichRandom = ", sn_lit(subj)), ")"),
      "post <- posterior(full, iterations = 10000, progress = FALSE)"),
    sn_plot_code(eng, o$plot, "d", x = fs[1], y = dv, fill = if (length(fs) > 1) fs[2], obj = "p",
                 xlab = sn_label(meta, fs[1]), ylab = sn_label(meta, dv))
  )
  list(code = code, assemble = assemble_bayes_anova)
}

assemble_bayes_anova <- function(env, o, ctx) {
  m <- sn_bf_models(sn_get(env, "models"))
  inc <- sn_get(env, "inclusion")
  post <- sn_get(env, "post")
  subj <- unlist(o$subject)
  keep <- if (!is.null(post)) grep(paste0("^(mu|", paste(make.names(unlist(o$factors)), collapse = "|"), ")"),
                                   colnames(post), value = TRUE)
  if (length(subj)) keep <- keep[!startsWith(keep, paste0(make.names(subj), "-"))]
  best <- m[1, ]
  txt <- c(
    paste0("A Bayesian ANOVA compared ", nrow(m), " models for ", o$dv, " (fixed-effect prior scale r = ",
           fmt_num(sn_bf_prior_value(o, "anova"), 3), if (length(subj)) paste0("; ", subj, " as a random factor"), ")."),
    paste0("The best model is ", if (best$model == "Null model") "the null model" else paste0("'", best$model, "'"),
           " with posterior probability ", fmt_num(best$post, 3),
           if (best$model != "Null model") paste0(" and BF₁₀ = ", fmt_bf(best$bf10), " against the null model (",
                                                   sn_lcfirst(sn_bf_evidence(best$bf10)), ")"), "."),
    if (!is.null(inc)) paste0("Model-averaged inclusion Bayes factors: ",
      paste0(rownames(inc), " BF = ", fmt_bf(exp(inc$log_BF)), collapse = "; "), "."))
  p <- sn_get(env, "p")
  sn_result(
    tables = list(
      if (o$descriptives) sn_tbl_group_desc(list(list(var = o$dv, obj = sn_get(env, "desc")))),
      sn_tbl_bf_models(m, notes = if (length(subj)) paste0("All models include ", subj, " as a random factor; the null model contains only it.")),
      if (!is.null(inc)) sn_tbl_bf_inclusion(inc),
      if (!is.null(post)) sn_tbl_posterior(post[, keep, drop = FALSE], o$ci_level, title = "Posterior Estimates (full model)")),
    plots = if (!is.null(p)) list(ctx$plot(p, paste(o$dv, "by", unlist(o$factors)[1]))),
    interpretation = paste(txt, collapse = "\n\n"))
}
