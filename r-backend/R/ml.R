# Helpers shared by the machine-learning modules ----
# Every learner supplies code that defines `fit` and `predict_fn(newdata)`:
# a matrix of class probabilities (classification) or a numeric vector (regression).

#' Task, outcome and predictors for a learner. `tasks` limits what the learner supports.
sn_ml_setup <- function(o, meta, ctx, tasks = c("classification", "regression")) {
  y <- o$outcome
  sn_need_predictors(o)
  task <- o$task %||% "auto"
  if (task == "auto") task <- if (identical(meta$variables[[y]]$measure, "continuous")) "regression" else "classification"
  if (!task %in% tasks) sn_abort(paste0("This method needs a ", if (tasks[1] == "classification") "categorical" else "numeric", " outcome."),
                                 SN_ERR$invalid_options, data = list(role = "outcome", variable = y, reason = "measure"))
  k <- if (task == "classification") ctx$n_distinct(y) else NA
  if (task == "classification" && (k < 2 || k > 30))
    sn_abort(paste0("'", y, "' has ", k, " distinct values; a classification outcome needs between 2 and 30 classes."),
             SN_ERR$invalid_options, data = list(role = "outcome", variable = y, reason = "levels"))
  list(task = task, cls = task == "classification", y = y, yq = sn_name(y), predictors = c(unlist(o$covariates), unlist(o$factors)),
       n_classes = k, binary = isTRUE(k == 2), formula = paste0(sn_name(y), " ~ ."), seed = as.integer(o$seed))
}

