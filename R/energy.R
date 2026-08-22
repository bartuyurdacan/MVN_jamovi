#' E-Statistic Test for Multivariate Normality (Energy Test)
#'
#' Performs the E-statistic test for multivariate normality using a parametric bootstrap
#' to estimate the null distribution of the test statistic.
#'
#' @param data A numeric matrix or data frame with observations in rows and variables in columns.
#' @param B Integer; number of bootstrap replicates to estimate the null distribution. Default is 1000.
#' @param seed Optional integer to set the random seed for reproducibility.
#'
#' @return A data frame with one row containing the following columns:
#' \code{Test}, the name of the test ("E-Statistic");
#' \code{Statistic}, the observed E-statistic;
#' and \code{p.value}, the p-value obtained from the bootstrap procedure.
#'
#' @examples
#' \dontrun{
#' data <- iris[1:50, 1:4]
#' energy_result <- energy(data, B = 500)
#' energy_result
#' }
#'
#' @importFrom boot boot
#' @importFrom stats complete.cases rnorm
#' @importFrom moments skewness kurtosis
#' @export
energy <- function(data, B = 1000, seed = NULL) {
  # Convert to data frame and drop non-numeric columns
  df <- as.data.frame(data)
  num_cols <- vapply(df, is.numeric, logical(1))
  if (!all(num_cols)) {
    warning("Dropping non-numeric columns: ", paste(names(df)[!num_cols], collapse=", "))
    df <- df[, num_cols, drop = FALSE]
  }
  if (ncol(df) < 1) stop("Need at least one numeric variable for E-statistic test.")
  
  # Handle missing values
  keep <- stats::complete.cases(df)
  dropped <- sum(!keep)
  if (dropped > 0) warning(sprintf("%d rows with missing values removed.", dropped))
  df <- df[keep, , drop = FALSE]
  
  # Convert to matrix and dimensions
  x <- as.matrix(df)
  n <- nrow(x)
  d <- ncol(x)
  
  # Define parametric bootstrap generator
  ran_gen <- function(data, mle) {
    matrix(stats::rnorm(n * d), nrow = n, ncol = d)
  }
  
  if (!is.null(seed)) {
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv)
      on.exit(assign(".Random.seed", old_seed, envir = .GlobalEnv), add = TRUE)
    } else {
      on.exit(rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
    }
    set.seed(seed)
  }
  
  # Perform bootstrap
  boot_obj <- boot::boot(
    data      = x,
    statistic = energy::mvnorm.e,
    R         = B,
    sim       = "parametric",
    ran.gen   = ran_gen
  )
  
  # Compute p-value and observed statistic
  if (B > 0) {
    p_val <- (1 + sum(boot_obj$t >= boot_obj$t0)) / (length(boot_obj$t) + 1)
  } else {
    p_val <- NA_real_
  }
  stat_obs <- boot_obj$t0

  # Assemble results
  result <- data.frame(
    Test      = "E-Statistic",
    Statistic = stat_obs,
    p.value   = p_val,
    Method = "bootstrap",
    stringsAsFactors = FALSE
  )
  return(result)
}
