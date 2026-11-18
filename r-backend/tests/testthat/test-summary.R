test_that("plain-language summaries come from easystats report and are in the code", {
  skip_if_no_pkgs("effectsize", "report")
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("am"),
                                                  test = list("welch"), plot = "none"))
  expect_length(res$summary, 1L)
  expect_equal(res$summary[[1]]$object, "welch")
  expect_match(res$summary[[1]]$text, "Welch")
  expect_match(res$code, "report_welch <- report(welch)", fixed = TRUE)

  res <- sn_run_analysis(sess, "reg_linear", list(dv = list("mpg"), covariates = list("wt", "hp"), plot = list()))
  expect_gte(length(res$summary), 1L)
  expect_match(res$summary[[1]]$text, "linear model", ignore.case = TRUE)

  off <- sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("am"), test = list("welch"),
                                                  plot = "none"), summaries = FALSE)
  expect_length(off$summary, 0L)
  expect_false(grepl("report(", off$code, fixed = TRUE))
})

test_that("objects that are not models or tests get no summary", {
  sess <- new_session("mtcars")
  expect_null(sn_summaries("x <- 1", list2env(list(x = 1))))
})
