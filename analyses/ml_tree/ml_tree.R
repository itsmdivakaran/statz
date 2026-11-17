# Decision tree (rpart)

codegen_ml_tree <- function(o, meta, ctx) {
  s <- sn_ml_setup(o, meta, ctx)
  e <- ctx$plot_engine
  fit <- c(
    paste0("set.seed(", s$seed, ")   # cross-validation inside rpart is random"),
    paste0("fit <- rpart::rpart(", s$formula, ", data = train, method = ", sn_lit(if (s$cls) "class" else "anova"),
           ", control = rpart::rpart.control(cp = ", sn_lit(o$cp), ", maxdepth = ", as.integer(o$maxdepth), ", minsplit = ", as.integer(o$minsplit), "))"),
    if (o$prune) c("best_cp <- fit$cptable[which.min(fit$cptable[, \"xerror\"]), \"CP\"]", "fit <- rpart::prune(fit, cp = best_cp)"),
    if (s$cls) "predict_fn <- function(newdata) predict(fit, newdata, type = \"prob\")" else "predict_fn <- function(newdata) as.numeric(predict(fit, newdata))",
    "",
    "# One row per node: the rule that leads to it, its size and its prediction",
    "node_id <- as.integer(rownames(fit$frame))",
    "nodes <- data.frame(node = node_id, depth = floor(log2(node_id)), rule = labels(fit), n = fit$frame$n, leaf = fit$frame$var == \"<leaf>\",",
    if (s$cls) "                    prediction = levels(train[[1]])[fit$frame$yval], stringsAsFactors = FALSE)" else "                    prediction = fit$frame$yval)")
  imp <- "importance <- if (is.null(fit$variable.importance)) numeric() else sort(fit$variable.importance, decreasing = TRUE)   # total improvement from splits (and surrogates)"
  extra <- if (isTRUE(o$tree_plot)) c(
    "# Tree diagram: leaves spread left to right, parents centred above their children",
    "nodes$x <- NA",
    "nodes$x[nodes$leaf] <- seq_len(sum(nodes$leaf))",
    "for (i in rev(which(!nodes$leaf))) nodes$x[i] <- mean(nodes$x[match(2 * nodes$node[i] + 0:1, nodes$node)])",
    "nodes$y <- -nodes$depth",
    "parent <- match(nodes$node %/% 2, nodes$node)",
    "branches <- data.frame(x = nodes$x[parent], y = nodes$y[parent], xend = nodes$x, yend = nodes$y)[-1, ]",
    paste0("nodes$text <- ifelse(nodes$leaf, paste0(", if (s$cls) "nodes$prediction" else "signif(nodes$prediction, 3)", ", \" (n=\", nodes$n, \")\"), \"\")"),
    "splits <- nodes[-1, ]",
    "splits$y <- splits$y + 0.5",
    sn_gg(e, "",
      c("geom_segment(aes(x = x, y = y, xend = xend, yend = yend), data = branches)", paste0("geom_text(aes(x = x, y = y, label = rule), data = splits", if (e == "ggnext") ", fontsize = 10)" else ", size = 3)"),
        paste0("geom_text(aes(x = x, y = y - 0.25, label = text), data = nodes[nodes$leaf, ]", if (e == "ggnext") ", fontsize = 10)" else ", size = 3)")),
      "Decision tree", "", "", "p_tree"),
    if (e == "ggnext") "p_tree <- p_tree + xlim(0, max(nodes$x) + 1) + ylim(min(nodes$y) - 0.6, 0.2) + theme(axis_text_x = FALSE, axis_text_y = FALSE, grid_major_y = FALSE, axis_line_x = FALSE, ticks_x = FALSE, base = theme_modern())"
    else "p_tree <- p_tree + xlim(0, max(nodes$x) + 1) + theme_void()")
  list(code = sn_ml_code(o, meta, ctx, s, "Decision tree", fit, imp, extra), assemble = function(env, o, ctx) {
    nd <- env$nodes; cp <- as.data.frame(env$fit$cptable)
    rows <- data.frame(node = nd$node, rule = paste0(strrep("   ", nd$depth), nd$rule), n = as.integer(nd$n), type = ifelse(nd$leaf, "Leaf", "Split"), stringsAsFactors = FALSE)
    rows$prediction <- if (s$cls) nd$prediction else fmt_num(nd$prediction, 2)
    extra <- list(importance_note = "Total improvement in fit from splits on the variable, including surrogate splits (rpart).",
      plots = c(p_tree = "Decision tree"),
      tables = list(
        sn_table("nodes", "Tree Structure", list(sn_col("node", "Node", "int"), sn_col("rule", "Rule", "text"), sn_col("n", "N", "int"), sn_col("type", "Type", "text"), sn_col("prediction", "Prediction", "text")), rows,
                 notes = sprintf("%d leaves. Indentation shows depth; a case follows the rule that is true for it.", sum(nd$leaf))),
        sn_table("cp", "Complexity Table", list(sn_col("cp", "cp", digits = 4), sn_col("nsplit", "Splits", "int"), sn_col("rel", "Relative error", digits = 3), sn_col("xerror", "Cross-validated error", digits = 3), sn_col("xstd", "SE", digits = 3)),
                 data.frame(cp = cp$CP, nsplit = as.integer(cp$nsplit), rel = cp[["rel error"]], xerror = cp$xerror, xstd = cp$xstd),
                 notes = if (o$prune) "The tree was pruned to the cp with the lowest cross-validated error.")))
    res <- sn_ml_assemble(env, o, ctx, s, "decision tree", extra)
    res
  })
}