#' Full analysis code around a learner's `fit` code.
#' @param native_imp code that sets `importance` (named numeric); NULL = permutation importance.
sn_ml_code <- function(o, meta, ctx, s, label, fit, native_imp = NULL, extra = NULL) {
  e <- ctx$plot_engine; y <- s$y
  ty <- sn_ref("test", y); try_ <- sn_ref("train", y)
  want_imp <- isTRUE(o$importance)
  want_shap <- isTRUE(o$shap) && (!s$cls || s$binary)
  plots <- unlist(o$plot)
  sn_code(
    if (length(plots) || want_shap) sn_libs(e),
    "",
    paste0("# ", label, " (", s$task, "): ", y, " ~ ", paste(s$predictors, collapse = " + ")),
    paste0("predictors <- ", sn_lit(s$predictors)),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, c(", sn_lit(y), ", predictors)]), c(", sn_lit(y), ", predictors), drop = FALSE]"),
    vapply(unlist(o$factors), function(v) sn_factor_code("d", v, meta), ""),
    if (s$cls) c(sn_factor_code("d", y, meta), paste0(sn_ref("d", y), " <- droplevels(", sn_ref("d", y), ")")),
    "",
    paste0("# Hold out ", o$test_size, "% of the cases to test the model"),
    paste0("set.seed(", s$seed, ")"),
    paste0("test_rows <- sample(nrow(d), round(", sn_lit(o$test_size / 100), " * nrow(d)))"),
    "train <- d[-test_rows, , drop = FALSE]",
    "test <- d[test_rows, , drop = FALSE]",
    "",
    fit,
    "",
    "# Performance on the held-out test set",
    if (s$cls) c(
      paste0("classes <- levels(", try_, ")"),
      "prob <- predict_fn(test)",
      "pred <- factor(colnames(prob)[apply(prob, 1, which.max)], levels = classes)",
      paste0("confusion <- table(Predicted = pred, Actual = ", ty, ")"),
      "n_test <- sum(confusion)",
      "accuracy <- c(sum(diag(confusion)) / n_test, binom.test(sum(diag(confusion)), n_test)$conf.int)",
      "chance <- sum(rowSums(confusion) * colSums(confusion)) / n_test^2",
      "kappa <- (accuracy[1] - chance) / (1 - chance)",
      "no_information_rate <- max(colSums(confusion)) / n_test",
      "by_class <- data.frame(class = classes, sensitivity = diag(confusion) / colSums(confusion),",
      "                       specificity = (n_test - rowSums(confusion) - colSums(confusion) + diag(confusion)) / (n_test - colSums(confusion)),",
      "                       precision = diag(confusion) / rowSums(confusion))",
      "by_class$f1 <- 2 * by_class$precision * by_class$sensitivity / (by_class$precision + by_class$sensitivity)",
      paste0("train_accuracy <- mean(colnames(prob)[apply(predict_fn(train), 1, which.max)] == ", try_, ")"),
      if (s$binary) c(
        paste0("roc_obj <- pROC::roc(", ty, ", prob[, classes[2]], levels = classes, direction = \"<\", quiet = TRUE)"),
        "auc <- c(pROC::auc(roc_obj), pROC::ci.auc(roc_obj)[c(1, 3)])"))
    else c(
      "pred <- predict_fn(test)",
      paste0("rmse <- sqrt(mean((", ty, " - pred)^2))"),
      paste0("mae <- mean(abs(", ty, " - pred))"),
      paste0("r2 <- 1 - sum((", ty, " - pred)^2) / sum((", ty, " - mean(", ty, "))^2)"),
      paste0("train_rmse <- sqrt(mean((", try_, " - predict_fn(train))^2))")),
    if (want_imp) c(
      "",
      if (!is.null(native_imp)) native_imp else c(
        paste0("# Permutation importance: ", if (s$cls) "loss of test accuracy" else "rise in test RMSE", " when one predictor is shuffled (mean of 10 shuffles)"),
        if (s$cls) paste0("score <- function(data) mean(colnames(prob)[apply(predict_fn(data), 1, which.max)] == ", sn_ref("data", y), ")")
        else paste0("score <- function(data) -sqrt(mean((", sn_ref("data", y), " - predict_fn(data))^2))"),
        paste0("set.seed(", s$seed, ")"),
        "importance <- sapply(predictors, function(v) mean(replicate(10, {",
        "  shuffled <- test",
        "  shuffled[[v]] <- sample(shuffled[[v]])",
        "  score(test) - score(shuffled)",
        "})))",
        "importance <- sort(importance, decreasing = TRUE)")),
    if (want_shap) c(
      "",
      "# SHAP values by Monte Carlo sampling (Strumbelj & Kononenko, 2014): how much each predictor",
      "# moves each test-set prediction away from the average prediction",
      if (s$cls) "shap_fn <- function(newdata) predict_fn(newdata)[, classes[2]]   # probability of the second class" else "shap_fn <- predict_fn",
      "explain <- test[seq_len(min(nrow(test), 200)), predictors, drop = FALSE]",
      "n_sim <- 30",
      "shap <- matrix(0, nrow(explain), length(predictors), dimnames = list(NULL, predictors))",
      paste0("set.seed(", s$seed, ")"),
      "for (i in seq_len(n_sim)) {",
      "  current <- train[sample(nrow(train), nrow(explain), replace = TRUE), predictors, drop = FALSE]   # background cases",
      "  before <- shap_fn(current)",
      "  for (v in sample(predictors)) {",
      "    current[[v]] <- explain[[v]]",
      "    after <- shap_fn(current)",
      "    shap[, v] <- shap[, v] + (after - before) / n_sim",
      "    before <- after",
      "  }",
      "}",
      "shap_importance <- sort(colMeans(abs(shap)), decreasing = TRUE)"),
    extra,
    if ("importance" %in% plots && want_imp) c(
      "importance_df <- data.frame(variable = names(importance), importance = as.numeric(importance))[seq_len(min(length(importance), 20)), ]",
      "importance_df$variable <- factor(importance_df$variable, levels = rev(importance_df$variable))",
      if (e == "ggnext") c(
        sn_ylabels_code("importance_df", "variable", "min(0, importance_df$importance)", "max(importance_df$importance)"),
        paste0("p_importance <- ", paste(c("ggnext(importance_df, aes(importance, variable))", "geom_importance()", sn_ylabels_layer("variable"),
               "labs(title = \"Variable importance\", x = \"Importance\")", sn_ylabels_theme()), collapse = " +\n  ")))
      else sn_gg(e, "importance_df, aes(variable, importance)", c("geom_col()", "coord_flip()"), "Variable importance", "", "Importance", "p_importance")),
    if ("performance" %in% plots) {
      if (s$cls && s$binary) {
        if (e == "ggnext") c(
          paste0("roc_df <- data.frame(truth = as.integer(", ty, " == classes[2]), score = prob[, classes[2]])"),
          sn_gg(e, "roc_df, aes(truth = truth, score = score)", "geom_roc()", "ROC curve (test set)", "1 − Specificity", "Sensitivity", "p_performance"))
        else c(
          "roc_df <- data.frame(fpr = 1 - roc_obj$specificities, tpr = roc_obj$sensitivities)",
          "roc_df <- roc_df[order(roc_df$fpr, roc_df$tpr), ]",
          sn_gg(e, "roc_df, aes(fpr, tpr)", c("geom_path()", sn_ref_line(e, "ab", c(0, 1))), "ROC curve (test set)", "1 − Specificity", "Sensitivity", "p_performance"))
      } else if (s$cls) {
        if (e == "ggnext") c(
          paste0("confusion_df <- data.frame(predicted = pred, actual = ", ty, ")"),
          sn_gg(e, "confusion_df, aes(predicted, actual)", "geom_confusion_matrix()", "Confusion matrix (test set)", "Predicted", "Actual", "p_performance"),
          "p_performance <- p_performance + labs(color = \"Share of actual\")")
        else c(
          "confusion_df <- as.data.frame(confusion)",
          sn_gg(e, "confusion_df, aes(Predicted, Actual, fill = Freq)", c("geom_tile()", "geom_text(aes(label = Freq))", "scale_fill_gradient(low = \"#F2F0EA\", high = \"#12A594\")"),
                "Confusion matrix (test set)", "Predicted", "Actual", "p_performance"))
      } else c(
        paste0("fit_df <- data.frame(observed = ", ty, ", predicted = pred)"),
        sn_gg(e, "fit_df, aes(predicted, observed)", c("geom_point(alpha = 0.7)", sn_ref_line(e, "ab", c(0, 1))), "Observed vs predicted (test set)", "Predicted", "Observed", "p_performance"))
    },
    if (want_shap) c(
      "shap_long <- do.call(rbind, lapply(names(shap_importance), function(v) {",
      "  x <- as.numeric(explain[[v]])",
      "  data.frame(feature = v, shap = shap[, v], value = (x - min(x)) / max(diff(range(x)), 1e-9))   # value scaled 0 to 1",
      "}))",
      "shap_long$feature <- factor(shap_long$feature, levels = rev(names(shap_importance)))",
      if (e == "ggnext") c(
        "shap_labels <- data.frame(feature = factor(levels(shap_long$feature), levels = levels(shap_long$feature)))",
        sn_ylabels_code("shap_labels", "feature", "min(shap_long$shap)", "max(shap_long$shap)", panel_px = 430),
        paste0("p_shap <- ", paste(c("ggnext(shap_long, aes(shap, feature))", "geom_shap(aes(color = value))", "geom_vline(0, dash = \"4 4\")", sn_ylabels_layer("feature", "shap_labels"),
               "labs(title = \"SHAP values (test set)\", x = \"SHAP value\", color = \"Predictor value\")", sn_ylabels_theme()), collapse = " +\n  ")))
      else sn_gg(e, "shap_long, aes(shap, feature, color = value)", c("geom_jitter(height = 0.2, width = 0, alpha = 0.7)", "geom_vline(xintercept = 0, linetype = 2)",
                 "scale_color_gradient(low = \"#2B6BE0\", high = \"#E05A2B\")"), "SHAP values (test set)", "SHAP value", "", "p_shap"))
  )
}

