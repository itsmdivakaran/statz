# Lasso, ridge and elastic-net regression (glmnet)

codegen_ml_glmnet <- function(o, meta, ctx) {
  s <- sn_ml_setup(o, meta, ctx)
  e <- ctx$plot_engine
  alpha <- c(lasso = 1, elastic = 0.5, ridge = 0)[[o$penalty]]
  family <- if (!s$cls) "gaussian" else if (s$binary) "binomial" else "multinomial"
  lam <- paste0("lambda.", o$lambda)
  ytr <- sn_ref("train", s$y)
  fit <- c(
    "# glmnet needs a numeric matrix: dummy-code the categorical predictors",
    "design <- function(newdata) model.matrix(~ ., data = newdata[predictors])[, -1, drop = FALSE]",
    paste0("set.seed(", s$seed, ")"),
    paste0("cv <- glmnet::cv.glmnet(design(train), ", ytr, ", family = ", sn_lit(family), ", alpha = ", alpha, ", nfolds = ", as.integer(o$folds), ")"),
    paste0("lambda <- cv$", lam),
    "fit <- cv$glmnet.fit",
    if (s$cls && s$binary) c(
      "predict_fn <- function(newdata) {",
      "  p <- as.numeric(predict(fit, design(newdata), s = lambda, type = \"response\"))",
      paste0("  cbind(1 - p, p, deparse.level = 0) |> `colnames<-`(levels(", ytr, "))"),
      "}")
    else if (s$cls) "predict_fn <- function(newdata) predict(fit, design(newdata), s = lambda, type = \"response\")[, , 1]"
    else "predict_fn <- function(newdata) as.numeric(predict(fit, design(newdata), s = lambda))",
    if (family != "multinomial") c(
      "coefs <- as.matrix(coef(fit, s = lambda))[, 1]",
      "coef_tbl <- data.frame(term = names(coefs), estimate = unname(coefs))",
      "coef_tbl$standardized <- c(NA, coefs[-1] * apply(design(train), 2, sd))   # per SD of the predictor"),
    "cv_curve <- data.frame(log_lambda = log(cv$lambda), error = cv$cvm, lower = cv$cvlo, upper = cv$cvup, nonzero = cv$nzero)")
  extra <- if (isTRUE(o$cv_plot)) sn_gg(e, "cv_curve, aes(log_lambda, error, ymin = lower, ymax = upper)", c("geom_errorbar()", "geom_point()", sn_ref_line(e, "v", "log(lambda)")),
    "Cross-validated error by penalty", "log(λ)", "Cross-validated error", "p_cv")
  list(code = sn_ml_code(o, meta, ctx, s, c(lasso = "Lasso", elastic = "Elastic net", ridge = "Ridge")[[o$penalty]], fit, NULL, extra), assemble = function(env, o, ctx) {
    cv <- env$cv; ct <- sn_get(env, "coef_tbl")
    i <- which(cv$lambda == env$lambda)
    tables <- list(sn_tbl_wide("model", "Penalty", list(sn_col("alpha", "α", digits = 1), sn_col("lambda", "λ", digits = 4), sn_col("nonzero", "Non-zero coefficients", "int"), sn_col("cv", "Cross-validated error", digits = 4)),
      list(alpha = alpha, lambda = env$lambda, nonzero = as.integer(cv$nzero[i]), cv = cv$cvm[i])))
    if (!is.null(ct)) tables <- c(tables, list(sn_table("coefficients", "Coefficients", list(sn_col("term", "Term", "text"), sn_col("estimate", if (s$cls) "B (log odds)" else "B", digits = 4), sn_col("standardized", "Standardized", digits = 4)), ct,
      notes = c("Penalized estimates: no standard errors or p-values. A coefficient of 0 means the variable was dropped.", "Standardized = change per one SD of the predictor."))))
    sn_ml_assemble(env, o, ctx, s, paste0(c(lasso = "lasso", elastic = "elastic-net", ridge = "ridge")[[o$penalty]], " regression"), list(tables = tables, plots = c(p_cv = "Cross-validation curve")))
  })
}
