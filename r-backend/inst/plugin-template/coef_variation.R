# Coefficient of variation: a starter StatNext plugin.
#
# codegen_<id>(o, meta, ctx) receives the validated options `o` (one entry per role and option
# in spec.json), the variable metadata `meta` and a context `ctx` (ctx$data is the name of the
# data frame in the generated code). It returns:
#   code     - plain R text. StatNext runs exactly this text and shows it in the R Code tab.
#   assemble - function(env, o, ctx) that turns the objects the code created (in `env`)
#              into tables, plots and a written interpretation.

codegen_coef_variation <- function(o, meta, ctx) {
  vars <- unlist(o$vars)
  g <- unlist(o$group)
  scale <- if (isTRUE(o$percent)) " * 100" else ""
  code <- c(
    "# Coefficient of variation = SD / mean",
    paste0("vars <- ", sn_lit(vars)),
    if (length(g)) paste0("groups <- split(", ctx$data, ", ", sn_ref(ctx$data, g), ")")
    else paste0("groups <- list(All = ", ctx$data, ")"),
    "cv <- do.call(rbind, lapply(names(groups), function(gr) {",
    "  d <- groups[[gr]]",
    "  data.frame(group = gr, variable = vars,",
    "             n = sapply(vars, function(v) sum(!is.na(d[[v]]))),",
    "             mean = sapply(vars, function(v) mean(d[[v]], na.rm = TRUE)),",
    "             sd = sapply(vars, function(v) sd(d[[v]], na.rm = TRUE)))",
    "}))",
    paste0("cv$cv <- cv$sd / cv$mean", scale),
    "cv"
  )
  list(code = paste(code, collapse = "\n"), assemble = assemble_coef_variation)
}

assemble_coef_variation <- function(env, o, ctx) {
  cv <- get("cv", envir = env)
  label <- if (isTRUE(o$percent)) "CV (%)" else "CV"
  table <- sn_table("cv", "Coefficient of Variation", list(
    sn_col("group", "Group", "text"), sn_col("variable", "Variable", "text"), sn_col("n", "N", "int"),
    sn_col("mean", "Mean", digits = o$digits), sn_col("sd", "SD", digits = o$digits), sn_col("cv", label, digits = o$digits)),
    cv, notes = "CV = standard deviation / mean. It is only meaningful for ratio-scale variables with a positive mean.")
  top <- cv[which.max(cv$cv), ]
  sn_result(tables = list(table),
            interpretation = paste0("The largest relative spread was for ", top$variable,
                                    if (length(o$group)) paste0(" in group ", top$group), " (", label, " = ",
                                    round(top$cv, o$digits), ")."))
}