#' Result for a learner run by sn_ml_code().
#' @param extra list(tables = , plots = c(obj = "Title"), notes = ) from the learner.
sn_ml_assemble <- function(env, o, ctx, s, label, extra = list()) {
  n_train <- nrow(env$train); n_test <- nrow(env$test)
  split_note <- sprintf("Trained on %d cases, tested on %d held-out cases (%s%%, seed %d).", n_train, n_test, format(o$test_size), s$seed)
  metric <- function(name, value, ci = c(NA_real_, NA_real_)) { r <- data.frame(metric = name, value = value, stringsAsFactors = FALSE); r$ci <- I(list(as.numeric(ci))); r }
  mcols <- list(sn_col("metric", "Metric", "text"), sn_col("value", "Value", digits = 3), sn_col("ci", "95% CI", "ci", 3))
  tables <- list(); checks <- list()
  if (s$cls) {
    acc <- env$accuracy; cm <- env$confusion; bc <- env$by_class
    rows <- rbind(metric("Accuracy", acc[1], acc[2:3]), metric("Cohen's κ", unname(env$kappa)), metric("Balanced accuracy", mean(bc$sensitivity, na.rm = TRUE)),
                  if (s$binary) metric("AUC", env$auc[1], env$auc[2:3]), metric("No-information rate", env$no_information_rate), metric("Accuracy on training data", env$train_accuracy))
    m <- matrix(as.integer(cm), nrow(cm), dimnames = list(paste("Predicted", rownames(cm)), paste("Actual", colnames(cm))))
    tables <- list(
      sn_table("performance", "Test-Set Performance", mcols, rows, notes = c(split_note, "The no-information rate is the accuracy of always predicting the largest class.")),
      sn_tbl_matrix("confusion", "Confusion Matrix (Test Set)", m, "", type = "int"),
      sn_table("by_class", "Performance by Class", list(sn_col("class", "Class", "text"), sn_col("sensitivity", "Sensitivity (recall)", digits = 3), sn_col("specificity", "Specificity", digits = 3),
        sn_col("precision", "Precision", digits = 3), sn_col("f1", "F1", digits = 3)), bc))
    gap <- env$train_accuracy - acc[1]
    checks <- list(sn_check("overfit", "Overfitting", if (gap > 0.1) "warn" else "ok",
      if (gap > 0.1) sprintf("Accuracy is %.1f points higher on the training data than on the test data; the model may be overfitted.", 100 * gap) else "Training and test accuracy are close."))
    text <- sprintf("A %s predicting %s from %d predictor%s classified %.1f%% of %d held-out cases correctly (95%% CI [%.1f, %.1f]; κ = %s), compared with %.1f%% for always predicting the largest class.%s",
      label, s$y, length(s$predictors), if (length(s$predictors) == 1) "" else "s", 100 * acc[1], n_test, 100 * acc[2], 100 * acc[3], fmt_num(env$kappa, 2), 100 * env$no_information_rate,
      if (s$binary) sprintf(" The AUC was %s.", fmt_num(env$auc[1], 3)) else "")
  } else {
    rows <- rbind(metric("RMSE", env$rmse), metric("MAE", env$mae), metric("R²", env$r2), metric("RMSE on training data", env$train_rmse))
    tables <- list(sn_table("performance", "Test-Set Performance", mcols[1:2], rows[, 1:2], notes = c(split_note, "R² is 1 − SSE/SST on the test set and can be negative for a poor model.")))
    ratio <- env$rmse / env$train_rmse
    checks <- list(sn_check("overfit", "Overfitting", if (isTRUE(ratio > 1.5)) "warn" else "ok",
      if (isTRUE(ratio > 1.5)) sprintf("The test RMSE is %.1f times the training RMSE; the model may be overfitted.", ratio) else "Training and test errors are close."))
    text <- sprintf("A %s predicting %s from %d predictor%s had a test-set RMSE of %s and explained %.1f%% of the variance in %d held-out cases (MAE = %s).",
      label, s$y, length(s$predictors), if (length(s$predictors) == 1) "" else "s", fmt_num(env$rmse, 2), 100 * env$r2, n_test, fmt_num(env$mae, 2))
  }
  if (n_test < 30) checks <- c(checks, list(sn_check("test_size", "Test-set size", "warn", sprintf("Only %d cases were held out, so the performance estimates are imprecise.", n_test))))
  imp <- sn_get(env, "importance")
  if (!is.null(imp)) {
    tables <- c(tables, list(sn_table("importance", "Variable Importance", list(sn_col("variable", "Variable", "text"), sn_col("importance", "Importance", digits = 4)),
      data.frame(variable = names(imp), importance = as.numeric(imp), stringsAsFactors = FALSE), notes = extra$importance_note %||%
        paste0("Permutation importance: ", if (s$cls) "loss of test accuracy" else "rise in test RMSE", " when the predictor is shuffled."))))
    text <- paste0(text, " The most important predictor was ", names(imp)[1], ".")
  }
  sh <- sn_get(env, "shap_importance")
  if (!is.null(sh)) tables <- c(tables, list(sn_table("shap", "SHAP Summary", list(sn_col("variable", "Variable", "text"), sn_col("shap", "Mean |SHAP|", digits = 4)),
    data.frame(variable = names(sh), shap = as.numeric(sh), stringsAsFactors = FALSE),
    notes = c(if (s$cls) paste0("SHAP values are on the probability scale for the class '", env$classes[2], "'.") else paste0("SHAP values are in the units of ", s$y, "."),
              sprintf("Estimated by Monte Carlo sampling (%d permutations) for %d test cases.", env$n_sim, nrow(env$explain))))))
  else if (isTRUE(o$shap)) tables[[1]]$notes <- c(tables[[1]]$notes, "SHAP values are available for numeric and two-class outcomes.")
  sn_result(tables = c(tables, extra$tables), assumptions = checks,
            plots = sn_plots(env, ctx, c(p_performance = if (!s$cls) "Observed vs predicted" else if (s$binary) "ROC curve" else "Confusion matrix",
                                         p_importance = "Variable importance", p_shap = "SHAP values", extra$plots)),
            interpretation = text)
}
