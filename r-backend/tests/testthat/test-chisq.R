# Reference: ?chisq.test example (Agresti 2007, p. 39): X-squared = 30.07, df = 2, p = 2.954e-07.

agresti_session <- function() {
  M <- as.table(rbind(c(762, 327, 468), c(484, 239, 477)))
  dimnames(M) <- list(gender = c("F", "M"), party = c("Democrat", "Independent", "Republican"))
  df <- as.data.frame(M)
  long <- df[rep(seq_len(nrow(df)), df$Freq), c("gender", "party")]
  f <- tempfile(fileext = ".csv")
  write.csv(long, f, row.names = FALSE)
  sess <- new_session()
  sn_import(sess, f)
  sess
}

test_that("chi-square matches the Agresti reference", {
  skip_if_no_pkgs("effectsize")
  sess <- agresti_session()
  res <- sn_run_analysis(sess, "chisq", list(rows = list("gender"), cols = list("party"),
                                              cells = list("expected", "row_pct"), plot = "none"))
  t <- row_of(res, "tests", "test", "Pearson χ²")
  expect_equal(t$stat, 30.07015, tolerance = 1e-5)
  expect_equal(t$df, 2)
  expect_equal(t$p, 2.953589e-07, tolerance = 1e-5)
  ct <- Filter(function(t) t$id == "crosstab", res$tables)[[1]]$rows
  expect_equal(ct$c1[ct$stat == "Count"], c(762, 484))
  expect_equal(ct$total[ct$stat == "% within row"], c(100, 100))
  cv <- Filter(function(t) t$id == "effect", res$tables)[[1]]$rows
  expect_equal(cv$value, sqrt(30.07015 / (2757 * 1)), tolerance = 1e-4)
})
