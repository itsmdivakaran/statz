# Cox proportional hazards regression with hazard ratios and a proportional-hazards check

codegen_surv_cox <- function(o, meta, ctx) {
  sn_need_predictors(o)
  tm <- o$time; ev <- o$event; cov <- o$covariates; fac <- o$factors
  terms <- c(cov, fac, o$interactions)
  en <- sn_event_name(c(tm, cov, fac))
  code <- sn_code(
    sn_libs(c("survival", if (length(o$plot)) ctx$plot_engine)),
    "",
    paste0("# Cox regression: ", tm, " on ", paste(c(cov, fac), collapse = ", ")),
    sn_prep_code("d", ctx$data, c(tm, ev, cov, fac), meta, factors = fac),
    sn_event_code("d", ev, o$event_level, en),
    paste0("fit <- coxph(", sn_formula(paste0("Surv(", sn_name(tm), ", ", en, ")"), terms), ", data = d, ties = ", sn_lit(o$ties), ")"),
    "fit_summary <- summary(fit)",
    paste0("coefs <- cbind(coef(fit_summary)[, c(\"coef\", \"se(coef)\", \"z\", \"Pr(>|z|)\"), drop = FALSE], confint(fit, level = ", sn_lit(o$conf_level), "))"),
    if ("ph" %in% o$diagnostics) "ph <- cox.zph(fit)",
    if ("forest" %in% o$plot) c(
      "# Hazard ratios with confidence limits",
      sn_coef_df_code(rows = "", exp = TRUE),
      sn_forest_plot_code(ctx$plot_engine, title = "Hazard ratios", xlab = paste0("Hazard ratio (", sn_pct(o$conf_level), ")"), ref = 1))
  )
  list(code = code, assemble = assemble_surv_cox)
}

assemble_surv_cox <- function(env, o, ctx) {
  s <- env$fit_summary; fit <- env$fit
  lt <- s$logtest; cc <- s$concordance
  fit_tb <- sn_table("fit", "Model Fit", list(sn_col("n", "N", "int"), sn_col("events", "Events", "int"), sn_col("chi", "χ² (LR)"), sn_col("df", "df", "int"),
    sn_col("p", "p", "pvalue"), sn_col("c", "Concordance", digits = 3), sn_col("c_se", "SE", digits = 3), sn_col("aic", "AIC")),
    data.frame(n = as.integer(s$n), events = as.integer(s$nevent), chi = unname(lt["test"]), df = as.integer(lt["df"]), p = unname(lt["pvalue"]),
               c = unname(cc[1]), c_se = unname(cc[2]), aic = stats::AIC(fit)))
  coef_tb <- sn_tbl_coefs(env$coefs, o, "z", "Hazard ratio",
    notes = c("Hazard ratios above 1 mean a higher event rate.", if (length(o$factors)) "Factor terms compare each level with the first (reference) level."))
  checks <- list()
  epv <- s$nevent / nrow(env$coefs)
  checks <- c(checks, list(sn_check("epv", "Events per coefficient", if (epv < 10) "warn" else "ok",
    paste0(fmt_num(epv, 1), " events per estimated coefficient", if (epv < 10) "; fewer than 10 makes estimates unstable." else "."))))
  ph <- sn_get(env, "ph")
  if (!is.null(ph)) {
    tb <- ph$table; bad <- rownames(tb)[tb[, "p"] < 0.05 & rownames(tb) != "GLOBAL"]
    gp <- tb["GLOBAL", "p"]
    checks <- c(checks, list(sn_check("ph", "Proportional hazards (Schoenfeld residuals)", if (length(bad) || gp < 0.05) "warn" else "ok",
      if (length(bad)) paste0("The hazard ratio changes over time for ", paste(bad, collapse = ", "), "; consider stratifying or a time-varying effect.")
      else if (gp < 0.05) "The global test suggests non-proportional hazards." else "No evidence against proportional hazards.",
      sn_table("ph", "Proportional Hazards Test", list(sn_col("term", "Term", "text"), sn_col("chi", "χ²"), sn_col("df", "df"), sn_col("p", "p", "pvalue")),
               data.frame(term = rownames(tb), chi = tb[, "chisq"], df = tb[, "df"], p = tb[, "p"], row.names = NULL)))))
  }
  rows <- coef_tb$rows; sig <- rows[rows$p < 0.05, ]
  text <- paste0("The Cox model was fitted to ", s$n, " cases with ", s$nevent, " events, likelihood-ratio χ²(", lt["df"], ") = ", fmt_num(lt["test"]), ", ",
    apa_p(lt["pvalue"]), "; concordance = ", fmt_num(cc[1]), ". ",
    if (nrow(sig)) paste0("Significant predictors: ", paste0(sig$term, " (HR = ", fmt_num(sig$exp), ")", collapse = ", "), ".") else "No predictor was significant.")
  sn_result(tables = list(fit_tb, coef_tb), assumptions = checks, plots = sn_plots(env, ctx, list(p_coef = "Hazard ratios")), interpretation = text)
}
