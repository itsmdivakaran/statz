test_that("codegen helpers quote non-syntactic names", {
  expect_equal(sn_name("mpg"), "mpg")
  expect_equal(sn_name("my var"), "`my var`")
  expect_equal(sn_ref("d", "my var"), "d[[\"my var\"]]")
  expect_equal(sn_lit(c(0, 1)), "c(0, 1)")
  expect_equal(fmt_p(c(0.0004, 0.0123, 0.5)), c("< .001", ".012", ".500"))
  expect_equal(fmt_num(-1.234), "−1.23")
})

test_that("option validation rejects bad input", {
  sess <- new_session("mtcars")
  expect_error(sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"))), class = "sn_error")
  expect_error(sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("cyl"))),
               "3 levels")
  expect_error(sn_run_analysis(sess, "ttest_ind", list(dv = list("model"), group = list("am"))),
               "nominal")
  expect_error(sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("am"), test = list("nope"))),
               "Invalid value")
})

test_that("data edits are applied through logged code", {
  sess <- new_session("mtcars")
  statnextr:::sn_data_patch(sess, "data", list(
    list(op = "set_cell", row = 0, column = "mpg", value = "99"),
    list(op = "rename", from = "hp", to = "horse power")))
  d <- sess$datasets$data$data
  expect_equal(d$mpg[1], 99)
  expect_true("horse power" %in% names(d))
  script <- statnextr:::sn_session_script(sess)
  expect_match(script, "data[1, \"mpg\"] <- 99", fixed = TRUE)
  sl <- statnextr:::sn_data_slice(sess, "data", 30, 10)
  expect_equal(length(sl$columns$mpg), 2)
})

test_that("JSON-RPC handler returns results and structured errors", {
  sess <- new_session("mtcars")
  ok <- jsonlite::fromJSON(statnextr:::sn_handle_line(sess,
    '{"jsonrpc":"2.0","id":1,"method":"data.info","params":{}}'), simplifyVector = FALSE)
  expect_equal(ok$result$nrow, 32)
  err <- jsonlite::fromJSON(statnextr:::sn_handle_line(sess,
    '{"jsonrpc":"2.0","id":2,"method":"analysis.run","params":{"module":"ttest_ind","options":{"dv":["mpg"]}}}'),
    simplifyVector = FALSE)
  expect_equal(err$error$code, -32003)
  bad <- jsonlite::fromJSON(statnextr:::sn_handle_line(sess, "not json"), simplifyVector = FALSE)
  expect_equal(bad$error$code, -32700)
  expect_null(statnextr:::sn_handle_line(sess, '{"jsonrpc":"2.0","method":"data.info"}'))
})

test_that("printed output never leaks into the protocol stream", {
  sess <- new_session("mtcars")
  out <- capture.output(resp <- statnextr:::sn_handle_line(sess,
    '{"jsonrpc":"2.0","id":3,"method":"code.run","params":{"code":"print(1:3); x <- 1"}}'))
  expect_length(out, 0)
  expect_match(jsonlite::fromJSON(resp)$result$console, "1 2 3")
})

test_that("plots render to svg and html", {
  skip_if_no_pkgs("ggnext", "effectsize", "car")
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("am")))
  pl <- res$plots[[1]]
  expect_equal(pl$engine, "ggnext")
  expect_false(pl$fallback)
  expect_true(file.exists(pl$svg) && file.exists(pl$html))
  skip_if_no_pkgs("rsvg")
  png <- tempfile(fileext = ".png")
  statnextr:::sn_export_plot(sess, pl$id, "png", png)
  expect_gt(file.size(png), 1000)
})
