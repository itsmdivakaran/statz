# Support vector machine (e1071)

codegen_ml_svm <- function(o, meta, ctx) {
  s <- sn_ml_setup(o, meta, ctx)
  fit <- c(
    paste0("set.seed(", s$seed, ")   # class probabilities are fitted by internal cross-validation"),
    paste0("fit <- e1071::svm(", s$formula, ", data = train, kernel = ", sn_lit(o$kernel), ", cost = ", sn_lit(o$cost), if (s$cls) ", probability = TRUE", ")"),
    if (s$cls) paste0("predict_fn <- function(newdata) attr(predict(fit, newdata, probability = TRUE), \"probabilities\")[, levels(", sn_ref("train", s$y), "), drop = FALSE]")
    else "predict_fn <- function(newdata) as.numeric(predict(fit, newdata))")
  list(code = sn_ml_code(o, meta, ctx, s, "Support vector machine", fit), assemble = function(env, o, ctx) {
    f <- env$fit
    sn_ml_assemble(env, o, ctx, s, "support vector machine", list(tables = list(sn_tbl_wide("model", "Model",
      list(sn_col("kernel", "Kernel", "text"), sn_col("cost", "Cost", digits = 3), sn_col("gamma", "γ", digits = 4), sn_col("sv", "Support vectors", "int")),
      list(kernel = o$kernel, cost = f$cost, gamma = if (o$kernel == "linear") NA else f$gamma, sv = as.integer(f$tot.nSV))))))
  })
}
