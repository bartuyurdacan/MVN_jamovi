#' Multivariate Normality Test (jamovi)
#'
#' Perform multivariate and univariate normality tests with optional
#' outlier detection, descriptive statistics, and data transformations.
#'
#' @param data the data as a data frame
#' @param vars a vector of strings naming the variables of interest in \code{data}
#' @param group a string naming the grouping variable in \code{data}
#' @param mvnTest the multivariate normality test to use
#' @param univariateTest the univariate normality test to use
#' @param showDescriptives \code{TRUE} (default) or \code{FALSE}, show descriptive statistics
#' @param outlierMethod method for outlier detection
#' @param outlierAlpha significance level for outlier detection
#' @param transform marginal transformation to apply
#' @param powerFamily power transformation family
#' @param scale \code{TRUE} or \code{FALSE} (default), standardize data
#' @param impute method for handling missing data
#' @param bootstrap \code{TRUE} or \code{FALSE} (default), use bootstrap p-values
#' @param nBoot number of bootstrap replicates
#' @param showQQPlot \code{TRUE} or \code{FALSE} (default), show multivariate Q-Q plot
#' @param showUniPlots \code{TRUE} or \code{FALSE} (default), show univariate Q-Q plots
#' @param showBoxPlots \code{TRUE} or \code{FALSE} (default), show box plots
#' @param showHistograms \code{TRUE} or \code{FALSE} (default), show histograms
#'
#' @return A results object containing tables and plots
#'
#' @export
mvntest <- function(
    data,
    vars,
    group = NULL,
    mvnTest = "hz",
    univariateTest = "AD",
    showDescriptives = TRUE,
    outlierMethod = "none",
    outlierAlpha = 0.05,
    transform = "none",
    powerFamily = "none",
    scale = FALSE,
    impute = "none",
    bootstrap = FALSE,
    nBoot = 1000,
    showQQPlot = FALSE,
    showUniPlots = FALSE,
    showBoxPlots = FALSE,
    showHistograms = FALSE) {

  if ( ! requireNamespace("jmvcore", quietly = TRUE))
    stop("mvntest requires jmvcore to be installed (jamovi)")

  if ( ! missing(vars)) vars <- jmvcore::resolveQuo(jmvcore::enquo(vars))
  if ( ! missing(group)) group <- jmvcore::resolveQuo(jmvcore::enquo(group))

  options <- mvntestOptions$new(
    vars = vars,
    group = group,
    mvnTest = mvnTest,
    univariateTest = univariateTest,
    showDescriptives = showDescriptives,
    outlierMethod = outlierMethod,
    outlierAlpha = outlierAlpha,
    transform = transform,
    powerFamily = powerFamily,
    scale = scale,
    impute = impute,
    bootstrap = bootstrap,
    nBoot = nBoot,
    showQQPlot = showQQPlot,
    showUniPlots = showUniPlots,
    showBoxPlots = showBoxPlots,
    showHistograms = showHistograms)

  analysis <- mvntestClass$new(
    options = options,
    data = data)

  analysis$run()

  analysis$results
}
