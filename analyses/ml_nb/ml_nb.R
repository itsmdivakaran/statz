# Naive Bayes classifier (e1071)

codegen_ml_nb <- function(o, meta, ctx) {
  s <- sn_ml_setup(o, meta, ctx, "classification")
  fit <- c(
    paste0("fit <- e1071::naiveBayes(", s$formula, ", data = train, laplace = ", sn_lit(o$laplace), ")"),
    "predict_fn <- function(newdata) predict(fit, newdata, type = \"raw\")")
  list(code = sn_ml_code(o, meta, ctx, s, "Naive Bayes", fit), assemble = function(env, o, ctx) {
    pr <- env$fit$apriori
    sn_ml_assemble(env, o, ctx, s, "naive Bayes classifier", list(tables = list(sn_table("priors", "Class Priors (Training Data)",
      list(sn_col("class", "Class", "text"), sn_col("n", "N", "int"), sn_col("prior", "Prior", digits = 3)),
      data.frame(class = names(pr), n = as.integer(pr), prior = as.numeric(pr) / sum(pr), stringsAsFactors = FALSE)))))
  })
}
