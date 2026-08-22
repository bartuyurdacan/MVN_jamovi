test_that("grouped analysis skips sparse and empty levels without aborting", {
  data <- iris[1:20, 1:4]
  data$group <- factor(
    c(rep("adequate", 18), "sparse", "sparse"),
    levels = c("adequate", "sparse", "empty")
  )

  result <- expect_no_error(
    mvntest(
      data = data,
      vars = names(data)[1:4],
      group = "group"
    )
  )

  expect_s3_class(result, "mvntestResults")
  expect_true("groupWarnings" %in% result$itemNames)

  notice <- result$get("groupWarnings")
  expect_s3_class(notice, "Notice")
  expect_match(notice$content, "sparse")
  expect_false(grepl("empty", notice$content, fixed = TRUE))
})


test_that("explicit seeds do not overwrite the caller RNG state", {
  data <- iris[1:20, 1:3]

  set.seed(20260822)
  rng_before <- .Random.seed
  expect_no_error(energy(data, B = 10, seed = 123))
  expect_identical(.Random.seed, rng_before)

  skip_if_not_installed("mice")
  incomplete <- data
  incomplete[seq(1, nrow(incomplete), by = 5), 1] <- NA_real_

  set.seed(20260823)
  rng_before <- .Random.seed
  expect_no_error(
    suppressMessages(
      impute_missing(
        incomplete,
        method = "mice",
        m = 1,
        seed = 123,
        maxit = 1
      )
    )
  )
  expect_identical(.Random.seed, rng_before)
})


test_that("bootstrap normality tests return positive Monte Carlo p-values", {
  data <- iris[1:30, 1:3]
  B <- 10

  results <- list(
    mardia(data, bootstrap = TRUE, B = B),
    hz(data, bootstrap = TRUE, B = B),
    hw(data, bootstrap = TRUE, B = B),
    royston(data, bootstrap = TRUE, B = B),
    doornik_hansen(data, bootstrap = TRUE, B = B),
    energy(data, B = B, seed = 123)
  )

  p_values <- unlist(lapply(results, function(result) result$p.value))
  expect_true(all(is.finite(p_values)))
  expect_true(all(p_values >= 1 / (B + 1)))
  expect_true(all(p_values <= 1))
})
