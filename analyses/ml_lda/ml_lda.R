# Linear discriminant analysis (MASS)

codegen_ml_lda <- function(o, meta, ctx) {
  s <- sn_ml_setup(o, meta, ctx, "classification")
  e <- ctx$plot_engine
  ytr <- sn_ref("train", s$y)
  fit <- c(
    paste0("fit <- MASS::lda(", s$formula, ", data = train", if (o$prior == "equal") paste0(", prior = rep(1 / nlevels(", ytr, "), nlevels(", ytr, "))"), ")"),
    "predict_fn <- function(newdata) predict(fit, newdata)$posterior",
    "discriminants <- fit$scaling                      # coefficients of the linear discriminants",
    "trace <- fit$svd^2 / sum(fit$svd^2)               # share of between-group variance per discriminant",
    "group_means <- fit$means")
  extra <- if (isTRUE(o$scores_plot)) c(
    "scores <- as.data.frame(predict(fit, train)$x)",
    paste0("scores$group <- ", ytr),
    if (s$n_classes > 2) sn_gg(e, "scores, aes(LD1, LD2, color = group)", "geom_point(size = 3, alpha = 0.8)", "Discriminant scores (training data)", "LD1", "LD2", "p_scores")
    else sn_gg(e, "scores, aes(group, LD1)", c("geom_boxplot()", "geom_jitter(width = 0.15, alpha = 0.6)"), "Discriminant scores (training data)", s$y, "LD1", "p_scores"))
  list(code = sn_ml_code(o, meta, ctx, s, "Linear discriminant analysis", fit, NULL, extra), assemble = function(env, o, ctx) {
    tr <- env$trace
    tables <- list(
      sn_tbl_matrix("discriminants", "Coefficients of Linear Discriminants", env$discriminants, "Predictor", digits = 4,
                    notes = paste0("Proportion of between-group variance: ", paste(sprintf("%s %.1f%%", colnames(env$discriminants), 100 * tr), collapse = ", "), ".")),
      sn_tbl_matrix("group_means", "Group Means (Training Data)", env$group_means, "Group", digits = 3))
    sn_ml_assemble(env, o, ctx, s, "linear discriminant analysis", list(tables = tables, plots = c(p_scores = "Discriminant scores")))
  })
}
