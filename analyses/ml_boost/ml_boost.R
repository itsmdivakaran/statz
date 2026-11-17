# Gradient boosting (gbm)

codegen_ml_boost <- function(o, meta, ctx) {
  s <- sn_ml_setup(o, meta, ctx)
  if (s$cls && !s$binary) sn_abort("Gradient boosting here needs a two-class or numeric outcome. Use a random forest for more classes.",
                                   SN_ERR$invalid_options, data = list(role = "outcome", variable = s$y, reason = "levels"))
  e <- ctx$plot_engine
  args <- paste0("n.trees = ", as.integer(o$n_trees), ", interaction.depth = ", as.integer(o$depth), ", shrinkage = ", sn_lit(o$shrinkage),
                 ", n.minobsinnode = ", as.integer(o$min_obs), ", cv.folds = ", as.integer(o$cv_folds), ", n.cores = 1")
  fit <- c(
    if (s$cls) c(
      "train_gbm <- train",
      paste0(sn_ref("train_gbm", s$y), " <- as.integer(", sn_ref("train", s$y), " == levels(", sn_ref("train", s$y), ")[2])   # gbm needs a 0/1 outcome")),
    paste0("set.seed(", s$seed, ")"),
    paste0("fit <- gbm::gbm(", s$formula, ", data = ", if (s$cls) "train_gbm" else "train", ", distribution = ", sn_lit(if (s$cls) "bernoulli" else "gaussian"), ", ", args, ")"),
    "best_trees <- gbm::gbm.perf(fit, method = \"cv\", plot.it = FALSE)   # number of trees with the lowest cross-validated error",
    if (s$cls) c(
      "predict_fn <- function(newdata) {",
      "  p <- predict(fit, newdata, n.trees = best_trees, type = \"response\")",
      paste0("  cbind(1 - p, p, deparse.level = 0) |> `colnames<-`(levels(", sn_ref("train", s$y), "))"),
      "}")
    else "predict_fn <- function(newdata) predict(fit, newdata, n.trees = best_trees, type = \"response\")")
  imp <- c("rel_inf <- summary(fit, n.trees = best_trees, plotit = FALSE)", "importance <- setNames(rel_inf$rel.inf, rel_inf$var)   # relative influence, sums to 100")
  extra <- c(
    "cv_curve <- data.frame(trees = seq_along(fit$cv.error), error = fit$cv.error)",
    if ("performance" %in% unlist(o$plot)) sn_gg(e, "cv_curve, aes(trees, error)", c("geom_line()", sn_ref_line(e, "v", "best_trees")), "Cross-validated error by number of trees", "Trees", "Cross-validated error", "p_cv"))
  list(code = sn_ml_code(o, meta, ctx, s, "Gradient boosting", fit, imp, extra), assemble = function(env, o, ctx) {
    extra <- list(importance_note = "Relative influence of each predictor (sums to 100).", plots = c(p_cv = "Cross-validation curve"),
      tables = list(sn_tbl_wide("model", "Boosting", list(sn_col("best", "Trees used", "int"), sn_col("max", "Trees fitted", "int"), sn_col("depth", "Depth", "int"), sn_col("shrinkage", "Learning rate", digits = 3),
        sn_col("cv", "Lowest CV error", digits = 4)), list(best = as.integer(env$best_trees), max = as.integer(o$n_trees), depth = as.integer(o$depth), shrinkage = o$shrinkage, cv = min(env$fit$cv.error)))))
    res <- sn_ml_assemble(env, o, ctx, s, "gradient boosting model", extra)
    if (env$best_trees >= o$n_trees) res$assumptions <- c(res$assumptions, list(sn_check("trees", "Number of trees", "warn",
      "The cross-validated error was still falling at the last tree; raise the maximum number of trees or the learning rate.")))
    res
  })
}
