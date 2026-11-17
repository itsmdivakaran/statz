# Reference: PlantGrowth (Dobson 1983), F(2, 27) = 4.846, p = 0.0159; Tukey trt2-trt1 diff 0.865, p = 0.012.

test_that("one-way ANOVA matches reference values", {
  skip_if_no_pkgs("effectsize", "car")
  sess <- new_session("plantgrowth")
  res <- sn_run_analysis(sess, "anova_oneway", list(dv = list("weight"), group = list("group"),
                                                     test = list("fisher", "welch", "kruskal"), plot = "none"))
  a <- row_of(res, "anova", "source", "group")
  expect_equal(a$F, 4.846, tolerance = 1e-3)
  expect_equal(a$df, 2L)
  expect_equal(a$p, 0.01591, tolerance = 1e-3)
  expect_equal(a$eta, 3.76634 / (3.76634 + 10.49209), tolerance = 1e-5)
  w <- row_of(res, "robust", "test", "Welch")
  ref <- oneway.test(weight ~ group, data = PlantGrowth)
  expect_equal(w$stat, unname(ref$statistic))
  expect_equal(w$df2, unname(ref$parameter[2]))
  ph <- Filter(function(t) t$id == "posthoc", res$tables)[[1]]$rows
  expect_equal(ph$diff[3], 0.865, tolerance = 1e-6)
  expect_equal(ph$p[3], 0.012, tolerance = 1e-2)
})

test_that("grouping variable needs at least 2 levels", {
  sess <- new_session("plantgrowth")
  statnextr:::sn_data_patch(sess, "data", list())
  sess$datasets$data$data$one <- "a"
  sess$datasets$data$meta$variables$one <- list(name = "one", measure = "nominal")
  expect_error(sn_run_analysis(sess, "anova_oneway", list(dv = list("weight"), group = list("one"))),
               class = "sn_error")
})
