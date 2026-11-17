# Random forest (ranger)

codegen_ml_forest <- function(o, meta, ctx) {
  s <- sn_ml_setup(o, meta, ctx)
  fit <- c(
    paste0("fit <- ranger::ranger(", s$formula, ", data = train, num.trees = ", as.integer(o$num_trees),
           if (o$mtry > 0) paste0(", mtry = ", min(as.integer(o$mtry), length(s$predictors))), if (o$min_node_size > 0) paste0(", min.node.size = ", as.integer(o$min_node_size)),
           if (s$cls) ", probability = TRUE", if (isTRUE(o$importance)) ", importance = \"permutation\"", ", seed = ", s$seed, ")"),
    "predict_fn <- function(newdata) predict(fit, data = newdata)$predictions",
    "oob_error <- fit$prediction.error")
  imp <- "importance <- sort(fit$variable.importance, decreasing = TRUE)   # permutation importance on out-of-bag cases"
  list(code = sn_ml_code(o, meta, ctx, s, "Random forest", fit, imp), assemble = function(env, o, ctx) {
    f <- env$fit
    extra <- list(importance_note = "Permutation importance on out-of-bag cases (ranger).",
      tables = list(sn_tbl_wide("model", "Forest", list(sn_col("trees", "Trees", "int"), sn_col("mtry", "Predictors per split", "int"), sn_col("node", "Minimum node size", "int"),
        sn_col("oob", if (s$cls) "Out-of-bag Brier score" else "Out-of-bag MSE", digits = 4)), list(trees = f$num.trees, mtry = f$mtry, node = f$min.node.size, oob = env$oob_error))))
    sn_ml_assemble(env, o, ctx, s, "random forest", extra)
  })
}
